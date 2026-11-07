{smcl}
{* *! version 0.2.0  07nov2026}{...}
{title:Title}

{phang}
{bf:fw_set} {hline 2} Set the backend and the location of fw


{title:Syntax}

{p 8 16 2}
{cmd:fw_set}

{p 8 16 2}
{cmd:fw_set backend} {c -(}{bf:auto}|{bf:core}|{bf:cli}|{bf:python}{c )-}

{p 8 16 2}
{cmd:fw_set fw_path} {c -(}{it:path}|{bf:clear}{c )-}


{title:Description}

{pstd}
{cmd:fw_set} with no arguments shows the options. Options are stored in
{bf:stata.conf} in the Framework configuration folder and apply to every
project.

{p2colset 8 20 22 2}{...}
{p2col:{bf:auto}}Stata handles folders and Framework Cloud. GitHub and S3 use
{bf:fw} when it is installed, then framework-py. The default.{p_end}
{p2col:{bf:core}}Stata only. GitHub and S3 publishing stop with an error.{p_end}
{p2col:{bf:cli}}every publish goes through {bf:fw}.{p_end}
{p2col:{bf:python}}every publish goes through framework-py in Stata's Python. Stata 16 or newer.{p_end}
{p2colreset}{...}

{pstd}
The global {cmd:FW_BACKEND} overrides the stored backend for one session:
{cmd:global FW_BACKEND cli}.

{pstd}
{cmd:fw_set fw_path} points to {bf:fw} when Stata cannot find it. The Stata
application on macOS starts with a short PATH, so this is common there.


{title:Example}

{phang2}{cmd:. fw_set backend cli}{p_end}
{phang2}{cmd:. fw_set fw_path "/opt/homebrew/bin/fw"}{p_end}
