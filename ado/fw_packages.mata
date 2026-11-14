*! fw_packages.mata: the packages a project lists, and fw_scaffold's settings
*! Loaded by _fw_init. Do not run directly.
*
* Reads the packages section R writes to settings/packages.yml:
*
*   packages:
*     project_ado: true
*     default_packages:
*       - name: estout
*         source: ssc
*       - name: reghdfe
*         source: github
*         repo: sergiocorreia/reghdfe
*         ref: 6.12.3
*       - name: mypkg
*         source: net
*         url: https://example.org/stata
*
* A plain string is shorthand: "estout" is an SSC package, and
* "owner/repo" or "owner/repo@ref" is a GitHub one. A flat packages: list,
* the older R layout, is read too. Entries for R and Python (cran, bioc,
* pypi) are listed and skipped.

version 14

mata:
mata set matastrict off

// The settings key that holds the package list, or "".
string scalar fw__packages_key(transmorphic S)
{
    if (asarray(S, "packages.default_packages.#") != "") return("packages.default_packages")
    if (asarray(S, "packages.#") != "") return("packages")
    return("")
}

// One row per package: name, source, from, problem. from is the folder or
// URL net install reads for github and net packages. problem says why the
// entry cannot be installed from Stata, or is "".
string matrix fw_packages(transmorphic S)
{
    key = fw__packages_key(S)
    out = J(0, 4, "")
    if (key == "") return(out)
    n = strtoreal(asarray(S, key + ".#"))
    for (i = 0; i < n; i++) {
        p = key + "." + strofreal(i)
        name = source = repo = ref = url = ""
        if (asarray(S, p + ".@") != "") {
            name = strtrim(fw_setting(S, p + ".name"))
            source = strlower(strtrim(fw_setting(S, p + ".source")))
            repo = strtrim(fw_setting(S, p + ".repo"))
            ref = strtrim(fw_setting(S, p + ".ref"))
            url = strtrim(fw_setting(S, p + ".url"))
            if (source == "") source = (url != "" ? "net" : (repo != "" ? "github" : "ssc"))
        }
        else {
            v = strtrim(fw_setting(S, p))
            if (strpos(v, "/")) {
                source = "github"
                at = strpos(v, "@")
                repo = (at ? substr(v, 1, at - 1) : v)
                ref = (at ? substr(v, at + 1, .) : "")
            }
            else {
                source = "ssc"
                name = v
            }
        }
        out = out \ fw__package_row(name, source, repo, ref, url)
    }
    return(out)
}

