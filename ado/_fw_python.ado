*! _fw_python: check the Python backend
*! Part of the framework package. Not for direct use.
*! Returns r(ok), r(why), r(version), r(exec), r(python).
*! Checking initializes Stata's Python for the session.
program define _fw_python, rclass
    version 14
    return scalar ok = 0
    if c(stata_version) < 16 {
        return local why "Stata `c(stata_version)' has no Python integration. The Python backend needs Stata 16 or newer."
        exit
    }
    capture quietly python query
    local exec `"`r(execpath)'"'
    local pyver `"`r(version)'"'
    return local exec `"`exec'"'
    return local python `"`pyver'"'
    * framework-py needs Python 3.11 or newer. python query reads the
    * version without starting Python.
    local old 0
    if regexm(`"`pyver'"', "^([0-9]+)[.]([0-9]+)") {
        local old = (real(regexs(1)) < 3 | (real(regexs(1)) == 3 & real(regexs(2)) < 11))
    }
    if `old' {
        return local why `"Stata's Python is `pyver' ("`exec'"). framework-py needs Python 3.11 or newer. Point Stata at a newer Python with: python set exec <path to python3.11 or newer>"'
        exit
    }
    capture python: import framework
    if _rc {
        if `"`exec'"' == "" {
            return local why "Stata has no Python configured. Point it at Python 3.11 or newer with: python set exec <path to python>"
        }
        else {
            return local why `"framework-py is not installed in Stata's Python. Install it with: "`exec'" -m pip install framework-py"'
        }
        exit
    }
    capture python: import framework, sfi; sfi.Macro.setLocal("pyver", getattr(framework, "__version__", ""))
    return local version `"`pyver'"'
    return scalar ok = 1
end
