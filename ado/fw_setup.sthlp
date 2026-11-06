{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:fw_setup} {hline 2} Check Stata, system tools, backends, and the Cloud connection


{title:Syntax}

{p 8 16 2}
{cmd:fw_setup} [{cmd:,} {opt nopy:thon} {opt nonet:work} {opt url(string)}]


{title:Description}

{pstd}
{cmd:fw_setup} checks everything Framework for Stata uses and prints the next
steps for anything missing:

{phang2}o  the Stata version and where the package is installed;{p_end}
{phang2}o  the project at or above the current folder;{p_end}
{phang2}o  curl, the SHA-256 tool, and the system keyring;{p_end}
{phang2}o  the Framework Cloud server and whether this computer is connected;{p_end}
{phang2}o  {bf:fw}, the command-line tool, and its version;{p_end}
{phang2}o  Stata's Python and whether framework-py is installed in it;{p_end}
{phang2}o  the backend setting.{p_end}

{pstd}
When framework-py is missing from Stata's Python, {cmd:fw_setup} prints the
{cmd:pip} command for that exact Python.


{title:Options}

{phang}
{opt nopython} skips the Python check. Checking Python starts Stata's Python
for the session, and Stata cannot change Python after that.

{phang}
{opt nonetwork} skips the request that confirms the Cloud login.

{phang}
{opt url(string)} checks a Framework Cloud server other than the default.


{title:Stored results}

{pstd}
{cmd:fw_setup} stores {cmd:r(steps)}, the number of next steps it printed.
