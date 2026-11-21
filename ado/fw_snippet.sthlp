{smcl}
{* *! version 0.3.5  18nov2026}{...}
{title:Title}

{phang}
{bf:fw_snippet} {hline 2} Publish a do-file's commands and the output they printed


{title:Syntax}

{p 8 16 2}
{cmd:fw_snippet begin} {it:label}

{p 8 16 2}
{cmd:fw_snippet end} [{cmd:,} {it:options}]

{synoptset 28}{...}
{synopthdr}
{synoptline}
{synopt:{opt fold:ed}}fold every output block{p_end}
{synopt:{opt unfold:ed}}show every output block open{p_end}
{synopt:{opt noout:put}}publish the code without its output{p_end}
{synopt:{opt slug(string)}}the artifact's name in its link; default the label{p_end}
{synopt:{opt ti:tle(string)}}the title readers see{p_end}
{synopt:{opt desc:ription(string)}}a short description{p_end}
{synopt:{opt to(destination)}}{bf:cloud} or a destination named in the project settings{p_end}
{synopt:{opt vis:ibility(string)}}{bf:public}, {bf:unlisted}, or {bf:private}{p_end}
{synopt:{opt priv:ate}}short for {cmd:visibility(private)}{p_end}
{synopt:{opt notebook(url)}}link to the full notebook or document{p_end}
{synopt:{opt model(slug or url)}}link to the model artifact the code fit{p_end}
{synopt:{opt repo:sitory(url)}}the GitHub repository that holds the do-file{p_end}
{synopt:{opt file(filename)}}the do-file that holds the snippet{p_end}
{synopt:{opt disp:lay(settings)}}what Framework Cloud embeds show, such as {cmd:display(legend=off)}{p_end}
{synopt:{opt sav:ing(filename [, replace])}}keep a copy of the snippet document{p_end}
{synopt:{opt nopub:lish}}save the snippet without publishing it; needs {opt saving()}{p_end}
{synoptline}


{title:Description}

{pstd}
A code snippet is an artifact that holds a few commands and the text Stata
printed under them. A blog post or report that embeds it shows the code beside
its results. Framework Cloud keeps Stata's layout and styles, so a regression
table reads as it does in the Results window.

{pstd}
{cmd:fw_snippet begin} {it:label} starts recording. It opens an SMCL log named
{bf:fw_snippet} beside any log of your own. {cmd:fw_snippet end} closes it,
splits it into code and output, and publishes it with {helpb fw_publish}.
The label names the snippet and, unless {opt slug()} says otherwise, the
artifact.

