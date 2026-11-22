#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Netresearch DTT GmbH
#
# Decides whether the current commit on main publishes an image release and
# renders its tag, title and body. Called by the release-plan job in
# build.yml after the image was pushed.
#
# The release version counts changes to the image. It is not the phpbu
# version, which the image tags carry. A release is due when a commit since
# the last v* tag changed a file that goes into the image (IMAGE_PATHS) and
# is not typed docs, ci, test or style. The
# bump comes from the Conventional Commit types of those commits: a breaking
# change raises the major version, feat the minor version, anything else the
# patch version. The first release is v1.0.0.
#
# Input (environment):
#   IMAGE_TAGS   newline-separated image references the build pushed
#   PHP_VERSION  optional; read from the pushed image when unset
#   GITHUB_REPOSITORY, GITHUB_OUTPUT  as set by GitHub Actions
#
# Output (to GITHUB_OUTPUT, or stdout outside Actions):
#   release=true|false, create_tag=true|false, tag, title, body, reason
#
# Needs gh with a token (GH_TOKEN) to check whether a tag on HEAD already
# has its release.

set -euo pipefail

IMAGE_PATHS=(Dockerfile app docker-bake.hcl)
REPO="${GITHUB_REPOSITORY:-netresearch/phpbu-docker}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

emit() {
  local key="$1" value="$2"
  printf '%s=%s\n' "$key" "$value" >> "$OUT"
}
emit_multi() {
  local key="$1" value="$2" delim
  delim="EOF_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  { printf '%s<<%s\n' "$key" "$delim"; printf '%s\n' "$value"; printf '%s\n' "$delim"; } >> "$OUT"
}
skip() {
  local reason="$1"
  emit release false
  emit reason "$reason"
  echo "No release: $reason" >&2
  exit 0
}

head_sha="$(git rev-parse HEAD)"

existing="$(git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"
# A tag without a release is left behind when the publish job failed after
# the tag was created. Publish for that tag instead of skipping it, because
# the next push counts from it.
if [[ -n "$existing" ]] && gh release view "$existing" --repo "$REPO" > /dev/null 2>&1; then
  skip "HEAD already carries the released tag $existing"
fi

# numbered: the highest version tag below this commit; the next version
# counts from it. base: the newest of those tags that has a release; the
# change list and the phpbu comparison start there. They differ when a
# publish run failed after creating its tag and a later push came first:
# that tag keeps its number, and its changes move into this release.
ref="HEAD"
if [[ -n "$existing" ]]; then
  ref="HEAD^"
fi
numbered="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' "$ref" 2>/dev/null || true)"
base=""
if [[ -n "$numbered" ]]; then
  while IFS= read -r t; do
    if gh release view "$t" --repo "$REPO" > /dev/null 2>&1; then
      base="$t"
      break
    fi
  done < <(git tag --merged "$ref" --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)
fi

phpbu="$(jq -re '.packages[] | select(.name == "phpbu/phpbu") | .version' app/composer.lock)"

# The immutable minimal tag of this build: <phpbu>-<short sha>.
ref_minimal=""
ref_full=""
while IFS= read -r ref; do
  suffix="${ref##*:"${phpbu}"-}"
  [[ "$suffix" != "$ref" ]] || continue
  if [[ "$suffix" =~ ^[0-9a-f]{7,40}$ ]]; then
    ref_minimal="${ref_minimal:-$ref}"
  elif [[ "$suffix" =~ ^full-[0-9a-f]{7,40}$ ]]; then
    ref_full="${ref_full:-$ref}"
  fi
done <<< "${IMAGE_TAGS:-}"
[[ -n "$ref_minimal" ]] || { echo "no <phpbu>-<sha> tag in IMAGE_TAGS" >&2; exit 1; }
[[ -n "$ref_full" ]] || { echo "no <phpbu>-full-<sha> tag in IMAGE_TAGS" >&2; exit 1; }

