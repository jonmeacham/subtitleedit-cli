# subtitleedit-cli

Docker / packaging home for **upstream** [Subtitle Edit](https://github.com/SubtitleEdit/subtitleedit) `seconv` — the headless subtitle converter.

This repository no longer maintains a forked LibSE copy. Format input/output and OCR behavior match the pinned Subtitle Edit commit under [`upstream/`](upstream/). See [UPSTREAM.md](UPSTREAM.md) for the pin.

## What you get

- 380+ subtitle formats (same registry as Subtitle Edit)
- Container input: Matroska (`.mkv`/`.mks`), MP4, MCC, MXF, transport-stream teletext
- Image subtitle OCR: Blu-ray `.sup`, VobSub `.sub`/`.idx`, MKV PGS/VobSub, and related paths
- OCR engines in the default image: **Tesseract** (eng), plus bundled **Latin.db** / **Latin.nocr** for `binaryocr` / `nocr`
- No GUI dependency

Canonical CLI docs live upstream:

- [Command-line reference](https://github.com/SubtitleEdit/subtitleedit/blob/main/docs/reference/command-line.md)
- [seconv feature overview](https://github.com/SubtitleEdit/subtitleedit/blob/main/docs/features/seconv.md)

## Prerequisites

- Docker
- Git submodule initialized:

```bash
git submodule update --init --recursive
```

## Build the image

```bash
./scripts/build-docker.sh
# optional: IMAGE_TAG=seconv:1.1 ./scripts/build-docker.sh
```

The image is labeled with `org.opencontainers.image.version` (e.g. `v5.1.0-rc16`) and `subtitleedit.upstream.ref` (full commit SHA).

## Run

```bash
# Format conversion (write into the mounted /subtitles workdir)
docker run --rm -v "$PWD/subs:/subtitles" seconv:local \
  sample.srt webvtt --output-folder:/subtitles --overwrite

# List formats / OCR engines
docker run --rm seconv:local formats
docker run --rm seconv:local list-ocr-engines

# VobSub OCR (.idx companion is auto-detected)
docker run --rm -v "$PWD/subs:/subtitles" seconv:local \
  movie.sub subrip --ocr-engine:tesseract --ocr-language:eng \
  --output-folder:/subtitles --overwrite

# Binary OCR with the bundled Latin DB
docker run --rm -v "$PWD/subs:/subtitles" seconv:local \
  movie.sub subrip --ocr-engine:binaryocr --ocr-db:/secli/ocr/Latin.db \
  --output-folder:/subtitles --overwrite

# MKV image/text track
docker run --rm -v "$PWD/videos:/videos:ro" -v "$PWD/out:/subtitles" seconv:local \
  "/videos/episode.mkv" subrip --track-number:2 \
  --ocr-engine:tesseract --ocr-language:eng \
  --output-folder:/subtitles --overwrite
```
Positional `seconv <pattern> <format>` works. Legacy slash options (`/overwrite`, `/ocrdb:…`) are translated by upstream seconv where supported; prefer the modern `--flag` forms.

Bundled OCR databases are under `/secli/ocr/` (`Latin.db`, `Latin.nocr`).

## Smoke tests

```bash
./scripts/build-docker.sh
./scripts/smoke-test.sh
```

## Updating the upstream pin

```bash
cd upstream
git fetch
git checkout <tag-or-commit>   # e.g. v5.1.0
cd ..
git add upstream
# refresh UPSTREAM.md to match, then rebuild
./scripts/build-docker.sh
./scripts/smoke-test.sh
```

## License

`subtitleedit-cli` packaging files in this repo follow [LICENSE](LICENSE). The packaged `seconv` binary and libraries come from upstream Subtitle Edit / LibSE (LGPL); see `upstream/LICENSE` and `/secli/LICENSE` in the image.

## History

Older releases of this project vendored SE 3.6.9-era code with most image OCR removed. That approach could not keep format or VobSub/MKV OCR parity with current Subtitle Edit; see [GAP_ANALYSIS.md](GAP_ANALYSIS.md). This tree packages upstream `seconv` instead.
