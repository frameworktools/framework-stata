{smcl}
{* *! version 0.1.1  07nov2026}{...}
{title:Title}

{phang}
{bf:fw_publish} {hline 2} Publish a figure, table, document, or estimation results


{title:Syntax}

{p 8 16 2}
{cmd:fw_publish} {it:filename} [{cmd:,} {it:options}]

{p 8 16 2}
{cmd:fw_publish} {cmd:,} {opt est:imates} [{it:options} {opt l:evel(#)} {opt sav:ing(filename [, replace])}]

{synoptset 26}{...}
{synopthdr}
{synoptline}
{synopt:{opt slug(string)}}the artifact's name in its link; default from the file name{p_end}
{synopt:{opt ti:tle(string)}}the title readers see{p_end}
{synopt:{opt desc:ription(string)}}a short description{p_end}
{synopt:{opt to(destination)}}{bf:cloud}, {bf:github}, {bf:s3}, or a destination named in the project settings{p_end}
{synopt:{opt vis:ibility(string)}}{bf:public}, {bf:unlisted}, or {bf:private}{p_end}
{synopt:{opt priv:ate}}short for {cmd:visibility(private)}{p_end}
{synopt:{opt includepriv:ate}}confirm files with "private" in their path{p_end}
{synopt:{opt kind(string)}}override the detected kind, such as {bf:image} or {bf:html}{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:fw_publish} publishes one file: a figure, a table, a rendered HTML
document with its {it:name}{bf:_files} folder, or any other file. Each publish
adds a version and keeps the earlier ones.

{pstd}
{cmd:fw_publish, estimates} publishes the current estimation results as a
model: a coefficient table with standard errors, test statistics, p-values,
and confidence intervals, plus fit statistics. Framework Cloud and the offline
reader show it like a model published from R or Python.


{title:Destinations}

{pstd}
Without {opt to()}, {cmd:fw_publish} uses {bf:publish.default} in the project
settings, then Framework Cloud. Named destinations live in the settings:

{p 8 8 2}
{cmd:publish:}{break}
{cmd:  default: lab}{break}
{cmd:  destinations:}{break}
{cmd:    lab:}{break}
{cmd:      driver: folder}{break}
{cmd:      path: /Volumes/lab/published}{break}
{cmd:      visibility: private}

{pstd}
A folder destination needs a {bf:path}, so name it in the settings and give
its name to {opt to()}. {cmd:to(folder)} alone stops with an error. When the
destination sets {bf:visibility}, {opt visibility()} must match it.

{pstd}
Stata publishes to folders and to Framework Cloud itself. GitHub Pages and S3
need {bf:fw} or framework-py; see {helpb fw_set}. Framework Cloud uploads use the
project token in the project's {bf:.env} file.

{pstd}
On Framework Cloud, {opt visibility()} sets who can open the artifact. Without
it, a new artifact is unlisted: anyone with the link can open it, but it is not
listed. A later publish without {opt visibility()} keeps the current visibility.
{opt slug()} names the artifact; it does not change the visibility.


{title:Estimation commands}

{pstd}
{cmd:regress}, {cmd:logit}, {cmd:logistic}, {cmd:probit}, {cmd:poisson},
{cmd:nbreg}, {cmd:glm}, {cmd:mixed}, {cmd:stcox}, and {cmd:ivregress} map to
Framework's model types with the right family, link, and ratio label. Other
commands with {cmd:e(b)} and {cmd:e(V)} publish a generic coefficient table.

{pstd}
Estimates stay on the model scale. Odds, rate, and hazard ratios are offered
by the reader. {cmd:_cons} becomes {bf:(Intercept)}. Base and omitted factor
levels are left out. {cmd:mixed} adds a random-effects table for independent,
identity, exchangeable, and unstructured covariance. {cmd:nbreg} reports alpha
or delta as a fit statistic. Other free parameters, such as tobit's
{cmd:var(e.}{it:y}{cmd:)}, go in an ancillary table, without a test where
Stata shows none.


{title:Private paths}

{pstd}
A file whose full path contains "private", in any case, needs confirmation.
Interactive Stata asks. Batch mode stops with error 198 until you add the
{opt includeprivate} option. R, Python, and {bf:fw} follow the same rule.
The {opt private} option sets visibility, not this confirmation.

{pstd}
With {opt estimates}, the rule checks the file the data in memory came from:
the last {helpb fw_use} or {helpb fw_save}, or {cmd:c(filename)} when a plain
{cmd:use} or {cmd:save} has loaded another file since. Results fit to data
from a path with "private" in it need the same confirmation.


{title:Options for estimates}

{phang}
{opt level(#)} sets the confidence level; the default is {cmd:c(level)}, 95
unless changed with {cmd:set level}. {cmd:fw_publish} does not read the level
of the estimation command; after {cmd:regress, level(90)}, give {cmd:level(90)}.

{phang}
{opt saving(filename [, replace])} keeps a copy of the model document.


{title:Examples}

{phang2}{cmd:. graph export "$fw_outputs_figures/price.png", replace}{p_end}
{phang2}{cmd:. fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")}{p_end}
{phang2}{cmd:. regress price mpg weight}{p_end}
{phang2}{cmd:. fw_publish, estimates slug(price-model) to(lab)}{p_end}


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(url)}}the published link, when the destination has one{p_end}
{p2col:{cmd:r(location)}}the published folder, for folder destinations{p_end}
{p2col:{cmd:r(version)}}the version number{p_end}
{p2col:{cmd:r(version_url)}}the link to this version, when the destination has one{p_end}
{p2col:{cmd:r(destination)}}the destination name{p_end}
{p2col:{cmd:r(driver)}}cloud, folder, github, or s3{p_end}
{p2col:{cmd:r(backend)}}core, cli, or python{p_end}
{p2col:{cmd:r(slug)}}the artifact name{p_end}
{p2col:{cmd:r(file)}}the published file; with {opt estimates}, the {opt saving()} copy, else empty{p_end}
{p2colreset}{...}

{pstd}
Every backend sets these results. A result is empty when the destination
does not report it.
