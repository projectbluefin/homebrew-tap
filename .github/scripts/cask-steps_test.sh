#!/usr/bin/env bash
# Runs the shell scripts embedded in the casks' install and uninstall steps
# against throwaway fixtures: `.github/scripts/cask-steps_test.sh`.
# `brew test-bot --only-tap-syntax` parses the casks but never executes these.
set -euo pipefail
cd "$(dirname "$0")/../.."

fails=0
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# snippet CASK BLOCK: print the heredoc passed to `run` inside `BLOCK do`,
# dedented the way Ruby's <<~ does. Unquoted heredocs must not contain
# backslashes or #{, #$ or #@ (Ruby interpolation): Ruby would rewrite
# those, so the text here would no longer be what Homebrew runs.
snippet() {
  awk -v block="  $2 do" '
    index($0, block) == 1 { inblock = 1; next }
    inblock && /^  end$/ { exit }
    inblock && !body && /<<~/ {
      body = 1; quoted = ($0 ~ /<<~\047SH\047/); next
    }
    body && /^[[:space:]]*SH$/ { done = 1; exit }
    body {
      lines[++n] = $0
      if ($0 ~ /[^[:space:]]/) {
        match($0, /^ */)
        if (min == "" || RLENGTH < min) min = RLENGTH
      }
    }
    END {
      if (!done) { print "no heredoc in block: " block > "/dev/stderr"; exit 1 }
      for (i = 1; i <= n; i++) {
        line = substr(lines[i], min + 1)
        if (!quoted && (line ~ /\\/ || line ~ /#[{$@]/)) {
          print "unquoted heredoc needs Ruby escaping: " line > "/dev/stderr"; exit 1
        }
        print line
      }
    }
  ' "$1"
}

# --- bluefin-wallpapers-extra: preflight rewrites ~ in XML to the user home ---
pre=$(snippet Casks/bluefin-wallpapers-extra.rb preflight_steps)
home="$tmp/h&o|m\\e"
staged="$tmp/pre-staged"
mkdir -p "$home" "$staged/gnome-background-properties/nested"
ln -s "$home" "$staged/.user-home"
printf '<filename>~/.local/share/backgrounds/bluefin/dusk/dusk-day.jxl</filename>\n' \
  >"$staged/gnome-background-properties/dusk.xml"
printf '<filename>~/a</filename><filename>~/b</filename>\n' \
  >"$staged/gnome-background-properties/nested/two.xml"
printf 'keep ~ here\n' >"$staged/README.txt"
(cd "$staged" && /bin/sh -eu -c "$pre") || fail "wallpapers preflight exited non-zero"

[ "$(cat "$staged/gnome-background-properties/dusk.xml")" = \
  "<filename>$home/.local/share/backgrounds/bluefin/dusk/dusk-day.jxl</filename>" ] ||
  fail "preflight did not substitute a home path containing &, | and \\"
[ "$(cat "$staged/gnome-background-properties/nested/two.xml")" = \
  "<filename>$home/a</filename><filename>$home/b</filename>" ] ||
  fail "preflight missed nested XML or a second ~ on the same line"
[ "$(cat "$staged/README.txt")" = "keep ~ here" ] || fail "preflight rewrote a non-XML file"
[ -z "$(find "$staged" -name '*.brew-home-backup')" ] || fail "preflight left sed backup files behind"

# --- bluefin-wallpapers-extra: postflight links images into per-wallpaper folders ---
post=$(snippet Casks/bluefin-wallpapers-extra.rb postflight_steps)
staged="$tmp/post-staged"
user="$tmp/post-home"
bg="$user/.local/share/backgrounds/bluefin"
props="$user/.local/share/gnome-background-properties"
mkdir -p "$staged/images" "$staged/gnome-background-properties" "$bg" "$props"
touch "$staged/images/"{dusk-day.jxl,dusk-night.jxl,lazy-days.jxl,v1.2.png}
touch "$staged/gnome-background-properties/dusk.xml"
run_post() { (cd "$staged" && WALLPAPER_HOME="$user" /bin/bash -eu -c "$post"); }
run_post || fail "wallpapers postflight exited non-zero"
run_post || fail "wallpapers postflight is not re-runnable over existing links"

for link in dusk/dusk-day.jxl dusk/dusk-night.jxl lazy-days/lazy-days.jxl v1.2/v1.2.png; do
  [ "$(readlink "$bg/$link")" = "$staged/images/${link#*/}" ] || fail "postflight did not link $link"
done
[ ! -e "$bg/lazy" ] || fail "postflight stripped -day from inside lazy-days"
[ "$(readlink "$props/dusk.xml")" = "$staged/gnome-background-properties/dusk.xml" ] ||
  fail "postflight did not link gnome-background-properties/dusk.xml"
[ "$(find "$bg" -mindepth 1 -maxdepth 1 | wc -l)" -eq 3 ] || fail "postflight created unexpected folders"

empty="$tmp/post-empty"
mkdir -p "$empty"
(cd "$empty" && WALLPAPER_HOME="$tmp/empty-home" /bin/bash -eu -c "$post") ||
  fail "postflight fails when the archive has no images or properties"

# --- chairlift: uninstall recompiles the schemas other applications left ---
uninst=$(snippet Casks/chairlift.rb uninstall_postflight_steps)
compiler=/usr/bin/glib-compile-schemas
[ "$(grep -c "$compiler" <<<"$uninst")" -eq 1 ] || fail "chairlift uninstall no longer calls $compiler once"
stub="$tmp/glib-compile-schemas"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\n' "$tmp/compiled" >"$stub"
chmod +x "$stub"
uninst=${uninst//"$compiler"/"$stub"}
schemas=.user-home/.local/share/glib-2.0/schemas

run_uninst() { # case-dir
  mkdir -p "$1/home"
  ln -sfn "$1/home" "$1/.user-home"
  : >"$tmp/compiled"
  (cd "$1" && /bin/sh -eu -c "$uninst")
}

case_dir="$tmp/no-dir"
run_uninst "$case_dir" || fail "chairlift uninstall fails when the schema directory is absent"
[ ! -s "$tmp/compiled" ] || fail "chairlift uninstall compiled a missing schema directory"

case_dir="$tmp/others"
mkdir -p "$case_dir/$schemas"
touch "$case_dir/$schemas/org.example.other.gschema.xml" "$case_dir/$schemas/gschemas.compiled"
run_uninst "$case_dir" || fail "chairlift uninstall fails when other schemas remain"
[ "$(cat "$tmp/compiled")" = "$schemas" ] || fail "chairlift uninstall did not recompile the remaining schemas"
[ -e "$case_dir/$schemas/gschemas.compiled" ] || fail "chairlift uninstall deleted a cache other schemas need"

case_dir="$tmp/only-cache"
mkdir -p "$case_dir/$schemas"
touch "$case_dir/$schemas/gschemas.compiled"
run_uninst "$case_dir" || fail "chairlift uninstall fails when only the compiled cache remains"
[ ! -s "$tmp/compiled" ] || fail "chairlift uninstall compiled an empty schema directory"
[ ! -e "$case_dir/$schemas/gschemas.compiled" ] || fail "chairlift uninstall left a stale compiled cache"

[ "$fails" -eq 0 ] && echo "cask-steps: all checks passed"
exit "$fails"
