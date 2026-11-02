# Assets

Three lanes, one catalog.

- `repo/` is committed. Only CC0, CC-BY, MIT, OFL or public domain. Every entry is credited.
- `embed/` is not committed. EULA or royalty free files that are baked into renders or builds.
- `private/` is not committed. Owner files such as the portrait source and voice reference.

Every file has an entry in `catalog.yaml` with lane, license, source, path and sha256.
Run `studio assets verify --offline` before committing.
