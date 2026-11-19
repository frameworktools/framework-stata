* fw_scaffold: seed, scheme, function folders, project packages, scaffold.do.

local fixture `"$FW_TEST_REPO/tests/fixtures/stata_pkg"'
local plus_before `"`c(sysdir_plus)'"'
local scheme_before `"`c(scheme)'"'

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/functions"'
mkdir `"`root'/helpers"'
t_write `"`root'/functions/fwtest_double.ado"' ///
    "program define fwtest_double, rclass" ///
    "    return scalar y = 42" ///
    "end"
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  project_name: scaffold-test" ///
    "  scaffold:" ///
    "    seed_on_scaffold: true" ///
    "    seed: 4242" ///
    "    set_theme_on_scaffold: true" ///
    "    stata_scheme: s1mono" ///
    "  packages:" ///
    "    project_ado: true" ///
    "    default_packages:" ///
    "      - name: fwdemo" ///
    "        source: net" ///
    `"        url: "`fixture'""'
t_write `"`root'/scaffold.do"' "global FW_TEST_SCAFFOLD_RAN yes"
quietly cd `"`root'"'

t_begin scaffold: seed, scheme, packages, functions, and scaffold.do
capture noisily {
    global FW_TEST_SCAFFOLD_RAN
    fw_scaffold
    t_eq `"`r(seed)'"' "4242"
    t_eq `"`r(scheme)'"' "s1mono"
    t_eq `"`c(scheme)'"' "s1mono"
    t_eq `"`r(plus)'"' `"`root'/ado/plus"'
    mata: assert(fw_norm(c("sysdir_plus")) == st_local("root") + "/ado/plus")
    * The missing package was installed into the project, and runs
    confirm file `"`root'/ado/plus/f/fwdemo.ado"'
    fwdemo
    t_eq `"`r(ok)'"' "yes"
    * A program in functions/ runs by name
    fwtest_double
    assert r(y) == 42
    t_eq `"$FW_TEST_SCAFFOLD_RAN"' "yes"
    * The seed makes draws repeat
    local a = runiform()
    set seed 4242
    local b = runiform()
    fw_scaffold, quietly noinstall
    local c = runiform()
    assert `a' == `b' & `b' == `c'
}
local rc = _rc
quietly sysdir set PLUS `"`plus_before'"'
* fw_scaffold put framework's folders from that PLUS on the ado-path when
* framework is installed there (FW_TEST_NETINSTALL=1). PLUS covers them again.
mata: st_local("pb", fw_norm(st_local("plus_before")))
foreach d in f _ {
    capture quietly adopath - `"`pb'/`d'"'
}
quietly set scheme `scheme_before'
t_end `rc'

