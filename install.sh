#!/bin/bash
#
# install.sh — Install LyX on macOS (arm/Intel) with Hebrew + XeLaTeX support
# Based on the Madlyx guide by Michael Kali (Oct 2025)
#
# Installs: MacTeX, LyX, Culmus + Noto Hebrew fonts
# Configures: Hebrew RTL, David CLM fonts, F12 language toggle, XeTeX output
#
# Prerequisites: macOS (Homebrew auto-installed if needed)
# Usage: ./install.sh [--help | --uninstall | --force | --dry-run]
#

set -euo pipefail

# ── Colors & output helpers ──────────────────────────
BOLD='\033[1m'; DIM='\033[90m'; NC='\033[0m'
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'

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

    wait "$_bg_cmd_pid"
    local rc=$?
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
    echo ""
    echo -e "  ${BOLD}lyx-he${NC} — Hebrew LyX installer for macOS"
    echo ""
    echo -e "  ${BOLD}Usage:${NC}  ./install.sh [OPTIONS]"
    echo ""
    echo -e "  ${BOLD}Options:${NC}"
    echo -e "    ${CYAN}(none)${NC}           Interactive component picker ${DIM}(default)${NC}"
    echo -e "    ${CYAN}--force, -f${NC}      Install all components without prompting"
    echo -e "    ${CYAN}--dry-run${NC}        Show what would be installed without doing anything"
    echo -e "    ${CYAN}--uninstall${NC}      Interactively select components to remove"
    echo -e "    ${CYAN}--help, -h${NC}       Show this help message"
    echo ""
    echo -e "  ${DIM}The script is idempotent — already-installed components are skipped.${NC}"
    echo ""
}

# ── Detect LyX config directory ──────────────────────
detect_lyx_dir() {
    local latest=""
    for d in "$HOME/Library/Application Support"/LyX-*; do
        [ -d "$d" ] && latest="$d"
    done
    if [ -n "$latest" ]; then
        LYX_DIR="$latest"
    else
        LYX_DIR="$HOME/Library/Application Support/LyX-2.5"
    fi
}

# ── Flags ────────────────────────────────────────────
FORCE=false
UNINSTALL=false
DRY_RUN=false
case "${1:-}" in
    --help|-h)      usage; exit 0 ;;
    --force|-f)     FORCE=true ;;
    --dry-run)      DRY_RUN=true ;;
    --uninstall)    UNINSTALL=true ;;
    "") ;;
    *) fail "Unknown flag: $1"; echo ""; usage; exit 1 ;;
esac