{pstd}
Stata echoes each command above its output, and the snippet follows the echo.
Each command becomes code without its {bf:.} prompt. Lines continued with
{bf:///} stay with their command. The output between two commands becomes an
output block, kept as SMCL. Commands that print nothing share one code block
with the commands after them. Output that starts with an error message shows
as an error. The {cmd:fw_snippet end} line itself is left out.

{pstd}
Graphs never enter a snippet. A {cmd:graph} command stays in the code, and
its window is not recorded. Publish the graph itself with {helpb fw_graph} and
{helpb fw_publish}.

{pstd}
Publishing the same snippet again with nothing changed adds no version.
{cmd:fw_snippet end} then reports "Unchanged, still version {it:#}".


{title:Echo}

{pstd}
The snippet holds what Stata echoed. Commands run with {cmd:quietly do} or
{cmd:run} are not echoed, and a snippet of them has no code. Stata does not
echo the commands inside a {cmd:quietly {c -(}} block either, so the code shows
only the block's first line.


{title:Source}

{pstd}
The snippet records where its code came from:

{p2colset 8 22 24 2}{...}
{p2col:{bf:file}}the do-file, relative to the project root{p_end}
{p2col:{bf:lines}}the lines between {cmd:fw_snippet begin} and {cmd:fw_snippet end}{p_end}
{p2col:{bf:commit}}the git commit checked out in the project, when it is a git repository{p_end}
{p2col:{bf:repository}}the GitHub repository, only when you give it{p_end}
{p2colreset}{...}

{pstd}
Stata does not report which do-file is running. {cmd:fw_snippet end} looks for
the do-file in the project that holds {cmd:fw_snippet begin} {it:label}. When
several do-files hold it, the snippet names none; name it with {opt file()}.

{pstd}
Framework Cloud links the line range to GitHub when the snippet has the
repository, the commit, the file, and the lines. Give the repository with
{opt repository()}, or in the project settings:

{p 8 8 2}
{cmd:publish:}{break}
{cmd:  repository: https://github.com/owner/analysis}


{title:Options}

{phang}
{opt folded} and {opt unfolded} set how output blocks open. Without them,
Framework Cloud folds an output block longer than 12 lines.

{phang}
{opt nooutput} publishes the code alone.

{phang}
{opt slug()}, {opt title()}, {opt description()}, {opt to()},
{opt visibility()}, and {opt private} work as in {helpb fw_publish}. A new
snippet on Framework Cloud is unlisted unless {opt visibility()} says
otherwise.

{phang}
{opt notebook(url)} adds a link to the full notebook. {opt model()} adds a
link to a model artifact: its slug in the same project, or an https address.
Readers see the model link only when they may open the model.

{phang}
{opt display(settings)} sets what embeds of the snippet show, as in
{helpb fw_publish##display:fw_publish}: {bf:output}, {bf:links}, {bf:title},
{bf:description}, and {bf:author}, each {bf:on} or {bf:off}.
{cmd:display(output=off)} starts the output hidden behind Show output in
every embed.

{phang}
{opt saving(filename [, replace])} keeps a copy of the snippet document, a
{bf:framework.artifact/v1} JSON file. With {opt nopublish}, the copy is all
{cmd:fw_snippet end} writes.

{pstd}
{cmd:fw_snippet end} checks its options before it stops recording. A mistyped
option leaves the snippet open, so run {cmd:fw_snippet end} again.


{title:Errors}

{pstd}
Snippets do not nest. {cmd:fw_snippet begin} while a snippet is open stops
with error 198, and the open snippet goes on. When a do-file stopped with an
error inside a snippet, the next {cmd:fw_snippet begin} closes that snippet
and starts the new one. To discard an open snippet, type
{cmd:log close fw_snippet}.

{pstd}
When publishing fails, the snippet document stays in a temporary folder, and
{cmd:fw_snippet end} prints the {cmd:fw_publish} command that publishes it.


{title:Examples}

{phang2}{cmd:. fw_snippet begin fit-ols}{p_end}
{phang2}{cmd:. regress price mpg i.foreign}{p_end}
{phang2}{cmd:. fw_snippet end, unfolded visibility(public)}{p_end}

{phang2}{cmd:. fw_snippet begin summary}{p_end}
{phang2}{cmd:. summarize price mpg weight}{p_end}
{phang2}{cmd:. fw_snippet end, nopublish saving(summary.json, replace)}{p_end}


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(url)}}the published link{p_end}
{p2col:{cmd:r(embed_link)}}the Share link, to paste into a site that takes Framework embeds{p_end}
{p2col:{cmd:r(artifact_url)}}the Manage link, your page for the artifact on Framework Cloud{p_end}
{p2col:{cmd:r(version)}}the version number{p_end}
{p2col:{cmd:r(unchanged)}}1 when Framework Cloud kept the latest version, else 0{p_end}
{p2col:{cmd:r(slug)}}the artifact name{p_end}
{p2col:{cmd:r(label)}}the snippet's label{p_end}
{p2col:{cmd:r(source_file)}}the do-file, relative to the project root{p_end}
{p2col:{cmd:r(lines)}}the do-file lines, such as {bf:12-15}{p_end}
{p2col:{cmd:r(commit)}}the git commit{p_end}
{p2col:{cmd:r(file)}}the {opt saving()} copy, else empty{p_end}
{p2col:{cmd:r(blocks)}}the number of blocks{p_end}
{p2col:{cmd:r(code_blocks)}}the number of code blocks{p_end}
{p2col:{cmd:r(output_blocks)}}the number of output blocks{p_end}
{p2colreset}{...}

{pstd}
Publishing also sets the other results of {helpb fw_publish}.


{title:Also see}

{pstd}
{helpb fw_publish}, {helpb framework}
