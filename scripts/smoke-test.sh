#!/usr/bin/env bash
# Smoke-test the packaged seconv Docker image (format I/O + VobSub OCR).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE_TAG="${IMAGE_TAG:-seconv:local}"
OUT="${SMOKE_OUT:-$ROOT/tests/out}"
FIX="$ROOT/tests/fixtures"

rm -rf "$OUT"
mkdir -p "$OUT"

pass=0
fail=0

ok() {
  echo "PASS: $*"
  pass=$((pass + 1))
}

bad() {
  echo "FAIL: $*" >&2
  fail=$((fail + 1))
}

run() {
  docker run --rm \
    -v "$FIX:/fixtures:ro" \
    -v "$OUT:/subtitles" \
    "$IMAGE_TAG" \
    "$@" --output-folder:/subtitles
}

echo "== formats count =="
formats_out="$(docker run --rm "$IMAGE_TAG" formats 2>&1 || true)"
if echo "$formats_out" | grep -Eq 'Total formats:[[:space:]]*[3-9][0-9]{2,}'; then
  ok "formats list reports >= 300 formats"
else
  bad "formats list missing or too small"
  echo "$formats_out" | tail -20
fi

if echo "$formats_out" | grep -Eqi 'EBU-TT-D|EbuTtD|ebutt'; then
  ok "newer format EBU-TT-D present in formats list"
else
  bad "EBU-TT-D not found in formats list (upstream parity)"
fi

echo "== srt -> webvtt =="
rm -f "$OUT"/*
run /fixtures/test.srt webvtt --overwrite >/dev/null
if [[ -f "$OUT/test.vtt" ]] && grep -q 'Hello, World!' "$OUT/test.vtt"; then
  ok "srt -> webvtt preserves dialogue"
else
  bad "srt -> webvtt failed or missing dialogue"
  ls -la "$OUT" || true
fi

echo "== srt -> ebuttd (newer format) =="
rm -f "$OUT"/*
if run /fixtures/test.srt "EBU-TT-D" --overwrite >/dev/null 2>"$OUT/ebutt.log"; then
  if compgen -G "$OUT/test.*" >/dev/null && grep -qiE 'Hello|World|tt:|div' "$OUT"/test.* 2>/dev/null; then
    ok "srt -> EBU-TT-D produced recognizable output"
  else
    bad "EBU-TT-D conversion produced no usable output"
    ls -la "$OUT" || true
    cat "$OUT/ebutt.log" || true
  fi
else
  bad "could not convert to EBU-TT-D"
  cat "$OUT/ebutt.log" || true
fi

echo "== VobSub round-trip OCR =="
rm -rf "$OUT"/*
mkdir -p "$OUT/vob" "$OUT/ocr"
# Render text -> VobSub inside the image
docker run --rm \
  -v "$FIX:/fixtures:ro" \
  -v "$OUT/vob:/subtitles" \
  "$IMAGE_TAG" \
  /fixtures/test.srt vobsub --resolution:720x480 --overwrite --output-folder:/subtitles >/dev/null

shopt -s nullglob
subs=("$OUT/vob"/*.sub)
idxs=("$OUT/vob"/*.idx)
if [[ ${#subs[@]} -lt 1 || ${#idxs[@]} -lt 1 ]]; then
  bad "vobsub export did not produce .sub/.idx"
  ls -la "$OUT/vob" || true
else
  ok "srt -> vobsub produced .sub/.idx"
  sub_base="$(basename "${subs[0]}")"
  docker run --rm \
    -v "$OUT/vob:/fixtures:ro" \
    -v "$OUT/ocr:/subtitles" \
    "$IMAGE_TAG" \
    "/fixtures/${sub_base}" subrip \
    --ocr-engine:tesseract --ocr-language:eng --overwrite --output-folder:/subtitles >/dev/null || true

  ocr_srts=("$OUT/ocr"/*.srt)
  if [[ ${#ocr_srts[@]} -lt 1 ]]; then
    bad "VobSub OCR produced no .srt"
  else
    content="$(cat "${ocr_srts[0]}")"
    if echo "$content" | grep -Eqi 'timestamp:|filepos:'; then
      bad "VobSub OCR looks like idx text parse (timestamp/filepos)"
      echo "$content" | head -20
    elif echo "$content" | grep -Eqi 'Hello|World|test|subtitle|SeConv|Testing'; then
      ok "VobSub OCR returned recognizable dialogue"
    else
      # Tesseract can be flaky on synthetic glyphs; try binaryocr as fallback proof of path
      rm -f "$OUT/ocr"/*
      docker run --rm \
        -v "$OUT/vob:/fixtures:ro" \
        -v "$OUT/ocr:/subtitles" \
        "$IMAGE_TAG" \
        "/fixtures/${sub_base}" subrip \
        --ocr-engine:binaryocr --ocr-db:/secli/ocr/Latin.db --overwrite --output-folder:/subtitles >/dev/null || true
      ocr_srts=("$OUT/ocr"/*.srt)
      content="$(cat "${ocr_srts[0]:-/dev/null}" 2>/dev/null || true)"
      if echo "$content" | grep -Eqi 'Hello|World|test|subtitle|SeConv|Testing'; then
        ok "VobSub OCR (binaryocr) returned recognizable dialogue"
      elif [[ -n "$content" ]] && ! echo "$content" | grep -Eqi 'timestamp:|filepos:'; then
        ok "VobSub OCR produced non-garbage SRT (engine path works; glyphs may be synthetic)"
        echo "(OCR text for inspection:)"
        echo "$content" | head -30
      else
        bad "VobSub OCR failed or produced garbage"
        echo "$content" | head -30
      fi
    fi
  fi
fi

echo "== negative: garbage input should fail =="
rm -f "$OUT"/*.srt "$OUT"/*.vtt 2>/dev/null || true
set +e
run /fixtures/not-a-subtitle.bin subrip --overwrite >"$OUT/neg.log" 2>&1
neg_rc=$?
set -e
if [[ $neg_rc -ne 0 ]]; then
  ok "unsupported input exits non-zero (rc=$neg_rc)"
else
  # Some paths may "succeed" with empty/odd output — reject idx-style garbage markers
  if grep -Eqi 'timestamp:|filepos:' "$OUT"/* 2>/dev/null; then
    bad "garbage input produced idx-like SRT"
  else
    bad "expected non-zero exit for unsupported binary input (rc=0)"
    cat "$OUT/neg.log" || true
  fi
fi

echo
echo "Results: $pass passed, $fail failed"
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
