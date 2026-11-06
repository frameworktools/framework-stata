{smcl}
{* *! version 0.1.0  05nov2026}{...}
{title:Title}

{phang}
{bf:fw_login} {hline 2} Connect this computer to Framework Cloud


{title:Syntax}

{p 8 16 2}
{cmd:fw_login} [{cmd:,} {opt url(string)} {opt nob:rowser}]


{title:Description}

{pstd}
{cmd:fw_login} connects this computer to Framework Cloud through your browser:

{phang2}1. Stata shows a short code and opens the approval page.{p_end}
{phang2}2. You sign in, or create a free account, and approve the computer.{p_end}
{phang2}3. Stata stores the new token in the system keyring.{p_end}

{pstd}
R, Python, and {bf:fw} use the same keyring entry, so one login serves them
all. Without a keyring, the token goes in a private file in the Framework
configuration folder. The token never appears in Stata's Results window,
macros, or logs.

{pstd}
Publishing a project to Cloud uses the project token in its {bf:.env} file;
{cmd:fw_login} connects the computer, not a project.


{title:Options}

{phang}
{opt url(string)} connects to a Framework Cloud server other than
{browse "https://framework.pub"}, such as a self-hosted one.

{phang}
{opt nobrowser} prints the link without opening the browser. Batch mode never
opens a browser.


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(account)}}the connected account's name{p_end}
{p2col:{cmd:r(stored)}}where the token went: {bf:keyring} or {bf:file}{p_end}
{p2colreset}{...}
