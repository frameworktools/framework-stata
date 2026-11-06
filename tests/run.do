* Framework for Stata test runner.
* Run from the repository root:  stata -b do tests/run.do
* Optional: global FW_TEST_LAYERS "core cli python" (default: all available)

version 14
clear all
set more off
set linesize 120

local repo = subinstr(`"`c(pwd)'"', "\", "/", .)
capture confirm file `"`repo'/ado/fw_core.mata"'
if _rc {
    display as error "Run tests/run.do from the repository root."
    exit 601
}
* FW_TEST_NETINSTALL=1 installs the package with net install into a
* temporary PLUS folder and tests the installed copy.
local netinstall : environment FW_TEST_NETINSTALL
if "`netinstall'" == "1" {
    tempfile plus
    local plus = subinstr("`plus'", "\", "/", .) + "_plus"
    mkdir "`plus'"
    sysdir set PLUS "`plus'"
    net install framework, from(`"`repo'"') replace
    which fw_publish
}
else adopath ++ `"`repo'/ado"'
global FW_TEST_REPO `"`repo'"'
global T_PASS 0
global T_FAIL 0
global T_SKIP 0
global T_FAILED ""
global T_TMPDIRS ""
do `"`repo'/tests/harness.do"'

local files : dir `"`repo'/tests/core"' files "test_*.do"
local files : list sort files
foreach f of local files {
    display as text _n "{hline}" _n "core/`f'" _n "{hline}"
    capture noisily do `"`repo'/tests/core/`f'"'
    if _rc {
        global T_FAIL = $T_FAIL + 1
        global T_FAILED `"$T_FAILED [core/`f' stopped with rc=`=_rc']"'
    }
}
foreach layer in cli python {
    capture confirm file `"`repo'/tests/`layer'/run_`layer'.do"'
    if _rc continue
    display as text _n "{hline}" _n "`layer' backend" _n "{hline}"
    capture noisily do `"`repo'/tests/`layer'/run_`layer'.do"'
    if _rc {
        global T_FAIL = $T_FAIL + 1
        global T_FAILED `"$T_FAILED [`layer' stopped with rc=`=_rc']"'
    }
}

* Leave nothing in the temporary folder: test projects, the example
* project, and the net install folder.
quietly cd `"`repo'"'
local leftovers `"$FW_EXAMPLE_PROJECT"'
if "`netinstall'" == "1" local leftovers `"`leftovers' `"`plus'"'"'
t_cleanup `leftovers'

display as text _n "{hline}"
display as text "Framework for Stata tests on Stata " c(stata_version) " (" c(os) ")"
display as result "  passed:  $T_PASS"
display as text   "  skipped: $T_SKIP"
if $T_FAIL {
    display as error  "  failed:  $T_FAIL"
    display as error `"    $T_FAILED"'
    display as text "{hline}"
    display as error "TESTS FAILED"
    exit 9
}
display as result "  failed:  0"
display as text "{hline}"
display as result "ALL TESTS PASSED"
