# lyx-he

Single-script installer for [LyX](https://www.lyx.org/) with full **Hebrew RTL** and **XeLaTeX** support on macOS.
Based on the [Madlyx guide](https://mkali56.wixsite.com/madlyx) by Michael Kali.

<p align="center">
  <img src="screenshots/banner.png" alt="lyx-he installer banner" width="640">
</p>

## Quick Start

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh)"
```

One command. Idempotent — safe to re-run. Already-installed components are skipped, existing configs are backed up.

> **Requires macOS** (Apple Silicon or Intel). Homebrew is set up automatically if needed.

```bash
# Install all without prompting
curl -fsSL https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh | bash -s -- --force

# Preview what would be installed
curl -fsSL https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh | bash -s -- --dry-run
```

<details>
<summary><strong>Or clone and run locally</strong></summary>

```bash
git clone https://github.com/tom-bleher/lyx-he.git
cd lyx-he
./install.sh              # or --force, --dry-run, --uninstall, --help
```

</details>

## What You Get

[MacTeX](https://www.tug.org/mactex/) (~6 GB), [LyX](https://www.lyx.org/), [Culmus](https://culmus.sourceforge.io/) and [Noto Hebrew](https://fonts.google.com/noto) fonts — plus full configuration:

- Hebrew RTL default language, David CLM + Latin Modern fonts (same as Overleaf)
- XeLaTeX output with polyglossia, bidi, and automatic Hebrew/Latin font switching
- **F12** / **Shift+F12** for Hebrew/English toggle, **Cmd+E/I** for emphasis
- Math auto-completion, OpenType math (STIX Two), hyperref cross-references
- 6 document templates (article, solutions, CV) in Hebrew and English

<p align="center">
  <img src="screenshots/component-picker.png" alt="Interactive component picker" width="570">
</p>

## Templates

Open from **File > New from Template** in LyX.

<table>
<tr>
<td align="center"><strong>Hebrew Article</strong></td>
<td align="center"><strong>English Article</strong></td>
<td align="center"><strong>Academic CV</strong></td>
</tr>
<tr>
<td><a href="examples/Hebrew_Article.pdf"><img src="examples/Hebrew_Article.png" alt="Hebrew Article" width="250"></a></td>
<td><a href="examples/English_Article.pdf"><img src="examples/English_Article.png" alt="English Article" width="250"></a></td>
<td><a href="examples/English_CV.pdf"><img src="examples/English_CV.png" alt="English CV" width="250"></a></td>
</tr>
<tr>
<td align="center"><strong>Hebrew Solutions</strong></td>
<td align="center"><strong>English Solutions</strong></td>
<td></td>
</tr>
<tr>
<td><a href="examples/Hebrew_Solutions.pdf"><img src="examples/Hebrew_Solutions.png" alt="Hebrew Solutions" width="250"></a></td>
<td><a href="examples/English_Solutions.pdf"><img src="examples/English_Solutions.png" alt="English Solutions" width="250"></a></td>
<td></td>
</tr>
</table>

## Uninstall

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tom-bleher/lyx-he/main/install.sh)" -- --uninstall
```

## Troubleshooting

Logs: `~/.lyx-he-install.log`

<details>
<summary><strong>LyX won't open (Gatekeeper)</strong></summary>

Right-click the app > **Open** > click Open in the dialog. One-time only.
</details>

<details>
<summary><strong>XeLaTeX not found after install</strong></summary>

Reopen your terminal, or run: `eval "$(/usr/libexec/path_helper)"`
</details>

<details>
<summary><strong>Hebrew text appears left-to-right</strong></summary>

**Document > Settings > Language > Hebrew**, or press **F12** on the paragraph.
</details>

<details>
<summary><strong>Italic doesn't work in Hebrew</strong></summary>

Check **Document > Settings > Fonts > "Use non-TeX fonts"** is on and output is set to **PDF (XeTeX)**.
</details>

<details>
<summary><strong>File paths with Hebrew characters</strong></summary>

LyX/TeX can't handle Hebrew in paths. Use English-only directory names.
</details>

## TODO

- [ ] Extend installer to Linux and Windows
- [ ] GUI wrapper for the installer
- [ ] Integration tests

Contributions welcome — open an issue or PR.

## Credits

[Madlyx guide](https://mkali56.wixsite.com/madlyx) by Michael Kali | [Ivlyx](https://lyx.srayaa.com/) | [Bruce Pourciau](https://wiki.lyx.org/Examples/CV) (CV template) | [Culmus Project](https://culmus.sourceforge.io/) | [LyX](https://www.lyx.org/)

## License

MIT
