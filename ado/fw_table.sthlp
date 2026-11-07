{smcl}
{* *! version 0.1.1  07nov2026}{...}
{title:Title}

{phang}
{bf:fw_table} {hline 2} Save a table to the project's tables folder


{title:Syntax}

{p 8 16 2}
{cmd:fw_table} {it:name} [{varlist}] [{it:if}] [{it:in}] [{cmd:,} {it:options}]

{p 8 16 2}
{cmd:fw_table} {it:name}{cmd:,} {opt mat:rix(matname)} [{it:options}]

{synoptset 24}{...}
{synopthdr}
{synoptline}
{synopt:{opt mat:rix(matname)}}save a matrix rather than the data in memory{p_end}
{synopt:{opt head:ers(strings)}}the column headers, one per column{p_end}
{synopt:{opt varn:ames}}use variable names, not labels, as headers{p_end}
{synopt:{opt for:mat(csv xlsx)}}the file types; the default is {cmd:csv}{p_end}
{synopt:{opt pub:lic}}save to the public tables folder of a sensitive project{p_end}
{synopt:{opt nolab:el}}write value codes, not value labels{p_end}
{synopt:{opt na(string)}}the text for missing numbers in CSV; the default is {cmd:NA}{p_end}
{synopt:{opt norep:lace}}stop when the file exists{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:fw_table} saves the data in memory, or a matrix, as a table in the
project's tables folder, as {bf:save_table()} does in R and Python. Headers
are free text, such as {bf:All patients, n (%)}: each variable's label, or the
words of {opt headers()}. The data in memory are not changed.

{pstd}
{it:name} names the file without its extension. It may hold subfolders, such as
{cmd:meeting/table-1}, which {cmd:fw_table} creates. A name that ends in
{bf:.csv} or {bf:.xlsx} picks that format.

{pstd}
The folder is the project's {bf:outputs_tables} folder, else
{bf:outputs/tables}. A project with {bf:security: sensitive: true}, or with
{bf:outputs_private_tables} or {bf:outputs_public_tables} folders, keeps private
and public tables apart: tables go to the private folder unless you add
{opt public}. A public table made from data in a file with "private" in its
path gets a warning.

{pstd}
Each file is recorded in {bf:.framework/stata-results.tsv} by its path from the
project root, with its type, whether it is public, its SHA-256 checksum, and
the time. R and Python record the same fields in {bf:framework.db}, which Stata
cannot read.

{pstd}
CSV files follow R's {bf:write_csv()}: missing numbers are {bf:NA}, numbers
have the fewest digits that read back as the same value, value labels are
written as text, dates as {bf:2026-11-07}, and fields are quoted only when
needed. Excel files are written with {cmd:export excel}; their headers hold at
most 80 characters.

{pstd}
A matrix is written with its column names as headers. Row names that are not
Stata's defaults ({bf:r1}, {bf:r2}, ...) become a first column with an empty
header. {opt headers()} then names that column too.


{title:Options}

{phang}
{opt matrix(matname)} saves a Stata matrix, such as {cmd:r(table)} copied to a
matrix, or one built with {cmd:matrix}. It cannot go with a varlist, {it:if},
or {it:in}.

{phang}
{opt headers(strings)} gives one header for each column, in order. Quote
headers with spaces: {cmd:headers("Group" "95% CI")}.

{phang}
{opt varnames} uses variable names as headers, even for labeled variables.

{phang}
{opt format(csv xlsx)} picks the file types. {cmd:format(csv xlsx)} writes
both.

{phang}
{opt public} saves to the public tables folder of a project that splits
private and public outputs. Other projects have one tables folder.

{phang}
{opt nolabel} writes the codes of labeled variables rather than their labels.

{phang}
{opt na(string)} sets the text for missing numbers in CSV files. {cmd:na("")}
leaves the cells empty.

{phang}
{opt noreplace} stops with error 602 when the file exists. By default
{cmd:fw_table} overwrites it, as {bf:save_table()} does.


{title:Examples}

{phang2}{cmd:. fw_table summary}{p_end}
{phang2}{cmd:. fw_table "meeting/table-1" group n pct, headers("Group" "Patients" "Share, %") format(csv xlsx)}{p_end}
{phang2}{cmd:. tabstat price mpg, by(foreign) save}{p_end}
{phang2}{cmd:. matrix S = r(StatTotal)}{p_end}
{phang2}{cmd:. fw_table totals, matrix(S) public}{p_end}


{title:Stored results}

{p2colset 8 22 24 2}{...}
{p2col:{cmd:r(path)}}the first file{p_end}
{p2col:{cmd:r(paths)}}every file{p_end}
{p2col:{cmd:r(sha256)}}the first file's checksum{p_end}
{p2col:{cmd:r(format)}}the formats written{p_end}
{p2col:{cmd:r(public)}}1 with {opt public}{p_end}
{p2col:{cmd:r(N)}}the rows written{p_end}
{p2col:{cmd:r(k)}}the columns written{p_end}
{p2colreset}{...}


{title:Also see}

{pstd}
{helpb fw_graph}, {helpb fw_publish}, {helpb fw_save}
