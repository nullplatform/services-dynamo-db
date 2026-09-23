#!/bin/bash
# Usage: tests/state_bucket.sh [build_context] [delete_tfstate_bucket]
set -uo pipefail

BUILD_CONTEXT="${1:-dynamodb/scripts/aws/build_context}"
DELETE_STATE="${2:-dynamodb/scripts/aws/delete_tfstate_bucket}"
BUCKET_VAR="DYNAMO_S3_STATE_BUCKET"
SERVICE_ID="11111111-2222-3333-4444-555555555555"
PASS=0
FAIL=0

for f in "$BUILD_CONTEXT" "$DELETE_STATE"; do
	if [ ! -f "$f" ]; then
		echo "not found: $f" >&2
		exit 1
	fi
done

BUILD_CONTEXT="$(cd "$(dirname "$BUILD_CONTEXT")" && pwd)/$(basename "$BUILD_CONTEXT")"
DELETE_STATE="$(cd "$(dirname "$DELETE_STATE")" && pwd)/$(basename "$DELETE_STATE")"

check() {
	local name="$1" verdict="$2" detail="${3:-}"
	if [ "$verdict" = "ok" ]; then
		echo "  PASS: $name"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $name"
		if [ -n "$detail" ]; then echo "        $detail"; fi
		FAIL=$((FAIL + 1))
	fi
}

setup_sandbox() {
	SANDBOX="$(mktemp -d)"
	mkdir -p "$SANDBOX/bin"
	: > "$SANDBOX/aws.log"
	: > "$SANDBOX/values.yaml"

	# Buckets the fake account already has. head-bucket succeeds only for these.
	printf '%s\n' "$@" > "$SANDBOX/existing_buckets"

	cat > "$SANDBOX/bin/aws" <<'EOS'
#!/bin/bash
echo "aws $*" >> "$AWS_LOG"
bucket=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--bucket" ]; then bucket="$a"; fi
  prev="$a"
done
if [ "$1 $2" = "s3api head-bucket" ]; then
  grep -qxF "$bucket" "$EXISTING_BUCKETS" || exit 255
  exit 0
fi
if [ "$1 $2" = "s3api create-bucket" ]; then
  echo "$bucket" >> "$EXISTING_BUCKETS"
  exit 0
fi
if [ "$1 $2" = "s3api list-object-versions" ]; then
  echo 'null'
  exit 0
fi
exit 0
EOS

	cat > "$SANDBOX/bin/np" <<'EOS'
#!/bin/bash
case "$1 $2" in
  "provider list")
    echo '{"results":[{"id":"prov-1","data_source":{"stored_keys":["account.region"]}}]}'
    ;;
  "provider read")
    echo '{"attributes":{"account":{"region":"us-east-1"}}}'
    ;;
  "service read")
    echo '{"name":"test-dynamo"}'
    ;;
  *)
    echo '{}'
    ;;
esac
exit 0
EOS

	cat > "$SANDBOX/run_build_context.sh" <<'EOS'
#!/bin/bash
source "$1" >"$2" 2>"$3"
printf 'TFSTATE_BUCKET=%s\n' "${TFSTATE_BUCKET-}"
printf 'TFSTATE_KEY_PREFIX=%s\n' "${TFSTATE_KEY_PREFIX-}"
printf 'TOFU_INIT_VARIABLES=%s\n' "${TOFU_INIT_VARIABLES-}"
EOS

	chmod +x "$SANDBOX/bin/aws" "$SANDBOX/bin/np" "$SANDBOX/run_build_context.sh"

	CONTEXT_JSON="$(cat <<EOS
{"service":{"id":"${SERVICE_ID}","name":"test-dynamo","nrn":"organization=1:account=2:namespace=3:application=4","attributes":{"hash_key":"pk"}}}
EOS
)"
}

teardown_sandbox() {
	rm -rf "${SANDBOX:?}"
	rm -rf "/tmp/np-service-${SERVICE_ID:?}"
}

