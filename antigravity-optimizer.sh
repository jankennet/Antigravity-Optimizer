#!/usr/bin/env bash

# ============================================================
# Antigravity Low-End Optimizer
# ============================================================

set -u

ANTIGRAVITY_BIN="/usr/bin/antigravity-ide"

BASE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/antigravity-lowend"
BACKUP_DIR="$BASE_DIR/backups"

mkdir -p "$BASE_DIR" "$BACKUP_DIR"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
    GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"
else
    RESET=""; BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; CYAN=""
fi

info() { printf "  ${CYAN}%-14s${RESET} %s\n" "$1" "$2"; }
ok()   { printf "  ${GREEN}%-14s${RESET} %s\n" "$1" "$2"; }
warn() { printf "  ${YELLOW}%-14s${RESET} %s\n" "$1" "$2"; }
fail() { printf "  ${RED}%-14s${RESET} %s\n" "$1" "$2"; }

section() {
    echo
    printf "${BOLD}%s${RESET}\n" "$1"
    printf "%s\n" "------------------------------------------------------------"
}

show_help() {
    cat <<'EOF'
Usage:
  antigravity-lowend                     Optimize and launch
  antigravity-lowend --optimize          Optimize only, no launch
  antigravity-lowend --profile <name>    auto | normal | low | extreme
  antigravity-lowend --safe              Compatibility mode (no GPU)
  antigravity-lowend --status            Show detected hardware/state
  antigravity-lowend --reset             Restore latest settings backup
  antigravity-lowend --help              Show this help

See README.md for details on each profile.
EOF
}

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------

PROFILE="auto"
OPTIMIZE_ONLY=0
RESET_REQUESTED=0
STATUS_REQUESTED=0
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || { fail "ERROR" "--profile requires a value"; exit 1; }
            PROFILE="${2,,}"
            shift 2
            ;;
        --safe)     PROFILE="safe"; shift ;;
        --optimize) OPTIMIZE_ONLY=1; shift ;;
        --reset)    RESET_REQUESTED=1; shift ;;
        --status)   STATUS_REQUESTED=1; shift ;;
        --help|-h)  show_help; exit 0 ;;
        *)          PASSTHROUGH_ARGS+=("$1"); shift ;;
    esac
done

# ------------------------------------------------------------
# Hardware detection
# ------------------------------------------------------------

CPU_THREADS="$(nproc 2>/dev/null || echo 1)"

CPU_MODEL="$(
    awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' \
        /proc/cpuinfo 2>/dev/null
)"
[[ -n "$CPU_MODEL" ]] || CPU_MODEL="Unknown CPU"

MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)"
[[ -n "$MEM_KB" ]] || MEM_KB=0
MEM_GB=$(( MEM_KB / 1024 / 1024 ))

# CPU classification
CPU_CLASS="normal"
if (( CPU_THREADS <= 2 )); then
    CPU_CLASS="extreme"
elif (( CPU_THREADS <= 4 )); then
    CPU_CLASS="low"
fi
if echo "$CPU_MODEL" | grep -Eiq \
    'Celeron N[0-9]+|Pentium Silver|Pentium N[0-9]+|Atom|Athlon Silver|Athlon 300U'; then
    CPU_CLASS="extreme"
fi

# RAM classification
RAM_CLASS="normal"
if (( MEM_GB <= 4 )); then
    RAM_CLASS="extreme"
elif (( MEM_GB <= 8 )); then
    RAM_CLASS="low"
fi

# Automatic profile
if [[ "$PROFILE" == "auto" ]]; then
    if [[ "$CPU_CLASS" == "extreme" || "$RAM_CLASS" == "extreme" ]]; then
        PROFILE="extreme"
    elif [[ "$CPU_CLASS" == "low" || "$RAM_CLASS" == "low" ]]; then
        PROFILE="low"
    else
        PROFILE="normal"
    fi
fi

case "$PROFILE" in
    normal|low|extreme|safe) ;;
    *) fail "ERROR" "Invalid profile: $PROFILE"; exit 1 ;;
