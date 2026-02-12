#!/bin/bash
#
# install-lyx-hebrew.sh
# Installs LyX on macOS with full Hebrew + XeLaTeX support.
# Based on the Madlyx guide by Kali (Oct 2025).
#
# What this script does:
#   1. Installs MacTeX (TeX distribution with XeLaTeX) via Homebrew
#   2. Installs LyX via Homebrew
#   3. Downloads and installs Culmus Hebrew fonts
#   4. Configures LyX preferences for Hebrew (RTL, visual cursor, keyboard map)
#   5. Sets up F12 shortcut to toggle Hebrew/English
#   6. Creates default document template with Hebrew + David CLM font
#
# Prerequisites: Homebrew must be installed (https://brew.sh)
#
# Usage:
#   chmod +x install-lyx-hebrew.sh
#   ./install-lyx-hebrew.sh
#

set -e

# ─────────────────────────────────────────────────────────
# Colors for output
# ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

LYX_CONFIG_DIR="$HOME/Library/Application Support/LyX-2.4"

# ─────────────────────────────────────────────────────────
# Step 0: Check prerequisites
# ─────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  LyX Hebrew Installer for macOS"
echo "  Based on the Madlyx guide by Kali"
echo "=============================================="
echo ""

if ! command -v brew &>/dev/null; then
    error "Homebrew is not installed. Install it from https://brew.sh"
    exit 1
fi
ok "Homebrew found"

if ! command -v python3 &>/dev/null; then
    warn "Python3 not found. LyX needs Python for some operations."
    warn "Install it with: xcode-select --install"
fi

# ─────────────────────────────────────────────────────────
# Step 1: Install MacTeX
# ─────────────────────────────────────────────────────────
info "Step 1/6: Installing MacTeX (this is ~5 GB and may take a while)..."

if command -v xelatex &>/dev/null || [ -f /Library/TeX/texbin/xelatex ]; then
    ok "MacTeX/XeLaTeX already installed: $(xelatex --version 2>/dev/null | head -1 || /Library/TeX/texbin/xelatex --version 2>/dev/null | head -1)"
else
    brew install --cask mactex
    # Refresh PATH to pick up TeX binaries
    eval "$(/usr/libexec/path_helper)" 2>/dev/null
    if command -v xelatex &>/dev/null || [ -f /Library/TeX/texbin/xelatex ]; then
        ok "MacTeX installed successfully"
    else
        warn "MacTeX installed but xelatex not yet on PATH."
        warn "You may need to restart your terminal or run: eval \"\$(/usr/libexec/path_helper)\""
    fi
fi

# ─────────────────────────────────────────────────────────
# Step 2: Install LyX
# ─────────────────────────────────────────────────────────
info "Step 2/6: Installing LyX..."

if [ -d "/Applications/LyX.app" ]; then
    ok "LyX already installed at /Applications/LyX.app"
else
    brew install --cask lyx
    if [ -d "/Applications/LyX.app" ]; then
        ok "LyX installed successfully"
    else
        error "LyX installation failed"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────
# Step 3: Install Culmus Hebrew fonts
# ─────────────────────────────────────────────────────────
info "Step 3/6: Installing Culmus Hebrew fonts..."

if fc-list 2>/dev/null | grep -qi "David CLM"; then
    ok "Culmus fonts already installed"
