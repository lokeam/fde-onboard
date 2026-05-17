---
title: fde-onboard
last_updated: 2026-05-17
owner: lokeam
status: draft
---

# fde-onboard

Public companion to the Tailor FDE workstation setup. The only thing here is
[`bootstrap.sh`](./bootstrap.sh) — a short, auditable shell script that takes
a fresh Apple Silicon Mac from zero to the point where the private
[workstation repo](https://github.com/lokeam/work-dot-files) can take over.

## One-line install

From a fresh macOS 14+ shell:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lokeam/fde-onboard/main/bootstrap.sh)"
```

The script does this in order:

1. Preflights macOS 14+, Apple Silicon (arm64), and a usable zsh.
2. Triggers the Xcode Command Line Tools install if missing.
3. Installs Homebrew.
4. Installs the GitHub CLI (`gh`).
5. Runs `gh auth login` interactively.
6. Clones `lokeam/work-dot-files` into `~/work-dot-files`.
7. Hands off to that repo's `./install.sh`.

Re-running is safe: every step short-circuits when its work is already done.

## What it does not do

- It does not configure anything. All workstation policy lives in the private
  install.sh. This script is the smallest possible step from a fresh macOS
  shell to a checked-out copy of that repo.
- It does not pin Homebrew or `gh`. Both are bootstrap dependencies — the
  pinning policy that matters (Oh My Zsh / powerlevel10k / nvm) is enforced
  inside the private repo via `versions.env`.

## Preflight error codes

| Code | Meaning |
|---|---|
| `FDE-001` | non-arm64 architecture |
| `FDE-002` | non-Darwin OS |
| `FDE-017` | macOS version below the supported floor (14, Sonoma) |
| `FDE-018` | zsh not available on PATH |

The authoritative catalog with cause + fix per code lives in the private repo
at `docs/reference/error-catalog.md`.

## License

[MIT](./LICENSE).
