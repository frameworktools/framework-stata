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

global FW_TEST_SCAFFOLD_RAN
quietly cd `"$FW_TEST_REPO"'
