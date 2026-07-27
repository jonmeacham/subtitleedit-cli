# syntax=docker/dockerfile:1
#
# Packages upstream Subtitle Edit seconv (LibSE + LibUiLogic) as a headless Linux image.
# Build from the repo root with submodule initialized:
#   ./scripts/build-docker.sh
# or:
#   git submodule update --init --recursive
#   docker build -t seconv:local -f docker/Dockerfile \
#     --build-arg UPSTREAM_REF=$(git -C upstream rev-parse HEAD) \
#     --build-arg UPSTREAM_VERSION=$(grep -Eo 'Version \{ get; set; \} = "v[^"]+"' upstream/src/ui/Logic/Config/Se.cs | grep -Eo 'v[^"]+') \
#     .

ARG DOTNET_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0
ARG RUNTIME_IMAGE=ubuntu:24.04

FROM ${DOTNET_SDK_IMAGE} AS build
ARG UPSTREAM_REF=unknown
ARG UPSTREAM_VERSION=unknown
WORKDIR /src

# Minimal upstream tree needed to publish seconv (avoids shipping the full UI).
COPY upstream/Directory.Build.props ./Directory.Build.props
COPY upstream/LICENSE ./LICENSE
COPY upstream/src/libse ./src/libse
COPY upstream/src/libuilogic ./src/libuilogic
COPY upstream/src/seconv ./src/seconv
COPY upstream/src/ui/Assets/Dictionaries.zip ./src/ui/Assets/Dictionaries.zip

RUN set -eux; \
    display_ver="${UPSTREAM_VERSION#v}"; \
    numeric_part="${display_ver%%-*}"; \
    case "$(printf '%s' "$numeric_part" | tr -cd '.' | wc -c)" in \
      0) numeric_part="${numeric_part}.0.0" ;; \
      1) numeric_part="${numeric_part}.0" ;; \
    esac; \
    suffix=""; \
    case "$display_ver" in *-*) suffix="${display_ver#*-}" ;; esac; \
    revision="$(printf '%s' "$suffix" | grep -oE '[0-9]+$' || true)"; \
    revision="${revision:-0}"; \
    app_ver_full="${numeric_part}.${revision}"; \
    dotnet publish src/seconv/SeConv.csproj \
      -c Release \
      -r linux-x64 \
      --self-contained true \
      -p:PublishSingleFile=true \
      -p:Version="${app_ver_full}" \
      -p:FileVersion="${app_ver_full}" \
      -p:InformationalVersion="${UPSTREAM_VERSION}" \
      -o /publish; \
    find /publish -name '*.pdb' -type f -delete

FROM ${RUNTIME_IMAGE}
ARG UPSTREAM_REF=unknown
ARG UPSTREAM_VERSION=unknown

LABEL maintainer="subtitleedit-cli packaging" \
      org.opencontainers.image.title="seconv" \
      org.opencontainers.image.description="Headless Subtitle Edit seconv (upstream packaged)" \
      org.opencontainers.image.source="https://github.com/SubtitleEdit/subtitleedit-cli" \
      org.opencontainers.image.version="${UPSTREAM_VERSION}" \
      subtitleedit.upstream.ref="${UPSTREAM_REF}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu74 \
    tesseract-ocr \
    tesseract-ocr-eng \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /publish /secli
COPY upstream/Ocr/Latin.db upstream/Ocr/Latin.nocr /secli/ocr/
COPY upstream/LICENSE /secli/LICENSE
RUN chmod +x /secli/seconv \
    && printf '%s\n' "${UPSTREAM_REF}" > /secli/UPSTREAM_REF \
    && printf '%s\n' "${UPSTREAM_VERSION}" > /secli/UPSTREAM_VERSION

ENV PATH="/secli:${PATH}" \
    SECONV_OCR_DB_DIR=/secli/ocr

WORKDIR /subtitles/
ENTRYPOINT ["/secli/seconv"]
