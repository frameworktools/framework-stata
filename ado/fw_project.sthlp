{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:fw_project} {hline 2} Find the project and set path globals


{title:Syntax}

{p 8 16 2}
{cmd:fw_project} [{cmd:,} {opt root(folder)} {opt q:uietly}]


{title:Description}

{pstd}
{cmd:fw_project} walks up from the current folder, at most 10 levels, to the
first folder with {bf:.framework/}, {bf:settings.yml}, {bf:config.yml}, or
{bf:settings.do}. It reads the project settings and sets a global for each
project folder:

{p2colset 8 32 34 2}{...}
{p2col:{cmd:$fw_root}}the project folder{p_end}
{p2col:{cmd:$fw_}{it:key}}each folder in {bf:directories}, such as {cmd:$fw_inputs_raw}{p_end}
{p2col:{cmd:$fw_data}}the {bf:data} folder, else {bf:inputs_final}, else
{bf:inputs_public_final}, when the settings define one, even before it exists{p_end}
{p2col:{cmd:$fw_outputs}}{bf:outputs}, when it exists{p_end}
{p2col:{cmd:$fw_project_name}}the project name{p_end}
{p2colreset}{...}

{pstd}
Paths are absolute and use forward slashes on every system. Globals from a
previous project are cleared.

{pstd}
Settings come from {bf:settings.yml}, with split files such as
{bf:settings/data.yml} and environment sections. The active environment is
{bf:FW_CONFIG_ACTIVE}, then {bf:R_CONFIG_ACTIVE}, then {bf:default}. Projects
that {bf:fw} created for Stata keep their folders in {bf:settings.do};
{cmd:fw_project} reads those too and leaves the globals of {bf:settings.do},
such as {cmd:$inputs_raw}, untouched.

{pstd}
Other commands run {cmd:fw_project} themselves when no project is loaded.
Run it again after you change to another project.


{title:Options}

{phang}
{opt root(folder)} starts the search in {it:folder} rather than the current folder.

{phang}
{opt quietly} skips the summary.


{title:Example}

{phang2}{cmd:. fw_project}{p_end}
{phang2}{cmd:. use "$fw_inputs_raw/survey.dta", clear}{p_end}


{title:Stored results}

{p2colset 8 24 26 2}{...}
{p2col:{cmd:r(root)}}the project folder{p_end}
{p2col:{cmd:r(name)}}the project name{p_end}
{p2col:{cmd:r(folders)}}the folder keys{p_end}
{p2colreset}{...}
