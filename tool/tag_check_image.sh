#!/usr/bin/env bash
# Promote a check image without rebuilding it. Invoked at the stable commit.
set -euo pipefail
mode="${1:-publish}"
if [[ "$mode" != publish && "$mode" != dry-run ]]; then
  echo 'Usage: tag_check_image.sh [publish|dry-run]' >&2
  exit 2
fi
version="$(sed -n 's/^version: *//p' packages/dartway_cli/pubspec.yaml)"
sha="$(git rev-parse HEAD)"
source="ghcr.io/dartway/dartway-check:$sha"
target="ghcr.io/dartway/dartway-check:$version"
if [[ "$version" == *-* ]]; then
  echo "Skipping prerelease $version"
  exit 0
fi
if [[ "$mode" == dry-run ]]; then
  echo "Would verify pub.dev has dartway_cli $version, then copy $source to $target without rebuilding."
  echo 'Would skip an existing published-version tag. No images will be pushed.'
  exit 0
fi
if ! published="$(curl --fail --silent --show-error "https://pub.dev/api/packages/dartway_cli/versions/$version" | jq -r .version)"; then
  echo "Cannot verify pub.dev has dartway_cli $version; stable must move only after publishing." >&2
  exit 1
fi
if [[ "$published" != "$version" ]]; then
  echo "pub.dev lacks dartway_cli $version; stable moved without publishing." >&2
  exit 1
fi
if docker buildx imagetools inspect "$target" --format '{{.Manifest.Digest}}' >existing-digest.txt 2>tag-error.txt; then
  echo "$target already published; skipping."
  exit 0
elif ! grep -Eiq 'manifest unknown|not found|404' tag-error.txt; then
  cat tag-error.txt >&2
  exit 1
fi
# master and stable can move while the master image is still building.
for attempt in {1..60}; do
  if digest="$(docker buildx imagetools inspect "$source" --format '{{.Manifest.Digest}}' 2>source-error.txt)"; then
    break
  fi
  if [[ "$attempt" == 60 ]] || ! grep -Eiq 'manifest unknown|not found|404' source-error.txt; then
    cat source-error.txt >&2
    exit 1
  fi
  sleep 10
done
docker buildx imagetools create --prefer-index=false --tag "$target" "ghcr.io/dartway/dartway-check@$digest"
copied="$(docker buildx imagetools inspect "$target" --format '{{.Manifest.Digest}}')"
if [[ "$copied" != "$digest" ]]; then
  echo "Copy verification failed: $target ($copied) differs from $source ($digest)." >&2
  exit 1
fi
