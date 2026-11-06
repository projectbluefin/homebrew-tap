# Sourced by the cask test scripts; not run on its own.
# shellcheck shell=bash

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
