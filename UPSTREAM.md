# Upstream pin

This repository packages Subtitle Edit's headless `seconv` rather than maintaining a parallel LibSE fork.

| Field | Value |
|-------|--------|
| Submodule path | [`upstream/`](upstream/) |
| Remote | https://github.com/SubtitleEdit/subtitleedit.git |
| Pinned commit | `c30ea37e14e21aa51b0d6a0ed6242eeff2dbc77e` |
| Describe | `v5.1.0-rc16-28-gc30ea37e1` |
| Display version (`Se.Version`) | `v5.1.0-rc16` |

## Init / update

```bash
git submodule update --init --recursive
# bump pin:
cd upstream && git fetch && git checkout <commit-or-tag> && cd ..
git add upstream
```

The Docker image labels `org.opencontainers.image.version` and `subtitleedit.upstream.ref` are stamped from this pin at build time (`./scripts/build-docker.sh`).