else
    CULMUS_TMP=$(mktemp -d)
    CULMUS_URL="https://sourceforge.net/projects/culmus/files/culmus/0.140/culmus-0.140.tar.gz/download"

    info "Downloading Culmus fonts from SourceForge..."
    curl -L -o "$CULMUS_TMP/culmus.tar.gz" "$CULMUS_URL" 2>/dev/null

    info "Extracting fonts..."
    tar xzf "$CULMUS_TMP/culmus.tar.gz" -C "$CULMUS_TMP"

    mkdir -p "$HOME/Library/Fonts"

    info "Installing font files to ~/Library/Fonts/..."
    cp "$CULMUS_TMP"/culmus-0.140/DavidCLM-*.otf \
       "$CULMUS_TMP"/culmus-0.140/FrankRuehlCLM-*.otf \
       "$CULMUS_TMP"/culmus-0.140/MiriamCLM-*.otf \
       "$CULMUS_TMP"/culmus-0.140/MiriamMonoCLM-*.ttf \
       "$CULMUS_TMP"/culmus-0.140/SimpleCLM-*.ttf \
       "$CULMUS_TMP"/culmus-0.140/NachlieliCLM-*.otf \
       "$CULMUS_TMP"/culmus-0.140/AharoniCLM-*.otf \
       "$HOME/Library/Fonts/"

    rm -rf "$CULMUS_TMP"

    FONT_COUNT=$(ls "$HOME"/Library/Fonts/*CLM* 2>/dev/null | wc -l | tr -d ' ')
    ok "Installed $FONT_COUNT Culmus font files"
fi

# ─────────────────────────────────────────────────────────
# Step 4: Wait for LyX config directory to exist
# ─────────────────────────────────────────────────────────
info "Step 4/6: Setting up LyX configuration directory..."

# LyX creates its config dir on first launch or during brew install.
# If it doesn't exist yet, create the minimal structure.
if [ ! -d "$LYX_CONFIG_DIR" ]; then
    warn "LyX config directory not found. Creating it..."
    mkdir -p "$LYX_CONFIG_DIR"
fi

mkdir -p "$LYX_CONFIG_DIR/bind"
mkdir -p "$LYX_CONFIG_DIR/templates"

ok "Config directory ready: $LYX_CONFIG_DIR"

# ─────────────────────────────────────────────────────────
# Step 5: Write LyX preferences (per Madlyx guide)
# ─────────────────────────────────────────────────────────
info "Step 5/6: Writing LyX preferences and keybindings..."

# Back up existing preferences if present
if [ -f "$LYX_CONFIG_DIR/preferences" ]; then
    cp "$LYX_CONFIG_DIR/preferences" "$LYX_CONFIG_DIR/preferences.backup.$(date +%Y%m%d%H%M%S)"
    warn "Existing preferences backed up"
fi

cat > "$LYX_CONFIG_DIR/preferences" << 'PREFS_EOF'
Format 38

# Bind file - load user.bind which includes Mac base bindings + Hebrew shortcuts
\bind_file "user"

#
# MISC SECTION ######################################
#

\path_prefix "/Library/TeX/texbin:/usr/texbin:/opt/homebrew/bin:/opt/local/bin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin"
\serverpipe "~/Library/Application Support/LyX-2.4/.lyxpipe"

#
# SCREEN & FONTS SECTION ############################
#

# Screen fonts - David CLM for Hebrew display in LyX GUI
\screen_font_roman "David CLM"
\screen_font_sans "Simple CLM"
\screen_font_typewriter "Miriam Mono CLM"

\open_buffers_in_tabs false
\mac_like_cursor_movement true

# Instant preview: No math (don't render math as preview images)
\preview no_math

# Scroll wheel zoom with Ctrl (Madlyx guide, page 15)
\scroll_wheel_zoom "ctrl"

#
# EDITING SECTION ###################################
#

# Cursor movement: Visual (Madlyx guide, page 15)
\visual_cursor true

# Cursor follows scrollbar
\cursor_follows_scrollbar true

# Scroll below document end
\scroll_below_document true

# Sort environments alphabetically (Madlyx guide, page 16)
\sort_layouts true

# Group environments by category
\group_layouts true

#
# LANGUAGE SUPPORT SECTION ##########################
#

# Language package: Automatic (Madlyx guide, page 15)
\language_package_selection 0

# Set language globally (Madlyx guide, page 15)
\language_global_options true

# Auto begin (Madlyx guide, page 15)
\language_auto_begin true

# Auto end (Madlyx guide, page 15)
\language_auto_end true

# Mark foreign language (Madlyx guide, page 15)
\mark_foreign_language true

# Language command
\language_command_begin "\selectlanguage{$$lang}"

# Do not follow OS keyboard - use F12 to toggle inside LyX
\respect_os_kbd_language false

#
# KEYBOARD SECTION ##################################
#

# Use keyboard map (Madlyx guide, page 15)
\kbmap true

# Primary: null (Madlyx guide, page 15)
\kbmap_primary ""

# Secondary: hebrew (Madlyx guide, page 15)
\kbmap_secondary "hebrew"

#
# TEMPLATE SECTION ##################################
#

\template_path "~/Library/Application Support/LyX-2.4/templates"

# Default output format for non-TeX font documents (XeTeX PDF)
\default_otf_view_format "pdf5"

#
# SPELLCHECKER SECTION ##############################
#

\spellchecker "native"
PREFS_EOF

ok "Preferences written"

# ─── Write user.bind (keybindings) ─────────────────────

if [ -f "$LYX_CONFIG_DIR/bind/user.bind" ]; then
    cp "$LYX_CONFIG_DIR/bind/user.bind" "$LYX_CONFIG_DIR/bind/user.bind.backup.$(date +%Y%m%d%H%M%S)"
fi

cat > "$LYX_CONFIG_DIR/bind/user.bind" << 'BIND_EOF'
## user.bind
## Configured per the Madlyx guide (by Kali)
## Mac-adapted: uses "mac" base bindings

Format 5

# Include Mac default bindings as base
\bind_file "mac"

# F12 toggles Hebrew language (Madlyx guide, page 16)
# IMPORTANT: Keep OS keyboard on English at all times.
# Use F12 to switch between Hebrew and English *within LyX*.
# Never use Alt+Shift to switch language.
\bind "F12"                    "language hebrew"
\bind "S-F12"                  "language english"
BIND_EOF

ok "Keybindings written (F12 = Hebrew, Shift+F12 = English)"

# ─────────────────────────────────────────────────────────
# Step 6: Create Hebrew document templates
# ─────────────────────────────────────────────────────────
info "Step 6/6: Creating Hebrew document templates..."

# This is the LYX_DOCUMENT content shared by both templates
LYX_DOC_HEADER='#LyX 2.4 created this file. For more info see https://www.lyx.org/
\lyxformat 620
\begin_document
\begin_header
\save_transient_properties true
\origin unavailable
\textclass article
\begin_preamble
\newfontfamily\hebrewfont[Script=Hebrew]{David CLM}
\newfontfamily\hebrewfonttt[Script=Hebrew]{Miriam Mono CLM}
\newfontfamily\hebrewfontsf[Script=Hebrew]{Simple CLM}
\end_preamble
\use_default_options true
\maintain_unincluded_children no
\language hebrew
\language_package default
\inputencoding auto-legacy
\fontencoding auto
\font_roman "default" "David CLM"
\font_sans "default" "Simple CLM"
\font_typewriter "default" "Miriam Mono CLM"
\font_math "auto" "auto"
\font_default_family default
\use_non_tex_fonts true
\font_sc false
\font_roman_osf false
\font_sans_osf false
\font_typewriter_osf false
\font_sf_scale 100 100
\font_tt_scale 100 100
\use_microtype false
\use_dash_ligatures true
\graphics default
\default_output_format pdf5
\output_sync 0
\bibtex_command default
\index_command default
\float_placement class
\float_alignment class
\paperfontsize default
\spacing single
\use_hyperref false
\papersize default
\use_geometry false
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
\use_formatted_ref 0
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
\end_header'

# ─── defaults.lyx (used by Cmd+N for new documents) ────

cat > "$LYX_CONFIG_DIR/templates/defaults.lyx" << DEFAULTS_EOF
${LYX_DOC_HEADER}

\begin_body

\begin_layout Standard

\end_layout

\end_body
\end_document
DEFAULTS_EOF

ok "defaults.lyx created (new documents will default to Hebrew RTL)"

# ─── Hebrew_Article.lyx template (for File > New from Template) ──

cat > "$LYX_CONFIG_DIR/templates/Hebrew_Article.lyx" << TEMPLATE_EOF
${LYX_DOC_HEADER}

\begin_body

\begin_layout Title

\end_layout

\begin_layout Author

\end_layout

\begin_layout Standard

\end_layout

\end_body
\end_document
TEMPLATE_EOF

ok "Hebrew_Article.lyx template created"

# ─────────────────────────────────────────────────────────
# Verification
# ─────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  Verification"
echo "=============================================="

# Check XeLaTeX
eval "$(/usr/libexec/path_helper)" 2>/dev/null
export PATH="/Library/TeX/texbin:$PATH"

if command -v xelatex &>/dev/null; then
    ok "XeLaTeX: $(xelatex --version 2>/dev/null | head -1)"
else
    warn "XeLaTeX not found on PATH (restart terminal after MacTeX install)"
fi

# Check polyglossia and bidi
if command -v kpsewhich &>/dev/null; then
    if kpsewhich polyglossia.sty &>/dev/null; then
        ok "polyglossia package: available"
    else
        warn "polyglossia package: NOT FOUND"
    fi
    if kpsewhich bidi.sty &>/dev/null; then
        ok "bidi (RTL) package: available"
    else
        warn "bidi (RTL) package: NOT FOUND"
    fi
fi

# Check LyX
if [ -d "/Applications/LyX.app" ]; then
    ok "LyX: installed at /Applications/LyX.app"
else
    warn "LyX: not found in /Applications"
fi

# Check fonts
if fc-list 2>/dev/null | grep -qi "David CLM"; then
    ok "David CLM font: installed"
else
    warn "David CLM font: not detected by fc-list (may still work via Font Book)"
fi

# Check config files
for f in "preferences" "bind/user.bind" "templates/defaults.lyx" "templates/Hebrew_Article.lyx"; do
    if [ -f "$LYX_CONFIG_DIR/$f" ]; then
        ok "Config: $f"
    else
        warn "Missing: $f"
    fi
done

# Quick XeTeX compilation test
if command -v xelatex &>/dev/null && fc-list 2>/dev/null | grep -qi "David CLM"; then
    info "Running Hebrew XeTeX compilation test..."
    TEST_DIR=$(mktemp -d)
    cat > "$TEST_DIR/test.tex" << 'TEX_EOF'
\documentclass{article}
\usepackage{polyglossia}
\setdefaultlanguage{hebrew}
\setotherlanguage{english}
\setmainfont{David CLM}
\newfontfamily\hebrewfont[Script=Hebrew]{David CLM}
\begin{document}
\begin{hebrew}
שלום עולם!
\end{hebrew}
\end{document}
TEX_EOF
    if xelatex -interaction=nonstopmode -output-directory="$TEST_DIR" "$TEST_DIR/test.tex" &>/dev/null; then
        ok "Hebrew XeTeX compilation test: PASSED"
    else
        warn "Hebrew XeTeX compilation test: FAILED (check XeTeX and font installation)"
    fi
    rm -rf "$TEST_DIR"
fi

# ─────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "  Next steps:"
echo "  1. Open LyX (first time: right-click > Open to bypass Gatekeeper)"
echo "  2. Run Tools > Reconfigure, then restart LyX"
echo "  3. New documents (Cmd+N) will default to Hebrew RTL with David CLM"
echo "  4. Press F12 to toggle Hebrew/English within LyX"
echo "  5. Keep your OS keyboard on English at all times"
echo "  6. File paths must not contain Hebrew characters"
echo ""
echo "  For a Hebrew template with Title/Author: File > New from Template > Hebrew_Article"
echo ""
