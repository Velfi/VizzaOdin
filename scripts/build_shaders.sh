#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <slangc> <shader_src_dir> <shader_build_dir>"
    exit 1
fi

SLANGC=$1
SHADER_SRC=$2
SHADER_BUILD=$3

if [ ! -x "$SLANGC" ]; then
    echo "slangc not executable: $SLANGC" >&2
    exit 1
fi

MANIFEST="${SHADER_BUILD}/slang-manifest.txt"
mkdir -p "$SHADER_BUILD"
: > "$MANIFEST"

should_recompile() {
    local input=$1
    local output=$2
    if [ ! -f "$output" ]; then
        return 0
    fi
    if [ "$input" -nt "$output" ]; then
        return 0
    fi
    if [ -d "${SHADER_SRC}/common" ]; then
        local common_dep
        while IFS= read -r common_dep; do
            if [ "$common_dep" -nt "$output" ]; then
                return 0
            fi
        done < <(find "${SHADER_SRC}/common" -type f -name '*.slang')
    fi
    return 1
}

extract_stage_entries() {
    local source=$1
    local current_stage=""
    local line
    local entry

    while IFS= read -r line; do
        if [[ $line =~ \[shader\(\"(compute|vertex|fragment)\"\) ]]; then
            current_stage="${BASH_REMATCH[1]}"
            continue
        fi

        if [ -z "$current_stage" ]; then
            continue
        fi

        if [[ $line =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\( ]]; then
            entry="${BASH_REMATCH[1]}"
            printf '%s|%s\n' "$current_stage" "$entry"
            current_stage=""
        fi
    done < "$source"
}

while IFS= read -r source; do
    rel=${source#"${SHADER_SRC}/"}
    out_base="${SHADER_BUILD}/${rel%.slang}"
    mkdir -p "$(dirname "$out_base")"

    entries=()
    entry_count=0
    while IFS= read -r stage_entry; do
        entries[$entry_count]="$stage_entry"
        entry_count=$((entry_count + 1))
    done < <(extract_stage_entries "$source")

    if [ $entry_count -eq 0 ]; then
        echo "Skipping ${source}: no shader entry markers found"
        continue
    fi

    if [ $entry_count -eq 1 ]; then
        stage_entry=${entries[0]}
        stage=${stage_entry%|*}
        entry=${stage_entry#*|}
        output="${out_base}.spv"
        if should_recompile "$source" "$output"; then
            "$SLANGC" "$source" -target spirv -profile spirv_1_5 -stage "$stage" -entry "$entry" -o "$output"
            echo "Compiled ${source} [${stage}/${entry}] -> ${output}"
        else
            echo "Up to date ${source} [${stage}/${entry}]"
        fi
        printf '%s|%s|%s|%s\n' "$source" "$stage" "$entry" "$output" >> "$MANIFEST"
    else
        for stage_entry in "${entries[@]}"; do
            stage=${stage_entry%|*}
            entry=${stage_entry#*|}
            stage_count=0
            for counted_stage_entry in "${entries[@]}"; do
                counted_stage=${counted_stage_entry%|*}
                if [ "$counted_stage" = "$stage" ]; then
                    stage_count=$((stage_count + 1))
                fi
            done
            if [ "$stage_count" -gt 1 ]; then
                output="${out_base}_${stage}_${entry}.spv"
            else
                output="${out_base}_${stage}.spv"
            fi
            if should_recompile "$source" "$output"; then
                "$SLANGC" "$source" -target spirv -profile spirv_1_5 -stage "$stage" -entry "$entry" -o "$output"
                echo "Compiled ${source} [${stage}/${entry}] -> ${output}"
            else
                echo "Up to date ${source} [${stage}/${entry}]"
            fi
            printf '%s|%s|%s|%s\n' "$source" "$stage" "$entry" "$output" >> "$MANIFEST"
        done
    fi
done < <(find "$SHADER_SRC" -type f -name '*.slang' | sort)
