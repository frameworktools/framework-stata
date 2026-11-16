{smcl}
{* *! version 0.3.2  16nov2026}{...}
{title:Title}

{phang}
{bf:fw_scaffold} {hline 2} Load the project and prepare the Stata session


{title:Syntax}

{p 8 16 2}
{cmd:fw_scaffold} [{cmd:,} {opt root(folder)} {opt noinst:all} {opt q:uietly}]


{title:Description}

{pstd}
{cmd:fw_scaffold} does in Stata what {bf:scaffold()} does in R and Python. Run
it at the top of {bf:master.do} or any do-file. In order, it:

{phang2}1. loads the project with {helpb fw_project}, which sets the path globals;{p_end}
{phang2}2. points PLUS at {bf:ado/plus} in the project, when {bf:packages: project_ado} is on;{p_end}
{phang2}3. installs the missing packages with {helpb fw_packages};{p_end}
{phang2}4. sets the random seed;{p_end}
{phang2}5. sets the graph scheme;{p_end}
{phang2}6. adds the function folders to the ado-path, so programs there load by name;{p_end}
{phang2}7. runs {bf:scaffold.do} from the project folder, if there is one.{p_end}

{pstd}
The settings are R's, under {bf:scaffold} in {bf:settings.yml}:

{p 8 8 2}{bf:scaffold:}{break}
{bf:  seed_on_scaffold: true}{break}
{bf:  seed: 123}{break}
{bf:  set_theme_on_scaffold: true}{break}
{bf:  stata_scheme: s2color}{break}
{bf:  source_all_functions: true}{p_end}

{p2colset 8 32 34 2}{...}
{p2col:{bf:seed_on_scaffold}}sets the seed. Without it, the environment
variable {bf:FW_SEED} turns seeding on. {bf:false} turns it off even then.{p_end}
{p2col:{bf:seed}}the seed. Without it, {bf:FW_SEED}, else 123.{p_end}
{p2col:{bf:set_theme_on_scaffold}}sets the graph scheme in {bf:stata_scheme}.{p_end}
{p2col:{bf:source_all_functions}}adds {bf:directories.functions}, else
{bf:functions}, to the ado-path. On unless {bf:false}.{p_end}
{p2colreset}{...}

{pstd}
A program in a function folder, such as {bf:functions/clean_ids.ado}, runs by
name in every do-file. After you edit one, type {cmd:discard} to load the new
version.


{title:Options}

{phang}
{opt root(folder)} starts the project search in {it:folder}.

{phang}
{opt noinstall} skips installing missing packages.

{phang}
{opt quietly} prints only errors and the output of {bf:scaffold.do}.


{title:Examples}

{phang2}{cmd:. fw_scaffold}{p_end}
{phang2}{cmd:. fw_scaffold, noinstall}{p_end}


{title:Stored results}

{p2colset 8 24 26 2}{...}
{p2col:{cmd:r(root)}}the project folder{p_end}
{p2col:{cmd:r(seed)}}the seed set, or empty{p_end}
{p2col:{cmd:r(scheme)}}the graph scheme set, or empty{p_end}
{p2col:{cmd:r(plus)}}the project's PLUS folder, when {bf:project_ado} is on{p_end}
{p2col:{cmd:r(functions)}}the folders added to the ado-path{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
{helpb framework}, {helpb fw_project}, {helpb fw_packages}
{p_end}
