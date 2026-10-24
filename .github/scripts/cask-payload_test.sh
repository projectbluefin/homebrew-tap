#!/usr/bin/env bash
# Downloads each Linux cask's current release archive and checks that it still
# holds everything the cask's install steps expect:
# `.github/scripts/cask-payload_test.sh [Casks/NAME.rb ...]`.
# Version bumps are merged automatically once `brew test-bot --only-tap-syntax`
# passes, and that only parses the casks. A release that renames a file the
# cask copies, or rewords a line it patches, would otherwise first fail on a
# user's `brew install --cask`.
#
# Checked per archive:
#   - the download matches the cask's sha256
#   - every `binary` and `copy` source exists
#   - every `inreplace` file exists and still contains the text it replaces
#   - every `"$PWD"/DIR/*` glob in an embedded script matches at least one file
#     (the scripts use nullglob, so a renamed DIR would silently do nothing)
#   - when a step rewrites `~` in XML, at least one XML file contains `~/`
set -euo pipefail
cd "$(dirname "$0")/../.."

fails=0
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Print the cask as one statement per line: a line ending in "," is joined with
# the next one, so multi-line `copy`/`inreplace` calls can be matched whole.
# Comment lines are dropped first so a trailing "," in one cannot swallow the
# statement after it.
statements() {
  awk '
    { sub(/^[[:space:]]+/, "") }
    /^#/ { next }
    { buf = (buf == "" ? $0 : buf " " $0) }
    !/,$/ { print buf; buf = "" }
    END { if (buf != "") print buf }
  ' "$1"
}

# field CASK REGEX: print capture group 1 of the first line matching REGEX.
field() {
  sed -nE "s/$2/\\1/p" "$1" | head -n1
}

check_archive() { # cask label url sha dir
  local cask=$1 label=$2 url=$3 sha=$4 dir=$5 archive="$tmp/archive"
  if ! curl -fsSL --retry 3 --connect-timeout 30 --max-time 600 -o "$archive" "$url"; then
    fail "$label: could not download $url"
    return
  fi
  if [ "$(sha256sum "$archive" | cut -d' ' -f1)" != "$sha" ]; then
    fail "$label: $url does not match the cask's sha256"
    return
  fi
  mkdir -p "$dir"
  if ! tar -xf "$archive" -C "$dir"; then
    fail "$label: could not extract $url"
    return
  fi

  local stmt path before
  while IFS= read -r stmt; do
    case $stmt in
      binary\ * | copy\ *)
        path=$(sed -nE 's/^(binary|copy) "([^"]+)".*/\2/p' <<<"$stmt")
        if [ -z "$path" ]; then
          fail "$label: cannot parse: $stmt"
        elif [ ! -f "$dir/$path" ]; then
          fail "$label: archive has no $path (needed by: ${stmt%%,*})"
        fi
        ;;
      inreplace\ *)
        path=$(sed -nE 's/^inreplace "([^"]+)", "([^"\\]*)",.*/\1/p' <<<"$stmt")
        before=$(sed -nE 's/^inreplace "([^"]+)", "([^"\\]*)",.*/\2/p' <<<"$stmt")
        if [ -z "$path" ] || [ -z "$before" ]; then
          fail "$label: cannot parse: $stmt"
        elif [ ! -f "$dir/$path" ]; then
          fail "$label: archive has no $path (needed by inreplace)"
        elif ! grep -qF -- "$before" "$dir/$path"; then
          fail "$label: $path no longer contains \"$before\" for inreplace"
        fi
        ;;
    esac
  done < <(statements "$cask")

  # shellcheck disable=SC2016 # literal $PWD in the cask's script
  while IFS= read -r path; do
    [ -n "$(find "$dir/$path" -mindepth 1 -maxdepth 1 2>/dev/null | head -n1)" ] ||
      fail "$label: archive has no files in $path/ (globbed by an install step)"
  done < <(grep -oE '"\$PWD"/[A-Za-z0-9._-]+/\*' "$cask" | sed -E 's|^"\$PWD"/||; s|/\*$||' | sort -u)

  # shellcheck disable=SC2088 # literal ~/ in the archive's XML
  if grep -qF -- "-name '*.xml'" "$cask" && grep -qF -- 's|~|' "$cask"; then
    [ -n "$(find "$dir" -type f -name '*.xml' -exec grep -lF '~/' {} + 2>/dev/null | head -n1)" ] ||
      fail "$label: no XML file uses ~/ for the install step to rewrite"
  fi
}

casks=("$@")
[ "${#casks[@]}" -gt 0 ] || casks=(Casks/*.rb)

for cask in "${casks[@]}"; do
  name=$(basename "$cask" .rb)
  version=$(field "$cask" '^[[:space:]]*version "([^"]+)".*')
  url=$(field "$cask" '^[[:space:]]*url "([^"]+)".*')
  if [ -z "$version" ] || [ -z "$url" ]; then
    fail "$name: cannot read version or url"
    continue
  fi
  url=${url//'#{version}'/$version}

  if grep -qE '^[[:space:]]*arch arm:' "$cask"; then
    # brew arch name, sha256 key for Linux on that arch
    for pair in "arm:arm64_linux" "intel:x86_64_linux"; do
      arch=$(field "$cask" "^[[:space:]]*arch .*${pair%%:*}: \"([^\"]+)\".*")
      sha=$(field "$cask" "^.*${pair#*:}:[[:space:]]+\"([0-9a-f]{64})\".*")
      if [ -z "$arch" ] || [ -z "$sha" ]; then
        fail "$name: cannot read arch or sha256 for ${pair#*:}"
        continue
      fi
      check_archive "$cask" "$name ($arch)" "${url//'#{arch}'/$arch}" "$sha" "$tmp/$name-$arch"
    done
  else
    sha=$(field "$cask" '^[[:space:]]*sha256 "([0-9a-f]{64})".*')
    if [ -z "$sha" ]; then
      fail "$name: cannot read sha256"
      continue
    fi
    check_archive "$cask" "$name" "$url" "$sha" "$tmp/$name"
  fi
done

[ "$fails" -eq 0 ] && echo "cask-payload: all checks passed"
exit "$fails"
