---
id: installation
title: Installation
description: Requirements, package installation, and setup check
section: getting_started
position: 1
---

## Requirements

- Stata 14 or newer.
- curl, for Framework Cloud. It ships with macOS, Linux, and Windows 10 or later.

Stata handles projects, named datasets, checksums, folder publishing, Cloud publishing, and Cloud login itself. Python is not needed.

Two optional backends add GitHub Pages and S3 publishing. See [Backends](guide:backends).

## Package installation

Install from GitHub with `net install`.

```stata
net install framework, from("https://raw.githubusercontent.com/frameworktools/framework-stata/main") replace
```

To install from a local copy of the repository, point `from()` at its folder.

```stata
net install framework, from("/path/to/framework-stata") replace
```

Run the same command again to update. `replace` overwrites the installed files.

## Setup check

```stata
fw_setup
```

[fw_setup](ref:fw_setup) checks the Stata version, the project, curl, the SHA-256 tool, the system keyring, the Cloud connection, `fw`, and Stata's Python. It prints the exact next step for anything missing.

Checking Python starts Stata's Python for the session, and Stata cannot switch Python after that. Skip that check with `nopython`.

```stata
fw_setup, nopython
```

## Help files

Every command has a help file.

```stata
help framework
help fw_publish
```
