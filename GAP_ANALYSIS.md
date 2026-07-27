# Gap analysis status

**Status (2026-07-26): addressed by packaging upstream seconv.**

This repository now builds a Docker image from the pinned Subtitle Edit submodule (`upstream/`) instead of the SE 3.6.9-era vendored CLI. Format I/O and headless OCR (including VobSub `.idx`/`.sub` and MKV image tracks) come from upstream `seconv`.

Verify with:

```bash
./scripts/build-docker.sh
./scripts/smoke-test.sh
```

---

# subtitleedit-cli gap analysis (historical)

Date: 2026-07-26

Context: Archivist needed headless OCR of embedded DVD/VobSub subtitles from Matroska episode remuxes. The available Docker image was `jonmeacham/seconv:1.0`, built from this `subtitleedit-cli` project lineage.

## Summary

The current CLI image can perform basic format conversion, but it is not keeping pace with current upstream Subtitle Edit/seconv behavior for image-based subtitle OCR.

For the Pokémon DVD remux validation case, it failed all useful VobSub OCR routes:

- extracted `.idx` input was treated as text/index content, producing SRT entries made from `timestamp:`/`filepos:` lines;
- extracted `.sub` input was treated as binary/text payload, producing mojibake rather than OCR text;
- direct `.mkv` input was rejected with `input file too large`;
- the CLI help exposes only the older `seconv <pattern> <format> [/options]` interface, including `/ocrdb:<db>`, but not the newer upstream seconv OCR engine flags.

The practical result is that this image cannot currently serve as Archivist?s headless subtitle OCR layer for DVD/VobSub tracks.

## Reproduction from Archivist validation

Source media:

```text
/mnt/e/Video Rips/Pokémon Remux/Season 10/Pokémon - S10E01.mkv
```

Track probe:

```bash
mkvmerge -J "/mnt/e/Video Rips/Pokémon Remux/Season 10/Pokémon - S10E01.mkv"
```

Relevant track:

```text
track id: 2
codec: VobSub
codec_id: S_VOBSUB
language: eng
```

Extracted VobSub:

```bash
mkdir -p /tmp/archivist_pokemon/subtitle_probe
mkvextract tracks \
  "/mnt/e/Video Rips/Pokémon Remux/Season 10/Pokémon - S10E01.mkv" \
  2:/tmp/archivist_pokemon/subtitle_probe/S10E01.idx
```

This creates:

```text
S10E01.idx
S10E01.sub
```

### Failure 1: `.idx` input is parsed as text, not VobSub OCR

Command:

```bash
docker run --rm \
  -v /tmp/archivist_pokemon/subtitle_probe:/subtitles \
  jonmeacham/seconv:1.0 \
  S10E01.idx subrip /ocrdb:Latin /overwrite
```

Observed output:

```text
1: S10E01.idx -> /subtitles/S10E01.srt... done.
```

But the resulting SRT contains index metadata instead of dialogue:

```text
00:00:00,280 --> 00:00:00,281
0:05:372, filepos: 000001000
ti
stamp: 00:00:08:809, filepos: 0
```

Interpretation: the converter is reading the `.idx` text file as subtitle text rather than treating `.idx` + sibling `.sub` as VobSub image subtitles requiring OCR.

### Failure 2: `.sub` input is parsed as binary/text, not VobSub OCR

Command:

```bash
docker run --rm \
  -v /tmp/archivist_pokemon/subtitle_probe:/subtitles \
  jonmeacham/seconv:1.0 \
  S10E01.sub subrip /ocrdb:Latin /overwrite
```

Observed output:

```text
1: S10E01.sub -> /subtitles/S10E01.srt... done.
```

But the resulting SRT contains binary garbage/mojibake.

Interpretation: the converter is not using VobSub image decoding/OCR for raw `.sub` input either.

### Failure 3: direct Matroska input is rejected

Command:

```bash
docker run --rm \
  -v "/mnt/e/Video Rips/Pokémon Remux/Season 10:/videos:ro" \
  -v /tmp/archivist_pokemon/subtitle_probe_mkv:/out \
  jonmeacham/seconv:1.0 \
  "Pokémon - S10E01.mkv" subrip \
  /inputfolder:/videos \
  /outputfolder:/out \
  /track-number:2 \
  /ocrdb:Latin \
  /overwrite
```

Observed output:

```text
ERROR: /videos/Pokémon - S10E01.mkv: subrip - input file too large!
```

Interpretation: although the old CLI lists Matroska as input-only support, it is not suitable for normal-size episode MKVs in this workflow.

## Upstream capability delta

Current upstream Subtitle Edit documentation and changelog indicate newer seconv has moved beyond this interface:

- headless `seconv` lives in the main Subtitle Edit repository and is updated with the desktop app;
- newer command-line behavior includes OCR engine selection such as Tesseract, nOCR, Binary OCR, Ollama, PaddleOCR, and later llama.cpp/CrispEmbed-related paths;
- newer seconv supports container input from `.mkv`/`.mp4`/`.mcc`;
- recent changelog entries explicitly mention VobSub OCR/color-isolation fixes and MKV VobSub passthrough fixes.

## Workaround that did work locally

ffmpeg + Tesseract on rendered frames (omitted here; see git history if needed). This proved the source subtitles are valid; the blocker was the old CLI converter path.

## Recommended update plan (implemented)

1. Package upstream seconv directly (this repo?s Docker image).
2. Pin upstream Subtitle Edit in `upstream/` and stamp version/ref on the image.
3. Ship Tesseract + Latin OCR DBs in the image.
4. Add smoke tests for format I/O and VobSub OCR round-trip (`./scripts/smoke-test.sh`).

## Acceptance criteria for Archivist

```bash
docker run --rm \
  -v "$WORKDIR:/work" \
  seconv:<tag> \
  <input idx/sub or mkv> subrip \
  --ocr-engine:tesseract --ocr-language:eng \
  --overwrite
```

Expected output: valid `.srt` with real dialogue text; stable non-zero exit on unsupported inputs; no GUI dependency.
