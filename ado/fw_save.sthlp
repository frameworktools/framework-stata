{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:fw_save} {hline 2} Save a named dataset and record its integrity


{title:Syntax}

{p 8 16 2}
{cmd:fw_save} {it:name} [{cmd:,} {opt replace} {opt unlocked} {opt opt:ions(string)}]


{title:Description}

{pstd}
{cmd:fw_save} saves the data in memory under a name, then records the file's
SHA-256 checksum and Stata's {cmd:datasignature}. Names resolve as in
{helpb fw_use}. {cmd:fw_save inputs.final.analysis} writes
{cmd:$fw_inputs_final/analysis.dta} and creates the folder when needed.

{pstd}
When the project's integrity ledger is on, {cmd:fw_save} also sends the
checksum, the file size, and this computer's name to Framework Cloud. The data
itself is never uploaded. Turn the ledger on with {bf:options: cloud_ledger: live}
in the project settings, and off with the environment variable {bf:FW_LEDGER=off}.

{pstd}
{cmd:fw_save} does not edit the YAML data catalog. R and Python find the
dataset by its path.


{title:Options}

{phang}
{opt replace} overwrites an existing file.

{phang}
{opt unlocked} lets the dataset change. {cmd:fw_use} then warns rather than
stops when the file differs from its record.

{phang}
{opt options(string)} passes options to {cmd:save}, {cmd:export delimited}, or
{cmd:export excel}.


{title:Example}

{phang2}{cmd:. fw_save inputs.final.analysis, replace}{p_end}
{phang2}{cmd:. fw_save "outputs/tables/summary.csv", replace}{p_end}


{title:Stored results}

{pstd}
The same as {helpb fw_use}.