esac

# ------------------------------------------------------------
# Find settings file
# ------------------------------------------------------------

SETTINGS_FILE=""
CANDIDATES=(
    "$HOME/.config/Antigravity/User/settings.json"
    "$HOME/.config/antigravity/User/settings.json"
)

for candidate in "${CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
        SETTINGS_FILE="$candidate"
        break
    fi
done

if [[ -z "$SETTINGS_FILE" && -d "$HOME/.config" ]]; then
    FOUND="$(
        find "$HOME/.config" -type f \
            \( -path '*/Antigravity/User/settings.json' \
            -o -path '*/antigravity/User/settings.json' \) \
            2>/dev/null | head -n 1
    )"
    [[ -n "$FOUND" ]] && SETTINGS_FILE="$FOUND"
fi

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

if [[ "$STATUS_REQUESTED" -eq 1 ]]; then
    section "ANTIGRAVITY LOW-END STATUS"
    info "CPU" "$CPU_MODEL"
    info "THREADS" "$CPU_THREADS"
    info "RAM" "${MEM_GB} GiB"
    info "CPU CLASS" "$CPU_CLASS"
    info "RAM CLASS" "$RAM_CLASS"
    info "PROFILE" "$PROFILE"

    if [[ -n "$SETTINGS_FILE" ]]; then
        info "SETTINGS" "$SETTINGS_FILE"
    else
        warn "SETTINGS" "Not found"
    fi

    if [[ -x "$ANTIGRAVITY_BIN" ]]; then
        ok "BINARY" "$ANTIGRAVITY_BIN"
    else
        warn "BINARY" "Not found"
    fi

    exit 0
fi

# ------------------------------------------------------------
# Reset
# ------------------------------------------------------------

if [[ "$RESET_REQUESTED" -eq 1 ]]; then
    section "ANTIGRAVITY LOW-END RESET"

    LATEST_BACKUP="$(
        find "$BACKUP_DIR" -type f -name 'settings.json.*.backup' \
            -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-
    )"

    if [[ -z "$LATEST_BACKUP" ]]; then
        fail "RESET" "No settings backup found."
        exit 1
    fi

    if [[ -z "$SETTINGS_FILE" ]]; then
        SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"
        mkdir -p "$(dirname "$SETTINGS_FILE")"
    fi

    cp "$LATEST_BACKUP" "$SETTINGS_FILE"

    ok "RESTORE" "Previous settings restored"
    info "SOURCE" "$LATEST_BACKUP"
    info "TARGET" "$SETTINGS_FILE"
    echo
    ok "DONE" "Reset complete."
    exit 0
fi

# ------------------------------------------------------------
# Validate binary
# ------------------------------------------------------------

if [[ ! -x "$ANTIGRAVITY_BIN" ]]; then
    fail "ERROR" "Antigravity binary not found:"
    echo "          $ANTIGRAVITY_BIN"
    exit 1
fi

# ------------------------------------------------------------
# Create settings file if missing
# ------------------------------------------------------------

if [[ -z "$SETTINGS_FILE" ]]; then
    SETTINGS_DIR="$HOME/.config/Antigravity/User"
    mkdir -p "$SETTINGS_DIR"
    SETTINGS_FILE="$SETTINGS_DIR/settings.json"
fi

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_FILE="$BACKUP_DIR/settings.json.$TIMESTAMP.backup"

if [[ -f "$SETTINGS_FILE" ]]; then
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    ok "BACKUP" "$BACKUP_FILE"
else
    touch "$SETTINGS_FILE"
    ok "SETTINGS" "Created settings.json"
fi

# ------------------------------------------------------------
# Display
# ------------------------------------------------------------

clear 2>/dev/null || true

printf "\n"
printf "${BOLD}Antigravity Low-End Optimizer${RESET}\n"
printf "Adaptive + Agent Responsiveness mode\n"

