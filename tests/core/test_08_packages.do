* Packages: the settings list, fw_packages list, install, and update.
* Installs come from a package folder in tests/fixtures, so no network is
* needed. FW_TEST_ONLINE=1 also installs a package from SSC.

local fixture `"$FW_TEST_REPO/tests/fixtures/stata_pkg"'

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/settings"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  project_name: packages-test" ///
    "  packages: settings/packages.yml"
t_write `"`root'/settings/packages.yml"' ///
    "packages:" ///
    "  project_ado: true" ///
    "  default_packages:" ///
    "    - name: fwdemo" ///
    "      source: net" ///
    `"      url: "`fixture'""' ///
    "    - estout" ///
    "    - sergiocorreia/reghdfe@6.12.3" ///
    "    - name: ftools" ///
    "      repo: sergiocorreia/ftools" ///
    "    - name: dplyr" ///
    "      source: cran" ///
    "      auto_attach: true" ///
    "    - name: polars" ///
    "      source: pypi" ///
    "    - name: broken" ///
    "      source: net" ///
    "    - name: odd" ///
    "      source: conda"
quietly cd `"`root'"'
fw_project, quietly

t_begin packages: the settings list, with shorthand and sources
capture noisily {
    mata: P = fw_packages(fw_S())
    mata: assert(rows(P) == 8)
    mata: assert(P[1, .] == ("fwdemo", "net", st_local("fixture"), ""))
    mata: assert(P[2, .] == ("estout", "ssc", "", ""))
    mata: assert(P[3, .] == ("reghdfe", "github", "https://raw.githubusercontent.com/sergiocorreia/reghdfe/6.12.3/", ""))
    * A repo without a source is GitHub, and without a ref uses the default branch.
    mata: assert(P[4, .] == ("ftools", "github", "https://raw.githubusercontent.com/sergiocorreia/ftools/HEAD/", ""))
    mata: assert(P[5, 4] == "an R package" & P[6, 4] == "a Python package")
    mata: assert(strpos(P[7, 4], "needs url") == 1)
    mata: assert(strpos(P[8, 4], "unknown source: conda") > 0)
    mata: assert(fw_packages_plus(fw_S()) == st_local("root") + "/ado/plus")
}
t_end `=_rc'

t_begin packages: invalid names and refs are rejected
capture noisily {
    mata: assert(fw__package_row("bad;name", "ssc", "", "", "")[4] != "")
    mata: assert(fw__package_row("", "github", "not a repo", "", "")[4] == "needs repo: owner/name")
    mata: assert(strpos(fw__package_row("", "github", "a/b", "x y", "")[4], "invalid ref") > 0)
    mata: assert(fw__package_row("x", "net", "", "", "http://x/" + char(34))[4] == "has quotes in its url")
}
t_end `=_rc'

t_begin packages: fw_packages lists the missing package
capture noisily {
    fw_packages
    t_eq `"`r(packages)'"' "fwdemo estout reghdfe ftools dplyr polars broken odd"
    t_eq `"`r(missing)'"' "fwdemo estout reghdfe ftools"
    t_eq `"`r(installed)'"' ""
    t_eq `"`r(skipped)'"' "dplyr polars broken odd"
    t_eq `"`r(plus)'"' `"`root'/ado/plus"'
}
t_end `=_rc'

t_begin packages: a name not in the settings is an error
capture fw_packages list nosuchpkg
local rc = _rc
t_end `=(`rc' != 111)'

t_begin packages: install puts the package in the project's ado/plus
capture noisily {
    local plus_before `"`c(sysdir_plus)'"'
    fw_packages install fwdemo
    t_eq `"`r(installed)'"' "fwdemo"
    t_eq `"`r(failed)'"' ""
    confirm file `"`root'/ado/plus/f/fwdemo.ado"'
    * PLUS is put back after the install.
    t_eq `"`c(sysdir_plus)'"' `"`plus_before'"'
    fw_packages list fwdemo
    t_eq `"`r(installed)'"' "fwdemo"
    t_eq `"`r(missing)'"' ""
}
t_end `=_rc'

t_begin packages: install skips installed packages, and update reinstalls
capture noisily {
    fw_packages install fwdemo
    t_eq `"`r(installed)'"' "fwdemo"
    fw_packages update fwdemo, quietly
    t_eq `"`r(installed)'"' "fwdemo"
    t_eq `"`r(failed)'"' ""
}
t_end `=_rc'

t_begin packages: a failed install is reported after the others are tried
capture noisily {
    t_write `"`root'/settings/packages.yml"' ///
        "packages:" ///
        "  project_ado: true" ///
        "  default_packages:" ///
        "    - name: nosuchpkg" ///
        "      source: net" ///
        `"      url: "`fixture'""' ///
        "    - name: fwdemo" ///
        "      source: net" ///
        `"      url: "`fixture'""'
    fw_project, quietly
    capture noisily fw_packages update
    assert _rc != 0
    * r() is cleared by the error, so check the folder.
    confirm file `"`root'/ado/plus/f/fwdemo.ado"'
}
t_end `=_rc'

t_begin packages: without project_ado, Stata's PLUS folder is checked
capture noisily {
    t_write `"`root'/settings/packages.yml"' ///
        "packages:" ///
        "  - fwdemo"
    fw_project, quietly
    fw_packages, quietly
    t_eq `"`r(plus)'"' `"`c(sysdir_plus)'"'
    t_eq `"`r(packages)'"' "fwdemo"
}
t_end `=_rc'

t_begin packages: a project without packages
capture noisily {
    t_write `"`root'/settings.yml"' ///
        "default:" ///
        "  project_name: packages-test"
    fw_project, quietly
    fw_packages
    t_eq `"`r(packages)'"' ""
}
t_end `=_rc'

local online : environment FW_TEST_ONLINE
if "`online'" == "1" {
    t_begin packages: install from SSC into the project
    capture noisily {
        t_write `"`root'/settings.yml"' ///
            "default:" ///
            "  project_name: packages-test" ///
            "  packages:" ///
            "    project_ado: true" ///
            "    default_packages:" ///
            "      - estout"
        fw_project, quietly
        fw_packages install
        t_eq `"`r(installed)'"' "estout"
        confirm file `"`root'/ado/plus/e/esttab.ado"'
    }
    t_end `=_rc'
}
else t_skip "packages: install from SSC (set FW_TEST_ONLINE=1)"

quietly cd `"$FW_TEST_REPO"'
