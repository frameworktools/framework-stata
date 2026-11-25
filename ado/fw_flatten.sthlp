{smcl}
{* *! version 0.3.13  25nov2026}{...}
{title:Title}

{phang}
{bf:fw_flatten} {hline 2} Keep only an artifact's newest version on Framework Cloud


{title:Syntax}

{p 8 16 2}
{cmd:fw_flatten} {it:artifact} [{cmd:,} {opt proj:ect(slug)} {opt confirm}]

{pstd}
{it:artifact} is the artifact's slug, as {cmd:r(slug)} from {helpb fw_publish}
reports it.

{synoptset 20}{...}
{synopthdr}
{synoptline}
{synopt:{opt proj:ect(slug)}}the project that holds the artifact{p_end}
{synopt:{opt confirm}}flatten without asking; required in batch mode{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:fw_flatten} makes the artifact's newest version its version 1. Framework
Cloud deletes every older version and its files for good. Trash keeps no copy.
Links and embeds of old versions open the latest one. Collections and reports
that pinned an old version show version 1. The next publish continues after
the highest old version number.

{pstd}
Every artifact kind can be flattened. Artifacts published to GitHub Pages, S3,
or a folder have no versions on Framework Cloud, and Cloud refuses them.

{pstd}
Before it flattens, {cmd:fw_flatten} says what Cloud deletes. In an
interactive session it asks for {bf:y}. In batch mode it stops with error 198
unless {opt confirm} is given.


{title:Options}

{phang}
{opt project(slug)} names the project. A project token reaches only the
artifacts of its own project. Outside a project, the account token from
{helpb fw_login} reaches every artifact of the account, and {opt project()} is
needed when several projects have an artifact with the same slug.

{phang}
{opt confirm} flattens without asking.


{title:Tokens}

{pstd}
{cmd:fw_flatten} uses the same token as {helpb fw_publish}: the project token
in {bf:FW_PROJECT_TOKEN} or the project's {bf:.env}. Without one, it uses the
account token from {helpb fw_login}.


{title:Examples}

{phang2}{cmd:. fw_flatten price-mileage, confirm}{p_end}
{phang2}{cmd:. fw_flatten structure, project(example-study) confirm}{p_end}

{pstd}Output{p_end}
{phang2}{cmd:Flattened price-mileage to version 1; removed 4 older versions.}{p_end}
{phang2}{cmd:Manage: https://framework.pub/artifacts/123}{p_end}


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(artifact_url)}}the Manage link, your page for the artifact on Framework Cloud{p_end}
{p2col:{cmd:r(artifact)}}the artifact{p_end}
{p2col:{cmd:r(version)}}the version number now, 1{p_end}
{p2col:{cmd:r(removed)}}the number of older versions deleted{p_end}
{p2colreset}{...}


{title:Also see}

{pstd}
{helpb fw_publish}, {helpb fw_login}, {helpb framework}