section "HARDWARE"
info "CPU" "$CPU_MODEL"
info "THREADS" "$CPU_THREADS"
info "RAM" "${MEM_GB} GiB"
info "CPU CLASS" "$CPU_CLASS"
info "RAM CLASS" "$RAM_CLASS"

section "PROFILE"
case "$PROFILE" in
    normal)  info "PROFILE" "NORMAL";          info "TARGET" "Conservative optimization" ;;
    low)     info "PROFILE" "LOW";             info "TARGET" "Low-end optimization" ;;
    extreme) info "PROFILE" "EXTREME LOW-END"; info "TARGET" "Agent responsiveness" ;;
    safe)    info "PROFILE" "SAFE";            info "TARGET" "Maximum compatibility" ;;
esac

section "OPTIMIZATION PROCEDURE"
echo "  STEP 1/10  Detect hardware"
echo "  STEP 2/10  Select adaptive profile"
echo "  STEP 3/10  Backup existing configuration"
echo "  STEP 4/10  Reduce editor rendering workload"
echo "  STEP 5/10  Reduce file watcher workload"
echo "  STEP 6/10  Reduce Git background activity"
echo "  STEP 7/10  Reduce search/index workload"
echo "  STEP 8/10  Reduce agent-output rendering pressure"
echo "  STEP 9/10  Configure Electron compatibility"
echo "  STEP 10/10 Launch optimized Antigravity"
echo

# ------------------------------------------------------------
# Generate settings via python3
# ------------------------------------------------------------

PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
    fail "ERROR" "python3 is required."
    exit 1
fi

export AG_SETTINGS_FILE="$SETTINGS_FILE"
export AG_PROFILE="$PROFILE"

"$PYTHON_BIN" <<'PY'
import json, os, re, sys

settings_file = os.environ["AG_SETTINGS_FILE"]
profile = os.environ["AG_PROFILE"]


def strip_jsonc(text):
    """Strip // and /* */ comments and trailing commas from JSONC."""
    output = []
    i, n = 0, len(text)
    string = escape = line_comment = block_comment = False

    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if line_comment:
            if c == "\n":
                line_comment = False
                output.append(c)
            i += 1
            continue

        if block_comment:
            if c == "*" and nxt == "/":
                block_comment = False
                i += 2
            else:
                i += 1
            continue

        if string:
            output.append(c)
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                string = False
            i += 1
            continue

        if c == '"':
            string = True
            output.append(c)
            i += 1
            continue

        if c == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue

        if c == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue

        output.append(c)
        i += 1

    result = "".join(output)
    return re.sub(r",(\s*[}\]])", r"\1", result)


try:
    with open(settings_file, "r", encoding="utf-8") as f:
        raw = f.read()
    settings = json.loads(strip_jsonc(raw)) if raw.strip() else {}
    if not isinstance(settings, dict):
        settings = {}
except Exception as exc:
    print(f"ERROR: Unable to parse settings.json: {exc}")
    sys.exit(1)


settings.update({
    # Editor rendering
    "editor.minimap.enabled": False,
    "editor.smoothScrolling": False,
    "workbench.list.smoothScrolling": False,
    "editor.cursorSmoothCaretAnimation": "off",
    "editor.hover.delay": 500,
    "editor.lightbulb.enabled": "off",
    "editor.codeLens": False,
    "editor.stickyScroll.enabled": False,
    "editor.occurrencesHighlight": False,
    "editor.selectionHighlight": False,
    "editor.renderWhitespace": "none",
    "editor.renderControlCharacters": False,
    "editor.overviewRulerBorder": False,
    "editor.guides.bracketPairs": False,
    # Workbench
    "workbench.editor.enablePreview": True,
    "workbench.editor.limit.enabled": True,
    # Git
    "git.autofetch": False,
    "git.autorefresh": False,
    # Search
    "search.followSymlinks": False,
    # Source control decorations
    "scm.diffDecorations": "none",
    # File saving
    "files.autoSave": "off",
})

