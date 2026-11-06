* The CLI backend: fw_publish through fw.

_fw_init
mata: st_local("fwexe", fw_find_fw_quick())
if `"`fwexe'"' == "" {
    t_skip "cli: fw was not found on the PATH"
    exit
}
display as text "Using fw at `fwexe'"

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
global FW_BACKEND cli

t_begin cli: fw_publish delivers a figure through fw
capture noisily {
    fw_publish "outputs/figure.png", title("Figure from fw")
    t_eq `"`r(backend)'"' "cli"
    confirm file `"`root'/site/figure/artifact.json"'
    mata: A = fw_json_read(st_local("root") + "/site/figure/artifact.json")
    mata: assert(fw_startswith(fw_get(A, "generator"), "framework-cli"))
    mata: assert(fw_get(A, "title") == "Figure from fw")
    * Every backend reports the same results.
    t_eq `"`r(version)'"' "1"
    t_eq `"`r(slug)'"' "figure"
    t_eq `"`r(location)'"' `"`root'/site/figure"'
    t_eq `"`r(file)'"' `"`root'/outputs/figure.png"'
}
t_end `=_rc'

t_begin cli: estimates publish as a model through fw
capture noisily {
    sysuse auto, clear
    logit foreign mpg
    fw_publish, estimates slug(foreign-model)
    confirm file `"`root'/site/foreign-model/representation.json"'
    mata: A = fw_json_read(st_local("root") + "/site/foreign-model/artifact.json")
    mata: assert(fw_get(A, "kind") == "model")
    mata: assert(fw_get(A, "source.language") == "stata")
}
t_end `=_rc'

t_begin cli: confirmed private paths pass --include-private
capture noisily {
    mkdir `"`root'/outputs/private"'
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/outputs/private/p.png"'
    capture fw_publish "outputs/private/p.png"
    assert _rc == 198
    fw_publish "outputs/private/p.png", includeprivate
    confirm file `"`root'/site/p/artifact.json"'
}
t_end `=_rc'

t_begin cli: fw errors come back as Stata errors
capture noisily {
    * Stata's own checks pass this call (they stop with 198). fw rejects
    * the visibility, and Stata reports fw's message with error 677.
    t_log_begin
    capture noisily fw_publish "outputs/figure.png", visibility(private)
    local rc = _rc
    t_log_end
    assert `rc' == 677
    t_log_has "fw publish failed"
}
t_end `=_rc'

t_begin cli: fw_setup describes the cli backend
capture noisily {
    t_log_begin
    fw_setup, nopython nonetwork
    t_log_end
    t_log_has "Every publish goes through fw."
    t_log_lacks "folder and Cloud publishing"
}
t_end `=_rc'

t_begin cli: a stale fw_path falls back to the PATH and is named
capture noisily {
    t_tmpdir
    local gone `"`r(dir)'/fw"'
    t_write `"`gone'"' "#!/bin/sh"
    fw_set fw_path `"`gone'"'
    erase `"`gone'"'
    t_log_begin
    fw_set
    fw_setup, nopython nonetwork
    t_log_end
    t_log_has "no longer exists"
    fw_publish "outputs/figure.png", slug(stale-path)
    t_eq `"`r(backend)'"' "cli"
    fw_set fw_path clear
}
local rc = _rc
capture fw_set fw_path clear
t_end `rc'

global FW_BACKEND
quietly cd `"$FW_TEST_REPO"'
