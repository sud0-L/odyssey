#!/usr/bin/env bash
# Build the two assets required by an official Odyssey GitHub Release.
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
output_dir=${1:-"$root_dir/dist"}
version=$(<"$root_dir/VERSION")
tag="v$version"
artifact="$output_dir/odyssey.ody"
descriptor="$output_dir/odyssey-release.json"
artifact_url="https://github.com/sud0-L/odyssey/releases/download/$tag/odyssey.ody"

mkdir -p -- "$output_dir"
[[ ! -e $artifact && ! -L $artifact ]] \
    || { printf 'release artifact already exists: %s\n' "$artifact" >&2; exit 1; }
[[ ! -e $descriptor && ! -L $descriptor ]] \
    || { printf 'release descriptor already exists: %s\n' "$descriptor" >&2; exit 1; }

"$root_dir/odyssey" artifact build --output "$artifact" --json >/dev/null
identity=$("$root_dir/odyssey" artifact verify "$artifact" --json)
jq -n -S \
    --arg version "$version" \
    --arg release_id "$(jq -r .releaseId <<<"$identity")" \
    --arg digest "$(jq -r .artifactSha256 <<<"$identity")" \
    --arg artifact_url "$artifact_url" \
    '{schema: 2, product: "odyssey", version: $version,
      releaseId: $release_id, artifactUrl: $artifact_url,
      artifactSha256: $digest}' > "$descriptor"

printf 'Version: %s\nTag: %s\nArtifact: %s\nDescriptor: %s\n' \
    "$version" "$tag" "$artifact" "$descriptor"