# Runs build_context with the bucket variable either unset, or set to $1.
run_build_context() {
	local mode="$1" value="${2:-}"
	if [ "$mode" = "unset" ]; then
		env -u "$BUCKET_VAR" \
			PATH="$SANDBOX/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			AWS_LOG="$SANDBOX/aws.log" EXISTING_BUCKETS="$SANDBOX/existing_buckets" \
			CONTEXT="$CONTEXT_JSON" VALUES="$SANDBOX/values.yaml" SERVICE_PATH="$SANDBOX" \
			bash "$SANDBOX/run_build_context.sh" "$BUILD_CONTEXT" "$SANDBOX/out.log" "$SANDBOX/err.log"
	else
		env "$BUCKET_VAR=$value" \
			PATH="$SANDBOX/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			AWS_LOG="$SANDBOX/aws.log" EXISTING_BUCKETS="$SANDBOX/existing_buckets" \
			CONTEXT="$CONTEXT_JSON" VALUES="$SANDBOX/values.yaml" SERVICE_PATH="$SANDBOX" \
			bash "$SANDBOX/run_build_context.sh" "$BUILD_CONTEXT" "$SANDBOX/out.log" "$SANDBOX/err.log"
	fi
}

run_delete_state() {
	local mode="$1" value="${2:-}" prefix="${3:-}"
	if [ "$mode" = "unset" ]; then
		env -u "$BUCKET_VAR" \
			PATH="$SANDBOX/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			AWS_LOG="$SANDBOX/aws.log" EXISTING_BUCKETS="$SANDBOX/existing_buckets" \
			REGION=us-east-1 TFSTATE_BUCKET=state-bucket TFSTATE_KEY_PREFIX="$prefix" \
			bash "$DELETE_STATE" 2>&1
	else
		env "$BUCKET_VAR=$value" \
			PATH="$SANDBOX/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			AWS_LOG="$SANDBOX/aws.log" EXISTING_BUCKETS="$SANDBOX/existing_buckets" \
			REGION=us-east-1 TFSTATE_BUCKET=state-bucket TFSTATE_KEY_PREFIX="$prefix" \
			bash "$DELETE_STATE" 2>&1
	fi
}

field() {
	echo "$1" | sed -n "s/^$2=//p"
}

echo "=== shared bucket configured and reachable ==="
setup_sandbox shared-state
out="$(run_build_context set shared-state)"
check_bucket="$(field "$out" TFSTATE_BUCKET)"
check_prefix="$(field "$out" TFSTATE_KEY_PREFIX)"
check_init="$(field "$out" TOFU_INIT_VARIABLES)"
if [ "$check_bucket" = "shared-state" ]; then
	check "uses the configured bucket" "ok"
else
	check "uses the configured bucket" "bad" "got '$check_bucket'"
fi
if [ "$check_prefix" = "services/${SERVICE_ID}/" ]; then
	check "prefixes the key with the service id" "ok"
else
	check "prefixes the key with the service id" "bad" "got '$check_prefix'"
fi
if echo "$check_init" | grep -qF -- "-backend-config=key=services/${SERVICE_ID}/terraform.tfstate"; then
	check "backend key lands under the prefix" "ok"
else
	check "backend key lands under the prefix" "bad" "got '$check_init'"
fi
if grep -q 'create-bucket' "$SANDBOX/aws.log"; then
	check "never creates a bucket" "bad" "$(grep create-bucket "$SANDBOX/aws.log" | head -1)"
else
	check "never creates a bucket" "ok"
fi
teardown_sandbox

echo "=== shared bucket configured but missing ==="
setup_sandbox some-other-bucket
out="$(run_build_context set shared-state)"
rc=$?
err="$(cat "$SANDBOX/err.log" 2>/dev/null)"
if [ "$rc" -ne 0 ]; then
	check "aborts when the bucket does not exist" "ok"
else
	check "aborts when the bucket does not exist" "bad" "rc=$rc"
fi
if echo "$err" | grep -q 'does not exist or is not reachable'; then
	check "says the bucket is unreachable" "ok"
else
	check "says the bucket is unreachable" "bad" "stderr: $(echo "$err" | tr '\n' '|')"
fi
if grep -q 'create-bucket' "$SANDBOX/aws.log"; then
	check "does not fall back to creating it" "bad"
else
	check "does not fall back to creating it" "ok"
fi
teardown_sandbox

echo "=== bucket variable set but empty ==="
setup_sandbox shared-state
out="$(run_build_context set "")"
rc=$?
err="$(cat "$SANDBOX/err.log" 2>/dev/null)"
if [ "$rc" -ne 0 ]; then
	check "treats set-but-empty as a config error" "ok"
