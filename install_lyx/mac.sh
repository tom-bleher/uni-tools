#!/bin/bash
#
# mac.sh — Install LyX on macOS (arm/Intel) with Hebrew + XeLaTeX support
# Based on the Madlyx guide by Kali (Oct 2025)
#
# Installs: MacTeX, LyX, Culmus + Noto Hebrew fonts
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

# Detect installed LyX version directory
if [ -d "$HOME/Library/Application Support/LyX-2.5" ]; then
    LYX_DIR="$HOME/Library/Application Support/LyX-2.5"
elif [ -d "$HOME/Library/Application Support/LyX-2.4" ]; then
    LYX_DIR="$HOME/Library/Application Support/LyX-2.4"
else
    # Default for fresh install (LyX 2.5 is current)
    LYX_DIR="$HOME/Library/Application Support/LyX-2.5"
fi

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
echo "  Hebrew Installer for macOS"
echo "  Based on the Madlyx guide by Kali"
echo ""

# ── Prerequisites ─────────────────────────────────────

if ! command -v brew &>/dev/null; then
    fail "Homebrew is not installed. Install it from https://brew.sh"
    exit 1
fi
ok "Homebrew found"

# ── Confirm before installing ─────────────────────────

echo ""
info "This script will install (skipping what you already have):"
[ -f /Library/TeX/texbin/xelatex ]  || echo "  • MacTeX (~6 GB download)"
[ -d "/Applications/LyX.app" ]      || echo "  • LyX"
fc-list 2>/dev/null | grep -qi "David CLM" || echo "  • Culmus Hebrew fonts"
echo "  • Noto Hebrew fonts (Sans, Serif, Rashi)"
echo "  • LyX preferences, keybindings & templates"
echo ""
read -rp "Continue? [Y/n] " REPLY
if [[ "$REPLY" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

# ── Step 1: MacTeX ────────────────────────────────────

info "Step 1/6: MacTeX..."
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

info "Step 2/6: LyX..."
if [ -d "/Applications/LyX.app" ]; then
    ok "LyX already installed"
else
    # NOTE: The LyX Homebrew cask is deprecated (Gatekeeper issue, disabled Sept 2026).
    # If this fails in the future, download directly from https://www.lyx.org/Download
    brew install --cask lyx
    if [ -d "/Applications/LyX.app" ]; then
        ok "LyX installed"
        info "First launch: right-click LyX.app > Open to bypass Gatekeeper"
    else
        fail "LyX installation failed. Download manually from https://www.lyx.org/Download"
        exit 1
    fi
fi

# ── Step 3: Culmus Hebrew fonts ──────────────────────

info "Step 3/6: Culmus Hebrew fonts..."
if fc-list 2>/dev/null | grep -qi "David CLM"; then
    ok "Culmus fonts already installed"
else
    CULMUS_TMP=$(mktemp -d)
    info "Downloading Culmus 0.140..."
    curl -#L -o "$CULMUS_TMP/culmus.tar.gz" \
        "https://sourceforge.net/projects/culmus/files/culmus/0.140/culmus-0.140.tar.gz/download"
    tar xzf "$CULMUS_TMP/culmus.tar.gz" -C "$CULMUS_TMP"

    mkdir -p "$HOME/Library/Fonts"
    # Copy all CLM font files (.otf and .ttf) — Culmus 0.140 ships OpenType
    cp "$CULMUS_TMP"/culmus-0.140/*CLM*.otf "$CULMUS_TMP"/culmus-0.140/*CLM*.ttf \
       "$HOME/Library/Fonts/" 2>/dev/null || true
    rm -rf "$CULMUS_TMP"

    FONT_COUNT=$(ls "$HOME"/Library/Fonts/*CLM* 2>/dev/null | wc -l | tr -d ' ')
    ok "Installed $FONT_COUNT Culmus font files"
fi

# ── Step 4: Noto Hebrew fonts ─────────────────────────

info "Step 4/6: Noto Hebrew fonts..."
NOTO_FONTS=(font-noto-sans-hebrew font-noto-serif-hebrew font-noto-rashi-hebrew)
NOTO_MISSING=()
for cask in "${NOTO_FONTS[@]}"; do
    brew list --cask "$cask" &>/dev/null || NOTO_MISSING+=("$cask")
done
if [ ${#NOTO_MISSING[@]} -eq 0 ]; then
    ok "Noto Hebrew fonts already installed"
else
    info "Installing ${NOTO_MISSING[*]}..."
    brew install --cask "${NOTO_MISSING[@]}"
    ok "Noto Hebrew fonts installed (Sans, Serif, Rashi)"
fi

# ── Step 5: LyX preferences + keybindings ────────────

info "Step 5/6: LyX configuration..."
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

# ── Step 6: Hebrew document templates ─────────────────

info "Step 6/6: Hebrew document templates..."

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

% Hyperref — clickable cross-refs & PDF bookmarks for Hebrew
% unicode=false is required for correct Hebrew PDF bookmarks
\usepackage[unicode=false,bookmarks=true,colorlinks=true,
  linkcolor=blue,citecolor=green,urlcolor=magenta]{hyperref}
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
    # NOTE: \use_hyperref is false because hyperref is loaded manually in the
    # preamble with unicode=false (required for correct Hebrew PDF bookmarks).
    # The theorems-ams modules are known to have potential RTL issues with
    # amsthm — if theorem numbering appears reversed, wrap with \L{}.
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

# ── Verification ──────────────────────────────────────

# ── Run LyX Reconfigure ──────────────────────────────

info "Running LyX reconfigure..."
export PATH="/Library/TeX/texbin:$PATH"
if ! command -v python3 &>/dev/null; then
    warn "python3 not found — run Tools > Reconfigure manually in LyX"
elif [ -f "/Applications/LyX.app/Contents/Resources/configure.py" ]; then
    (cd "$LYX_DIR" && python3 /Applications/LyX.app/Contents/Resources/configure.py &>/dev/null) \
        && ok "LyX reconfigured" \
        || warn "LyX reconfigure failed — run Tools > Reconfigure manually in LyX"
else
    warn "LyX configure script not found — run Tools > Reconfigure manually in LyX"
fi

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
fc-list 2>/dev/null | grep -qi "Noto.*Hebrew" && ok "Noto Hebrew: installed" || warn "Noto Hebrew: not found by fc-list"

for f in preferences bind/user.bind templates/defaults.lyx templates/Hebrew_Article.lyx templates/English_Article.lyx; do
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
