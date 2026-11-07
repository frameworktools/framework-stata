{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:fw_use} {hline 2} Load a named dataset and check its integrity


{title:Syntax}

{p 8 16 2}
{cmd:fw_use} {it:name} [{cmd:,} {opt clear} {opt check(strict|warn|off|accept)} {opt opt:ions(string)}]


{title:Description}

{pstd}
{cmd:fw_use} loads a dataset by name. A {it:name} is resolved in this order:

{phang2}1. A file path, such as {cmd:inputs/raw/survey.csv}. A relative path is
tried from the current folder, then from the project root.{p_end}
{phang2}2. An entry in the project's data catalog, such as {cmd:inputs.raw.survey}.{p_end}
{phang2}3. Dot notation: the longest leading part that names a project folder
picks the folder, and the rest names the file. {cmd:inputs.final.analysis}
is {cmd:$fw_inputs_final/analysis.dta}.{p_end}

{pstd}
The extension picks the reader: {bf:.dta} uses {cmd:use}, {bf:.csv} and
{bf:.tsv} use {cmd:import delimited}, and {bf:.xlsx} and {bf:.xls} use
{cmd:import excel, firstrow}.


{title:Integrity checks}

{pstd}
Before loading, {cmd:fw_use} computes the file's SHA-256 checksum and compares
it with the record from the last {cmd:fw_save} or {cmd:fw_use}. After loading,
it compares Stata's {cmd:datasignature}. A dataset that changed:

{phang2}o  stops with error 459 when it is locked;{p_end}
{phang2}o  loads with a warning when it is unlocked.{p_end}

{pstd}
To accept a change to a locked dataset, load it with {cmd:check(accept)}. It
records the new checksum and data signature and keeps the lock. The file is
not rewritten. {cmd:check(warn)} loads it once and keeps the old record.

{pstd}
The checksum covers the whole file, as in R and Python. A {bf:.dta} file holds
the time it was saved, so saving the same data again with plain {cmd:save}
changes the checksum, and a locked dataset then stops with error 459. Save
with {helpb fw_save}, which records the new file, or accept the change with
{cmd:check(accept)}.

{pstd}
The first read of a name records it. Reads of unlocked datasets update the
record, as in R and Python. Records live in {bf:.framework/stata-integrity.tsv}.

{pstd}
SHA-256 comes from {bf:sha256sum} or {bf:shasum} on Linux and macOS and from
PowerShell on Windows. Without one, only {cmd:datasignature} is checked. It
covers values and variable names, not labels or notes.


{title:Options}

{phang}
{opt clear} replaces the data in memory.

{phang}
{opt check(strict|warn|off|accept)} sets the integrity check. {bf:strict} is
the default. {bf:warn} loads a changed locked dataset with a warning and keeps
the old record. {bf:off} skips the check and the record. {bf:accept} loads the
dataset and records it as it is now: the new SHA-256, the new data signature,
and the time. The lock stays as it was, and the file is not rewritten. With
the integrity ledger on, it sends the new checksum, as {cmd:fw_save} does.
{bf:accept} needs a catalog or dot name.

{phang}
{opt options(string)} passes options to {cmd:use}, {cmd:import delimited}, or
{cmd:import excel}.


{title:Example}

{phang2}{cmd:. fw_use inputs.raw.survey, clear}{p_end}
{phang2}{cmd:. fw_use "inputs/raw/visits.csv", clear options(varnames(1))}{p_end}
{phang2}{cmd:. fw_use inputs.raw.survey, clear check(accept)}{p_end}


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(name)}}the dataset name{p_end}
{p2col:{cmd:r(path)}}the file{p_end}
{p2col:{cmd:r(type)}}dta, csv, tsv, xlsx, or xls{p_end}
{p2col:{cmd:r(sha256)}}the file checksum, when available{p_end}
{p2col:{cmd:r(datasignature)}}the data signature{p_end}
{p2col:{cmd:r(locked)}}1 when the dataset is locked{p_end}
{p2col:{cmd:r(accepted)}}1 when {cmd:check(accept)} recorded the dataset again{p_end}
{p2colreset}{...}