t_begin scaffold: R's rules for the seed and FW_SEED
capture noisily {
    mata: S = asarray_create(); asarray_notfound(S, "")
    mata: assert(fw_scaffold_seed(S) == "")
    mata: asarray(S, "scaffold.seed_on_scaffold", "true")
    mata: assert(fw_scaffold_seed(S) == "123")
    mata: asarray(S, "options.seed", "7")
    mata: assert(fw_scaffold_seed(S) == "7")
    mata: asarray(S, "scaffold.seed", "9")
    mata: assert(fw_scaffold_seed(S) == "9")
    mata: asarray(S, "scaffold.seed_on_scaffold", "false")
    mata: assert(fw_scaffold_seed(S) == "")
    mata: assert(fw_scaffold_scheme(S) == "")
    mata: asarray(S, "scaffold.set_theme_on_scaffold", "true")
    mata: asarray(S, "scaffold.stata_scheme", "s2color")
    mata: assert(fw_scaffold_scheme(S) == "s2color")
}
t_end `=_rc'

t_begin scaffold: a list of function folders, and source_all_functions: false
capture noisily {
    t_write `"`root'/settings.yml"' ///
        "default:" ///
        "  project_name: scaffold-test" ///
        "  directories:" ///
        "    functions:" ///
        "      - functions" ///
        "      - helpers" ///
        "      - missing"
    fw_scaffold, quietly
    local funcs `"`r(functions)'"'
    assert `: word count `funcs'' == 2
    gettoken f1 rest : funcs
    gettoken f2 : rest
    t_eq `"`f1'"' `"`root'/functions"'
    t_eq `"`f2'"' `"`root'/helpers"'
    t_eq `"`r(seed)'`r(scheme)'`r(plus)'"' ""
    t_write `"`root'/settings.yml"' ///
        "default:" ///
        "  project_name: scaffold-test" ///
        "  scaffold:" ///
        "    source_all_functions: false"
    fw_scaffold, quietly
    t_eq `"`r(functions)'"' ""
}
t_end `=_rc'

t_begin scaffold: an unknown scheme leaves the scheme as it was
capture noisily {
    t_write `"`root'/settings.yml"' ///
        "default:" ///
        "  project_name: scaffold-test" ///
        "  scaffold:" ///
        "    set_theme_on_scaffold: true" ///
        "    stata_scheme: nosuchscheme"
    fw_scaffold, quietly
    t_eq `"`r(scheme)'"' ""
    t_eq `"`c(scheme)'"' `"`scheme_before'"'
}
t_end `=_rc'

* Framework installed in the shared PLUS folder, as users install it. With
* project_ado on, fw_scaffold points PLUS at the project's ado/plus. Framework
* commands not yet loaded must still run, also after clear all.
t_begin scaffold: framework stays on the ado-path when PLUS moves to the project
local shared
local devpath 0
capture noisily {
    t_tmpdir
    local shared `"`r(dir)'"'
    t_tmpdir
    local proj `"`r(dir)'"'
    quietly sysdir set PLUS `"`shared'"'
    quietly net install framework, from(`"$FW_TEST_REPO"')
    * A shared copy of fwdemo, in plus/f with framework, and a package that
    * the project does not list, in plus/z
    quietly net install fwdemo, from(`"`fixture'"')
    mkdir `"`shared'/z"'
    t_write `"`shared'/z/zzfwshared.ado"' "program define zzfwshared" "end"
    * Only the installed copy of framework is on the ado-path.
    mata: st_local("devpath", strofreal(anyof(tokens(st_global("S_ADO"), ";"), st_global("FW_TEST_REPO") + "/ado")))
    if `devpath' quietly adopath - `"$FW_TEST_REPO/ado"'
    t_write `"`proj'/settings.yml"' ///
        "default:" ///
        "  project_name: scaffold-plus-test" ///
        "  packages:" ///
        "    project_ado: true" ///
        "    default_packages:" ///
        "      - name: fwdemo" ///
        "        source: net" ///
        `"        url: "`fixture'""'
    quietly cd `"`proj'"'
    * A fresh session: no framework program or Mata function is loaded.
    clear all
    quietly do `"$FW_TEST_REPO/tests/harness.do"'
    fw_scaffold, quietly
    mata: assert(fw_norm(c("sysdir_plus")) == st_local("proj") + "/ado/plus")
    * Framework commands that were not loaded come from the shared folder.
    findfile fw_use.ado
    t_eq `"`r(fn)'"' `"`shared'/f/fw_use.ado"'
    which fw_save
    * The project's packages come first.
    findfile fwdemo.ado
    t_eq `"`r(fn)'"' `"`proj'/ado/plus/f/fwdemo.ado"'
    * The rest of the shared folder is off the ado-path.
    capture which zzfwshared
    assert _rc == 111
    * clear all drops programs and Mata, and keeps the ado-path and PLUS.
    clear all
    quietly do `"$FW_TEST_REPO/tests/harness.do"'
    which fw_use
    fw_project, quietly
    t_eq `"$fw_root"' `"`proj'"'
    mata: assert(fw_norm(c("sysdir_plus")) == st_local("proj") + "/ado/plus")
    * Scaffolding again adds no ado-path entries.
    mata: st_local("n1", strofreal(cols(tokens(st_global("S_ADO"), ";"))))
    fw_scaffold, quietly
    mata: st_local("n2", strofreal(cols(tokens(st_global("S_ADO"), ";"))))
    assert `n1' == `n2'
}
local rc = _rc
* Back to the repository's framework and the PLUS folder from before
quietly sysdir set PLUS `"`plus_before'"'
if `"`shared'"' != "" {
    foreach d in f _ {
        capture quietly adopath - `"`shared'/`d''"'
    }
}
if `devpath' quietly adopath ++ `"$FW_TEST_REPO/ado"'
clear all
quietly do `"$FW_TEST_REPO/tests/harness.do"'
quietly cd `"$FW_TEST_REPO"'
t_end `rc'

global FW_TEST_SCAFFOLD_RAN
quietly cd `"$FW_TEST_REPO"'
