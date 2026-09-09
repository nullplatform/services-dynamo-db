# Changelog

## [0.3.0](https://github.com/nullplatform/services-dynamo-db/compare/v0.2.0...v0.3.0) (2026-09-09)


### Features

* **ci:** build+push the worker image and register its artifact on release ([#5](https://github.com/nullplatform/services-dynamo-db/issues/5)) ([add027e](https://github.com/nullplatform/services-dynamo-db/commit/add027e81f87f57f8352cf457bdeb60589173e6b))

## [0.2.0](https://github.com/nullplatform/services-dynamo-db/compare/v0.1.0...v0.2.0) (2026-08-07)


### Features

* **trigger:** restrict the link to scopes ([#3](https://github.com/nullplatform/services-dynamo-db/issues/3)) ([91beb15](https://github.com/nullplatform/services-dynamo-db/commit/91beb15bccabf4f322fc496210026087bbad71f2))

## [0.1.0](https://github.com/nullplatform/services-dynamo-db/compare/0.0.1...v0.1.0) (2026-07-31)


### Features

* agent permissions role ([9407b61](https://github.com/nullplatform/services-dynamo-db/commit/9407b61cd007328fe35b364deeae60c727a1837b))
* assume role from identity-access-control provider ([2374e90](https://github.com/nullplatform/services-dynamo-db/commit/2374e9054621ec04f618915cf0eb38247be9946a))
* dynamodb table with streams, ttl, gsi and deletion protection ([3d18f36](https://github.com/nullplatform/services-dynamo-db/commit/3d18f3634f346906634113be41b76ed5c0af37c1))
* entrypoints and tofu execution ([d4fa693](https://github.com/nullplatform/services-dynamo-db/commit/d4fa6937a95a2dff373733bf18e8caf669f6c10c))
* per-link iam user with access levels ([480102d](https://github.com/nullplatform/services-dynamo-db/commit/480102dcca52eb1f4af518bd4977aa4f5dd77a79))
* service and connect link specs ([60d6416](https://github.com/nullplatform/services-dynamo-db/commit/60d6416f115e2283ca579bbc05123e73fe1dea6e))
* service and link workflows ([bbfaeef](https://github.com/nullplatform/services-dynamo-db/commit/bbfaeef4daa0d1a61fa7838c4cc5831a1d89a1f1))
* service context building and output persistence ([b519c34](https://github.com/nullplatform/services-dynamo-db/commit/b519c349cdc21e2c19014e0b95827b34f2b29433))
* trigger link wiring table streams to lambda ([f048150](https://github.com/nullplatform/services-dynamo-db/commit/f048150ba2076ed5a4e9add187b9ae496219ba6a))


### Bug Fixes

* allow tag reads on the mapping and point it at the alias ([7ec3728](https://github.com/nullplatform/services-dynamo-db/commit/7ec3728cf69b201751b44806697488011098c502))
* allow the reads the lambda data source actually performs ([5c84c68](https://github.com/nullplatform/services-dynamo-db/commit/5c84c687479659dba2adcd0833e3783a1fc58c20))
* fail with a clear message when the trigger target has no alias ([20aeca1](https://github.com/nullplatform/services-dynamo-db/commit/20aeca116deaa2a0bbd38ae5bdfddc7edc461a89))
* isolate link workspaces so a link cannot destroy the table ([b0316ab](https://github.com/nullplatform/services-dynamo-db/commit/b0316abb533d28025a6c2e95c93e01b00d603cc1))
* read the linked scope from the context tags ([9539879](https://github.com/nullplatform/services-dynamo-db/commit/9539879ff3faeda3a760d26b4b23b1a3e898f86a))
* reject a sort key equal to the partition key with a readable error ([00d307c](https://github.com/nullplatform/services-dynamo-db/commit/00d307c4cc6020e4f927433d614d71b0a1ced1b8))
* resolve the service name from the api when the context omits it ([eda4986](https://github.com/nullplatform/services-dynamo-db/commit/eda4986e88355852116a5524cbcc2e7294c4d92c))
* stop the connect link from exporting what the service already exports ([f7da500](https://github.com/nullplatform/services-dynamo-db/commit/f7da5005e89cba1da8b1b9672c03248a2dc53d78))