else
	check "treats set-but-empty as a config error" "bad" "rc=$rc bucket='$(field "$out" TFSTATE_BUCKET)'"
fi
if echo "$err" | grep -q 'set but empty'; then
	check "names the empty variable" "ok"
else
	check "names the empty variable" "bad" "stderr: $(echo "$err" | tr '\n' '|')"
fi
if grep -q 'create-bucket' "$SANDBOX/aws.log"; then
	check "does not silently use the deprecated path" "bad" "$(grep create-bucket "$SANDBOX/aws.log" | head -1)"
else
	check "does not silently use the deprecated path" "ok"
fi
teardown_sandbox

echo "=== bucket variable unset: deprecated per-instance bucket ==="
setup_sandbox
out="$(run_build_context unset)"
err="$(cat "$SANDBOX/err.log" 2>/dev/null)"
if [ "$(field "$out" TFSTATE_BUCKET)" = "np-service-${SERVICE_ID}" ]; then
	check "falls back to the per-instance bucket" "ok"
else
	check "falls back to the per-instance bucket" "bad" "got '$(field "$out" TFSTATE_BUCKET)'"
fi
if [ -z "$(field "$out" TFSTATE_KEY_PREFIX)" ]; then
	check "leaves the key prefix empty" "ok"
else
	check "leaves the key prefix empty" "bad" "got '$(field "$out" TFSTATE_KEY_PREFIX)'"
fi
if field "$out" TOFU_INIT_VARIABLES | grep -qF -- "-backend-config=key=terraform.tfstate"; then
	check "keeps the legacy backend key unchanged" "ok"
else
	check "keeps the legacy backend key unchanged" "bad" "got '$(field "$out" TOFU_INIT_VARIABLES)'"
fi
if grep -q 'create-bucket' "$SANDBOX/aws.log"; then
	check "creates the bucket it owns" "ok"
else
	check "creates the bucket it owns" "bad" "$(cat "$SANDBOX/aws.log" | tr '\n' '|')"
fi
if echo "$err" | grep -qi 'deprecated'; then
	check "warns that the fallback is deprecated" "ok"
else
	check "warns that the fallback is deprecated" "bad" "stderr: $(echo "$err" | tr '\n' '|')"
fi
teardown_sandbox

echo "=== delete: shared bucket keeps the bucket, empties the prefix ==="
setup_sandbox state-bucket
out="$(run_delete_state set shared-state "services/${SERVICE_ID}/")"
if grep -q -- "--prefix services/${SERVICE_ID}/" "$SANDBOX/aws.log"; then
	check "scopes the listing to its own prefix" "ok"
else
	check "scopes the listing to its own prefix" "bad" "$(cat "$SANDBOX/aws.log" | tr '\n' '|')"
fi
if grep -q 'delete-bucket' "$SANDBOX/aws.log"; then
	check "never deletes the shared bucket" "bad" "$(grep delete-bucket "$SANDBOX/aws.log" | head -1)"
else
	check "never deletes the shared bucket" "ok"
fi
teardown_sandbox

echo "=== delete: legacy per-instance bucket is removed ==="
setup_sandbox state-bucket
out="$(run_delete_state unset "" "")"
if grep -q 'delete-bucket' "$SANDBOX/aws.log"; then
	check "deletes the bucket it owns" "ok"
else
	check "deletes the bucket it owns" "bad" "$(cat "$SANDBOX/aws.log" | tr '\n' '|')"
fi
teardown_sandbox

echo "=== delete: shared bucket with an empty prefix is refused ==="
setup_sandbox state-bucket
out="$(run_delete_state set shared-state "")"
rc=$?
if [ "$rc" -ne 0 ]; then
	check "refuses the dangerous combination" "ok"
else
	check "refuses the dangerous combination" "bad" "rc=$rc"
fi
if echo "$out" | grep -q 'every service'; then
	check "explains it would wipe every service's state" "ok"
else
	check "explains it would wipe every service's state" "bad" "out: $(echo "$out" | tr '\n' '|')"
fi
if grep -qE 'delete-objects|delete-bucket' "$SANDBOX/aws.log"; then
	check "deletes nothing at all" "bad" "$(cat "$SANDBOX/aws.log" | tr '\n' '|')"
else
	check "deletes nothing at all" "ok"
fi
teardown_sandbox

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