if [ $# -gt 1 ]; then
    fail "Only one option allowed at a time"; echo ""; usage; exit 1
fi

INSTALL_START=$SECONDS

# ── Uninstall flow ───────────────────────────────────
if $UNINSTALL; then
    detect_lyx_dir
    header "Uninstall"

    TUI_ITEMS=()
    TUI_CHECKED=()
    UNINSTALL_ACTIONS=()

    # Config files
    _has_config=false
    for f in preferences bind/user.bind; do
        [ -f "$LYX_DIR/$f" ] && _has_config=true
    done
    if $_has_config; then
        TUI_ITEMS+=("LyX preferences & keybindings")
        TUI_CHECKED+=(1)
        UNINSTALL_ACTIONS+=("config")
    fi

    # Templates
    _has_templates=false
    for f in templates/defaults.lyx templates/Hebrew_Article.lyx templates/English_Article.lyx; do
        [ -f "$LYX_DIR/$f" ] && _has_templates=true
    done
    if $_has_templates; then
        TUI_ITEMS+=("LyX templates (defaults, Hebrew, English)")
        TUI_CHECKED+=(1)
        UNINSTALL_ACTIONS+=("templates")
    fi

    # Backups
    _backup_count=0
    for bak in "$LYX_DIR"/preferences.bak.* "$LYX_DIR"/bind/user.bind.bak.*; do
        [ -f "$bak" ] && _backup_count=$((_backup_count + 1))
    done
    if [ "$_backup_count" -gt 0 ]; then
        TUI_ITEMS+=("Configuration backups ($_backup_count files)")
        TUI_CHECKED+=(1)
        UNINSTALL_ACTIONS+=("backups")
    fi

    # Culmus fonts
    if fc-list 2>/dev/null | grep -qi "David CLM"; then
        TUI_ITEMS+=("Culmus Hebrew fonts (~/Library/Fonts/*CLM*)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("culmus")
    fi

    # Noto fonts
    _NOTO_INSTALLED=()
    for cask in font-noto-sans-hebrew font-noto-serif-hebrew font-noto-rashi-hebrew; do
        brew list --cask "$cask" &>/dev/null && _NOTO_INSTALLED+=("$cask")
    done
    if [ ${#_NOTO_INSTALLED[@]} -gt 0 ]; then
        TUI_ITEMS+=("Noto Hebrew fonts (${#_NOTO_INSTALLED[@]} casks)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("noto")
    fi

    # LyX application
    if [ -d "/Applications/LyX.app" ]; then
        TUI_ITEMS+=("LyX application")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("lyx")
    fi

    # MacTeX
    if [ -f /Library/TeX/texbin/xelatex ]; then
        TUI_ITEMS+=("MacTeX (~6 GB)")
        TUI_CHECKED+=(0)
        UNINSTALL_ACTIONS+=("mactex")
    fi

    if [ ${#TUI_ITEMS[@]} -eq 0 ]; then
        info "Nothing found to uninstall."
        exit 0
    fi

    tui_checkbox "Select components to remove:"

    # Check if anything selected
    _any=false
    for ((i = 0; i < ${#TUI_ITEMS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && _any=true
    done
    if ! $_any; then
        info "Nothing selected."
        exit 0
    fi

    # Show what will be removed and confirm
    echo ""
    echo -e "  ${BOLD}The following will be removed:${NC}"
    for ((i = 0; i < ${#TUI_ITEMS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && echo -e "    ${RED}▸${NC} ${TUI_ITEMS[i]}"
    done
    echo ""
    if [ -t 0 ]; then
        echo -ne "  ${YELLOW}This cannot be undone.${NC} Continue? [y/N] "
        read -r _confirm
        case "$_confirm" in
            [yY]|[yY][eE][sS]) ;;
            *) info "Cancelled."; exit 0 ;;
        esac
    fi

    # Prompt for sudo once if MacTeX uninstall is selected
    _uninstall_needs_sudo=false
    for ((i = 0; i < ${#UNINSTALL_ACTIONS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] && [ "${UNINSTALL_ACTIONS[i]}" = "mactex" ] && _uninstall_needs_sudo=true
    done
    if $_uninstall_needs_sudo; then sudo_init; fi

    # Execute removals
    for ((i = 0; i < ${#UNINSTALL_ACTIONS[@]}; i++)); do
        [ "${TUI_CHECKED[i]}" = "1" ] || continue
        case "${UNINSTALL_ACTIONS[i]}" in
            config)
                for f in preferences bind/user.bind; do
                    [ -f "$LYX_DIR/$f" ] && rm "$LYX_DIR/$f" && ok "Removed $f"
                done
                ;;
            templates)
                for f in templates/defaults.lyx templates/Hebrew_Article.lyx templates/English_Article.lyx; do
                    [ -f "$LYX_DIR/$f" ] && rm "$LYX_DIR/$f" && ok "Removed $f"
                done
                ;;
            backups)
                rm -f "$LYX_DIR"/preferences.bak.* "$LYX_DIR"/bind/user.bind.bak.* 2>/dev/null || true
                ok "Removed $_backup_count backup files"
                ;;
            culmus)
                rm -f "$HOME"/Library/Fonts/*CLM*.otf "$HOME"/Library/Fonts/*CLM*.ttf 2>/dev/null || true
                ok "Removed Culmus fonts"
                ;;
            noto)
                if brew uninstall --cask "${_NOTO_INSTALLED[@]}" 2>/dev/null; then
                    ok "Removed Noto Hebrew fonts"
                else
                    warn "Failed to remove some Noto fonts"
                fi
                ;;
            lyx)
                if brew uninstall --cask lyx 2>/dev/null; then
                    ok "Removed LyX"
                else
                    warn "Failed to remove LyX via Homebrew"
                fi
                ;;
            mactex)
                if brew uninstall --cask mactex 2>/dev/null; then
                    ok "Removed MacTeX"
                else
                    warn "Failed to remove MacTeX via Homebrew"
                fi
                ;;
        esac
    done

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

TUI_ITEMS+=("LyX configuration (preferences, keybindings, templates)")
TUI_CHECKED+=(1); INSTALL_ACTIONS+=("config")

if $FORCE; then
    info "Force mode — installing all components"
else
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
        config) echo "LyX configuration ${DIM}(preferences, keybindings, templates)${NC}" ;;
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

# ── Dry-run exit ─────────────────────────────────────

if $DRY_RUN; then
    echo ""
    info "Dry run — no changes were made."
    echo -e "  ${DIM}Run without --dry-run to install.${NC}"
    echo ""
    exit 0
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
            warn "Checksum mismatch — verifying archive contents instead"
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
        cp "$CULMUS_TMP"/culmus-"$CULMUS_VERSION"/*CLM*.otf "$HOME/Library/Fonts/"
        cp "$CULMUS_TMP"/culmus-"$CULMUS_VERSION"/*CLM*.ttf "$HOME/Library/Fonts/" 2>/dev/null || true  # some versions lack .ttf
        rm -rf "$CULMUS_TMP"

        FONT_COUNT=$(find "$HOME/Library/Fonts" -name '*CLM*' 2>/dev/null | wc -l | tr -d ' ')
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
            ok "Noto Hebrew fonts installed ${DIM}($(fmt_elapsed))${NC}"
        else
            fail "Noto Hebrew font installation failed"
            exit 1
        fi
    fi
fi

# ── Install: LyX configuration ──────────────────────

if is_selected "config"; then
    step "LyX configuration"
    mkdir -p "$LYX_DIR/bind" "$LYX_DIR/templates"

    # Back up existing files
    for f in preferences bind/user.bind; do
        [ -f "$LYX_DIR/$f" ] && cp "$LYX_DIR/$f" "$LYX_DIR/$f.bak.$(date +%s)" 2>/dev/null
        ls -t "$LYX_DIR/$f".bak.* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
    done

    # Preferences — only non-default settings (matches LyX 2.4.4 on macOS)
    cat > "$LYX_DIR/preferences" << 'EOF'
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

    ok "Preferences written"

    # Keybindings — F12 for Hebrew (Madlyx guide, page 16)
    cat > "$LYX_DIR/bind/user.bind" << 'EOF'
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

    ok "Keybindings written (F12 = Hebrew, Shift+F12 = English)"

    # ── Hebrew document templates ─────────────────────

    info "Writing document templates..."

    # Shared document header for templates
    write_lyx_template() {
        local file="$1"
        local body="$2"
        cat > "$file" << 'HEADER'
#LyX 2.4 created this file. For more info see https://www.lyx.org/
\lyxformat 620
\begin_document
\begin_header
\save_transient_properties true
\origin unavailable
\textclass article
\begin_preamble
% Hebrew fonts — David CLM with explicit italic/bold mapping
\newfontfamily\hebrewfont[Script=Hebrew,Ligatures=TeX,
  ItalicFont={David CLM Medium Italic},
  BoldFont={David CLM Bold},
  BoldItalicFont={David CLM Bold Italic}]{David CLM}
\newfontfamily\hebrewfonttt[Script=Hebrew]{Miriam Mono CLM}
\newfontfamily\hebrewfontsf[Script=Hebrew]{Simple CLM}

% OpenType math font for proper math typography with XeTeX
\usepackage{unicode-math}
\setmathfont{XITS Math}

% Hyperref — clickable cross-refs & PDF bookmarks for Hebrew
% unicode=false is required for correct Hebrew PDF bookmarks
\usepackage[unicode=false,bookmarks=true,colorlinks=true,
  linkcolor=blue,citecolor=green,urlcolor=magenta]{hyperref}

% Auto font-switch for characters outside Hebrew Unicode block
\usepackage{ucharclasses}
\setTransitionsForLatin{\begingroup\rmfamily}{\endgroup}
\end_preamble
\use_default_options true
\begin_modules
theorems-ams
theorems-ams-extended
eqs-within-sections
\end_modules
\maintain_unincluded_children no
\language hebrew
\language_package default
\inputencoding auto-legacy
\fontencoding auto
\font_roman "default" "default"
\font_sans "default" "default"
\font_typewriter "default" "default"
\font_math "auto" "auto"
\font_default_family default
\use_non_tex_fonts true
\font_sc false
\font_roman_osf false
\font_sans_osf false
\font_typewriter_osf false
\font_sf_scale 100 100
\font_tt_scale 100 100
\use_microtype true
\use_dash_ligatures true
\graphics xetex
\default_output_format pdf4
\output_sync 0
\bibtex_command default
\index_command default
\float_placement class
\float_alignment class
\paperfontsize 12
\spacing single
\use_hyperref false
\papersize a4paper
\use_geometry true
\topmargin 2cm
\bottommargin 2cm
\leftmargin 2cm
\rightmargin 2cm
\use_package amsmath 1
\use_package amssymb 1
\use_package cancel 1
\use_package esint 1
\use_package mathdots 1
\use_package mathtools 1
\use_package mhchem 1
\use_package stackrel 1
\use_package stmaryrd 1
\use_package undertilde 1
\cite_engine basic
\cite_engine_type default
\biblio_style plain
\use_bibtopic false
\use_indices false
\paperorientation portrait
\suppress_date false
\justification true
\use_refstyle 1
\use_formatted_ref 1
\use_minted 0
\use_lineno 0
\index Index
\shortcut idx
\color #008000
\end_index
\secnumdepth 3
\tocdepth 3
\paragraph_separation indent
\paragraph_indentation default
\is_math_indent 0
\math_numbering_side default
\quotes_style english
\dynamic_quotes 0
\papercolumns 1
\papersides 1
\paperpagestyle default
\tablestyle default
\tracking_changes false
\output_changes false
\change_bars false
\postpone_fragile_content true
\html_math_output 0
\html_css_as_file 0
\html_be_strict false
\docbook_table_output 0
\docbook_mathml_prefix 1
\end_header
HEADER
        # NOTE: \use_hyperref is false because hyperref is loaded manually in the
        # preamble with unicode=false (required for correct Hebrew PDF bookmarks).
        # The theorems-ams modules are known to have potential RTL issues with
        # amsthm — if theorem numbering appears reversed, wrap with \L{}.
        echo "" >> "$file"
        printf '%s\n' "$body" >> "$file"
    }

    # defaults.lyx — used by Cmd+N for new documents
    write_lyx_template "$LYX_DIR/templates/defaults.lyx" '\begin_body

\begin_layout Standard

\end_layout

\end_body
\end_document'

    ok "defaults.lyx created (Cmd+N defaults to Hebrew RTL)"

    # Hebrew_Article.lyx — template with Title/Author
    write_lyx_template "$LYX_DIR/templates/Hebrew_Article.lyx" '\begin_body

\begin_layout Title

\end_layout

\begin_layout Author

\end_layout

\begin_layout Standard

\end_layout

\end_body
\end_document'

    ok "Hebrew_Article.lyx template created"

    # English_Article.lyx — default Overleaf-style English article
    cat > "$LYX_DIR/templates/English_Article.lyx" << 'ENDLYX'
#LyX 2.4 created this file. For more info see https://www.lyx.org/
\lyxformat 620
\begin_document
\begin_header
\save_transient_properties true
\origin unavailable
\textclass article
\use_default_options true
\maintain_unincluded_children no
\language english
\language_package default
\inputencoding auto-legacy
\fontencoding auto
\font_roman "default" "default"
\font_sans "default" "default"
\font_typewriter "default" "default"
\font_math "auto" "auto"
\font_default_family default
\use_non_tex_fonts false
\font_sc false
\font_roman_osf false
\font_sans_osf false
\font_typewriter_osf false
\font_sf_scale 100 100
\font_tt_scale 100 100
\use_microtype true
\use_dash_ligatures true
\graphics default
\default_output_format pdf2
\output_sync 0
\bibtex_command default
\index_command default
\float_placement class
\float_alignment class
\paperfontsize 12
\spacing single
\use_hyperref true
\papersize a4paper
\use_geometry true
\topmargin 2cm
\bottommargin 2cm
\leftmargin 2cm
\rightmargin 2cm
\use_package amsmath 1
\use_package amssymb 1
\use_package cancel 1
\use_package esint 1
\use_package mathdots 1
\use_package mathtools 1
\use_package mhchem 1
\use_package stackrel 1
\use_package stmaryrd 1
\use_package undertilde 1
\cite_engine basic
\cite_engine_type default
\biblio_style plain
\use_bibtopic false
\use_indices false
\paperorientation portrait
\suppress_date false
\justification true
\use_refstyle 1
\use_formatted_ref 1
\use_minted 0
\use_lineno 0
\index Index
\shortcut idx
\color #008000
\end_index
\secnumdepth 3
\tocdepth 3
\paragraph_separation indent
\paragraph_indentation default
\is_math_indent 0
\math_numbering_side default
\quotes_style english
\dynamic_quotes 0
\papercolumns 1
\papersides 1
\paperpagestyle default
\tablestyle default
\tracking_changes false
\output_changes false
\change_bars false
\postpone_fragile_content true
\html_math_output 0
\html_css_as_file 0
\html_be_strict false
\docbook_table_output 0
\docbook_mathml_prefix 1
\end_header

\begin_body

\begin_layout Title

\end_layout

\begin_layout Author

\end_layout

\begin_layout Date
\begin_inset ERT
status open

\begin_layout Plain Layout


\backslash
today
\end_layout

\end_inset


\end_layout

\begin_layout Standard

\end_layout

\end_body
\end_document
ENDLYX

    ok "English_Article.lyx template created (Overleaf-style)"

    # ── Run LyX Reconfigure ──────────────────────────

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
    for f in preferences bind/user.bind templates/defaults.lyx templates/Hebrew_Article.lyx templates/English_Article.lyx; do
        _check "Missing config: $f" test -f "$LYX_DIR/$f"
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

# ── Gatekeeper bypass ────────────────────────────────

if [ -d "/Applications/LyX.app" ] && xattr -l /Applications/LyX.app 2>/dev/null | grep -q com.apple.quarantine; then
    xattr -d com.apple.quarantine /Applications/LyX.app 2>/dev/null \
        && ok "Cleared Gatekeeper quarantine on LyX.app" \
        || true  # not critical
fi

# ── Total elapsed time ───────────────────────────────

_total_el=$(( SECONDS - INSTALL_START ))
if [ "$_total_el" -ge 60 ]; then
    _total_fmt=$(printf '%dm%02ds' $((_total_el / 60)) $((_total_el % 60)))
else
    _total_fmt=$(printf '%ds' "$_total_el")
fi

header "Setup Complete  ${DIM}(${_total_fmt})${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
if [ -d "/Applications/LyX.app" ]; then
    echo -e "  ${CYAN}1${NC}  Open LyX and run ${BOLD}${YELLOW}Tools > Reconfigure${NC}, then restart LyX"
    echo -e "     ${DIM}This is required for the new settings to take effect${NC}"
else
    echo -e "  ${CYAN}1${NC}  Install LyX, then run ${BOLD}${YELLOW}Tools > Reconfigure${NC}"
fi
echo -e "  ${CYAN}2${NC}  ${BOLD}Cmd+N${NC} creates Hebrew RTL documents with David CLM"
echo -e "  ${CYAN}3${NC}  ${BOLD}F12${NC} toggles Hebrew/English ${DIM}(keep OS keyboard on English)${NC}"
echo -e "     ${DIM}On laptops: you may need Fn+F12 if F12 is mapped to a media key${NC}"
echo -e "  ${CYAN}4${NC}  File paths must not contain Hebrew characters"
echo ""
echo -e "  ${DIM}Log: $LOG_FILE${NC}"
echo ""
