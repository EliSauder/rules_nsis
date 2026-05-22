# NSIS Rules for Bazel

## Overview

Aims to support creating a NSIS installer through bazel; inspired by CPack.

## Features

- Setup NSIS toolchains for cross-platform use.
- Define basic installer attributes (Version, Product, etc.).
- Recursively define Components and Component Groups.
- Install Windows Services using `sc.exe`

### ToDo

[ ] StartMenu Entries
[ ] Desktop Shortcuts
[ ] Dependency Based Selections (option exits but does nothing)
[ ] Update Path \[Help Wanted]
[ ] Set Environment Variables \[Help Wanted]
