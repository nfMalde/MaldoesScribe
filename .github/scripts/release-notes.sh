#!/usr/bin/env bash
# Pulls the notes of one version out of CHANGELOG.md (Keep a Changelog format) into a Markdown file.
#
#   release-notes.sh CHANGELOG.md 1.2.0 false notes.md
#
# Takes the "## [1.2.0]" section. For a prerelease (third argument "true") whose exact version has no
# section, the "## [Unreleased]" section is used instead. The output is empty when nothing was found;
# the caller decides what that means.
set -euo pipefail

changelog="$1"
version="$2"
prerelease="${3:-false}"
out="$4"

# The heading is compared as plain text (no regex), so dots and brackets in the version need no escaping.
section() {
    SECTION="$1" awk '
        BEGIN { heading = "## [" ENVIRON["SECTION"] "]"; width = length(heading) }
        !on && substr($0, 1, width) == heading { on = 1; next }
        on && /^## \[/ { exit }
        on { lines[++n] = $0 }
        END {
            start = 1
            while (start <= n && lines[start] ~ /^[[:space:]]*$/) start++
            end = n
            while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
            for (i = start; i <= end; i++) print lines[i]
        }' "$changelog"
}

section "$version" > "$out"
if [[ ! -s "$out" && "$prerelease" == "true" ]]; then
    section "Unreleased" > "$out"
fi
