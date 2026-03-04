# LyX Hebrew Installer for macOS

One-click installer for [LyX](https://www.lyx.org/) with full Hebrew/English support using XeLaTeX. Based on the [Madlyx guide](https://mkali56.wixsite.com/madlyx) by Kali.

## What Gets Installed

| Component | Description |
|-----------|-------------|
| **MacTeX** | Full TeX Live distribution (~6 GB) with XeLaTeX, polyglossia, bidi |
| **LyX** | WYSIWYM document editor (via Homebrew) |
| **Culmus fonts** | David CLM, Frank Ruehl CLM, Miriam CLM, Simple CLM, Nachlieli CLM, etc. |
| **Noto Hebrew fonts** | Noto Sans Hebrew, Noto Serif Hebrew, Noto Rashi Hebrew |

## Prerequisites

- **macOS** (Apple Silicon or Intel)
- **[Homebrew](https://brew.sh)** — install with:
  ```
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

## Running the Installer

```shell
chmod +x install_lyx/mac.sh
./install_lyx/mac.sh
```

The script is idempotent — you can run it again safely. It will skip components that are already installed and back up existing LyX config files before overwriting.

## After Installation

1. **Open LyX** — first launch may require right-click > Open to bypass macOS Gatekeeper
2. **Run Tools > Reconfigure** inside LyX, then restart LyX (the script runs this automatically, but do it again if prompted)
3. **Cmd+N** creates a new Hebrew RTL document ready to type in

## Font Setup

The installer configures a dual-font setup:

- **Hebrew text** — David CLM (from the Culmus project), with full italic/bold support
- **English text** — Latin Modern (the default LaTeX/Overleaf font)

This is handled via XeLaTeX and polyglossia. When you switch to Hebrew (F12), text renders in David CLM. English text uses the standard LaTeX font you'd see on Overleaf.

### Available Hebrew Fonts

These are installed and available for use in your documents:

| Font | Style | Use |
|------|-------|-----|
| David CLM | Serif | Default Hebrew roman font |
| Simple CLM | Sans-serif | Hebrew sans font |
| Miriam Mono CLM | Monospace | Hebrew monospace font |
| Frank Ruehl CLM | Serif | Alternative Hebrew serif |
| Nachlieli CLM | Sans-serif | Alternative Hebrew sans |
| Noto Sans Hebrew | Sans-serif | Modern variable-weight sans |
| Noto Serif Hebrew | Serif | Modern variable-weight serif |
| Noto Rashi Hebrew | Semi-cursive | Rashi script / commentary style |

## Keyboard Shortcuts

### Language Switching

Keep your **macOS keyboard on English** at all times. Language switching is handled inside LyX:

| Shortcut | Action |
|----------|--------|
| **F12** | Switch to Hebrew |
| **Shift+F12** | Switch to English |

> On laptops with media keys on the function row, you may need **Fn+F12** instead. To avoid this, go to **System Settings > Keyboard** and enable "Use F1, F2, etc. keys as standard function keys".

### Text Formatting

The installer rebinds Cmd+E and Cmd+I to emphasis (italic), since the default LyX binding (Cmd+Alt+E) doesn't work on macOS — the Option key produces special characters instead of reaching LyX.

| Shortcut | Action |
|----------|--------|
| **Cmd+E** | Emphasis (italic) |
| **Cmd+I** | Emphasis (italic) |
| **Cmd+B** | Bold |
| **Cmd+N** | New document (Hebrew RTL default) |
| **Cmd+S** | Save |
| **Cmd+R** | Preview PDF |

### Math Mode

| Shortcut | Action |
|----------|--------|
| **Cmd+M** | Inline math mode |
| **Cmd+Shift+M** | Display math mode |

## Document Templates

The installer creates two templates in LyX's template directory:

### `defaults.lyx`
Used when you press **Cmd+N**. Pre-configured with:
- Hebrew as default language (RTL)
- XeLaTeX output
- David CLM for Hebrew, Latin Modern for English
- Non-TeX fonts enabled (fontspec/polyglossia)

### `Hebrew_Article.lyx`
Article template with Title and Author fields. Same font/language configuration as defaults.

## Troubleshooting

### LyX won't open (Gatekeeper)
Right-click the app > **Open** > click Open in the dialog. You only need to do this once.

### XeLaTeX not found after install
Close and reopen your terminal, or run:
```
eval "$(/usr/libexec/path_helper)"
```

### Hebrew text appears left-to-right
Make sure the document language is set to Hebrew:
- **Document > Settings > Language > Language: Hebrew**
- Or press **F12** to switch the current paragraph to Hebrew

### Italic doesn't work in Hebrew
The installer configures explicit italic font mapping for David CLM. If italic still looks identical to regular text, check:
- **Document > Settings > Fonts > "Use non-TeX fonts"** must be checked
- **Document > Settings > Output > Default output format** must be **PDF (XeTeX)**

### File paths with Hebrew characters
LyX and TeX cannot handle Hebrew characters in file paths. Save your documents in directories with English-only names.

### LyX Homebrew cask deprecation
The LyX Homebrew cask is deprecated due to Gatekeeper signing issues (disabled Sept 2026). If `brew install --cask lyx` fails, download LyX directly from [lyx.org/Download](https://www.lyx.org/Download).

## What the Script Configures

For reference, here are the LyX settings the script writes:

**Preferences** (`~/Library/Application Support/LyX-2.5/preferences`):
- Hebrew keyboard map enabled
- Visual cursor (correct for bidirectional text)
- Screen fonts: David CLM (roman), Simple CLM (sans), Miriam Mono CLM (mono)
- Default PDF viewer: XeTeX PDF

**Keybindings** (`~/Library/Application Support/LyX-2.5/bind/user.bind`):
- Inherits from `mac.bind` (standard macOS bindings)
- F12 / Shift+F12 for Hebrew/English
- Cmd+E and Cmd+I rebound to emphasis

**Templates** (`~/Library/Application Support/LyX-2.5/templates/`):
- `defaults.lyx` — blank Hebrew RTL document
- `Hebrew_Article.lyx` — article with Title/Author
