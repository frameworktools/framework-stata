{smcl}
{* *! version 0.1.1  07nov2026}{...}
{title:Title}

{phang}
{bf:fw_logout} {hline 2} Remove this computer's Framework Cloud token


{title:Syntax}

{p 8 16 2}
{cmd:fw_logout} [{cmd:,} {opt url(string)}]


{title:Description}

{pstd}
{cmd:fw_logout} removes the token for a Framework Cloud server from the system
keyring and from the token files Python and {bf:fw} use. It first revokes the
token on the server, so the token stops working everywhere. When the server
cannot be reached, it still removes the token here and says to revoke it on
the server's tokens page. R keeps a separate token file; {cmd:fw_logout} names
it when it exists. A token in {bf:FW_CLOUD_TOKEN} is neither removed nor revoked.
