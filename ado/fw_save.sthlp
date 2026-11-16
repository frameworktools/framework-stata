{smcl}
{* *! version 0.3.1  16nov2026}{...}
{title:Title}

{phang}
{bf:fw_save} {hline 2} Save a named dataset and record its integrity


{title:Syntax}

{p 8 16 2}
{cmd:fw_save} {it:name} [{cmd:,} {opt replace} {opt lock} {opt unlock} {opt out:side} {opt opt:ions(string)}]


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

{pstd}
{cmd:fw_save} to a plain file path, such as {cmd:outputs/tables/summary.csv},
records the file's checksum under its path from the project root, as R's
{bf:data_save()} does. {helpb fw_use} does not check plain paths, as R's
{bf:data_read()} does not.

{pstd}
Saved data is unlocked unless you add {opt lock}, as in R's and Python's
{bf:data_save()}. A do-file can then save it again.

{pstd}
{cmd:fw_save} does not change locked data, as R's and Python's
{bf:data_save()} do not: {helpb fw_use} stops when a locked file changed.
Locked data is the file of a catalog entry with {bf:locked: true}, whether you
give its name or its path, or a dataset {cmd:fw_save} saved with {opt lock}.
Saving the same data again works and keeps the lock; new data stops with
error 608 and leaves the file as it was. Save the result under another name,
or add {opt unlock} to replace the file. Setting {bf:locked: false} for a
catalog entry unlocks it.

{pstd}
The same data means the same {cmd:datasignature} as the dataset's integrity
record, with the file still matching the record's SHA-256. A {cmd:.dta} file
stores its save time, so the file bytes cannot tell. Without a record or a
SHA-256 tool, a locked catalog entry needs {opt unlock}.

{pstd}
{cmd:fw_save} also stops for a file outside the project folder, such as one in
a folder that a {bf:settings.do} global puts above the project, unless you add
{opt outside}.


{title:Options}

{phang}
{opt replace} overwrites an existing file.

{phang}
{opt lock} locks the dataset. {cmd:fw_use} then stops when the file differs
from its record, and a later save of new data needs {opt unlock}. Without
{opt lock}, {cmd:fw_use} warns and updates the record, and later saves replace
the file.

{phang}
{opt unlock} replaces locked data. The new file is unlocked unless you also add
{opt lock}.

{phang}
{opt outside} allows a file outside the project folder. Locked data still
needs {opt unlock}.

{phang}
{opt options(string)} passes options to {cmd:save}, {cmd:export delimited}, or
{cmd:export excel}.

{phang}
{opt unlocked} is deprecated and does nothing. Saves are unlocked unless you
add {opt lock}. Do-files that still give it keep working.


{title:Example}

{phang2}{cmd:. fw_save inputs.intermediate.clean, replace}{p_end}
{phang2}{cmd:. fw_save inputs.final.analysis, replace lock}{p_end}
{phang2}{cmd:. fw_save "outputs/tables/summary.csv", replace}{p_end}
{phang2}{cmd:. fw_save inputs.final.analysis, replace unlock lock}{p_end}


{title:Stored results}

{pstd}
The same as {helpb fw_use}, and:

{p2colset 8 24 26 2}{...}
{p2col:{cmd:r(record)}}the name of the record: the dataset name, or the path
from the project root for a plain file path{p_end}
{p2colreset}{...}
