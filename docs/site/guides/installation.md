---
id: installation
title: Installation
description: System requirements, package installation, and environment checks
section: getting_started
position: 1
---

## Requirements

- Stata 14 or newer.
- `curl` for Framework Cloud. It ships with macOS, Linux, and Windows 10 or later.

Stata handles project discovery, cataloged datasets, SHA-256 checksums, folder publishing, Cloud publishing, and Cloud login natively. Python is unnecessary for core commands.

Optional backends add GitHub Pages and S3 publishing. See [Backends](guide:backends).

## Package installation

Install the package from GitHub with `net install`:

```stata
net install framework, from("https://raw.githubusercontent.com/frameworktools/framework-stata/main") replace
```

To install from a local repository clone, pass the directory path to `from()`:

```stata
net install framework, from("/path/to/framework-stata") replace
```

Run the same command to upgrade. The `replace` option overwrites installed package files.

## Setup check

```stata
fw_setup
```

[fw_setup](ref:fw_setup) checks the Stata version, active project, `curl`, SHA-256 utility, system keyring, Cloud connection, `fw` binary, and Stata's Python configuration. It prints setup instructions for any missing component.

Probing Python initializes Stata's Python environment for the remainder of the session, preventing subsequent `python set exec` changes. Pass `nopython` to skip the Python check:

```stata
fw_setup, nopython
```

## Help files

Every command includes a Stata help file:

```stata
help framework
help fw_scaffold
help fw_publish
```
