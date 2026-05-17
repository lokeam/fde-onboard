#!/usr/bin/env bash
# ============================================================================
# bootstrap.sh — public companion that takes a fresh macOS box from zero to
# the point where the private workstation repo's install.sh can take over.
#
# Usage (one-liner from a fresh shell):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lokeam/fde-onboard/main/bootstrap.sh)"
#
# Order of operations:
#   1. Preflight (macOS 14+, arm64, zsh present) — fail fast on unsupported.
#   2. Trigger Xcode Command Line Tools install if missing.
#   3. Install Homebrew if missing.
#   4. Install gh (GitHub CLI) if missing.
#   5. Run gh auth login interactively (handles 2FA, device flow, scopes).
#   6. gh repo clone lokeam/work-dot-files into $CLONE_DIR.
#   7. exec into the private install.sh.
#
# Error codes (catalog: workstation repo docs/reference/error-catalog.md):
#   FDE-001  non-arm64 architecture
#   FDE-002  non-Darwin OS
#   FDE-017  macOS version below the supported floor
#   FDE-018  zsh not available on PATH
# ============================================================================

set -euo pipefail

REPO="lokeam/work-dot-files"
CLONE_DIR="${FDE_CLONE_DIR:-$HOME/work-dot-files}"
MIN_MACOS_MAJOR=14

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# --- Preflight --------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "[FDE-002] This bootstrap targets macOS. Detected $(uname -s). Run it on a macOS host."
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  die "[FDE-001] This bootstrap targets Apple Silicon (arm64). Detected $(uname -m). Run it on an M-series Mac."
fi

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
if (( macos_major < MIN_MACOS_MAJOR )); then
  die "[FDE-017] This bootstrap targets macOS ${MIN_MACOS_MAJOR}+ (Sonoma). Detected ${macos_version}. Upgrade macOS, then re-run."
fi

if ! command -v zsh >/dev/null 2>&1; then
  die "[FDE-018] zsh not found on PATH. macOS ${MIN_MACOS_MAJOR}+ ships zsh at /bin/zsh — verify the shell is on PATH, then re-run."
fi

# --- Xcode Command Line Tools -----------------------------------------------
# `xcode-select --install` opens a GUI dialog and returns immediately; the
# install runs in the background. We exit so the user can complete it and
# re-run the bootstrap once the toolchain is ready.
if ! xcode-select -p >/dev/null 2>&1; then
  log "Triggering Xcode Command Line Tools install (a macOS dialog will appear)…"
  xcode-select --install || true
  warn "Re-run this bootstrap once the Xcode CLT install finishes."
  exit 0
fi

# --- Homebrew ---------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew…"
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- gh (GitHub CLI) --------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  log "Installing gh…"
  brew install gh
fi

# --- gh auth (interactive) --------------------------------------------------
# gh auth login walks the engineer through device-flow auth and stores the
# token in the system keychain. Subsequent `gh repo clone` calls use that
# token transparently over HTTPS, so no ssh-key setup is required up front.
if ! gh auth status >/dev/null 2>&1; then
  log "Running gh auth login…"
  gh auth login
fi

# --- Clone private workstation repo ------------------------------------------
if [[ ! -d "$CLONE_DIR/.git" ]]; then
  log "Cloning ${REPO} into ${CLONE_DIR}…"
  gh repo clone "$REPO" "$CLONE_DIR"
else
  log "${CLONE_DIR} already a git repo; skipping clone."
fi

# --- Hand off to private install.sh ------------------------------------------
cd "$CLONE_DIR"
log "Handing off to ./install.sh in ${CLONE_DIR}…"
exec ./install.sh
