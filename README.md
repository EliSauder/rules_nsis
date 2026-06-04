# NSIS Rules for Bazel

## Overview

Aims to support creating a NSIS installer through bazel; inspired by CPack.

### Features

[x] NSIS Toolchain for cross-platform use
[x] Define installer attributes (version, product, etc.).
[x] Support Components and Component Groups.
[x] Install windows Services (uses `sc.exe`).
[x] Dependency Based Selections (option exits but does nothing)
[ ] StartMenu Entries \[Help Wanted]
[ ] Desktop Shortcuts \[Help Wanted]
[ ] Update Path \[Help Wanted]
[ ] Set Environment Variables \[Help Wanted]
