---
id: backends
title: Backends
description: The fw command-line tool and framework-py for GitHub Pages and S3
section: features
position: 6
---

## Backend choice

Stata publishes to folders and to Framework Cloud itself. GitHub Pages and S3 need one of two backends:

- **CLI:** the `fw` command-line tool
- **Python:** framework-py in Stata's Python, on Stata 16 or newer

[fw_set](ref:fw_set) chooses the backend. The setting is stored in `stata.conf` in the Framework configuration folder and applies to every project.

| Backend | Behavior |
|---------|----------|
| `auto` | Stata for folders and Cloud. `fw`, then framework-py, for GitHub and S3. The default. |
| `core` | Stata only. GitHub and S3 stop with an error. |
| `cli` | Every publish goes through `fw`. |
| `python` | Every publish goes through framework-py. |

```stata
fw_set backend cli
```

The global `FW_BACKEND` overrides the setting for one session. A chosen backend that is unavailable stops and prints the fix. It never falls back to another.

```stata
global FW_BACKEND python
```

## CLI backend

Install `fw` from the [CLI docs](cli:guide:install). Stata looks for it on the PATH and in the usual install folders. The Stata application on macOS starts with a short PATH, so point to `fw` when it is not found.

```stata
fw_set fw_path "/opt/homebrew/bin/fw"
fw_set fw_path clear
```

## Python backend

Stata needs Python 3.11 or newer with framework-py installed. Find the Python Stata uses:

```stata
python query
```

Install framework-py with that Python:

```sh
/path/from/python/query -m pip install framework-py
```

`fw_setup` prints this command with the exact path. When Stata's Python is older than 3.11, `fw_setup` says so instead. Point Stata at a newer Python first.

### Python builds

Stata needs a Python built with a shared `libpython`. Most installers provide one. Some cluster modules are static and do not work. `uv python install 3.11` gives a shared build.

Point Stata at the interpreter with `python set exec`. A symbolic link, such as uv's `cpython-3.11-linux-x86_64-gnu`, works. Add a virtual environment's packages with `python set userpath`.

```stata
python set exec "/home/me/.local/share/uv/python/cpython-3.11-linux-x86_64-gnu/bin/python3.11"
python set userpath "/home/me/venvs/framework/lib/python3.11/site-packages", prepend
```

Checking Python starts it for the session, and Stata cannot switch Python after that. Use `fw_setup, nopython` to skip the check.

## Results and records

Every backend sets the same stored results. See [Publishing](guide:publishing).

A model records `source.language` `stata` through every backend. A plain file, such as a figure, records `stata` through Stata itself. Through `fw` it records no language, and through framework-py it records `python`. Neither tool has a way to set the language yet.
