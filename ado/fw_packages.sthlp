{smcl}
{* *! version 0.3.2  16nov2026}{...}
{title:Title}

{phang}
{bf:fw_packages} {hline 2} List and install the packages a project uses


{title:Syntax}

{p 8 16 2}
{cmd:fw_packages} [{bf:list}] [{it:names}] [{cmd:,} {opt q:uietly}]

{p 8 16 2}
{cmd:fw_packages install} [{it:names}] [{cmd:,} {opt q:uietly}]

{p 8 16 2}
{cmd:fw_packages update} [{it:names}] [{cmd:,} {opt q:uietly}]


{title:Description}

{pstd}
{cmd:fw_packages} reads the packages listed in the project settings, as
{bf:packages_install()} does in R and Python. It shows whether each one is
installed. {cmd:fw_packages install} installs the missing ones.
{cmd:fw_packages update} reinstalls every package, which picks up new versions.
{it:names} limits the command to some of the packages.

{pstd}
Packages come from SSC with {cmd:ssc install}, or from GitHub or another
address with {cmd:net install}. List them under {bf:packages} in
{bf:settings.yml}, or in {bf:settings/packages.yml}, the file R writes:

{p 8 8 2}{bf:packages:}{break}
{bf:  project_ado: true}{break}
{bf:  default_packages:}{break}
{bf:    - name: estout}{break}
{bf:      source: ssc}{break}
{bf:    - name: reghdfe}{break}
{bf:      source: github}{break}
{bf:      repo: sergiocorreia/reghdfe}{break}
{bf:      ref: 6.12.3}{break}
{bf:    - name: mytools}{break}
{bf:      source: net}{break}
{bf:      url: https://example.org/stata}{p_end}

{p2colset 8 20 22 2}{...}
{p2col:{bf:ssc}}installs {it:name} from SSC. The default source.{p_end}
{p2col:{bf:github}}installs from the {bf:.pkg} file at the top of {bf:repo}.
{bf:ref} picks a tag, branch, or commit. Without it, the default branch is
used. A tag fixes the version.{p_end}
{p2col:{bf:net}}installs from the folder or web address in {bf:url}.{p_end}
{p2colreset}{...}

{pstd}
A plain entry is shorthand: {bf:- estout} is an SSC package, and
{bf:- sergiocorreia/reghdfe@6.12.3} is a GitHub package. Entries for R or
Python, with source {bf:cran}, {bf:bioc}, or {bf:pypi}, are listed as skipped.


{title:Project packages}

{pstd}
With {bf:project_ado: true}, packages install into {bf:ado/plus} in the
project folder, and {cmd:fw_packages} checks that folder. Commit the folder to
keep the exact versions with the project. Other people then run the same
code without installing anything. Without {bf:project_ado}, packages install
into Stata's PLUS folder, {cmd:c(sysdir_plus)}, and every project shares
them.

{pstd}
{cmd:fw_packages} sets PLUS to the project folder only while it installs.
{helpb fw_scaffold} sets it for the whole session, so the project's packages
run.


{title:Options}

{phang}
{opt quietly} prints nothing but the output of {cmd:ssc} and {cmd:net}.


{title:Examples}

{phang2}{cmd:. fw_packages}{p_end}
{phang2}{cmd:. fw_packages install}{p_end}
{phang2}{cmd:. fw_packages update reghdfe}{p_end}


{title:Stored results}

{p2colset 8 24 26 2}{...}
{p2col:{cmd:r(packages)}}every package in the settings{p_end}
{p2col:{cmd:r(installed)}}the installed packages{p_end}
{p2col:{cmd:r(missing)}}the packages not installed{p_end}
{p2col:{cmd:r(skipped)}}entries Stata cannot install{p_end}
{p2col:{cmd:r(failed)}}packages that failed to install{p_end}
{p2col:{cmd:r(plus)}}the folder checked and installed into{p_end}
{p2colreset}{...}

{pstd}
A failed install stops with the error of the first failure, after the other
packages are tried.


{title:Also see}

{psee}
{helpb framework}, {helpb fw_scaffold}, {helpb fw_project}, {helpb ssc}, {helpb net}
{p_end}