# File watcher exclusions (avoids event storms from agent-generated dirs)
settings["files.watcherExclude"] = {
    "**/.git/objects/**": True,
    "**/.git/subtree-cache/**": True,
    "**/node_modules/**": True,
    "**/.next/**": True,
    "**/dist/**": True,
    "**/build/**": True,
    "**/coverage/**": True,
    "**/.cache/**": True,
    "**/.turbo/**": True,
    "**/.parcel-cache/**": True,
    "**/.vite/**": True,
    "**/target/**": True,
    "**/__pycache__/**": True,
    "**/.venv/**": True,
}

settings["search.exclude"] = {
    "**/node_modules": True,
    "**/.git": True,
    "**/dist": True,
    "**/build": True,
    "**/.next": True,
    "**/coverage": True,
    "**/.cache": True,
    "**/.turbo": True,
    "**/target": True,
    "**/__pycache__": True,
    "**/.venv": True,
}

if profile == "normal":
    settings["workbench.editor.limit.value"] = 8
    settings["terminal.integrated.scrollback"] = 2000
elif profile == "low":
    settings["workbench.editor.limit.value"] = 5
    settings["terminal.integrated.scrollback"] = 1000
elif profile in ("extreme", "safe"):
    settings["workbench.editor.limit.value"] = 3
    settings["terminal.integrated.scrollback"] = 500

if profile in ("extreme", "safe"):
    settings["editor.inlayHints.enabled"] = "off"
    settings["editor.bracketPairColorization.enabled"] = False
    settings["editor.guides.bracketPairs"] = False
    settings["editor.semanticHighlighting.enabled"] = False
    settings["terminal.integrated.gpuAcceleration"] = "off"
    settings["terminal.integrated.scrollback"] = 500

temp = settings_file + ".tmp"
with open(temp, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(temp, settings_file)

print("OK")
PY

if [[ $? -ne 0 ]]; then
    fail "CONFIG" "Configuration generation failed."
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$SETTINGS_FILE"
        warn "RESTORE" "Original configuration restored."
    fi
    exit 1
fi

ok "CONFIG" "Agent responsiveness configuration applied"

# ------------------------------------------------------------
# Electron / Node / environment
# ------------------------------------------------------------

ELECTRON_ARGS=()
if [[ "$PROFILE" == "safe" ]]; then
    ELECTRON_ARGS+=("--disable-gpu")
fi
ok "ELECTRON" "Using stable Electron arguments only"

case "$PROFILE" in
    normal)  NODE_HEAP=1536 ;;
    low)     NODE_HEAP=1024 ;;
    extreme) NODE_HEAP=768 ;;
    safe)    NODE_HEAP=768 ;;
esac

export NODE_OPTIONS="--max-old-space-size=${NODE_HEAP}"
ok "MEMORY" "Node heap: ${NODE_HEAP} MB"

export ANTIGRAVITY_LOWEND=1
export ANTIGRAVITY_LOWEND_PROFILE="$PROFILE"

# ------------------------------------------------------------
# Final configuration
# ------------------------------------------------------------

section "FINAL CONFIGURATION"
info "Profile" "$PROFILE"
info "CPU" "$CPU_MODEL"
info "RAM" "${MEM_GB} GiB"
info "Threads" "$CPU_THREADS"
info "Node heap" "${NODE_HEAP} MB"
info "GPU" "$([[ "$PROFILE" == "safe" ]] && echo "software" || echo "hardware")"
info "Agent mode" "$([[ "$PROFILE" == "extreme" || "$PROFILE" == "safe" ]] && echo "RESPONSIVE" || echo "BALANCED")"
info "Diagnostics" "OFF"
echo

if [[ "$OPTIMIZE_ONLY" -eq 1 ]]; then
    ok "DONE" "Antigravity optimization complete."
    echo
    echo "  Launch with:"
    echo "    antigravity-lowend"
    echo
    exit 0
fi

section "LAUNCH"
echo "  Antigravity is starting with the optimized configuration."
echo

exec "$ANTIGRAVITY_BIN" "${ELECTRON_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}"