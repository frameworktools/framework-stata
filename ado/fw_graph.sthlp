{smcl}
{* *! version 0.1.1  07nov2026}{...}
{title:Title}

{phang}
{bf:fw_graph} {hline 2} Export a graph to the project's figures folder


{title:Syntax}

{p 8 16 2}
{cmd:fw_graph} {it:name} [{cmd:,} {it:options}]

{synoptset 24}{...}
{synopthdr}
{synoptline}
{synopt:{opt name(graphname)}}the graph to export; the default is the current graph{p_end}
{synopt:{opt for:mat(types)}}one or more file types; the default is {cmd:png}{p_end}
{synopt:{opt pub:lic}}save to the public figures folder of a sensitive project{p_end}
{synopt:{opt dpi(#)}}pixels per inch for PNG, TIFF, JPEG, and GIF; the default is 300{p_end}
{synopt:{opt wid:th(#)}}the width in pixels, in place of {opt dpi()}{p_end}
{synopt:{opt hei:ght(#)}}the height in pixels, in place of {opt dpi()}{p_end}
{synopt:{opt opt:ions(string)}}more options for {cmd:graph export}{p_end}
{synopt:{opt norep:lace}}stop when the file exists{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:fw_graph} exports a graph to the project's figures folder with
{cmd:graph export}, as {bf:save_figure()} does in R and Python, and records each
file.

{pstd}
{it:name} names the file without its extension. It may hold subfolders, such as
{cmd:meeting/figure-1}, which {cmd:fw_graph} creates. A name that ends in a
file type, such as {bf:figure-1.pdf}, picks that type.

{pstd}
The folder is the project's {bf:outputs_figures} folder, else
{bf:outputs/figures}. A project with {bf:security: sensitive: true}, or with
{bf:outputs_private_figures} or {bf:outputs_public_figures} folders, keeps
private and public figures apart: figures go to the private folder unless you
add {opt public}.

{pstd}
Each file is recorded in {bf:.framework/stata-results.tsv} by its path from the
project root, with its type, whether it is public, its SHA-256 checksum, and
the time, as {helpb fw_table} records tables.

{pstd}
File types are those {cmd:graph export} writes: {bf:png}, {bf:pdf}, {bf:svg},
{bf:eps}, {bf:ps}, {bf:tif}, {bf:jpg}, {bf:gif}, {bf:emf}, and {bf:wmf}. Some
depend on the system: Stata for Unix writes no GIF, and EMF and WMF need
Windows.


{title:Options}

{phang}
{opt name(graphname)} exports a named graph. {cmd:fw_graph} displays it first,
so it becomes the current graph; {cmd:graph export, name()} needs a graph
window, which batch mode lacks.

{phang}
{opt format(types)} lists the file types, such as {cmd:format(png pdf)}.

{phang}
{opt public} saves to the public figures folder of a project that splits
private and public outputs.

{phang}
{opt dpi(#)} sets the size of raster files: the graph's width in inches times
{it:#} pixels. The default, 300, matches {bf:save_figure()}. A graph 5.5 inches
wide gives a PNG 1,650 pixels wide. Set the graph's size in inches with
{cmd:xsize()} and {cmd:ysize()} when you draw it.

{phang}
{opt width(#)} and {opt height(#)} set the raster size in pixels directly.

{phang}
{opt options(string)} passes options to {cmd:graph export}, such as
{cmd:options(fontface(Arial))} for SVG.

{phang}
{opt noreplace} stops with error 602 when the file exists. By default
{cmd:fw_graph} overwrites it, as {bf:save_figure()} does.


{title:Examples}

{phang2}{cmd:. scatter mpg price}{p_end}
{phang2}{cmd:. fw_graph price-mpg}{p_end}
{phang2}{cmd:. fw_graph "meeting/figure-1", format(png pdf) public}{p_end}
{phang2}{cmd:. fw_graph weight.svg, name(byweight)}{p_end}


{title:Stored results}

{p2colset 8 22 24 2}{...}
{p2col:{cmd:r(path)}}the first file{p_end}
{p2col:{cmd:r(paths)}}every file{p_end}
{p2col:{cmd:r(sha256)}}the first file's checksum{p_end}
{p2col:{cmd:r(format)}}the formats written{p_end}
{p2col:{cmd:r(public)}}1 with {opt public}{p_end}
{p2colreset}{...}


{title:Also see}

{pstd}
{helpb fw_table}, {helpb fw_publish}
