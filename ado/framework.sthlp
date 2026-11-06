{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:framework} {hline 2} Framework for Stata: project paths, named datasets, publishing, and Framework Cloud


{title:Commands}

{synoptset 16}{...}
{synopt:{helpb fw_setup}}check Stata, system tools, backends, and the Cloud connection{p_end}
{synopt:{helpb fw_project}}find the project and set path globals{p_end}
{synopt:{helpb fw_use}}load a named dataset and check its integrity{p_end}
{synopt:{helpb fw_save}}save a named dataset and record its integrity{p_end}
{synopt:{helpb fw_publish}}publish a figure, table, document, or estimation results{p_end}
{synopt:{helpb fw_login}}connect this computer to Framework Cloud{p_end}
{synopt:{helpb fw_logout}}remove this computer's Cloud token{p_end}
{synopt:{helpb fw_set}}set the backend and the location of fw{p_end}


{title:Description}

{pstd}
Framework gives a research project a standard layout, records which data an
analysis used, and publishes results. The R and Python packages and the
{bf:fw} command-line tool share the same project settings, data catalog, and
publishing destinations. Framework for Stata reads and writes them too.

{pstd}
Stata itself handles projects, datasets, SHA-256 checksums, publishing to a
folder or to Framework Cloud, and Cloud login. Python is not needed. Two
optional backends add publishing to GitHub Pages and S3:

{p2colset 8 24 26 2}{...}
{p2col:{bf:CLI}}the {bf:fw} command-line tool{p_end}
{p2col:{bf:Python}}framework-py in Stata's Python (Stata 16 or newer){p_end}
{p2colreset}{...}

{pstd}
Run {helpb fw_setup} after installing. It lists what works and the exact steps
for anything missing.


{title:Example}

{phang2}{cmd:. fw_project}{p_end}
{phang2}{cmd:. fw_use inputs.raw.survey, clear}{p_end}
{phang2}{cmd:. regress outcome treatment age}{p_end}
{phang2}{cmd:. fw_publish, estimates title("Treatment effect")}{p_end}

{pstd}
The {bf:examples} folder of the package has runnable do-files that use
{cmd:sysuse auto} and a temporary project.


{title:Requirements}

{pstd}
Stata 14 or newer. {bf:curl} for Framework Cloud, which ships with macOS,
Linux, and Windows 10 or later.


{title:Also see}

{pstd}
Documentation: {browse "https://framework.pub/docs/stata"}
