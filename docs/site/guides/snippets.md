---
id: snippets
title: Code snippets
description: Commands and their printed output from a do-file, published for embedding
section: features
position: 5
---

## Recording a snippet

A code snippet is a `code_snippet` artifact that holds a few commands and the text Stata printed under them. Blog posts and reports embed snippets through framework-embed, so the code appears beside the results it produced. [fw_snippet](ref:fw_snippet) records a snippet from a do-file:

```stata
sysuse auto, clear
fw_snippet begin fit-ols
regress price mpg i.foreign
fw_snippet end, unfolded visibility(public)
```

`fw_snippet begin` opens an SMCL log named `fw_snippet` alongside any log of your own. `fw_snippet end` closes it, builds `code_snippet.json`, and publishes it through [fw_publish](ref:fw_publish) with the label as the slug. Publishing uses the same destinations and backends as `fw_publish` and needs no Python.

## Code and output blocks

Stata echoes each command above its output, and the snippet follows that echo:

- Each command becomes a code block without its `.` prompt. Lines continued with `///` stay with their command, and loop bodies lose their line numbers.
- The SMCL between two commands becomes an output block, sent unchanged.
- Commands that print nothing share one code block with the commands after them.
- The `fw_snippet end` line is excluded.

Framework Cloud renders the SMCL with Stata's column layout, box characters, and result styles, so a regression table stays aligned. Output that starts with an `{err}` message becomes an error block. Cloud also applies the snippet limits: at most 200 blocks and 400 lines of code, with long output cut at 500 lines. The client sends the full output.

Graphs never enter a snippet. A `graph` command stays in the code, and its window is not recorded.

Stata echoes only commands it runs visibly. Commands run with `quietly do` or `run` do not appear, and a `quietly {` block appears as its first line.

## Folding and output

Without options, Cloud folds an output block longer than 12 lines. `folded` folds every output block, and `unfolded` opens every one. `nooutput` publishes the code alone. A reader can also hide output with `?output=none` on the snippet's link.

## Source

The snippet records where its code came from:

| Field | Value |
|---|---|
| `source.file` | Do-file path relative to the project root |
| `source.lines` | Lines between `fw_snippet begin` and `fw_snippet end` |
| `source.commit` | Git `HEAD` of the project, when it is a repository |
| `source.repository` | GitHub repository, only when set |

Stata does not expose the running do-file, so `fw_snippet end` searches the project's do-files for `fw_snippet begin` with the label. When several do-files match, the file is omitted. Name it with `file()`.

The repository comes from `repository()` or from the project settings:

```yaml
default:
  publish:
    repository: https://github.com/owner/analysis
```

With the repository, a 40-character commit, the file, and the lines, Cloud links the line range to GitHub.

## Versions

Each render of a do-file publishes its snippets again. When nothing changed, Cloud adds no version and returns the current one. `fw_snippet end` reports "Unchanged, still version 3" and sets `r(unchanged)` to 1. A post that embeds a numbered version keeps that code and output after the do-file changes.

## Errors and recovery

Snippets do not nest. `fw_snippet begin` with a snippet open stops with error 198, and the open snippet keeps recording. When a do-file stops with an error inside a snippet, the log stays open. The next `fw_snippet begin` closes it and starts the new snippet. `log close fw_snippet` discards an open snippet.

`fw_snippet end` checks its options before it closes the log, so a mistyped option leaves the snippet open. When publishing fails, the snippet JSON stays in a temporary folder, and the error prints the `fw_publish` command that retries it.
