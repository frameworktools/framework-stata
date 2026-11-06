*! _fw_backend: choose the backend for a publish
*! Part of the framework package. Not for direct use.
*! Returns r(backend) core, cli, or python, and r(fw) for the CLI.
program define _fw_backend, rclass
    version 14
    syntax , DRIVER(string)
    _fw_init
    local pref `"$FW_BACKEND"'
    if `"`pref'"' == "" mata: st_local("pref", fw_conf_get("backend"))
    if `"`pref'"' == "" local pref auto
    local pref = lower(`"`pref'"')
    if !inlist("`pref'", "auto", "core", "cli", "python") {
        display as error `"The backend setting is "`pref'". Use auto, core, cli, or python: fw_set backend auto"'
        exit 198
    }
    local external = inlist("`driver'", "github", "s3")
    mata: st_local("fwexe", fw_find_fw_quick())

    if "`pref'" == "core" {
        if `external' {
            display as error "Publishing to `driver' needs the CLI or Python backend, and fw_set backend core turns them off."
            display as error "Run: fw_set backend auto"
            exit 198
        }
        return local backend core
        exit
    }
    if "`pref'" == "cli" {
        if `"`fwexe'"' == "" {
            display as error "fw_set backend cli needs fw, and fw was not found."
            mata: st_local("stale", fw_fw_path_stale())
            if `"`stale'"' != "" display as error `"The fw_path setting points to `stale', which no longer exists."'
            display as error "Install fw (https://framework.pub/docs/cli), or tell Stata where it is: fw_set fw_path <path to fw>"
            exit 601
        }
        return local backend cli
        return local fw `"`fwexe'"'
        exit
    }
    if "`pref'" == "python" {
        _fw_python
        if !r(ok) {
            display as error "fw_set backend python is not usable: `r(why)'"
            exit 601
        }
        return local backend python
        exit
    }
    * auto: the core handles folders and Framework Cloud itself.
    if !`external' {
        return local backend core
        exit
    }
    if `"`fwexe'"' != "" {
        return local backend cli
        return local fw `"`fwexe'"'
        exit
    }
    _fw_python
    if r(ok) {
        return local backend python
        exit
    }
    local why `"`r(why)'"'
    display as error "Publishing to `driver' needs the CLI or Python backend. Neither is available."
    display as error "  CLI:    install fw from https://framework.pub/docs/cli"
    display as error `"  Python: `why'"'
    display as error "Run fw_setup for details."
    exit 601
end
