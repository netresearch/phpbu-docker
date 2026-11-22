#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Netresearch DTT GmbH
#
# Tests for .github/scripts/plan-release.sh. Each case builds a throwaway git
# repository, runs the planner with a stub gh and a fixed PHP version, and
# compares the decision it writes to GITHUB_OUTPUT.
#
# Usage: tests/plan-release.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLANNER="$ROOT/.github/scripts/plan-release.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
# Stub gh: "release view <tag>" succeeds for the tags in RELEASED, and for
# every tag while RELEASED is unset.
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
if [[ "$1 $2" = "release view" ]]; then
  [[ -z "${RELEASED+set}" ]] && exit 0
  for t in ${RELEASED}; do [[ "$t" = "$3" ]] && exit 0; done
  exit 1
fi
exit 0
STUB
chmod +x "$WORK/bin/gh"

TAGS="ghcr.io/netresearch/phpbu-docker:6.0.33
ghcr.io/netresearch/phpbu-docker:6.0.33-abc1234
ghcr.io/netresearch/phpbu-docker:6.0.33-2026-11-22
ghcr.io/netresearch/phpbu-docker:6.0.33-full
ghcr.io/netresearch/phpbu-docker:6.0.33-full-abc1234
ghcr.io/netresearch/phpbu-docker:latest"

pass=0
fail=0

lock() { printf '{"packages":[{"name":"phpbu/phpbu","version":"%s"}]}\n' "$1" > app/composer.lock; }
g() { git -c user.email=test@example.org -c user.name=test -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }
commit() {
  local path="$1"
  shift
  echo "$RANDOM" >> "$path"
  git add "$path"
  g commit -q "$@"
}

new_repo() {
  local dir="$WORK/$1"
  mkdir -p "$dir/app"
  cd "$dir"
  git init -q -b main
  echo base > Dockerfile
  echo base > README.md
  lock 6.0.33
  git add .
  g commit -q -m "feat: initial image"
}

# expect <case> <release> <tag or reason pattern> [body pattern]
expect() {
  local name="$1" want_release="$2" want="$3" body_pat="${4:-}" out
  out="$WORK/$name.out"
  rm -f "$out"
  if ! PATH="$WORK/bin:$PATH" IMAGE_TAGS="$TAGS" PHP_VERSION=8.6.0 GITHUB_OUTPUT="$out" \
    MINIMAL_DIGEST="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" FULL_DIGEST="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
    GITHUB_REPOSITORY=netresearch/phpbu-docker "$PLANNER" 2> "$WORK/$name.err"; then
    echo "FAIL $name: planner exited non-zero: $(tail -n1 "$WORK/$name.err")"
    fail=$((fail + 1))
    return
  fi
  local got_release got
  got_release="$(sed -n 's/^release=//p' "$out")"
  if [[ "$want_release" = true ]]; then
    got="$(sed -n 's/^tag=//p' "$out")"
  else
    got="$(sed -n 's/^reason=//p' "$out")"
  fi
  # $want is a glob pattern on purpose.
  # shellcheck disable=SC2053
  if [[ "$got_release" != "$want_release" ]] || [[ "$got" != $want ]]; then
    echo "FAIL $name: release=$got_release, got '$got', want release=$want_release '$want'"
    fail=$((fail + 1))
    return
  fi
  if [[ -n "$body_pat" ]] && ! grep -qF -- "$body_pat" "$out"; then
    echo "FAIL $name: output lacks '$body_pat'"
    fail=$((fail + 1))
    return
  fi
  echo "ok   $name"
  pass=$((pass + 1))
}

new_repo first
expect first true v1.0.0 "First image release with its own version number"

new_repo title
expect title true v1.0.0 "title=v1.0.0 — phpbu 6.0.33, PHP 8.6.0"

new_repo pinned
expect pinned true v1.0.0 "docker pull ghcr.io/netresearch/phpbu-docker@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

new_repo pull-labels
expect pull-labels true v1.0.0 "# full: all sync adapters"

new_repo released-at-head
g tag -a v1.0.0 -m v1.0.0
RELEASED=v1.0.0 expect released-at-head false "*already carries the released tag v1.0.0*"

new_repo tag-without-release
g tag -a v1.0.0 -m v1.0.0
RELEASED="" expect tag-without-release true v1.0.0 "create_tag=false"

new_repo orphan-behind-head
g tag -a v1.0.0 -m v1.0.0
commit Dockerfile -m "fix: change A"
g tag -a v1.0.1 -m v1.0.1
commit Dockerfile -m "fix: change B"
RELEASED=v1.0.0 expect orphan-behind-head true v1.0.2 "- fix: change A"

new_repo fix
g tag -a v1.0.0 -m v1.0.0
commit app/composer.json -m "chore(deps): lock file maintenance"
expect fix true v1.0.1 "create_tag=true"

new_repo feat
g tag -a v1.0.0 -m v1.0.0
commit Dockerfile -m "fix(deps): update docker images"
commit app/full.json -m "feat: add an adapter"
expect feat true v1.1.0 "- feat: add an adapter"

new_repo bang
g tag -a v1.2.3 -m v1.2.3
commit Dockerfile -m "feat!: drop TZ"
commit Dockerfile -m "fix: later fix"
expect bang true v2.0.0

new_repo footer
g tag -a v1.2.3 -m v1.2.3
commit Dockerfile -m "fix: move the entrypoint" -m "BREAKING CHANGE: the entrypoint moved"
expect footer true v2.0.0

new_repo docs-only
g tag -a v1.0.0 -m v1.0.0
commit README.md -m "docs: readme"
expect docs-only false "no change to *"

new_repo docs-in-image-file
g tag -a v1.0.0 -m v1.0.0
commit docker-bake.hcl -m "docs(bake): describe the cache"
commit Dockerfile -m "ci: lint hint"
expect docs-in-image-file false "only docs, ci, test or style commits*"

new_repo docs-bang
g tag -a v1.2.3 -m v1.2.3
commit Dockerfile -m "docs!: clarify usage"
expect docs-bang false "only docs, ci, test or style commits*"

new_repo docs-plus-fix
g tag -a v1.0.0 -m v1.0.0
commit docker-bake.hcl -m "docs(bake): describe the cache"
commit Dockerfile -m "fix: real change"
expect docs-plus-fix true v1.0.1 "- fix: real change"

new_repo phpbu-changed
lock 6.0.32
g commit -q -am "chore(deps): phpbu 6.0.32"
g tag -a v1.0.0 -m v1.0.0
lock 6.0.33
g commit -q -am "chore(deps): lock file maintenance"
expect phpbu-changed true v1.0.1 "phpbu changed from 6.0.32 to"

new_repo no-sha-tag
out="$WORK/no-sha-tag.out"
if PATH="$WORK/bin:$PATH" IMAGE_TAGS="ghcr.io/x:latest" PHP_VERSION=8.6.0 GITHUB_OUTPUT="$out" \
  "$PLANNER" 2> /dev/null; then
  echo "FAIL no-sha-tag: planner accepted a tag list without <phpbu>-<sha>"
  fail=$((fail + 1))
else
  echo "ok   no-sha-tag"
  pass=$((pass + 1))
fi

echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
