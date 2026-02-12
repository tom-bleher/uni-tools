# uni-tools

A collection of tools to aid the Hebrew STEM student.

## Tools

### install_lyx (macOS)

One-click installer for [LyX](https://www.lyx.org/) with full Hebrew RTL + XeLaTeX support, based on the [Madlyx guide](https://mkali56.wixsite.com/madlyx).

**Prerequisites:**

- [Homebrew](https://brew.sh)

**What the installer does:**

1. Install MacTeX (TeX distribution with XeLaTeX)
2. Install LyX
3. Download and install Culmus Hebrew fonts (David CLM, etc.)
4. Configure LyX preferences for Hebrew (RTL, visual cursor, keyboard map)
5. Set up F12 / Shift+F12 to toggle Hebrew/English within LyX
6. Create default document templates with Hebrew + David CLM font

**Running the installer:**

```shell
# Make the script executable
chmod +x install_lyx/mac.sh

# Run the installer
./install_lyx/mac.sh
```

## License

MIT
