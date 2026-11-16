---
id: backends
title: Backends
description: CLI and Python backends for GitHub Pages and S3 publishing
section: features
position: 6
---

## Backend selection

Stata handles local folder bundles and Framework Cloud uploads natively. Publishing to GitHub Pages or S3 uses one of two external backends:

- **CLI:** the `fw` command-line binary
- **Python:** `framework-py` running inside Stata's embedded Python (Stata 16 or newer)

[fw_set](ref:fw_set) saves your preferred backend in `stata.conf` inside the Framework configuration directory for all projects on the computer.

| Backend | Behavior |
|---|---|
| `auto` | Native Stata for `folder` and `cloud`; tries `fw`, then `framework-py`, for `github` and `s3` (default) |
| `core` | Native Stata only; `github` and `s3` stop with an error |
| `cli` | Routes every publish call through `fw` |
| `python` | Routes every publish call through `framework-py` |

```stata
fw_set backend cli
```

Define `global FW_BACKEND` to override the saved setting for the current Stata session. If an explicitly selected backend is unavailable, Stata stops with setup instructions and never falls back to another backend.

```stata
global FW_BACKEND python
```

## CLI backend

Install `fw` following the [CLI installation guide](cli:guide:install). Stata searches `PATH` and standard system locations. Because the macOS Stata app launches with a minimal `PATH`, configure `fw_path` when `fw` is installed in a custom directory:

```stata
fw_set fw_path "/opt/homebrew/bin/fw"
fw_set fw_path clear
```

## Python backend

The Python backend requires Stata 16 or newer and Python 3.11 or newer with `framework-py` installed. Inspect Stata's active Python executable:

```stata
python query
```

Install `framework-py` with that interpreter:

```sh
/path/from/python/query -m pip install framework-py
```

`fw_setup` prints the exact `pip` command for Stata's configured Python, or warns if the interpreter is older than Python 3.11.

### Shared Python builds

Stata's Python integration requires a dynamically linked `libpython`. Standard macOS, Windows, and Linux distribution packages include one, whereas some HPC cluster modules compile Python statically. Run `uv python install 3.11` to obtain a compatible shared build on Linux clusters.

Point Stata at the interpreter with `python set exec` and prepend any virtual environment's `site-packages` with `python set userpath`:

```stata
python set exec "/home/me/.local/share/uv/python/cpython-3.11-linux-x86_64-gnu/bin/python3.11"
python set userpath "/home/me/venvs/framework/lib/python3.11/site-packages", prepend
```

Running `fw_setup` initializes Python for the current Stata session, locking `python set exec` until Stata restarts. Pass `fw_setup, nopython` when you need to avoid starting Python.

## Return values and metadata

All three backends populate the same `r()` return macros and scalars. See [Publishing](guide:publishing).

Model artifacts (`fw_publish, estimates`) record `source.language` as `"stata"` across every backend. File artifacts record `"stata"` through the native `core` backend, omit `source.language` through `cli`, and record `"python"` through `python`.
