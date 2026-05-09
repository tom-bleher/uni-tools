#!/bin/bash
#
# install.sh — Install LyX on macOS (arm/Intel) with Hebrew + XeLaTeX support
# Based on the Madlyx guide by Michael Kali (Oct 2025)
#
# Installs: MacTeX, LyX, Culmus + Noto Hebrew fonts
# Configures: Hebrew RTL, David CLM fonts, F12 language toggle, XeTeX output
#
# Prerequisites: macOS (Homebrew auto-installed if needed)
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh)"
#

# Wrapping braces ensure the entire script is downloaded before execution,
# protecting against partial downloads when piped via curl.
{

set -euo pipefail

# ── Colors & output helpers ──────────────────────────
BOLD=$'\033[1m'; DIM=$'\033[90m'; NC=$'\033[0m'
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'

info()    { echo -e "  ${CYAN}●${NC} $1"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1"; }

# ── Log file ────────────────────────────────────────
LOG_FILE="$HOME/.lyx-he-install.log"
echo "" >> "$LOG_FILE"
echo "═══ lyx-he install — $(date) ═══" >> "$LOG_FILE"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Spinner for long-running commands ────────────────
# Usage: run_with_spinner "message" command [args...]
# Redirects stdout/stderr to the log file, shows a spinner with elapsed time.
_bg_cmd_pid=""
run_with_spinner() {
    local msg="$1"; shift
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local cmd_start=$SECONDS

    log "Running: $*"

    # Start the command in the background, redirecting to log
    "$@" >> "$LOG_FILE" 2>&1 &
    _bg_cmd_pid=$!

    # Show spinner if interactive
    if [ -t 1 ]; then
        printf '\e[?25l'  # hide cursor
        while kill -0 "$_bg_cmd_pid" 2>/dev/null; do
            local el=$(( SECONDS - cmd_start ))
            local ts
            if [ "$el" -ge 60 ]; then
                ts=$(printf '%dm%02ds' $((el / 60)) $((el % 60)))
            else
                ts=$(printf '%ds' "$el")
            fi
            for ((c = 0; c < ${#spin_chars}; c++)); do
                kill -0 "$_bg_cmd_pid" 2>/dev/null || break
                printf '\r  %s %s %s' "${spin_chars:$c:1}" "$msg" "${DIM}${ts}${NC}"
                sleep 0.08
            done
        done
        printf '\r\e[2K'  # clear spinner line
        printf '\e[?25h'  # restore cursor
    else
        # Non-interactive: print periodic status to stderr
        while kill -0 "$_bg_cmd_pid" 2>/dev/null; do
            sleep 10
            printf '.' >&2
        done
        printf '\n' >&2
    fi

    local rc=0
    wait "$_bg_cmd_pid" || rc=$?
    _bg_cmd_pid=""
    log "Exit code: $rc"
    if [ "$rc" -ne 0 ]; then
        fail "$msg — failed (see $LOG_FILE)"
        echo -e "  ${DIM}Last 5 lines of log:${NC}"
        tail -5 "$LOG_FILE" | while IFS= read -r line; do
            echo -e "  ${DIM}  $line${NC}"
        done
    fi
    return "$rc"
}

# Section header with horizontal rule
header() {
    local text="$1"
    local rule; printf -v rule '─%.0s' $(seq 1 50)
    echo ""
    echo -e "  ${DIM}${rule}${NC}"
    echo -e "  ${BOLD}${text}${NC}"
    echo -e "  ${DIM}${rule}${NC}"
}

# Progress step counter (set _total and _cur=0 before first call)
_cur=0; _total=0; _step_start=0
step() {
    _cur=$((_cur + 1))
    _step_start=$SECONDS
    local filled=$(( _cur * 20 / _total ))
    local empty=$(( 20 - filled ))
    local bar=""
    for ((i = 0; i < filled; i++)); do bar+="━"; done
    for ((i = 0; i < empty; i++)); do bar+="╌"; done
    echo ""
    echo -e "  ${BOLD}[${_cur}/${_total}]${NC} ${CYAN}${bar}${NC}  ${BOLD}$1${NC}"
}

# Format elapsed time since last step()
fmt_elapsed() {
    local el=$(( SECONDS - _step_start ))
    if [ "$el" -ge 60 ]; then
        printf '%dm%02ds' $((el / 60)) $((el % 60))
    else
        printf '%ds' "$el"
    fi
}

# ── Sudo keepalive helper ────────────────────────────
# Call sudo_init to prompt once; a background loop keeps the ticket alive.
_sudo_keepalive_pid=""
sudo_init() {
    if [ -t 0 ]; then
        info "Requesting administrator privileges (once)..."
        sudo -v || { fail "sudo authentication failed"; exit 1; }
        # Refresh sudo timestamp every 50s in the background
        while true; do sudo -n true; sleep 50; done 2>/dev/null &
        _sudo_keepalive_pid=$!
    fi
}

# ── Cleanup ──────────────────────────────────────────
cleanup() {
    if [ -n "$_bg_cmd_pid" ]; then
        kill "$_bg_cmd_pid" 2>/dev/null || true
    fi
    if [ -n "$_sudo_keepalive_pid" ]; then
        kill "$_sudo_keepalive_pid" 2>/dev/null || true
    fi
    if [ -t 1 ]; then printf '\e[?25h' 2>/dev/null; fi   # restore cursor visibility
    rm -rf "${CULMUS_TMP:-}"
    rm -rf "${TEST_DIR:-}"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# ── TUI: Interactive checkbox selector ───────────────
# Set TUI_ITEMS (labels) and TUI_CHECKED (0/1) before calling.
# After return, TUI_CHECKED reflects the user's choices.
tui_checkbox() {
    local title="$1"
    local n=${#TUI_ITEMS[@]}
    local cur=0

    # Non-interactive fallback: keep pre-set state
    if [ ! -t 0 ] || [ ! -t 1 ]; then return 0; fi

    # ── Frame dimensions ──
    local max_item=0
    for ((i = 0; i < n; i++)); do
        [ ${#TUI_ITEMS[i]} -gt "$max_item" ] && max_item=${#TUI_ITEMS[i]}
    done
    local hint="↑↓ navigate · Space toggle · a/n all/none · Enter confirm"
    local inner=$(( max_item + 10 ))
    [ $(( ${#hint} + 4 )) -gt "$inner" ] && inner=$(( ${#hint} + 4 ))
    [ $(( ${#title} + 5 )) -gt "$inner" ] && inner=$(( ${#title} + 5 ))

    local hrule; printf -v hrule '─%.0s' $(seq 1 "$inner")
    local title_rule; printf -v title_rule '─%.0s' $(seq 1 $(( inner - ${#title} - 3 )))
    local spacer; printf -v spacer '%*s' "$inner" ""
    local total_lines=$(( n + 6 ))

    printf '\e[?25l'  # hide cursor
    echo ""

    __tui_draw() {
        printf '\r\e[2K  ╭─ \e[1m%s\e[0m %s╮\n' "$title" "$title_rule"
        printf '\r\e[2K  │%s│\n' "$spacer"
        for ((i = 0; i < n; i++)); do
            local pad_n=$(( inner - 7 - ${#TUI_ITEMS[i]} ))
            local pad; printf -v pad '%*s' "$pad_n" ""
            if [ "$i" -eq "$cur" ]; then
                if [ "${TUI_CHECKED[i]}" = "1" ]; then
                    printf '\r\e[2K  │ \e[36m▸\e[0m [\e[36m✓\e[0m] \e[1m%s\e[0m%s│\n' "${TUI_ITEMS[i]}" "$pad"
                else
                    printf '\r\e[2K  │ \e[36m▸\e[0m [ ] \e[1m%s\e[0m%s│\n' "${TUI_ITEMS[i]}" "$pad"
                fi
            else
                if [ "${TUI_CHECKED[i]}" = "1" ]; then
                    printf '\r\e[2K  │   [\e[36m✓\e[0m] %s%s│\n' "${TUI_ITEMS[i]}" "$pad"
                else
                    printf '\r\e[2K  │   [ ] \e[90m%s\e[0m%s│\n' "${TUI_ITEMS[i]}" "$pad"
                fi
            fi
        done
        printf '\r\e[2K  │%s│\n' "$spacer"
        printf '\r\e[2K  ├%s┤\n' "$hrule"
        local hpad_n=$(( inner - ${#hint} - 2 ))
        local hpad; printf -v hpad '%*s' "$hpad_n" ""
        printf '\r\e[2K  │ \e[90m%s\e[0m%s │\n' "$hint" "$hpad"
        printf '\r\e[2K  ╰%s╯\n' "$hrule"
    }

    __tui_draw

    while true; do
        IFS= read -rsn1 key 2>/dev/null || true
        if [ "$key" = $'\x1b' ]; then
            IFS= read -rsn2 seq 2>/dev/null || true
            case "$seq" in
                '[A') [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
                '[B') [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1)) ;;
            esac
        elif [ "$key" = 'k' ]; then
            [ "$cur" -gt 0 ] && cur=$((cur - 1))
        elif [ "$key" = 'j' ]; then
            [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1))
        elif [ "$key" = ' ' ]; then
            TUI_CHECKED[cur]=$(( 1 - TUI_CHECKED[cur] ))
        elif [ "$key" = 'a' ]; then
            for ((i = 0; i < n; i++)); do TUI_CHECKED[i]=1; done
        elif [ "$key" = 'n' ]; then
            for ((i = 0; i < n; i++)); do TUI_CHECKED[i]=0; done
        elif [ "$key" = '' ]; then
            break  # Enter
        fi
        printf '\e[%dA' "$total_lines"
        __tui_draw
    done

    printf '\e[?25h'  # restore cursor
    echo ""
    local _sel=0
    for ((i = 0; i < n; i++)); do [ "${TUI_CHECKED[i]}" = "1" ] && _sel=$((_sel + 1)); done
    echo -e "  ${DIM}${_sel} of ${n} selected${NC}"
}

# ── Usage ────────────────────────────────────────────
usage() {
    local url="https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh"
    echo ""
    echo -e "  ${BOLD}lyx-he${NC} — Hebrew LyX installer for macOS"
    echo ""
    echo -e "  ${BOLD}Install:${NC}"
    echo -e "    /bin/bash -c \"\$(curl -fsSL ${url})\""
    echo ""
    echo -e "  ${BOLD}Options:${NC}"
    echo -e "    ${CYAN}(none)${NC}           Interactive component picker ${DIM}(default)${NC}"
    echo -e "    ${CYAN}--force, -f${NC}      Install all components without prompting"
    echo -e "    ${CYAN}--uninstall${NC}      Interactively select components to remove"
    echo -e "    ${CYAN}--help, -h${NC}       Show this help message"
    echo ""
    echo -e "  ${BOLD}Examples:${NC}"
    echo -e "    curl -fsSL ${url} | bash -s -- --force"
    echo -e "    /bin/bash -c \"\$(curl -fsSL ${url})\" -- --uninstall"
    echo ""
    echo -e "  ${DIM}Already-installed components are skipped; existing LyX files are backed up before overwrite.${NC}"
    echo ""
}

# ── Detect LyX config directory ──────────────────────
lyx_version_gt() {
    local a="${1##*/LyX-}"
    local b="${2##*/LyX-}"
    local IFS=.
    local av=()
    local bv=()
    local i ai bi

    read -r -a av <<< "$a"
    read -r -a bv <<< "$b"

    for i in 0 1 2; do
        ai="${av[i]:-0}"; bi="${bv[i]:-0}"
        [[ "$ai" =~ ^[0-9]+$ ]] || ai=0
        [[ "$bi" =~ ^[0-9]+$ ]] || bi=0
        (( ai > bi )) && return 0
        (( ai < bi )) && return 1
    done
    return 1
}

detect_lyx_dir() {
    local dirs=()
    local d latest=""

    shopt -s nullglob
    dirs=("$HOME/Library/Application Support"/LyX-*)
    shopt -u nullglob

    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        if [ -z "$latest" ] || lyx_version_gt "$d" "$latest"; then
            latest="$d"
        fi
    done

    LYX_DIR="${latest:-$HOME/Library/Application Support/LyX-2.5}"
}

# ── Flags ────────────────────────────────────────────
FORCE=false
UNINSTALL=false
case "${1:-}" in
    --help|-h)      usage; exit 0 ;;
    --force|-f)     FORCE=true ;;
    --uninstall)    UNINSTALL=true ;;
    "") ;;
    *) fail "Unknown flag: $1"; echo ""; usage; exit 1 ;;
esac

if [ $# -gt 1 ]; then
    fail "Only one option allowed at a time"; echo ""; usage; exit 1
fi

INSTALL_START=$SECONDS

TEMPLATE_FILES=(
    templates/defaults.lyx
    templates/Hebrew_Article.lyx   templates/English_Article.lyx
    templates/Hebrew_Solutions.lyx  templates/English_Solutions.lyx
    templates/English_CV.lyx
)

REPO_RAW_BASE="${LYX_HE_RAW_BASE:-https://raw.githubusercontent.com/tom-bleher/lyx-he/main}"
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR=""
if [ -f "$SCRIPT_PATH" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)
fi

MANIFEST_FILE="$HOME/.lyx-he-manifest"

manifest_add() {
    local type="$1"
    local value="$2"
    local line="$type"$'\t'"$value"

    if [ ! -f "$MANIFEST_FILE" ] || ! grep -Fqx "$line" "$MANIFEST_FILE"; then
        printf '%s\n' "$line" >> "$MANIFEST_FILE"
    fi
}

manifest_has() {
    local type="$1"
    local value="$2"
    local line="$type"$'\t'"$value"

    [ -f "$MANIFEST_FILE" ] && grep -Fqx "$line" "$MANIFEST_FILE"
}

manifest_has_type() {
    local type="$1"
    local found_type value

    [ -f "$MANIFEST_FILE" ] || return 1
    while IFS=$'\t' read -r found_type value; do
        [ "$found_type" = "$type" ] && return 0
    done < "$MANIFEST_FILE"
    return 1
}

manifest_remove() {
    local type="$1"
    local value="$2"
    local line="$type"$'\t'"$value"
    local tmp existing

    [ -f "$MANIFEST_FILE" ] || return 0
    tmp=$(mktemp)
    while IFS= read -r existing; do
        [ "$existing" = "$line" ] || printf '%s\n' "$existing"
    done < "$MANIFEST_FILE" > "$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

prune_backups() {
    local base="$1"
    local backups=()
    local remove_count i

    shopt -s nullglob
    backups=("$base".bak.*)
    shopt -u nullglob

    [ "${#backups[@]}" -le 3 ] && return 0
    remove_count=$(( ${#backups[@]} - 3 ))
    for ((i = 0; i < remove_count; i++)); do
        rm -f "${backups[i]}"
    done
}

backup_file() {
    local path="$1"
    local backup

    [ -f "$path" ] || return 0
    backup="$path.bak.$(date +%s)"
    cp "$path" "$backup" || return 1
    prune_backups "$path" || return 1
}

confirm_overwrite() {
    local label="$1"; shift
    local existing=()
    local path answer

    for path in "$@"; do
        [ -e "$path" ] && existing+=("$path")
    done
    [ "${#existing[@]}" -eq 0 ] && return 0
    $FORCE && return 0

    if [ ! -t 0 ]; then
        fail "$label already exists. Re-run with --force to overwrite non-interactively."
        exit 1
    fi

    echo ""
    warn "$label already exists. Existing files will be backed up before overwrite."
    echo -ne "  Overwrite $label? [y/N] "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

install_file_from_temp() {
    local tmp="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")" || return 2
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp" || return 2
        manifest_add file "$dest" || return 2
        return 1
    fi
    backup_file "$dest" || return 2
    mv "$tmp" "$dest" || return 2
    manifest_add file "$dest" || return 2
    return 0
}

install_template_file() {
    local rel="$1"
    local dest="$LYX_DIR/$rel"
    local tmp

    tmp=$(mktemp)
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$rel" ]; then
        cp "$SCRIPT_DIR/$rel" "$tmp" || { rm -f "$tmp"; return 2; }
    else
        if ! run_with_spinner "Downloading $rel" curl -fsSL -o "$tmp" "$REPO_RAW_BASE/$rel"; then
            rm -f "$tmp"
            return 2
        fi
    fi

    install_file_from_temp "$tmp" "$dest"
}

report_install_status() {
    local rc="$1"
    local changed_msg="$2"
    local same_msg="$3"

    case "$rc" in
        0) ok "$changed_msg" ;;
        1) ok "$same_msg" ;;
        *) fail "$changed_msg failed"; exit "$rc" ;;
    esac
}

# ── Uninstall flow ───────────────────────────────────
if $UNINSTALL; then
    detect_lyx_dir
    header "Uninstall"

    TUI_ITEMS=()
    TUI_CHECKED=()
    UNINSTALL_ACTIONS=()

    _config_backups=()
    shopt -s nullglob
    _config_backups=("$LYX_DIR"/preferences.bak.* "$LYX_DIR"/bind/user.bind.bak.*)
    shopt -u nullglob

    _has_managed_config=false
    for f in preferences bind/user.bind templates/defaults.lyx; do
        manifest_has file "$LYX_DIR/$f" && _has_managed_config=true
    done
    if $_has_managed_config || [ "${#_config_backups[@]}" -gt 0 ]; then
        TUI_ITEMS+=("LyX preferences & keybindings (restore backups if available)")
        TUI_CHECKED+=(1)
        UNINSTALL_ACTIONS+=("config")
    fi

    _has_managed_templates=false
    for f in "${TEMPLATE_FILES[@]}"; do
        [ "$f" = "templates/defaults.lyx" ] && continue
        manifest_has file "$LYX_DIR/$f" && _has_managed_templates=true
    done
    if $_has_managed_templates; then
        TUI_ITEMS+=("Managed LyX templates")
        TUI_CHECKED+=(1)
        UNINSTALL_ACTIONS+=("templates")
    fi

    _CULMUS_MANAGED=()
    if [ -f "$MANIFEST_FILE" ]; then
        while IFS=$'\t' read -r _type _value; do
            [ "$_type" = "font" ] && [ -f "$_value" ] && _CULMUS_MANAGED+=("$_value")
        done < "$MANIFEST_FILE"
    fi
    if [ "${#_CULMUS_MANAGED[@]}" -gt 0 ]; then
        TUI_ITEMS+=("Managed Culmus Hebrew fonts (${#_CULMUS_MANAGED[@]} files)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("culmus")
    fi

    _NOTO_INSTALLED=()
    for cask in font-noto-sans-hebrew font-noto-serif-hebrew font-noto-rashi-hebrew; do
        manifest_has cask "$cask" && brew list --cask "$cask" &>/dev/null && _NOTO_INSTALLED+=("$cask")
    done
    if [ "${#_NOTO_INSTALLED[@]}" -gt 0 ]; then
        TUI_ITEMS+=("Managed Noto Hebrew fonts (${#_NOTO_INSTALLED[@]} casks)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("noto")
    fi

    if manifest_has cask lyx && brew list --cask lyx &>/dev/null; then
        TUI_ITEMS+=("Managed LyX application")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("lyx")
    fi

    if manifest_has cask mactex && brew list --cask mactex &>/dev/null; then
        TUI_ITEMS+=("Managed MacTeX (~6 GB)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("mactex")
    fi

    if [ ${#TUI_ITEMS[@]} -eq 0 ]; then
        info "Nothing managed by lyx-he found to uninstall."
        [ -f "$MANIFEST_FILE" ] || info "No manifest found at $MANIFEST_FILE; leaving untracked files alone."
        exit 0
    fi

    tui_checkbox "Select components to remove:"

    _any=false
    for ((i = 0; i < ${#TUI_ITEMS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && _any=true
    done
    if ! $_any; then
        info "Nothing selected."
        exit 0
    fi

    echo ""
    echo -e "  ${BOLD}The following will be removed or restored:${NC}"
    for ((i = 0; i < ${#TUI_ITEMS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && echo -e "    ${RED}▸${NC} ${TUI_ITEMS[i]}"
    done
    echo ""
    if [ -t 0 ]; then
        echo -ne "  ${YELLOW}Continue?${NC} [y/N] "
        read -r _confirm
        case "$_confirm" in
            [yY]|[yY][eE][sS]) ;;
            *) info "Cancelled."; exit 0 ;;
        esac
    fi

    _uninstall_needs_sudo=false
    for ((i = 0; i < ${#UNINSTALL_ACTIONS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && [ "${UNINSTALL_ACTIONS[i]}" = "mactex" ] && _uninstall_needs_sudo=true
    done
    if $_uninstall_needs_sudo; then sudo_init; fi

    restore_or_remove_config_file() {
        local rel="$1"
        local path="$LYX_DIR/$rel"
        local backups=()
        local latest_backup=""

        shopt -s nullglob
        backups=("$path".bak.*)
        shopt -u nullglob

        if [ "${#backups[@]}" -gt 0 ]; then
            latest_backup="${backups[$(( ${#backups[@]} - 1 ))]}"
            mkdir -p "$(dirname "$path")"
            cp "$latest_backup" "$path"
            ok "Restored $rel from $(basename "$latest_backup")"
            manifest_remove file "$path"
        elif manifest_has file "$path"; then
            [ -f "$path" ] && rm "$path" && ok "Removed managed $rel"
            manifest_remove file "$path"
        elif [ -f "$path" ]; then
            warn "Left untracked $rel in place"
        fi
    }

    for ((i = 0; i < ${#UNINSTALL_ACTIONS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] || continue
        case "${UNINSTALL_ACTIONS[i]}" in
            config)
                restore_or_remove_config_file preferences
                restore_or_remove_config_file bind/user.bind
                restore_or_remove_config_file templates/defaults.lyx
                ;;
            templates)
                for f in "${TEMPLATE_FILES[@]}"; do
                    [ "$f" = "templates/defaults.lyx" ] && continue
                    if manifest_has file "$LYX_DIR/$f"; then
                        [ -f "$LYX_DIR/$f" ] && rm "$LYX_DIR/$f" && ok "Removed $f"
                        manifest_remove file "$LYX_DIR/$f"
                    fi
                done
                ;;
            culmus)
                for font in "${_CULMUS_MANAGED[@]}"; do
                    [ -f "$font" ] && rm "$font" && ok "Removed $(basename "$font")"
                    manifest_remove font "$font"
                done
                ;;
            noto)
                for cask in "${_NOTO_INSTALLED[@]}"; do
                    if brew uninstall --cask "$cask" 2>/dev/null; then
                        ok "Removed $cask"
                        manifest_remove cask "$cask"
                    else
                        warn "Failed to remove $cask"
                    fi
                done
                ;;
            lyx)
                if brew uninstall --cask lyx 2>/dev/null; then
                    ok "Removed LyX"
                    manifest_remove cask lyx
                else
                    warn "Failed to remove LyX via Homebrew"
                fi
                ;;
            mactex)
                if brew uninstall --cask mactex 2>/dev/null; then
                    ok "Removed MacTeX"
                    manifest_remove cask mactex
                else
                    warn "Failed to remove MacTeX via Homebrew"
                fi
                ;;
        esac
    done

    if [ -f "$MANIFEST_FILE" ] && [ ! -s "$MANIFEST_FILE" ]; then
        rm -f "$MANIFEST_FILE"
    fi

    echo ""
    ok "Uninstall complete."
    [ -d "/Applications/LyX.app" ] && info "Run Tools > Reconfigure in LyX to restore defaults."
    echo ""
    exit 0
fi

# ═══════════════════════════════════════════════════════
#  INSTALL FLOW
# ═══════════════════════════════════════════════════════

echo ""
# Colored LyX logo (generated from Lyx_Logo.svg via ascii-image-converter)
LYX_LOGO_B64='ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7MjsxNzU7NDQ7MG0tG1swbRtb
Mzg7MjsxNzY7NDM7MG0tG1swbRtbMzg7MjsxNjI7NDA7MG06G1swbRtbMzg7MjsxNDg7Mzc7MG06G1sw
bRtbMzg7MjsxMzI7MzM7MG06G1swbRtbMzg7MjsxMTY7Mjk7MG06G1swbRtbMzg7Mjs5NzsyNDswbS4b
WzBtCiAgICAgICAgICAbWzM4OzI7MDszMjs2NW0uG1swbRtbMzg7MjswOzI3OzU1bSAbWzBtICAgICAgICAg
ICAgICAgICAgICAgICAgICAgIBtbMzg7Mjs4ODsyMjswbS4bWzBtG1szODsyOzIwMzs1MTswbS0bWzBt
G1szODsyOzIwNDs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0b
WzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzEzNjszNDsw
bTobWzBtICAbWzM4OzI7NDg7MTI7MG0gG1swbRtbMzg7MjsxNTI7Mzg7MG06G1swbRtbMzg7MjsxNzQ7
NDM7MG0tG1swbRtbMzg7MjsxNTg7Mzk7MG06G1swbRtbMzg7MjsxNDI7MzU7MG06G1swbRtbMzg7Mjsx
MjQ7MzE7MG06G1swbRtbMzg7MjsxMDI7MjY7MG0uG1swbRtbMzg7Mjs4NjsyMTswbS4bWzBtG1szODsy
Ozc5OzE5OzBtLhtbMG0bWzM4OzI7MzU7ODswbSAbWzBtCiAgICAgG1szODsyOzA7MTM7MjZtIBtbMG0b
WzM4OzI7MDszNjs3NG0uG1swbRtbMzg7MjswOzY2OzEzMm06G1swbRtbMzg7MjswOzkzOzE4N206G1sw
bRtbMzg7MjswOzExNTsyMzJtLRtbMG0bWzM4OzI7MDsxMjc7MjUzbT0bWzBtG1szODsyOzA7MTIwOzI0
Mm0tG1swbRtbMzg7MjswOzIxOzQzbSAbWzBtICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7Mjsx
NjM7NDI7MG06G1swbRtbMzg7MjsyMDU7NTM7MG0tG1swbRtbMzg7MjsxOTg7NTA7MG0tG1swbRtbMzg7
MjsyMDA7NTA7MG0tG1swbRtbMzg7MjsxOTk7NTA7MG0tG1swbRtbMzg7MjsxOTg7NDk7MG0tG1swbRtb
Mzg7MjsyMDI7NTE7MG0tG1swbRtbMzg7Mjs5MTsyMjswbS4bWzBtG1szODsyOzExMjsyODswbS4bWzBt
G1szODsyOzIwMjs1MTswbS0bWzBtG1szODsyOzIwNDs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0b
WzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTsw
bS0bWzBtG1szODsyOzIwNDs1MTswbS0bWzBtG1szODsyOzIwMTs1MTswbS0bWzBtG1szODsyOzEyOTsz
MjswbTobWzBtG1szODsyOzI4Ozc7MG0gG1swbQogICAgG1szODsyOzA7MzA7NjBtIBtbMG0bWzM4OzI7
MDsxMjI7MjQ2bS0bWzBtG1szODsyOzA7MTI3OzI1NG09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0b
WzM4OzI7MDsxMjc7MjU1bT0bWzBtG1szODsyOzA7MTI3OzI1NW09G1swbRtbMzg7MjswOzEyNTsyNTFt
PRtbMG0bWzM4OzI7MDsxMjg7MjU1bT0bWzBtG1szODsyOzA7MTA3OzIxNm0tG1swbSAgICAgG1szODsy
OzQ0OzMyOzBtLhtbMG0bWzM4OzI7MTk3OzE0NzswbSsbWzBtG1szODsyOzE5MDsxNDQ7MG0rG1swbRtb
Mzg7MjsxNzQ7MTMxOzBtKxtbMG0bWzM4OzI7MTU4OzExOTswbT0bWzBtG1szODsyOzE0MTsxMDY7MG09
G1swbRtbMzg7MjsxMjQ7OTM7MG0tG1swbRtbMzg7MjsxMDc7ODA7MG0tG1swbRtbMzg7Mjs4NTs2NDsw
bTobWzBtICAgICAgICAgICAgG1szODsyOzE4ODszNjswbS0bWzBtG1szODsyOzIwMTs0NTswbS0bWzBt
G1szODsyOzIwMjs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0b
WzBtG1szODsyOzIwMjs1MDswbS0bWzBtG1szODsyOzIwMjs1MTswbS0bWzBtG1szODsyOzIwMzs1MTsw
bS0bWzBtG1szODsyOzIwMjs1MDswbS0bWzBtG1szODsyOzIwMTs1MDswbS0bWzBtG1szODsyOzIwMTs1
MDswbS0bWzBtG1szODsyOzE5ODs0OTswbS0bWzBtG1szODsyOzIwNDs1MTswbS0bWzBtG1szODsyOzIw
Mjs1MTswbS0bWzBtG1szODsyOzE0MzszNjswbTobWzBtG1szODsyOzM4Ozk7MG0gG1swbQogICAgIBtb
Mzg7MjswOzYxOzEyMm0uG1swbRtbMzg7MjswOzEyNzsyNTRtPRtbMG0bWzM4OzI7MDsxMjI7MjQ2bS0b
WzBtG1szODsyOzA7MTI1OzI1Mm09G1swbRtbMzg7MjswOzEyNjsyNTRtPRtbMG0bWzM4OzI7MDsxMjc7
MjU1bT0bWzBtG1szODsyOzA7MTI1OzI1Mm09G1swbRtbMzg7MjswOzEyODsyNTVtPRtbMG0bWzM4OzI7
MDs5MTsxODRtOhtbMG0gICAgIBtbMzg7Mjs5MTs2ODswbTobWzBtG1szODsyOzI0OTsxODg7MW0jG1sw
bRtbMzg7MjsyNTU7MTk0OzJtIxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTI7
MG0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7MjU0OzE5MjswbSMbWzBtG1szODsyOzI1
MjsxOTE7MG0jG1swbRtbMzg7MjsxNjM7MTIyOzBtPRtbMG0gICAbWzM4OzI7ODQ7NjM7MG06G1swbRtb
Mzg7MjsyMTU7MTYyOzBtKhtbMG0bWzM4OzI7MjIxOzE2ODswbSobWzBtG1szODsyOzIwOTsxNTc7MG0q
G1swbRtbMzg7MjsxOTY7MTQ0OzBtKxtbMG0bWzM4OzI7MTgxOzEzNzswbSsbWzBtG1szODsyOzE2Nzsx
MjQ7MG09G1swbRtbMzg7MjsxNDY7MTExOzBtPRtbMG0bWzM4OzI7MjA1OzEyOTswbSsbWzBtG1szODsy
OzIwNjs4OTswbT0bWzBtG1szODsyOzIwMTs0NzswbS0bWzBtG1szODsyOzIwMzs1MjswbS0bWzBtG1sz
ODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMDs1MDswbS0bWzBt
G1szODsyOzIwMDs1MDswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0b
WzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzE3Mjs0Mzsw
bS0bWzBtG1szODsyOzY5OzE3OzBtLhtbMG0KICAgICAgG1szODsyOzA7NzQ7MTQ5bTobWzBtG1szODsy
OzA7MTI3OzI1NG09G1swbRtbMzg7MjswOzEyNTsyNTFtPRtbMG0bWzM4OzI7MDsxMjc7MjU1bT0bWzBt
G1szODsyOzA7MTI3OzI1NW09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4OzI7MDsxMjU7MjUx
bT0bWzBtG1szODsyOzA7MTI3OzI1NG09G1swbRtbMzg7MjswOzcyOzE0Nm06G1swbSAgICAgG1szODsy
Ozk1OzcwOzBtOhtbMG0bWzM4OzI7MjQ5OzE4NjswbSMbWzBtG1szODsyOzI0ODsxODg7MW0jG1swbRtb
Mzg7MjsyNTE7MTg4OzBtIxtbMG0bWzM4OzI7MjUxOzE4ODswbSMbWzBtG1szODsyOzI1MTsxODg7MG0j
G1swbRtbMzg7MjsyNDk7MTg4OzBtIxtbMG0bWzM4OzI7MjUzOzE5MjswbSMbWzBtG1szODsyOzE1Mzsx
MTU7MG09G1swbRtbMzg7MjsyMTsxNTswbSAbWzBtG1szODsyOzE1MDsxMTM7MG09G1swbRtbMzg7Mjsy
NTA7MTg5OzBtIxtbMG0bWzM4OzI7MjU1OzE5NDswbSMbWzBtG1szODsyOzI1NTsxOTM7MG0jG1swbRtb
Mzg7MjsyNTU7MTkzOzBtIxtbMG0bWzM4OzI7MjU1OzE5MzswbSMbWzBtG1szODsyOzI1NTsxOTA7MG0j
G1swbRtbMzg7MjsyNTU7MTk2OzBtIxtbMG0bWzM4OzI7MjUzOzE5NzswbSMbWzBtG1szODsyOzIyNjsx
Mzk7MG0rG1swbRtbMzg7MjsyMDI7NjI7MG0tG1swbRtbMzg7MjsyMDM7NTA7MG0tG1swbRtbMzg7Mjsy
MDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7
MjsyMDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtb
Mzg7MjsyMDI7NTA7MG0tG1swbRtbMzg7MjsxOTU7NDk7MG0tG1swbRtbMzg7Mjs5NTsyNDswbS4bWzBt
CiAgICAgICAbWzM4OzI7MDs4OTsxNzhtOhtbMG0bWzM4OzI7MDsxMjc7MjU1bT0bWzBtG1szODsyOzA7
MTI1OzI1MW09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4OzI7MDsxMjc7MjU1bT0bWzBtG1sz
ODsyOzA7MTI3OzI1NW09G1swbRtbMzg7MjswOzEyNTsyNTFtPRtbMG0bWzM4OzI7MDsxMjY7MjUzbT0b
WzBtG1szODsyOzA7NTI7MTA1bS4bWzBtICAgICAbWzM4OzI7MTE2OzEwNTszN20tG1swbRtbMzg7Mjsy
NTU7MTkyOzBtIxtbMG0bWzM4OzI7MjUwOzE5MDsxbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtb
Mzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBtG1szODsyOzI1MzsxOTE7MG0j
G1swbRtbMzg7MjsyNTM7MTkxOzBtIxtbMG0bWzM4OzI7MjMyOzE3NDswbSobWzBtG1szODsyOzI1NTsx
OTI7MG0jG1swbRtbMzg7MjsyNTM7MTkxOzBtIxtbMG0bWzM4OzI7MjUzOzE5MDswbSMbWzBtG1szODsy
OzI1NDsxOTE7MG0jG1swbRtbMzg7MjsyNTI7MTg5OzBtIxtbMG0bWzM4OzI7MjUyOzE4ODswbSMbWzBt
G1szODsyOzI1MjsxOTg7MG0jG1swbRtbMzg7MjsyMzk7MTc3OzBtKhtbMG0bWzM4OzI7MjA0Ozg4OzBt
PRtbMG0bWzM4OzI7MTk3OzM0OzBtLRtbMG0bWzM4OzI7MjAzOzQ4OzBtLRtbMG0bWzM4OzI7MjAzOzUy
OzBtLRtbMG0bWzM4OzI7MjAyOzUwOzBtLRtbMG0bWzM4OzI7MjAwOzUwOzBtLRtbMG0bWzM4OzI7MjAy
OzUwOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7
MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAxOzUwOzBtLRtbMG0bWzM4OzI7MTk3OzUwOzBtLRtbMG0bWzM4
OzI7NDk7MTI7MG0gG1swbQogICAgICAgIBtbMzg7MjswOzEwMjsyMDVtLRtbMG0bWzM4OzI7MDsxMjg7
MjU1bT0bWzBtG1szODsyOzA7MTI1OzI1Mm09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4OzI7
MDsxMjc7MjU1bT0bWzBtG1szODsyOzA7MTI2OzI1NG09G1swbRtbMzg7MjswOzEyNjsyNTJtPRtbMG0b
WzM4OzI7MDsxMjU7MjUybT0bWzBtG1szODsyOzA7Mzc7NzRtLhtbMG0bWzM4OzI7MDsyMjs0NG0gG1sw
bRtbMzg7MjswOzU0OzEwOG0uG1swbRtbMzg7MjswOzg1OzE2OW06G1swbRtbMzg7Mjs0OzExMzsyMjJt
LRtbMG0bWzM4OzI7MDsxMTc7MjQ3bS0bWzBtG1szODsyOzEzNDsxNTM7MTA1bSsbWzBtG1szODsyOzI1
NDsxOTU7MG0jG1swbRtbMzg7MjsyNTE7MTkxOzNtIxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBtG1sz
ODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7MjUzOzE5MDswbSMb
WzBtG1szODsyOzI1NTsxOTQ7MG0jG1swbRtbMzg7MjsyNTI7MTg5OzBtIxtbMG0bWzM4OzI7MjU1OzE5
MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTM7MTg5OzBtIxtbMG0bWzM4OzI7
MjU1OzE5MzswbSMbWzBtG1szODsyOzI1NTsyMDI7MG0jG1swbRtbMzg7MjsyMjk7MTQ5OzBtKhtbMG0b
WzM4OzI7MjAxOzYxOzBtLRtbMG0bWzM4OzI7MjAxOzQyOzBtLRtbMG0bWzM4OzI7MjA0OzUzOzBtLRtb
MG0bWzM4OzI7MjAzOzUyOzBtLRtbMG0bWzM4OzI7MjAxOzUwOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBt
LRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAzOzUx
OzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAx
OzUwOzBtLRtbMG0bWzM4OzI7MjA0OzUxOzBtLRtbMG0bWzM4OzI7MTg4OzQ3OzBtLRtbMG0KICAgICAg
ICAbWzM4OzI7MDsxNDsyOG0gG1swbRtbMzg7MjswOzExMjsyMjZtLRtbMG0bWzM4OzI7MDsxMjg7MjU1
bT0bWzBtG1szODsyOzA7MTI2OzI1M209G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4OzI7MDsx
Mjc7MjU1bT0bWzBtG1szODsyOzA7MTI2OzI1NG09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4
OzI7MDsxMjY7MjUzbT0bWzBtG1szODsyOzA7MTI2OzI1M209G1swbRtbMzg7MjswOzEyNzsyNTRtPRtb
MG0bWzM4OzI7MDsxMjc7MjU1bT0bWzBtG1szODsyOzE7MTI3OzI1NG09G1swbRtbMzg7MjszOzEyNzsy
NTFtPRtbMG0bWzM4OzI7MDsxMjA7MjUxbS0bWzBtG1szODsyOzE1MjsxNTg7ODdtKxtbMG0bWzM4OzI7
MjU1OzE5NjswbSMbWzBtG1szODsyOzI1MzsxOTI7Mm0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0b
WzM4OzI7MjU1OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTQ7MTkxOzBt
IxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTU7
MTkxOzBtIxtbMG0bWzM4OzI7MjU1OzE5NzswbSMbWzBtG1szODsyOzI0OTsxOTE7MG0jG1swbRtbMzg7
MjsyMTI7MTA5OzBtKxtbMG0bWzM4OzI7MTk0OzQzOzBtLRtbMG0bWzM4OzI7MTk5OzQ3OzBtLRtbMG0b
WzM4OzI7MjAxOzUyOzBtLRtbMG0bWzM4OzI7MjAxOzUwOzBtLRtbMG0bWzM4OzI7MTk5OzUwOzBtLRtb
MG0bWzM4OzI7MjA0OzUxOzBtLRtbMG0bWzM4OzI7MjAyOzUxOzBtLRtbMG0bWzM4OzI7MTE1OzI5OzBt
OhtbMG0bWzM4OzI7MTg4OzQ3OzBtLRtbMG0bWzM4OzI7MjAzOzUwOzBtLRtbMG0bWzM4OzI7MjAyOzUw
OzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAzOzUxOzBtLRtbMG0bWzM4OzI7MjAw
OzUwOzBtLRtbMG0bWzM4OzI7MjA0OzUxOzBtLRtbMG0bWzM4OzI7MTQ4OzM3OzBtOhtbMG0KICAgICAg
ICAgG1szODsyOzA7MjU7NTBtIBtbMG0bWzM4OzI7MDsxMjE7MjQybS0bWzBtG1szODsyOzA7MTI2OzI1
M209G1swbRtbMzg7MjswOzEyNjsyNTRtPRtbMG0bWzM4OzI7MDsxMjc7MjU1bT0bWzBtG1szODsyOzA7
MTI3OzI1NW09G1swbRtbMzg7MjswOzEyNjsyNTRtPRtbMG0bWzM4OzI7MDsxMjY7MjUzbT0bWzBtG1sz
ODsyOzA7MTI1OzI1MW09G1swbRtbMzg7MjswOzEyMzsyNDdtLRtbMG0bWzM4OzI7MDsxMjU7MjUybT0b
WzBtG1szODsyOzA7MTI3OzI1NW09G1swbRtbMzg7MjsxOzEyNzsyNTRtPRtbMG0bWzM4OzI7MzsxMjg7
MjUzbT0bWzBtG1szODsyOzA7MTIxOzI1MW0tG1swbRtbMzg7MjsxNjc7MTUyOzU0bSsbWzBtG1szODsy
OzI1NDsxOTQ7MW0jG1swbRtbMzg7MjsyNTM7MTkxOzJtIxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBt
G1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7MjU1OzE5Mjsw
bSMbWzBtG1szODsyOzI1NTsxOTE7MG0jG1swbRtbMzg7MjsyNTU7MTk1OzBtIxtbMG0bWzM4OzI7MjMx
OzE2NDswbSobWzBtG1szODsyOzIwMzs3NDswbT0bWzBtG1szODsyOzE5OTs0MTswbS0bWzBtG1szODsy
OzIwNDs1MjswbS0bWzBtG1szODsyOzIwMzs1MjswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1sz
ODsyOzIwNDs1MTswbS0bWzBtG1szODsyOzIwMzs1MTswbS0bWzBtG1szODsyOzE3Mjs0MzswbS0bWzBt
G1szODsyOzUyOzEzOzBtIBtbMG0gG1szODsyOzExMjsyODswbS4bWzBtG1szODsyOzIwMzs1MTswbS0b
WzBtG1szODsyOzE5Njs0OTswbS0bWzBtG1szODsyOzE5OTs1MDswbS0bWzBtG1szODsyOzE5OTs1MDsw
bS0bWzBtG1szODsyOzE5OTs1MDswbS0bWzBtG1szODsyOzE5Njs0OTswbS0bWzBtG1szODsyOzIwMzs1
MTswbS0bWzBtG1szODsyOzk0OzIzOzBtLhtbMG0KICAgICAgICAgIBtbMzg7MjswOzM4Ozc2bS4bWzBt
G1szODsyOzA7MTI2OzI1Mm09G1swbRtbMzg7MjswOzEyNTsyNTFtPRtbMG0bWzM4OzI7MDsxMjU7MjUx
bT0bWzBtG1szODsyOzA7MTI1OzI1MW09G1swbRtbMzg7MjswOzEyNzsyNTVtPRtbMG0bWzM4OzI7MDsx
Mjc7MjU1bT0bWzBtG1szODsyOzA7MTI3OzI1NW09G1swbRtbMzg7MjswOzEyNzsyNTRtPRtbMG0bWzM4
OzI7MDsxMjY7MjUzbT0bWzBtG1szODsyOzA7MTA4OzIxN20tG1swbRtbMzg7MjswOzgxOzE2M206G1sw
bRtbMzg7MjszOzUzOzEwMW0uG1swbRtbMzg7MjswOzIwOzQ2bSAbWzBtG1szODsyOzg4OzczOzE1bTob
WzBtG1szODsyOzI1MjsxOTA7MG0jG1swbRtbMzg7MjsyNTE7MTg4OzBtIxtbMG0bWzM4OzI7MjU1OzE5
MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7
MjU1OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTM7MG0jG1swbRtbMzg7MjsyNDE7MTgyOzBtIxtbMG0b
WzM4OzI7Mzk7MjE7MG0gG1swbRtbMzg7MjszMjsxOzBtIBtbMG0bWzM4OzI7NjM7MTg7MG0uG1swbRtb
Mzg7Mjs4OTsyMjswbS4bWzBtG1szODsyOzExODsyOTswbTobWzBtG1szODsyOzE0NDszNjswbTobWzBt
G1szODsyOzE3MDs0MjswbTobWzBtG1szODsyOzEyNzszMTswbTobWzBtICAgIBtbMzg7MjsxOTU7NDk7
MG0tG1swbRtbMzg7MjsyMDQ7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7
NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7MjsyMDM7NTE7MG0tG1swbRtbMzg7Mjsy
MDQ7NTE7MG0tG1swbRtbMzg7MjsyMDE7NTE7MG0tG1swbRtbMzg7Mjs1NzsxNDswbS4bWzBtCiAgICAg
ICAgICAgG1szODsyOzA7NTI7MTA1bS4bWzBtG1szODsyOzA7MTI2OzI1M209G1swbRtbMzg7MjswOzEy
NzsyNTVtPRtbMG0bWzM4OzI7MDsxMjc7MjU0bT0bWzBtG1szODsyOzA7MTI2OzI1M209G1swbRtbMzg7
MjswOzEwNzsyMTRtLRtbMG0bWzM4OzI7MDs4MDsxNTltOhtbMG0bWzM4OzI7MDs0OTs5OW0uG1swbRtb
Mzg7MjswOzIxOzQzbSAbWzBtICAgIBtbMzg7MjsxNzA7MTI2OzBtPRtbMG0bWzM4OzI7MjU1OzE5Mzsw
bSMbWzBtG1szODsyOzI1MjsxODk7MG0jG1swbRtbMzg7MjsyNTU7MTkyOzBtIxtbMG0bWzM4OzI7MjU1
OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7MjsyNTI7MTg5OzBtIxtbMG0bWzM4
OzI7MjU0OzE5MjswbSMbWzBtG1szODsyOzE3MzsxMzA7MG0rG1swbSAgICAgICAgICAgIBtbMzg7Mjs2
MDsxNTswbS4bWzBtG1szODsyOzEwMTsyNTswbS4bWzBtG1szODsyOzEwNzsyNzswbS4bWzBtG1szODsy
OzExNjsyOTswbTobWzBtG1szODsyOzEyNDszMTswbTobWzBtG1szODsyOzEzMTszMzswbTobWzBtG1sz
ODsyOzEzNzszNDswbTobWzBtG1szODsyOzE0NzszNjswbTobWzBtG1szODsyOzEyNzszMjswbTobWzBt
CiAgICAgICAgICAgIBtbMzg7MjswOzYzOzEyNm06G1swbRtbMzg7MjswOzgxOzE2Mm06G1swbRtbMzg7
MjswOzQ2OzkzbS4bWzBtG1szODsyOzA7MjA7NDFtIBtbMG0gICAgICAgIBtbMzg7MjsyMjU7MTcwOzBt
KhtbMG0bWzM4OzI7MjUzOzE5MjswbSMbWzBtG1szODsyOzI1MzsxOTA7MG0jG1swbRtbMzg7MjsyNTQ7
MTkxOzBtIxtbMG0bWzM4OzI7MjU1OzE5MjswbSMbWzBtG1szODsyOzI1NTsxOTI7MG0jG1swbRtbMzg7
MjsyNTE7MTg5OzBtIxtbMG0bWzM4OzI7MjUyOzE4OTswbSMbWzBtG1szODsyOzg0OzYzOzBtOhtbMG0K
ICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzI7NzI7NTQ7MG06G1swbRtbMzg7MjsyNTE7MTg5OzBt
IxtbMG0bWzM4OzI7MjU1OzE5NDswbSMbWzBtG1szODsyOzI1NTsxOTM7MG0jG1swbRtbMzg7MjsyNTU7
MTkzOzBtIxtbMG0bWzM4OzI7MjU1OzE5MzswbSMbWzBtG1szODsyOzI1MjsxOTA7MG0jG1swbRtbMzg7
MjsyNTI7MTkxOzBtIxtbMG0bWzM4OzI7MjI5OzE3MjswbSobWzBtCiAgICAgICAgICAgICAgICAgICAg
ICAgG1szODsyOzk0OzcxOzBtOhtbMG0bWzM4OzI7MjAwOzE1MDswbSsbWzBtG1szODsyOzIxNTsxNjE7
MG0qG1swbRtbMzg7MjsyMzI7MTc0OzBtKhtbMG0bWzM4OzI7MjQ0OzE4MzswbSMbWzBtG1szODsyOzI1
MTsxODk7MG0jG1swbRtbMzg7MjsyNTI7MTkwOzBtIxtbMG0bWzM4OzI7MjUzOzE5MTswbSMbWzBtG1sz
ODsyOzE1ODsxMTg7MG09G1swbQogICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzI7MjY7MTk7
MG0gG1swbRtbMzg7Mjs0MDszMDswbS4bWzBtG1szODsyOzU1OzQyOzBtLhtbMG0bWzM4OzI7NzY7NTc7
MG06G1swbRtbMzg7MjszMjsyNDswbSAbWzBt'
echo "$LYX_LOGO_B64" | base64 -d
echo ""
echo -e "  ${BOLD}Hebrew Installer for macOS${NC}"
echo -e "  ${DIM}Based on the Madlyx guide by Michael Kali${NC}"
echo ""

header "Prerequisites"

if ! command -v brew &>/dev/null; then
    warn "Homebrew is not installed"
    if [ -t 0 ]; then
        echo -ne "  Install Homebrew now? [Y/n] "
        read -r _brew_confirm
        case "$_brew_confirm" in
            [nN]|[nN][oO])
                fail "Homebrew is required. Install it from https://brew.sh"
                exit 1
                ;;
        esac
        info "Installing Homebrew (this will ask for your password)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for the rest of this script (Apple Silicon vs Intel)
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        if ! command -v brew &>/dev/null; then
            fail "Homebrew installation failed"
            exit 1
        fi
        ok "Homebrew installed"
    else
        fail "Homebrew is required. Install it from https://brew.sh"
        exit 1
    fi
else
    ok "Homebrew found"
fi

# ── Detect installed components ───────────────────────

detect_lyx_dir

_HAS_MACTEX=false; [ -f /Library/TeX/texbin/xelatex ] && _HAS_MACTEX=true
_HAS_LYX=false;    [ -d "/Applications/LyX.app" ]     && _HAS_LYX=true
_HAS_CULMUS=false; if fc-list 2>/dev/null | grep -qi "David CLM"; then _HAS_CULMUS=true; fi
CULMUS_VERSION="0.140"

NOTO_FONTS=(font-noto-sans-hebrew font-noto-serif-hebrew font-noto-rashi-hebrew)
NOTO_MISSING=()
for cask in "${NOTO_FONTS[@]}"; do
    brew list --cask "$cask" &>/dev/null || NOTO_MISSING+=("$cask")
done
_HAS_NOTO=false; [ ${#NOTO_MISSING[@]} -eq 0 ] && _HAS_NOTO=true

_HAS_CONFIG=false
[ -f "$LYX_DIR/preferences" ] && [ -f "$LYX_DIR/bind/user.bind" ] && _HAS_CONFIG=true

_HAS_TEMPLATES=false
for f in "${TEMPLATE_FILES[@]}"; do
    [ -f "$LYX_DIR/$f" ] && _HAS_TEMPLATES=true && break
done

# ── Build install menu ────────────────────────────────

TUI_ITEMS=()
TUI_CHECKED=()
INSTALL_ACTIONS=()

_label="MacTeX — full TeX Live distribution (~6 GB)";    $_HAS_MACTEX && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("mactex")

_label="LyX — WYSIWYM document editor";                  $_HAS_LYX && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("lyx")

_label="Culmus Hebrew fonts (David CLM, Miriam, etc.)";  $_HAS_CULMUS && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("culmus")

_label="Noto Hebrew fonts (Sans, Serif, Rashi)";         $_HAS_NOTO && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("noto")

_label="LyX preferences & keybindings";                  $_HAS_CONFIG && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("config")

_label="Document templates (articles, solutions, CV)";   $_HAS_TEMPLATES && _label+=" (installed)"
TUI_ITEMS+=("$_label"); TUI_CHECKED+=(1); INSTALL_ACTIONS+=("templates")

if $FORCE; then
    info "Force mode — installing all components"
else
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        fail "Interactive install requires a terminal. Re-run with --force for non-interactive install."
        exit 1
    fi
    tui_checkbox "Select components to install:"
fi

# Check if anything selected
_any_selected=false
for ((i = 0; i < ${#TUI_ITEMS[@]}; i++)); do
    [ "${TUI_CHECKED[i]}" = "1" ] && _any_selected=true
done
if ! $_any_selected; then info "Nothing selected."; exit 0; fi

# ── Helpers ───────────────────────────────────────────

is_selected() {
    local target="$1"
    for ((i = 0; i < ${#INSTALL_ACTIONS[@]}; i++)); do
        [ "${INSTALL_ACTIONS[i]}" = "$target" ] && [ "${TUI_CHECKED[i]}" = "1" ] && return 0
    done
    return 1
}

# ── Pre-flight summary ───────────────────────────────

# Build description for each selected action
_describe_action() {
    case "$1" in
        mactex) echo "MacTeX — full TeX Live distribution ${DIM}(~6 GB download)${NC}" ;;
        lyx)    echo "LyX — WYSIWYM document editor" ;;
        culmus) echo "Culmus Hebrew fonts ${DIM}(David CLM, Miriam, Frank Ruehl, etc.)${NC}" ;;
        noto)   echo "Noto Hebrew fonts ${DIM}(Sans, Serif, Rashi)${NC}" ;;
        config)    echo "LyX preferences & keybindings ${DIM}(F12 Hebrew toggle, fonts, etc.)${NC}" ;;
        templates) echo "Document templates ${DIM}(articles, solutions, CV)${NC}" ;;
    esac
}

echo ""
echo -e "  ${BOLD}About to install:${NC}"
for ((i = 0; i < ${#INSTALL_ACTIONS[@]}; i++)); do
    [ "${TUI_CHECKED[i]}" = "1" ] || continue
    echo -e "    ${CYAN}▸${NC} $(_describe_action "${INSTALL_ACTIONS[i]}")"
done

# ── Disk space check ─────────────────────────────────

_needed_gb=1  # base overhead for fonts + config
is_selected "mactex" && _needed_gb=$((_needed_gb + 8))
_avail_gb=$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "$_avail_gb" ] && [ "$_avail_gb" -lt "$_needed_gb" ]; then
    echo ""
    warn "Low disk space: ${_avail_gb} GB available, ~${_needed_gb} GB needed"
    if [ -t 0 ] && ! $FORCE; then
        echo -ne "  ${YELLOW}Continue anyway?${NC} [y/N] "
        read -r _ds_confirm
        case "$_ds_confirm" in
            [yY]|[yY][eE][sS]) ;;
            *) info "Cancelled."; exit 0 ;;
        esac
    fi
else
    echo -e "  ${DIM}  Disk space: ${_avail_gb:-?} GB available${NC}"
fi

# ── Confirm ──────────────────────────────────────────

if ! $FORCE && [ -t 0 ]; then
    echo ""
    echo -ne "  Proceed? [Y/n] "
    read -r _confirm
    case "$_confirm" in
        [nN]|[nN][oO]) info "Cancelled."; exit 0 ;;
    esac
fi

# Prompt for sudo once if MacTeX needs to be installed
if is_selected "mactex" && ! $_HAS_MACTEX; then
    sudo_init
fi

_total=0
for ((i = 0; i < ${#INSTALL_ACTIONS[@]}; i++)); do
    [ "${TUI_CHECKED[i]}" = "1" ] && _total=$((_total + 1))
done
_cur=0

header "Installation"

# ── Install: MacTeX ──────────────────────────────────

if is_selected "mactex"; then
    step "MacTeX"
    if $_HAS_MACTEX; then
        ok "MacTeX already installed — skipped"
    else
        info "Downloading ~6 GB — this will take a while"
        run_with_spinner "Installing MacTeX" brew install --cask mactex
        eval "$(/usr/libexec/path_helper)" 2>/dev/null
        if [ -f /Library/TeX/texbin/xelatex ]; then
            manifest_add cask mactex
            ok "MacTeX installed ${DIM}($(fmt_elapsed))${NC}"
        else
            warn "MacTeX installed but xelatex not on PATH. Restart your terminal."
        fi
    fi
fi

# ── Install: LyX ────────────────────────────────────

if is_selected "lyx"; then
    step "LyX"
    if $_HAS_LYX; then
        ok "LyX already installed — skipped"
    else
        # NOTE: The LyX Homebrew cask is deprecated (Gatekeeper issue, disabled Sept 2026).
        # If this fails in the future, download directly from https://www.lyx.org/Download
        run_with_spinner "Installing LyX" brew install --cask lyx
        if [ -d "/Applications/LyX.app" ]; then
            manifest_add cask lyx
            ok "LyX installed ${DIM}($(fmt_elapsed))${NC}"
        else
            fail "LyX installation failed. Download manually from https://www.lyx.org/Download"
            exit 1
        fi
    fi
fi

# ── Install: Culmus Hebrew fonts ─────────────────────

if is_selected "culmus"; then
    step "Culmus Hebrew fonts"
    if $_HAS_CULMUS; then
        ok "Culmus Hebrew fonts already installed — skipped"
    else
        CULMUS_TMP=$(mktemp -d)
        run_with_spinner "Downloading Culmus $CULMUS_VERSION" \
            curl -sL -o "$CULMUS_TMP/culmus.tar.gz" \
            "https://sourceforge.net/projects/culmus/files/culmus/$CULMUS_VERSION/culmus-$CULMUS_VERSION.tar.gz/download"

        CULMUS_SHA256="6daed104481007752a76905000e71c0093c591c8ef3017d1b18222c277fc52e3"
        if ! echo "$CULMUS_SHA256  $CULMUS_TMP/culmus.tar.gz" | shasum -a 256 -c - >/dev/null 2>&1; then
            fail "Culmus checksum mismatch — refusing to install unverified archive"
            exit 1
        fi

        # Verify the archive is a valid tarball containing Culmus fonts
        CLM_COUNT=$(tar tzf "$CULMUS_TMP/culmus.tar.gz" 2>/dev/null | grep -c "CLM" || true)
        if [ "$CLM_COUNT" -lt 5 ]; then
            fail "Downloaded file is not a valid Culmus archive ($CLM_COUNT CLM files found, expected ≥5)"
            fail "Try downloading manually from https://culmus.sourceforge.io/"
            exit 1
        fi

        tar xzf "$CULMUS_TMP/culmus.tar.gz" -C "$CULMUS_TMP"
        mkdir -p "$HOME/Library/Fonts"
        FONT_COUNT=0
        for font in "$CULMUS_TMP"/culmus-"$CULMUS_VERSION"/*CLM*.otf "$CULMUS_TMP"/culmus-"$CULMUS_VERSION"/*CLM*.ttf; do
            [ -f "$font" ] || continue
            cp "$font" "$HOME/Library/Fonts/"
            manifest_add font "$HOME/Library/Fonts/$(basename "$font")"
            FONT_COUNT=$((FONT_COUNT + 1))
        done
        rm -rf "$CULMUS_TMP"

        ok "Installed $FONT_COUNT Culmus font files ${DIM}($(fmt_elapsed))${NC}"
    fi
fi

# ── Install: Noto Hebrew fonts ───────────────────────

if is_selected "noto"; then
    step "Noto Hebrew fonts"
    if $_HAS_NOTO; then
        ok "Noto Hebrew fonts already installed — skipped"
    else
        if run_with_spinner "Installing Noto Hebrew fonts" brew install --cask "${NOTO_MISSING[@]}"; then
            for cask in "${NOTO_MISSING[@]}"; do manifest_add cask "$cask"; done
            ok "Noto Hebrew fonts installed ${DIM}($(fmt_elapsed))${NC}"
        else
            fail "Noto Hebrew font installation failed"
            exit 1
        fi
    fi
fi

# ── Install: LyX configuration ──────────────────────

if is_selected "config"; then
    step "LyX preferences & keybindings"
    mkdir -p "$LYX_DIR/bind" "$LYX_DIR/templates"

    CONFIG_TARGETS=(
        "$LYX_DIR/preferences"
        "$LYX_DIR/bind/user.bind"
        "$LYX_DIR/templates/defaults.lyx"
    )

    if confirm_overwrite "LyX preferences & keybindings" "${CONFIG_TARGETS[@]}"; then
        _prefs_tmp=$(mktemp)
        # Preferences — only non-default settings (matches LyX 2.4/2.5 on macOS)
        cat > "$_prefs_tmp" << 'EOF'
Format 38

\bind_file "user"
\gui_language english

#
# MISC SECTION ######################################
#

\path_prefix "/Library/TeX/texbin:/usr/texbin:/opt/homebrew/bin:/opt/local/bin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin"
\kbmap true
\kbmap_primary "null"
\kbmap_secondary "hebrew"
\preview no_math
\preview_scale_factor 0.8

#
# SCREEN & FONTS SECTION ############################
#

\scroll_below_document true
\screen_font_roman "David CLM"
\screen_font_sans "Simple CLM"
\screen_font_typewriter "Miriam Mono CLM"
\screen_font_sizes 5 7 8 9 10 12 14.4 17.26 20.74 24.88
\open_buffers_in_tabs true

#
# LANGUAGE SUPPORT SECTION ##########################
#

\spellcheck_continuously false
\visual_cursor true
\language_custom_package ""

#
# 2nd MISC SUPPORT SECTION ##########################
#

\scroll_wheel_zoom ctrl
\default_otf_view_format pdf4

#
# COMPLETION SECTION ##########################
#

\completion_inline_math true
\completion_inline_text false
\completion_popup_math true
\completion_popup_text false
\completion_inline_delay 0.2
\completion_popup_delay 0.3
\completion_minlength 3
EOF

        if install_file_from_temp "$_prefs_tmp" "$LYX_DIR/preferences"; then
            _install_rc=0
        else
            _install_rc=$?
        fi
        report_install_status "$_install_rc" "Preferences written" "Preferences already up to date"

        _bind_tmp=$(mktemp)
        # Keybindings — F12 for Hebrew (Madlyx guide, page 16)
        cat > "$_bind_tmp" << 'EOF'
## user.bind — Hebrew keybindings (Madlyx guide)
## Keep OS keyboard on English. Use F12 to toggle Hebrew inside LyX.

Format 5

\bind_file "mac"

\bind "F12"    "language hebrew"
\bind "S-F12"  "language english"

# Rebind Cmd+E and Cmd+I to emphasis (italic) — macOS Option key
# produces Greek/accents, so the default Cmd+Alt+E never reaches LyX
\bind "C-e" "font-emph"
\bind "C-M-e" "search-string-set"
\bind "C-i" "font-emph"
\bind "C-M-i" "inset-toggle"
EOF

        if install_file_from_temp "$_bind_tmp" "$LYX_DIR/bind/user.bind"; then
            _install_rc=0
        else
            _install_rc=$?
        fi
        report_install_status "$_install_rc" \
            "Keybindings written (F12 = Hebrew, Shift+F12 = English)" \
            "Keybindings already up to date"

        if install_template_file "templates/defaults.lyx"; then
            _install_rc=0
        else
            _install_rc=$?
        fi
        report_install_status "$_install_rc" \
            "defaults.lyx created (Cmd+N defaults to Hebrew RTL)" \
            "defaults.lyx already up to date"
    else
        ok "Skipped LyX preferences & keybindings"
    fi
fi

# ── Install: Document templates ─────────────────────

if is_selected "templates"; then
    step "Document templates"
    mkdir -p "$LYX_DIR/templates"

    TEMPLATE_TARGETS=()
    for f in "${TEMPLATE_FILES[@]}"; do
        [ "$f" = "templates/defaults.lyx" ] && continue
        TEMPLATE_TARGETS+=("$LYX_DIR/$f")
    done

    if ! confirm_overwrite "Document templates" "${TEMPLATE_TARGETS[@]}"; then
        ok "Skipped document templates"
    else
        info "Writing document templates..."

        for f in "${TEMPLATE_FILES[@]}"; do
            [ "$f" = "templates/defaults.lyx" ] && continue
            if install_template_file "$f"; then
                _install_rc=0
            else
                _install_rc=$?
            fi
            report_install_status "$_install_rc" \
                "$(basename "$f") template installed" \
                "$(basename "$f") template already up to date"
        done
    fi
fi

# ── Run LyX Reconfigure ─────────────────────────────

if is_selected "config" || is_selected "templates"; then
    export PATH="/Library/TeX/texbin:$PATH"
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found — run Tools > Reconfigure manually in LyX"
    elif [ -f "/Applications/LyX.app/Contents/Resources/configure.py" ]; then
        if (cd "$LYX_DIR" && run_with_spinner "Running LyX reconfigure" \
            python3 /Applications/LyX.app/Contents/Resources/configure.py); then
            ok "LyX reconfigured"
        else
            warn "LyX reconfigure failed — run Tools > Reconfigure manually in LyX"
        fi
    else
        warn "LyX configure script not found — run Tools > Reconfigure manually in LyX"
    fi
fi

# ── Verification ──────────────────────────────────────

header "Verification"

eval "$(/usr/libexec/path_helper)" 2>/dev/null
export PATH="/Library/TeX/texbin:$PATH"

_checks=0; _passed=0; _warnings=()

_check() {
    local desc="$1"; shift
    _checks=$((_checks + 1))
    if "$@" &>/dev/null; then
        _passed=$((_passed + 1))
    else
        _warnings+=("$desc")
    fi
}

# Only check components relevant to what was installed
if is_selected "mactex" || [ -f /Library/TeX/texbin/xelatex ]; then
    _check "XeLaTeX not on PATH (restart terminal after MacTeX install)" command -v xelatex
    _check "polyglossia: NOT FOUND"  kpsewhich polyglossia.sty
    _check "bidi (RTL): NOT FOUND"   kpsewhich bidi.sty
fi
if is_selected "lyx" || [ -d "/Applications/LyX.app" ]; then
    _check "LyX: not found in /Applications" test -d "/Applications/LyX.app"
fi
if is_selected "culmus"; then
    _check "David CLM font: not found by fc-list" bash -c 'fc-list 2>/dev/null | grep -qi "David CLM"'
fi
if is_selected "noto"; then
    _check "Noto Hebrew fonts: not found by fc-list" bash -c 'fc-list 2>/dev/null | grep -qi "Noto.*Hebrew"'
fi

if is_selected "config"; then
    detect_lyx_dir
    for f in preferences bind/user.bind templates/defaults.lyx; do
        _check "Missing config: $f" test -f "$LYX_DIR/$f"
    done
fi
if is_selected "templates"; then
    detect_lyx_dir
    for f in "${TEMPLATE_FILES[@]}"; do
        [ "$f" = "templates/defaults.lyx" ] && continue
        _check "Missing template: $f" test -f "$LYX_DIR/$f"
    done
fi

# Hebrew XeTeX compilation test
if command -v xelatex &>/dev/null && fc-list 2>/dev/null | grep -qi "David CLM"; then
    _checks=$((_checks + 1))
    TEST_DIR=$(mktemp -d)
    cat > "$TEST_DIR/test.tex" << 'TEX'
\documentclass{article}
\usepackage{polyglossia}
\setdefaultlanguage{hebrew}
\setotherlanguage{english}
% English: Latin Modern (default). Hebrew: David CLM
\newfontfamily\hebrewfont[Script=Hebrew,
  ItalicFont={David CLM Medium Italic},
  BoldFont={David CLM Bold},
  BoldItalicFont={David CLM Bold Italic}]{David CLM}
\begin{document}
\begin{hebrew}
שלום עולם! \textit{נטוי} \textbf{עבה}
\end{hebrew}
\begin{english}
Hello World! \textit{Italic} \textbf{Bold}
\end{english}
\end{document}
TEX
    if xelatex -interaction=nonstopmode -output-directory="$TEST_DIR" "$TEST_DIR/test.tex" &>/dev/null; then
        _passed=$((_passed + 1))
    else
        _warnings+=("Hebrew XeTeX compilation: FAILED")
    fi
    rm -rf "$TEST_DIR"
fi

if [ "${#_warnings[@]}" -eq 0 ]; then
    ok "All $_checks checks passed"
else
    ok "$_passed of $_checks checks passed"
    for w in "${_warnings[@]}"; do warn "$w"; done
fi

# ── Total elapsed time ───────────────────────────────

_total_el=$(( SECONDS - INSTALL_START ))
if [ "$_total_el" -ge 60 ]; then
    _total_fmt=$(printf '%dm%02ds' $((_total_el / 60)) $((_total_el % 60)))
else
    _total_fmt=$(printf '%ds' "$_total_el")
fi

echo ""
echo ""
echo -e "  ${GREEN}${BOLD}Setup complete!${NC}  ${DIM}(${_total_fmt})${NC}"
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${BOLD}Getting started:${NC}"
echo ""
if [ -d "/Applications/LyX.app" ]; then
    echo -e "    ${CYAN}1.${NC}  Open LyX and run ${BOLD}Tools > Reconfigure${NC}, then restart LyX"
else
    echo -e "    ${CYAN}1.${NC}  Install LyX, then run ${BOLD}Tools > Reconfigure${NC}"
fi
echo -e "    ${CYAN}2.${NC}  ${BOLD}Cmd+N${NC} to create a new Hebrew RTL document"
echo -e "    ${CYAN}3.${NC}  ${BOLD}F12${NC} / ${BOLD}Shift+F12${NC} to switch between Hebrew and English"
if is_selected "templates"; then
    echo -e "    ${CYAN}4.${NC}  ${BOLD}File > New from Template${NC} for articles, solutions, and CV"
fi
echo ""
echo -e "  ${DIM}Tip: Keep your macOS keyboard on English — language${NC}"
echo -e "  ${DIM}switching is handled inside LyX with F12.${NC}"
echo ""
echo -e "  ${DIM}Log: $LOG_FILE${NC}"
echo -e "  ${DIM}Report issues: https://github.com/tom-bleher/lyx-he${NC}"
echo ""
echo -e "  ${BOLD}Happy LyXing!${NC}"
echo ""

}
