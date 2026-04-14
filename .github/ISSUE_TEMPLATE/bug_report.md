---
name: Bug report
about: Something broken, misbehaving, or failing on install / dispatch
title: "[bug] "
labels: bug
---

## What happened

<!-- A clear and concise description of the bug. What did you expect to happen vs what actually happened? -->

## Environment

Please run `./scripts/doctor.sh` and paste the full output here:

```
<paste doctor.sh output>
```

If doctor.sh didn't flag the issue, also include:

- OS: <macOS / Linux distro / Windows + (git-bash | WSL | PowerShell)>
- Claude Code version: <from `claude --version` or About dialog>
- Codex CLI version: <from `codex --version`>
- Shell: <bash / zsh / powershell version>

## Reproduction

Steps to reproduce:

1. <step 1>
2. <step 2>
3. <step 3>

The prompt you gave Claude (if this was a dispatch bug):

```
<the prompt verbatim>
```

Any Codex stderr log (if applicable — see the skill's logging section):

```
<paste stderr log>
```

## What you expected

<!-- What you thought would happen -->

## Anything else

<!-- Workarounds you tried, suspected cause, related issues, etc. -->
