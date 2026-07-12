#!/usr/bin/env bash
set -euo pipefail

manifest=${1:-build/shaders/slang-manifest.txt}
test -s "$manifest"

expected=$(awk '
    /\[shader\("(compute|vertex|fragment)"\)\]/ { count += 1 }
    END { print count + 0 }
' $(find assets/shaders -type f -name '*.slang' | sort))
actual=$(wc -l < "$manifest" | tr -d ' ')

if [ "$actual" -ne "$expected" ]; then
    echo "shader manifest has $actual entries; expected $expected" >&2
    exit 1
fi
if awk -F'|' 'NF != 6 || $5 != "SPIR-V 1.6" || $6 != "vulkan1.3" { exit 1 }' "$manifest"; then :; else
    echo "shader manifest contains a non-Vulkan-1.3/SPIR-V-1.6 entry" >&2
    exit 1
fi
cut -d'|' -f1-3 "$manifest" | sort | uniq -d | grep . && {
    echo "shader manifest contains duplicate source/stage/entry records" >&2
    exit 1
}
while IFS='|' read -r source stage entry output spirv environment; do
    test -s "$output" || { echo "missing shader output: $output" >&2; exit 1; }
done < "$manifest"
