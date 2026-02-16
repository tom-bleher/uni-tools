#!/bin/bash
#
# mac.sh — Install LyX on macOS (arm/Intel) with Hebrew + XeLaTeX support
# Based on the Madlyx guide by Kali (Oct 2025)
#
# Installs: MacTeX, LyX, Culmus Hebrew fonts
# Configures: Hebrew RTL, David CLM fonts, F12 language toggle, XeTeX output
#
# Prerequisites: Homebrew (https://brew.sh)
# Usage: chmod +x mac.sh && ./mac.sh
#

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[ERROR]${NC} $1"; }

LYX_DIR="$HOME/Library/Application Support/LyX-2.4"

echo ""
echo "=============================================="
echo "  LyX Hebrew Installer for macOS"
echo "  Based on the Madlyx guide by Kali"
echo "=============================================="
echo ""

# ── Prerequisites ─────────────────────────────────────

if ! command -v brew &>/dev/null; then
    fail "Homebrew is not installed. Install it from https://brew.sh"
    exit 1
fi
ok "Homebrew found"

# ── Step 1: MacTeX ────────────────────────────────────

info "Step 1/5: MacTeX..."
if [ -f /Library/TeX/texbin/xelatex ]; then
    ok "MacTeX already installed"
else
    info "Installing MacTeX (~6 GB download, requires sudo)..."
    brew install --cask mactex
    eval "$(/usr/libexec/path_helper)" 2>/dev/null
    [ -f /Library/TeX/texbin/xelatex ] && ok "MacTeX installed" \
        || warn "MacTeX installed but xelatex not on PATH. Restart your terminal."
fi

# ── Step 2: LyX ──────────────────────────────────────

info "Step 2/5: LyX..."
if [ -d "/Applications/LyX.app" ]; then
    ok "LyX already installed"
else
    brew install --cask lyx
    [ -d "/Applications/LyX.app" ] && ok "LyX installed" \
        || { fail "LyX installation failed"; exit 1; }
fi

# ── Step 3: Culmus Hebrew fonts ──────────────────────

info "Step 3/5: Culmus Hebrew fonts..."
if fc-list 2>/dev/null | grep -qi "David CLM"; then
    ok "Culmus fonts already installed"
else
    CULMUS_TMP=$(mktemp -d)
    info "Downloading Culmus 0.140..."
    curl -sL -o "$CULMUS_TMP/culmus.tar.gz" \
        "https://sourceforge.net/projects/culmus/files/culmus/0.140/culmus-0.140.tar.gz/download"
    tar xzf "$CULMUS_TMP/culmus.tar.gz" -C "$CULMUS_TMP"

    mkdir -p "$HOME/Library/Fonts"
    cp "$CULMUS_TMP"/culmus-0.140/{David,FrankRuehl,Miriam,Nachlieli,Aharoni}CLM-*.otf \
       "$CULMUS_TMP"/culmus-0.140/{MiriamMono,Simple}CLM-*.ttf \
       "$HOME/Library/Fonts/" 2>/dev/null
    # Also copy any remaining .otf/.ttf CLM fonts
    cp "$CULMUS_TMP"/culmus-0.140/*CLM*.otf "$CULMUS_TMP"/culmus-0.140/*CLM*.ttf \
       "$HOME/Library/Fonts/" 2>/dev/null || true
    rm -rf "$CULMUS_TMP"

    FONT_COUNT=$(ls "$HOME"/Library/Fonts/*CLM* 2>/dev/null | wc -l | tr -d ' ')
    ok "Installed $FONT_COUNT Culmus font files"
fi

# ── Step 4: LyX preferences + keybindings ────────────

info "Step 4/5: LyX configuration..."
mkdir -p "$LYX_DIR/bind" "$LYX_DIR/templates"

# Back up existing files
for f in preferences bind/user.bind; do
    [ -f "$LYX_DIR/$f" ] && cp "$LYX_DIR/$f" "$LYX_DIR/$f.bak.$(date +%s)" 2>/dev/null
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
\sort_layouts true
\kbmap true
\kbmap_secondary "hebrew"
\preview no_math
\preview_scale_factor 0.8

#
# SCREEN & FONTS SECTION ############################
#

\cursor_follows_scrollbar true
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
EOF

ok "Keybindings written (F12 = Hebrew, Shift+F12 = English)"

# ── Step 5: Hebrew document templates ─────────────────

info "Step 5/5: Hebrew document templates..."

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
\graphics xetex
\default_output_format pdf4
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
\end_header
HEADER
    echo "" >> "$file"
    echo "$body" >> "$file"
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

# ── Verification ──────────────────────────────────────

echo ""
echo "=============================================="
echo "  Verification"
echo "=============================================="

eval "$(/usr/libexec/path_helper)" 2>/dev/null
export PATH="/Library/TeX/texbin:$PATH"

command -v xelatex &>/dev/null \
    && ok "XeLaTeX: $(xelatex --version 2>/dev/null | head -1)" \
    || warn "XeLaTeX not on PATH (restart terminal after MacTeX install)"

if command -v kpsewhich &>/dev/null; then
    kpsewhich polyglossia.sty &>/dev/null && ok "polyglossia: available" || warn "polyglossia: NOT FOUND"
    kpsewhich bidi.sty &>/dev/null && ok "bidi (RTL): available" || warn "bidi (RTL): NOT FOUND"
fi

[ -d "/Applications/LyX.app" ] && ok "LyX: /Applications/LyX.app" || warn "LyX: not found"
fc-list 2>/dev/null | grep -qi "David CLM" && ok "David CLM: installed" || warn "David CLM: not found by fc-list"

for f in preferences bind/user.bind templates/defaults.lyx templates/Hebrew_Article.lyx; do
    [ -f "$LYX_DIR/$f" ] && ok "$f" || warn "Missing: $f"
done

# Hebrew XeTeX compilation test
if command -v xelatex &>/dev/null && fc-list 2>/dev/null | grep -qi "David CLM"; then
    info "Running Hebrew XeTeX compilation test..."
    TEST_DIR=$(mktemp -d)
    cat > "$TEST_DIR/test.tex" << 'TEX'
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
TEX
    xelatex -interaction=nonstopmode -output-directory="$TEST_DIR" "$TEST_DIR/test.tex" &>/dev/null \
        && ok "Hebrew XeTeX compilation: PASSED" \
        || warn "Hebrew XeTeX compilation: FAILED"
    rm -rf "$TEST_DIR"
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
echo ""
echo "  Next steps:"
echo "  1. Open LyX (first time: right-click > Open to bypass Gatekeeper)"
echo "  2. Run Tools > Reconfigure, then restart LyX"
echo "  3. Cmd+N creates Hebrew RTL documents with David CLM"
echo "  4. F12 toggles Hebrew/English (keep OS keyboard on English)"
echo "     On laptops: you may need Fn+F12 if F12 is mapped to a media key"
echo "  5. File paths must not contain Hebrew characters"
echo ""
