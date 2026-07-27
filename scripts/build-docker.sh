#!/usr/bin/env bash
# Build the seconv Docker image from the pinned upstream/ submodule.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE_TAG="${IMAGE_TAG:-seconv:local}"

if [[ ! -f upstream/src/seconv/SeConv.csproj ]]; then
  echo "upstream submodule missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

UPSTREAM_REF="$(git -C upstream rev-parse HEAD)"
UPSTREAM_VERSION="$(
  grep -E 'public[[:space:]]+static[[:space:]]+string[[:space:]]+Version[[:space:]]*\{' \
    upstream/src/ui/Logic/Config/Se.cs \
    | sed -E 's/.*"v([^"]+)".*/v\1/'
)"

if [[ -z "$UPSTREAM_VERSION" || "$UPSTREAM_VERSION" == *"Version"* ]]; then
  echo "Could not parse upstream version from Se.cs" >&2
  exit 1
fi

echo "Building ${IMAGE_TAG}"
echo "  upstream ref:     ${UPSTREAM_REF}"
echo "  upstream version: ${UPSTREAM_VERSION}"

docker build \
  -t "${IMAGE_TAG}" \
  -f docker/Dockerfile \
  --build-arg "UPSTREAM_REF=${UPSTREAM_REF}" \
  --build-arg "UPSTREAM_VERSION=${UPSTREAM_VERSION}" \
  .

echo "Built ${IMAGE_TAG} (upstream ${UPSTREAM_VERSION} @ ${UPSTREAM_REF})"