# The <phpbu>-<sha> tags are pushed again by the weekly rebuild of the same
# commit, so the release names each image by the digest this build pushed.
digest_of() {
  local ref="$1"
  docker buildx imagetools inspect "$ref" --format '{{.Manifest.Digest}}'
}
digest_minimal="${MINIMAL_DIGEST:-$(digest_of "$ref_minimal")}"
digest_full="${FULL_DIGEST:-$(digest_of "$ref_full")}"
for d in "$digest_minimal" "$digest_full"; do
  [[ "$d" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "unexpected digest: $d" >&2; exit 1; }
done
pin_minimal="${ref_minimal%:*}@${digest_minimal}"
pin_full="${ref_full%:*}@${digest_full}"

php="${PHP_VERSION:-}"
if [[ -z "$php" ]]; then
  php="$(docker run --rm --entrypoint php "$pin_minimal" -r 'echo PHP_VERSION;')"
fi
[[ "$php" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || { echo "unexpected PHP version: $php" >&2; exit 1; }

changes=""
phpbu_before=""
if [[ -z "$numbered" ]]; then
  next="1.0.0"
else
  range="HEAD"
  if [[ -n "$base" ]]; then
    range="$base..HEAD"
  fi
  mapfile -t commits < <(git log --no-merges --format=%H "$range" -- "${IMAGE_PATHS[@]}")
  [[ "${#commits[@]}" -gt 0 ]] || skip "no change to ${IMAGE_PATHS[*]} since ${base:-the first commit}"
  bump="patch"
  counted=0
  for c in "${commits[@]}"; do
    subject="$(git log -1 --format=%s "$c")"
    # A comment or CI tweak in an image file does not change the image.
    if [[ "$subject" =~ ^(docs|ci|test|style)(\([^\)]*\))?!?: ]]; then
      continue
    fi
    counted=$((counted + 1))
    if [[ "$subject" =~ ^[a-z]+(\([^\)]*\))?!: ]] || git log -1 --format=%B "$c" | grep -qE '^BREAKING[ -]CHANGE:'; then
      bump="major"
    elif [[ "$subject" =~ ^feat(\(|:) ]] && [[ "$bump" != major ]]; then
      bump="minor"
    fi
    changes+="- ${subject} ([${c:0:7}](https://github.com/${REPO}/commit/${c}))"$'\n'
  done
  [[ "$counted" -gt 0 ]] || skip "only docs, ci, test or style commits touched ${IMAGE_PATHS[*]} since ${base:-the first commit}"
  IFS=. read -r major minor patch <<< "${numbered#v}"
  case "$bump" in
    major) next="$((major + 1)).0.0" ;;
    minor) next="${major}.$((minor + 1)).0" ;;
    patch) next="${major}.${minor}.$((patch + 1))" ;;
    *) echo "unknown bump: $bump" >&2; exit 1 ;;
  esac
  if [[ -n "$base" ]]; then
    phpbu_before="$(git show "$base:app/composer.lock" | jq -r '.packages[] | select(.name == "phpbu/phpbu") | .version')"
  fi
fi

if [[ -n "$existing" ]]; then
  next="${existing#v}"
  create_tag=false
else
  create_tag=true
fi

tag="v${next}"
title="${tag} — phpbu ${phpbu}, PHP ${php}"

if [[ -z "$base" ]]; then
  change_section="First image release with its own version number. Earlier changes are listed in [CHANGELOG.md](https://github.com/${REPO}/blob/${head_sha}/CHANGELOG.md)."
else
  change_section=""
  if [[ -n "$phpbu_before" ]] && [[ "$phpbu_before" != "$phpbu" ]]; then
    change_section="phpbu changed from ${phpbu_before} to [${phpbu}](https://github.com/sebastianfeldmann/phpbu/releases/tag/${phpbu})."$'\n\n'
  fi
  change_section+="Commits since [${base}](https://github.com/${REPO}/releases/tag/${base}) that change the image:"$'\n\n'"${changes%$'\n'}"
fi

body="**${tag} is the version of the phpbu-docker image, not of phpbu.** It counts changes to the image: PHP, system packages, PHP dependencies, sync adapters and the entrypoint. The image tags carry the phpbu version, so this release is pulled as \`${phpbu}\` or \`${phpbu}-full\`.

| Component | Version |
|---|---|
| Image release | ${tag} |
| phpbu | [${phpbu}](https://github.com/sebastianfeldmann/phpbu/releases/tag/${phpbu}) |
| PHP | ${php} |

## Changes to the image

${change_section}

## Pull this build

The references below name exactly this build by digest. The tag \`${ref_minimal##*:}\` is pushed again by the weekly rebuild, and \`${phpbu}\`, \`latest\`, \`${phpbu}-full\` and \`full\` move to every later build.

\`\`\`bash
docker pull ${pin_minimal}
docker pull ${pin_full}
\`\`\`

## Verify the signature

\`\`\`bash
cosign verify ${pin_minimal} \\
  --certificate-identity-regexp \"https://github.com/${REPO}\" \\
  --certificate-oidc-issuer \"https://token.actions.githubusercontent.com\"
\`\`\`

SBOM (in-image attestation): \`docker buildx imagetools inspect ${pin_minimal} --format '{{ json .SBOM }}'\`"

emit release true
emit create_tag "$create_tag"
emit tag "$tag"
emit title "$title"
emit_multi body "$body"
