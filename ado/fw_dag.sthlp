{smcl}
{* *! version 0.3.6  21nov2026}{...}
{title:Title}

{phang}
{bf:fw_dag} {hline 2} Publish a causal DAG


{title:Syntax}

{p 8 16 2}
{cmd:fw_dag} {cmd:"}{it:path}{cmd:"} [{cmd:"}{it:path}{cmd:"} ...] [{cmd:,} {it:options}]

{p 8 16 2}
{cmd:fw_dag using} {it:filename} [{cmd:,} {it:options}]

{pstd}
A {it:path} names variables joined by arrows: {bf:->} for a cause,
{bf:<-} for the same arrow written the other way, and {bf:<->} for a common
unobserved cause. A path can chain, as in {bf:"age -> smoking -> cancer"}, and
braces group names, as in {bf:"{c -(}age sex{c )-} -> smoking"}. A name alone
adds a variable with no arrows. Names may hold spaces, as in
{bf:"family income -> smoking"}.

{synoptset 28}{...}
{synopthdr}
{synoptline}
{syntab:Graph}
{synopt:{opt exp:osure(names)}}the exposure{p_end}
{synopt:{opt out:come(names)}}the outcome{p_end}
{synopt:{opt lat:ent(names)}}variables that are not observed{p_end}
{synopt:{opt adj:usted(names)}}variables the analysis adjusts for{p_end}
{synopt:{opt sel:ected(names)}}variables the sample was selected on{p_end}
{synopt:{opt lab:els(name "label" ...)}}labels readers see in place of names{p_end}
{synopt:{opt novarl:abels}}do not take labels from variables in memory{p_end}
{synopt:{opt nocode}}leave out the {cmd:fw_dag} command{p_end}

{syntab:Publishing}
{synopt:{opt slug(string)}}the artifact's name in its link{p_end}
{synopt:{opt ti:tle(string)}}the title readers see{p_end}
{synopt:{opt desc:ription(string)}}a short description{p_end}
{synopt:{opt to(destination)}}{bf:cloud} or a destination named in the project settings{p_end}
{synopt:{opt vis:ibility(string)}}{bf:public}, {bf:unlisted}, or {bf:private}{p_end}
{synopt:{opt priv:ate}}short for {cmd:visibility(private)}{p_end}
{synopt:{opt includepriv:ate}}confirm a {cmd:using} file with "private" in its path{p_end}
{synopt:{opt disp:lay(settings)}}what Framework Cloud embeds show, such as {cmd:display(legend=off)}{p_end}
{synopt:{opt sav:ing(filename [, replace])}}keep a copy of the DAG{p_end}
{synopt:{opt nopub:lish}}save the DAG without publishing it; needs {opt saving()}{p_end}
{synoptline}


{title:Description}

{pstd}
A DAG artifact is a causal diagram with the DAGitty model text that defines it.
A blog post or report that embeds it shows the drawing. Readers can copy the
DAGitty text into dagitty.net or R's {bf:dagitty} package and get the same
graph back. Framework Cloud lays out and draws the graph, so Stata needs no
graph of its own.

{pstd}
{cmd:fw_dag} {it:paths} writes the DAGitty text from the paths and the role
options, then publishes it with {helpb fw_publish} as a {bf:framework.artifact/v1}
document of kind {bf:dag}. The document holds the labels and, as the code that
built the graph, the {cmd:fw_dag} command as typed. {cmd:fw_dag} prints the
DAGitty text before it publishes.

{pstd}
{cmd:fw_dag using} {it:filename} publishes a DAGitty file, such as one saved
from dagitty.net. The file sets its own roles, as in {bf:smoking [exposure]}.
A file publishes as it is, unless {opt labels()} adds labels.

{pstd}
Framework Cloud checks the graph when it publishes. A graph with a directed
cycle fails with a message that names the problem. A graph holds at most 100
variables and 400 arrows. Framework draws DAGs only, so {bf:--} undirected
edges are refused.


{title:Options}

{phang}
{opt exposure()}, {opt outcome()}, {opt latent()}, {opt adjusted()}, and
{opt selected()} each take one or more names from the paths. Put a name with
spaces in double quotes, as in {cmd:latent("tar deposits")}. They go with paths
only.

{phang}
{opt labels(name "label" ...)} gives labels by name. Without it, a variable in
the dataset in memory with the same name as a node lends its variable label.
{opt labels()} wins over a variable label. {opt novarlabels} turns variable
labels off.

{phang}
{opt nocode} leaves out the {cmd:fw_dag} command. A {cmd:using} file never
carries one.

{phang}
{opt slug()}, {opt title()}, {opt description()}, {opt to()},
{opt visibility()}, and {opt private} work as in {helpb fw_publish}. The slug
defaults to {bf:dag-}{it:exposure}{bf:-}{it:outcome} from the first exposure and
outcome, else {bf:dag}. For a {cmd:using} file, it defaults to the file name.
Publishing again under the same slug adds a version. A new DAG on Framework
Cloud is unlisted unless {opt visibility()} says otherwise.

{phang}
{opt display(settings)} sets what embeds of the DAG show, as in
{helpb fw_publish##display:fw_publish}: {bf:legend}, {bf:analysis},
{bf:dagitty}, {bf:code}, {bf:title}, {bf:description}, and {bf:author}, each
{bf:on} or {bf:off}. A DAG embeds as its drawing alone by default: its
description, analysis, DAGitty code, and code start off.
{cmd:display(dagitty=on code=on)} adds the DAGitty code and the {cmd:fw_dag}
command to embeds. The reader page on Framework Cloud always shows them.

{phang}
{opt saving(filename [, replace])} keeps a copy. A name ending in
{bf:.dagitty} saves the DAGitty text. Any other name saves the
{bf:framework.artifact/v1} JSON document. With {opt nopublish}, the copy is all
{cmd:fw_dag} writes, and no project is needed.


{title:Examples}

{pstd}Smoking, age, and lung cancer{p_end}
{phang2}{cmd:. fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) title("Smoking and lung cancer")}{p_end}

{pstd}Labels, a latent variable, and a group of causes{p_end}
{phang2}{cmd:. fw_dag "{c -(}age sex{c )-} -> smoking -> tar deposits -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) latent("tar deposits") labels(cancer "Lung cancer")}{p_end}

{pstd}A DAGitty file{p_end}
{phang2}{cmd:. fw_dag using "models/smoking.dagitty", visibility(unlisted)}{p_end}

{pstd}The DAGitty text alone, without publishing{p_end}
{phang2}{cmd:. fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) nopublish saving(smoking.dagitty, replace)}{p_end}


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(url)}}the published link{p_end}
{p2col:{cmd:r(embed_link)}}the Share link, to paste into a site that takes Framework embeds{p_end}
{p2col:{cmd:r(artifact_url)}}the Manage link, your page for the artifact on Framework Cloud{p_end}
{p2col:{cmd:r(version)}}the version number{p_end}
{p2col:{cmd:r(slug)}}the artifact name{p_end}
{p2col:{cmd:r(dagitty)}}the DAGitty text{p_end}
{p2col:{cmd:r(file)}}the {opt saving()} copy, else empty{p_end}
{p2col:{cmd:r(nodes)}}the number of variables; missing for a {cmd:using} file{p_end}
{p2col:{cmd:r(edges)}}the number of arrows; missing for a {cmd:using} file{p_end}
{p2colreset}{...}

{pstd}
Publishing also sets the other results of {helpb fw_publish}.


{title:Also see}

{pstd}
{helpb fw_publish}, {helpb fw_snippet}, {helpb framework}
