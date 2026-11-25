{smcl}
{* *! version 0.3.12  25nov2026}{...}
{title:Title}

{phang}
{bf:fw_structure} {hline 2} Show or publish a project's folder tree


{title:Syntax}

{p 8 16 2}
{cmd:fw_structure} [{it:folder} ...] [{cmd:,} {it:options}]

{pstd}
Each {it:folder} is relative to the project root. Without one, the tree shows
the whole project.

{synoptset 30}{...}
{synopthdr}
{synoptline}
{syntab:Tree}
{synopt:{opt dep:th(#)}}levels to list; deeper folders show a file count{p_end}
{synopt:{opt exc:lude(globs)}}paths to leave out, such as {cmd:exclude(renv "*.log")}{p_end}
{synopt:{opt note:s(path "note" ...)}}notes beside paths{p_end}
{synopt:{opt op:en(paths)}}folders that start open in embeds{p_end}
{synopt:{opt high:light(paths)}}paths drawn highlighted{p_end}
{synopt:{opt ign:ored(rules|hide)}}show ignored paths with their rules, the default, or leave them out{p_end}
{synopt:{opt sav:ing(filename [, replace])}}keep a copy of the tree document{p_end}

{syntab:Publishing}
{synopt:{opt pub:lish}}publish the tree to Framework Cloud{p_end}
{synopt:{opt slug(string)}}the artifact's name in its link{p_end}
{synopt:{opt ti:tle(string)}}the title readers see{p_end}
{synopt:{opt desc:ription(string)}}a short description{p_end}
{synopt:{opt to(destination)}}{bf:cloud} or a destination named in the project settings{p_end}
{synopt:{opt vis:ibility(string)}}{bf:public}, {bf:unlisted}, or {bf:private}{p_end}
{synopt:{opt priv:ate}}short for {cmd:visibility(private)}{p_end}
{synopt:{opt disp:lay(settings)}}what Framework Cloud embeds show, such as {cmd:display(notes=off)}{p_end}
{synoptline}


{title:Description}

{pstd}
A structure artifact is a project's folder tree with notes on its paths. A
tutorial or course page embeds it to explain how a project is laid out.
Ignored paths show the {bf:.gitignore} rule that hides them, so the tree
explains the {bf:.gitignore} too. The tree holds names only. File contents and
sizes never publish.

{pstd}
{cmd:fw_structure} prints the full local tree and uploads nothing. Ignored
files are listed by name with their rule, at most 20 per folder and rule.
{cmd:fw_structure, publish} prints the tree as it publishes, then uploads it
with {helpb fw_publish} as a {bf:framework.artifact/v1} document of kind
{bf:tree}, named {it:slug}{bf:.json}.

{pstd}
Several folders publish as one tree under the project's folder name, with only
the chosen folders and the folders above them.


{title:Privacy rules}

{pstd}
The rules apply before anything is uploaded.

{phang2}1. {bf:.git} is always left out.{p_end}
{phang2}2. Ignored paths never publish their names. An ignored folder publishes
as a stub with its rule and a file count. Ignored files in a folder that is not
ignored publish as one group per rule, with the rule and a count.{p_end}
{phang2}3. A private folder publishes as a stub with a file count, whether or
not it is ignored. A folder is private when it is named {bf:private} or ends
in {bf:_private}, in any case, or when it is a settings folder whose key holds
{bf:private} and not {bf:public}, such as {bf:inputs_private_raw}.{p_end}
{phang2}4. A folder below {opt depth()} publishes as a stub with a file
count.{p_end}
{phang2}5. {opt exclude()} leaves paths out with no stub.{p_end}
{phang2}6. Symbolic links show as files and are never followed.{p_end}
{phang2}7. A rule from outside the project, such as git's global excludes file
or {bf:.git/info/exclude}, shows its source as {bf:global} or
{bf:info/exclude}, never as a path.{p_end}

{pstd}
File counts stop at 10,000, shown as "10,000+ files". A private folder's own
structure does not publish: {cmd:fw_structure data/private, publish} stops with
an error.


{title:Ignored paths}

{pstd}
When git runs and the project is in a git work tree, git decides what is
ignored, with every {bf:.gitignore}, {bf:.git/info/exclude}, and the global
excludes file. Without git, {cmd:fw_structure} reads the project root's
{bf:.gitignore} alone: blank lines and {bf:#} comments, {bf:!} negation, a
trailing {bf:/} for folders, a leading or middle {bf:/} to anchor a pattern to
the root, {bf:*}, {bf:?}, {bf:**}, and {bf:[...]}. {cmd:r(method)} reports
{bf:git}, {bf:gitignore}, or {bf:none}.

{pstd}
On an Apple silicon Mac, Stata 14 runs under Rosetta, where
{bf:/usr/bin/git} fails. {cmd:fw_structure} then runs the Command Line Tools
git directly.


{title:Options}

{phang}
{opt depth(#)} lists # levels below each chosen folder. A folder at the last
level shows its file count in place of its contents. The default is no limit.

{phang}
{opt exclude(globs)} takes {bf:.gitignore} patterns. A pattern without a
{bf:/} matches a name at any level. A pattern with one matches the path from
the tree's top. A trailing {bf:/} matches folders only.

{phang}
{opt notes(path "note" ...)} gives notes by path, relative to the folder the
tree shows. A folder may end in {bf:/}. A note holds up to 500 characters of
plain text. A path that is not in the published tree is an error, including
the name of an ignored file.

{phang}
{opt open(paths)} and {opt highlight(paths)} name paths in the tree. Embeds
open the top level and close deeper folders unless {opt open()} names them. A
folder that holds a highlighted path opens too.

{phang}
{opt ignored(hide)} leaves ignored paths out. Private stubs stay, unless the
private folder is also ignored.

{phang}
{opt slug()} defaults to {bf:structure}, or {bf:structure-}{it:folder} for one
subfolder. {opt title()} defaults to {it:folder} {bf:structure}.
{opt description()}, {opt to()}, {opt visibility()}, and {opt private} work as
in {helpb fw_publish}. Publishing again under the same slug adds a version.

{phang}
{opt display(settings)} sets what embeds show, as in
{helpb fw_publish##display:fw_publish}: {bf:title}, {bf:description},
{bf:notes}, and {bf:ignored}, each {bf:on} or {bf:off}. With
{cmd:display(ignored=off)}, embeds drop ignored stubs and groups. Private stubs
stay.

{phang}
{opt saving(filename [, replace])} writes the tree document as it would
publish. Without {opt publish}, the copy is all {cmd:fw_structure} writes.


{title:Examples}

{pstd}The whole project, locally{p_end}
{phang2}{cmd:. fw_structure}{p_end}

{pstd}Notes and a highlighted file, published{p_end}
{phang2}{cmd:. fw_structure, notes(scripts "Analysis do-files" README.md "Start here") highlight(README.md) publish}{p_end}

{pstd}Two folders, two levels deep{p_end}
{phang2}{cmd:. fw_structure scripts outputs, depth(2) publish visibility(public)}{p_end}

{pstd}A subfolder without ignored paths{p_end}
{phang2}{cmd:. fw_structure scripts, ignored(hide) publish}{p_end}


{title:Output}

{phang2}{cmd:my-project/}{p_end}
{phang2}{cmd:├── data/}{p_end}
{phang2}{cmd:│   ├── private/   private · 1 file}{p_end}
{phang2}{cmd:│   └── raw/       ignored by data/raw/ (.gitignore:1) · 2 files}{p_end}
{phang2}{cmd:├── outputs/}{p_end}
{phang2}{cmd:│   ├── table.csv}{p_end}
{phang2}{cmd:│   ├── draws.rds  ignored by *.rds (.gitignore:2)}{p_end}
{phang2}{cmd:│   └── fit.rds    ignored by *.rds (.gitignore:2)}{p_end}
{phang2}{cmd:└── README.md      Start here}{p_end}

{pstd}
As published, the two {bf:.rds} files show as one group:
{cmd:*.rds  ignored by *.rds (.gitignore:2) · 2 files}.


{title:Stored results}

{p2colset 8 26 28 2}{...}
{p2col:{cmd:r(nodes)}}the number of published nodes{p_end}
{p2col:{cmd:r(method)}}{bf:git}, {bf:gitignore}, or {bf:none}{p_end}
{p2col:{cmd:r(root)}}the name at the top of the tree{p_end}
{p2col:{cmd:r(base)}}the folder relative to the project root; empty for the root or several folders{p_end}
{p2col:{cmd:r(slug)}}the artifact name{p_end}
{p2col:{cmd:r(file)}}the {opt saving()} copy, else empty{p_end}
{p2col:{cmd:r(url)}}the published link{p_end}
{p2col:{cmd:r(embed_link)}}the Share link, to paste into a site that takes Framework embeds{p_end}
{p2col:{cmd:r(artifact_url)}}the Manage link, your page for the artifact on Framework Cloud{p_end}
{p2col:{cmd:r(version)}}the version number{p_end}
{p2colreset}{...}

{pstd}
Publishing also sets the other results of {helpb fw_publish}.


{title:Also see}

{pstd}
{helpb fw_publish}, {helpb fw_dag}, {helpb framework}
