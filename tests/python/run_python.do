* The Python backend: fw_publish through framework-py in Stata's Python.

if c(stata_version) < 16 {
    t_skip "python: needs Stata 16 or newer"
    exit
}
local exe : environment FW_TEST_PYTHON
if `"`exe'"' == "" {
    t_skip "python: set FW_TEST_PYTHON to a Python with framework-py installed"
    exit
}
t_begin python: an old Python gets version advice, not pip advice
capture noisily {
    * python query reads the version without starting Python, so this
    * runs before python set exec below.
    quietly python query
    local v `"`r(version)'"'
    if regexm(`"`v'"', "^3[.]([0-9]+)") & real(regexs(1)) < 11 {
        _fw_python
        assert r(ok) == 0
        assert strpos(`"`r(why)'"', "needs Python 3.11 or newer")
        assert !strpos(`"`r(why)'"', "pip install")
    }
    else display as text "Stata's default Python is `v'; nothing to check."
}
t_end `=_rc'

* Stata needs an interpreter built with a shared libpython. A virtual
* environment's packages are added with python set userpath.
python set exec `"`exe'"'
local site : environment FW_TEST_PYTHONPATH
if `"`site'"' != "" python set userpath `"`site'"', prepend

t_begin python: _fw_python finds framework-py
capture noisily {
    _fw_python
    assert r(ok) == 1
    display "framework-py `r(version)' at `r(exec)'"
}
t_end `=_rc'

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/outputs"'
copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/outputs/figure.png"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  directories:" ///
    "    outputs: outputs" ///
    "  publish:" ///
    "    default: lab" ///
    "    destinations:" ///
    "      lab:" ///
    "        driver: folder" ///
    "        path: site" ///
    "        visibility: public"
quietly cd `"`root'"'
fw_project, quietly
global FW_BACKEND python

t_begin python: fw_publish delivers a figure through framework-py
capture noisily {
    fw_publish "outputs/figure.png", title("Figure from Python")
    t_eq `"`r(backend)'"' "python"
    confirm file `"`root'/site/figure/artifact.json"'
    mata: A = fw_json_read(st_local("root") + "/site/figure/artifact.json")
    mata: assert(fw_startswith(fw_get(A, "generator"), "framework-py"))
    mata: assert(fw_get(A, "title") == "Figure from Python")
    * Every backend reports the same results.
    t_eq `"`r(version)'"' "1"
    t_eq `"`r(slug)'"' "figure"
    t_eq `"`r(location)'"' `"`root'/site/figure"'
    t_eq `"`r(file)'"' `"`root'/outputs/figure.png"'
    fw_publish "outputs/figure.png", title("Figure from Python")
    t_eq `"`r(version)'"' "2"
    t_eq `"`r(version_url)'"' ""
}
t_end `=_rc'

t_begin python: estimates publish as a model through framework-py
capture noisily {
    sysuse auto, clear
    poisson rep78 mpg
    fw_publish, estimates slug(rep-model)
    confirm file `"`root'/site/rep-model/representation.json"'
    mata: A = fw_json_read(st_local("root") + "/site/rep-model/artifact.json")
    mata: assert(fw_get(A, "kind") == "model")
    mata: assert(fw_get(A, "source.language") == "stata")
}
t_end `=_rc'

t_begin python: framework-py errors come back as Stata errors
capture noisily {
    * Stata's own checks pass this call (they stop with 198).
    * framework-py rejects the visibility, and Stata reports its message
    * with error 677.
    t_log_begin
    capture noisily fw_publish "outputs/figure.png", visibility(private)
    local rc = _rc
    t_log_end
    assert `rc' == 677
    t_log_has "framework-py:"
}
t_end `=_rc'

t_begin python: a folder publishes as one artifact through framework-py
capture noisily {
    mkdir `"`root'/outputs/set"'
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/outputs/set/a.png"'
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/outputs/set/b.png"'
    fw_publish "outputs/set", slug(py-set)
    t_eq `"`r(backend)'"' "python"
    t_eq `"`r(slug)'"' "py-set"
    confirm file `"`root'/site/py-set/a.png"'
    confirm file `"`root'/site/py-set/b.png"'
}
t_end `=_rc'

global FW_BACKEND
quietly cd `"$FW_TEST_REPO"'