string rowvector fw__package_row(string scalar name_in, string scalar source,
    string scalar repo, string scalar ref, string scalar url)
{
    name = name_in
    from = problem = ""
    if (source == "github") {
        if (!regexm(repo, "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) {
            problem = "needs repo: owner/name"
        }
        else if (ref != "" & !regexm(ref, "^[A-Za-z0-9_./-]+$")) {
            problem = "has an invalid ref: " + ref
        }
        else {
            if (name == "") name = substr(repo, strpos(repo, "/") + 1, .)
            from = "https://raw.githubusercontent.com/" + repo + "/" + (ref == "" ? "HEAD" : ref) + "/"
        }
    }
    else if (source == "net") {
        if (url == "") problem = "needs url: the folder or web address that holds " + name + ".pkg"
        else if (regexm(url, "[" + fw_dq() + char(96) + char(39) + "]")) problem = "has quotes in its url"
        else from = url
    }
    else if (anyof(("cran", "bioc"), source)) problem = "an R package"
    else if (source == "pypi") problem = "a Python package"
    else if (source != "ssc") problem = "has an unknown source: " + source + ". Use ssc, github, or net."
    if (problem == "" & !regexm(name, "^[A-Za-z_][A-Za-z0-9_]*$")) {
        problem = (name == "" ? "has no name" : "has an invalid name for a Stata package")
    }
    if (name == "") name = (repo != "" ? repo : "(no name)")
    return((name, source, from, problem))
}

// The folder packages install into when the project keeps its own
// (packages: project_ado: true), else "".
string scalar fw_packages_plus(transmorphic S)
{
    if (!fw_truthy(fw_setting(S, "packages.project_ado"))) return("")
    return(asarray(S, "__root") + "/ado/plus")
}

// Whether net install recorded the package in the folder's stata.trk.
// ado describe, from() does not fail for a missing package, so the record
// is read directly. Each installed package has a line "N name.pkg".
real scalar fw_package_installed(string scalar folder, string scalar name)
{
    trk = fw_norm(folder) + "/stata.trk"
    if (!fileexists(trk)) return(0)
    lines = strlower(strtrim(fw_readlines(trk)))
    return(anyof(lines, "n " + strlower(name) + ".pkg"))
}

// Put the project's packages in locals for fw_packages: fw_n, then
// fw_name#, fw_source#, fw_from#, and fw_problem# for each, and fw_plus.
void fw_packages_locals()
{
    S = fw_S()
    P = fw_packages(S)
    st_local("fw_n", strofreal(rows(P)))
    for (i = 1; i <= rows(P); i++) {
        st_local("fw_name" + strofreal(i), P[i, 1])
        st_local("fw_source" + strofreal(i), P[i, 2])
        st_local("fw_from" + strofreal(i), P[i, 3])
        st_local("fw_problem" + strofreal(i), P[i, 4])
    }
    st_local("fw_plus", fw_packages_plus(S))
    st_local("fw_settings_file", fw_relpath(asarray(S, "__file"), asarray(S, "__root")))
}

// ---------------------------------------------------------------------------
// fw_scaffold: what R's scaffold() reads, from the same settings
// ---------------------------------------------------------------------------

// A scaffold setting: scaffold.<key>, then options.<key>, then <key>, as R
// reads them (new projects write scaffold:, older ones options: or the top).
string scalar fw__scaffold_setting(transmorphic S, string scalar key)
{
    keys = ("scaffold." + key, "options." + key, key)
    for (i = 1; i <= cols(keys); i++) {
        v = strtrim(fw_setting(S, keys[i]))
        if (v != "") return(v)
    }
    return("")
}

real scalar fw__falsy(string scalar v) return(anyof(("false", "no", "off", "0"), strlower(strtrim(v))))

// The seed fw_scaffold sets, or "" for none, with R's rules: an explicit
// seed_on_scaffold: false skips seeding even when FW_SEED is set; without a
// project setting, FW_SEED turns it on. The project's seed wins over FW_SEED,
// and the fallback is 123.
string scalar fw_scaffold_seed(transmorphic S)
{
    on = fw__scaffold_setting(S, "seed_on_scaffold")
    envseed = strtrim(fw_env("FW_SEED"))
    if (fw__falsy(on)) return("")
    if (on == "" & envseed == "") return("")
    seed = fw__scaffold_setting(S, "seed")
    if (!regexm(seed, "^[0-9]+$")) seed = (regexm(envseed, "^[0-9]+$") ? envseed : "123")
    if (strtoreal(seed) > 2147483647) fw_error("The seed " + seed + " is too large. Stata takes 0 to 2147483647.", 198)
    return(seed)
}

// The graph scheme to set, or "": stata_scheme, when set_theme_on_scaffold is on.
string scalar fw_scaffold_scheme(transmorphic S)
{
    if (!fw_truthy(fw__scaffold_setting(S, "set_theme_on_scaffold"))) return("")
    scheme = fw__scaffold_setting(S, "stata_scheme")
    if (scheme != "" & !regexm(scheme, "^[A-Za-z0-9_]+$")) fw_error("stata_scheme " + scheme + " is not a scheme name.", 198)
    return(scheme)
}

// The function folders that exist: directories.functions (one folder or a
// list), else functions, unless source_all_functions is false.
string colvector fw_scaffold_functions(transmorphic S)
{
    root = asarray(S, "__root")
    out = J(0, 1, "")
    if (fw__falsy(fw__scaffold_setting(S, "source_all_functions"))) return(out)
    names = fw_children(S, "directories.functions")
    if (cols(names)) {
        dirs = J(cols(names), 1, "")
        for (i = 1; i <= cols(names); i++) dirs[i] = fw_setting(S, "directories.functions." + names[i])
    }
    else {
        dirs = fw_setting(S, "directories.functions")
        if (dirs == "") dirs = "functions"
    }
    for (i = 1; i <= rows(dirs); i++) {
        d = fw_abs(dirs[i], root)
        if (dirs[i] != "" & direxists(d)) out = out \ d
    }
    return(out)
}

// Locals for fw_scaffold: fw_seed, fw_scheme, fw_plus, fw_script, and
// fw_nfunc with fw_func# for each function folder.
void fw_scaffold_locals()
{
    S = fw_S()
    root = asarray(S, "__root")
    st_local("fw_seed", fw_scaffold_seed(S))
    st_local("fw_scheme", fw_scaffold_scheme(S))
    st_local("fw_plus", fw_packages_plus(S))
    st_local("fw_script", fileexists(root + "/scaffold.do") ? root + "/scaffold.do" : "")
    F = fw_scaffold_functions(S)
    st_local("fw_nfunc", strofreal(rows(F)))
    for (i = 1; i <= rows(F); i++) {
        st_local("fw_func" + strofreal(i), F[i])
        st_local("fw_funcrel" + strofreal(i), fw_relpath(F[i], root))
    }
    st_local("fw_npkg", strofreal(rows(fw_packages(S))))
}

end
