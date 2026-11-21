* fw_dag demo: publish a causal DAG of smoking, age, and lung cancer to
* Framework Cloud.
*
* Needs FW_CLOUD_URL and a project token in FW_PROJECT_TOKEN, for example the
* token of a throwaway project on framework.pub:
*
*   FW_CLOUD_URL=https://framework.pub FW_PROJECT_TOKEN=<token> \
*     stata-mp -b do examples/dag-demo.do
*
* Run it from the repository root. It loads fw_dag from this checkout's ado
* folder and works in a temporary project, which it removes at the end.

version 14
clear all
set more off

local repo = subinstr(`"`c(pwd)'"', "\", "/", .)
adopath ++ `"`repo'/ado"'
if `"`: environment FW_PROJECT_TOKEN'"' == "" | `"`: environment FW_CLOUD_URL'"' == "" {
    display as error "Set FW_CLOUD_URL and FW_PROJECT_TOKEN first."
    exit 198
}

* A temporary project: settings.yml is all fw_dag needs.
tempfile base
local project `"`base'_dag_demo"'
mkdir `"`project'"'
tempname fh
file open `fh' using `"`project'/settings.yml"', write text replace
file write `fh' "default:" _n "  project_name: dag-demo-stata" _n
file close `fh'
quietly cd `"`project'"'

* Variables in memory lend their labels to the nodes with the same names.
clear
set obs 1
generate byte smoking = .
label variable smoking "Smoking status"
generate byte age = .
label variable age "Age at baseline"
generate byte cancer = .
label variable cancer "Lung cancer by age 70"

* Age confounds smoking and cancer. Tar deposits, unmeasured, carry the
* effect of smoking. Sex affects smoking and cancer.
fw_dag "{age sex} -> smoking -> tar deposits -> cancer" "{age sex} -> cancer", ///
    exposure(smoking) outcome(cancer) latent("tar deposits") ///
    labels(sex "Sex at birth") ///
    title("Smoking and lung cancer") ///
    description("A causal diagram for the effect of smoking on lung cancer. Adjust for age and sex.") ///
    visibility(unlisted)
local url `"`r(url)'"'

* The same graph as a DAGitty file, as dagitty.net saves it, published as it is.
fw_dag "{age sex} -> smoking -> tar deposits -> cancer" "{age sex} -> cancer", ///
    exposure(smoking) outcome(cancer) latent("tar deposits") ///
    nopublish saving(smoking-cancer.dagitty, replace)
fw_dag using smoking-cancer.dagitty, title("Smoking and lung cancer, DAGitty file") ///
    visibility(unlisted)
local url2 `"`r(url)'"'

quietly cd `"`repo'"'
_fw_init
mata: fw_rmtree(st_local("project"))
display as text `"DAG published: `url'"'
display as text `"DAGitty file published: `url2'"'
