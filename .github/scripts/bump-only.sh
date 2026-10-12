#!/usr/bin/env bash
# Exits 0 only when a pull request changes nothing but cask `version` and `sha256` lines.
# stdin: `gh api --paginate repos/{owner}/{repo}/pulls/{n}/files` output (one or more JSON arrays).
# The version charset excludes `/` and quotes so a bump cannot redirect the cask's url path.
set -euo pipefail

jq -se '
  add // [] | length > 0 and all(.[];
    (.filename | test("^Casks/[a-z0-9-]+\\.rb$"))
    and .status == "modified"
    and ([(.patch // "") | split("\n")[] | select(test("^[-+]"))]
         | length > 0 and all(.[];
             test("^[-+] *(version \"[0-9A-Za-z._,-]+\"|(sha256 +)?([a-z0-9_]+: *)?\"[0-9a-f]{64}\",?) *$"))))
' >/dev/null
