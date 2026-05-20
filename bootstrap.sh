#!/usr/bin/env bash
# bootstrap.sh — public companion: macOS preflight → Homebrew → gh → clone
# → exec into the private install.sh.
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lokeam/fde-onboard/main/bootstrap.sh)" [-- --verbose]
# Output mirrors the private repo's scripts/lib/output.sh (inlined here so
# the bootstrap stays self-contained — it runs before the repo exists).
# Underlying tool output is suppressed unless --verbose; cause/fix prose is
# printed inline on every FDE failure so the catalog isn't required reading.
# FDE codes: 001 non-arm64, 002 non-Darwin, 017 macOS<14, 018 no zsh, 902 tool exit
set -euo pipefail

REPO="lokeam/fde-workstation"
CLONE_DIR="${FDE_CLONE_DIR:-$HOME/fde-workstation}"
MIN_MACOS_MAJOR=14
# Accept either --verbose flag (needs `bash -c "..." -- --verbose`) or VERBOSE=1 env var.
VERBOSE="${VERBOSE:-0}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=1 ;;
    -h|--help) printf 'Usage: VERBOSE=1 bootstrap.sh    OR    bootstrap.sh [-- --verbose]\n'; exit 0 ;;
    *) printf 'unknown flag: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

if { [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; } || [[ -n "${FORCE_COLOR:-}" ]]; then  # color: TTY + TERM + NO_COLOR; FORCE_COLOR overrides
  G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'; C=$'\033[1;36m'; BL=$'\033[1;34m'; BD=$'\033[1m'; D=$'\033[2m'; GR=$'\033[90m'; X=$'\033[0m'
else
  G=""; R=""; Y=""; C=""; BL=""; BD=""; D=""; GR=""; X=""
fi
N=0; T=5
# step "<label>" ["<emoji>"]  — bracketed counter in gray; optional emoji
# between the prefix and the label. Keeps the visual anchor on the label.
step() { N=$((N+1)); printf '%s[%d/%d]%s %s%s... ' "$GR" "$N" "$T" "$X" "${2:+$2 }" "$1"; }
pass() { printf '%s\xe2\x9c\x93 done%s\n' "$G" "$X"; }
skip() { printf '%s\xe2\x9a\xa0 skipped%s (%s)\n' "$Y" "$X" "$1"; }
die() {
  printf '%s\xe2\x9c\x97 FAILED%s (%s)\n    %sCause:%s %s\n    %sFix:%s   %s\n    See docs/reference/error-catalog.md.\n' \
    "$R" "$X" "$1" "$C" "$X" "$2" "$BL" "$X" "$3"
  exit 1
}
run() {
  local tmp rc=0; tmp="$(mktemp -t fde-boot.XXXXXX)"
  if (( VERBOSE )); then "$@" 2>&1 | tee -a "$tmp"; rc="${PIPESTATUS[0]}"
  else "$@" >"$tmp" 2>&1 || rc=$?; fi
  if (( rc != 0 )) && (( ! VERBOSE )); then
    printf '\n%s--- captured output (last 40 lines) ---%s\n' "$D" "$X"; tail -n 40 "$tmp"
  fi
  rm -f "$tmp"; return "$rc"
}

# Brand banner — single-quoted printf preserves the art verbatim. Uses printf
# (bash builtin) instead of `cat <<EOF` so the bootstrap doesn't depend on
# /bin/cat being on PATH. Bold cyan on TTY, plain otherwise (color helpers
# handle that already).
printf '%s' "$BD$C"
printf '%s' '

            .##
         #####                                    #   #.+
      #####   -###-                              #### ###
     ###   #####    ##       .##                      ###
     ##  ####    #####     #########  #######    ###  ###    ######     ######
     ##  ##  #####++##       -##  .  ###   ####  ###  ###  ###.  +###  ###  #
     ##  ## ##++++++##        ##    ##+      ### ###  ### ###      ### ###
     ##  ## ##++++++##       -##    ##       ### ###  ### ###      ### ###
      .  ## ##+++++###       ###    ###.    #### ###  ### ####    ###  ###
        .## ##++####          ###### ####### ### ###  ###   ########   ###
            #####
             +

'
printf '%s\n' "$X"

# Welcome text — plain (no color); the banner above is the visual accent.
printf '%s\n' \
'Welcome to the Tailor FDE workstation setup.' \
'' \
'This takes ~15-25 minutes to bring a fresh Mac to a working dev environment.' \
'' \
'What gets installed:' \
'  • Homebrew + the GitHub CLI' \
'  • Brewfile packages: bat, ripgrep, fzf, VS Code, Claude Code, Tailscale' \
'  • Pinned versions of Oh My Zsh, powerlevel10k, and nvm' \
'  • Symlinks for ~/.zshrc, ~/.zprofile, ~/.zsh_aliases' \
'' \
"You'll be prompted once for sudo and once for GitHub login." \
'Recovery from any broken state: dotfix.' \
''

step "Verifying preflight (macOS 14+, arm64, zsh on PATH)" "🔍"
[[ "$(uname -s)" != "Darwin" ]] && die "FDE-002" "This bootstrap targets macOS; detected $(uname -s)." "Run on a macOS host."
[[ "$(uname -m)" != "arm64" ]] && die "FDE-001" "This bootstrap targets Apple Silicon (arm64); detected $(uname -m)." "Run on an M-series Mac."
mv="$(sw_vers -productVersion)"
(( ${mv%%.*} < MIN_MACOS_MAJOR )) && die "FDE-017" "Detected macOS $mv; this bootstrap targets ${MIN_MACOS_MAJOR}+ (Sonoma)." "Upgrade via System Settings → General → Software Update, then re-run."
command -v zsh >/dev/null 2>&1 || die "FDE-018" "zsh not found on PATH; macOS ${MIN_MACOS_MAJOR}+ ships /bin/zsh." "Verify /bin is on \$PATH (echo \"\$PATH\") or run from a regular Terminal."
pass

step "Triggering Xcode Command Line Tools install" "🔨"
if xcode-select -p >/dev/null 2>&1; then skip "already installed"
else
  skip "GUI dialog will appear — re-run this bootstrap once the install completes"
  xcode-select --install || true; exit 0
fi

step "Installing Homebrew" "☕"
if command -v brew >/dev/null 2>&1; then skip "already installed"
else
  # Prime sudo cache OUTSIDE run() so the password prompt is visible; set
  # NONINTERACTIVE=1 so the installer skips its "Press RETURN" gate. Both
  # required, otherwise run()'s output capture hides interactive prompts.
  printf '\n  %s(brew install needs sudo; you may be prompted for your password)%s\n' "$D" "$X"
  sudo -v || die "FDE-902" "Could not validate sudo access for the Homebrew installer." \
    "Run 'sudo -v' manually, enter your password, then re-run this bootstrap."
  NONINTERACTIVE=1 run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "FDE-902" "Homebrew installer exited non-zero." "Re-run with VERBOSE=1 to stream the installer output."
  pass
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

step "Installing gh (GitHub CLI)" "🐙"
if command -v gh >/dev/null 2>&1; then skip "already installed"
else
  run brew install gh || die "FDE-902" "brew install gh exited non-zero." "Re-run with --verbose to stream brew's output."
  pass
fi

# gh auth login is interactive (device flow + 2FA); do NOT wrap in run().
step "Authenticating with GitHub + cloning private workstation repo" "🔐"
gh auth status >/dev/null 2>&1 || gh auth login
if [[ ! -d "$CLONE_DIR/.git" ]]; then
  run gh repo clone "$REPO" "$CLONE_DIR" || die "FDE-902" \
    "gh repo clone $REPO into $CLONE_DIR failed." \
    "Confirm your gh auth has access to the repo and re-run with --verbose for details."
fi
pass

cd "$CLONE_DIR"
printf '\n%sHanding off to ./install.sh%s\n\n' "$BD" "$X"
exec ./install.sh
