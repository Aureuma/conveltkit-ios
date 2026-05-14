# ConveltKit 0.1.109

Patch release to add authenticated proxy support for Lingospeak's Convelt client routes.

- Add `ConveltClient.bindAuthorizationBearerToken(_:)`.
- Include `Authorization: Bearer <token>` on Convelt client API requests when bound.
- Keeps existing API behavior unchanged when no token is bound.
