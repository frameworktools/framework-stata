* Test helpers for tests/run.do

capture program drop t_begin
program define t_begin
    global T_NAME `"`0'"'
end

capture program drop t_end
program define t_end
    args rc
    if "`rc'" == "" local rc 0
    if `rc' == 0 {
        global T_PASS = $T_PASS + 1
        display as result "PASS " as text `"$T_NAME"'
    }
    else {
        global T_FAIL = $T_FAIL + 1
        global T_FAILED `"$T_FAILED [$T_NAME]"'
        display as error "FAIL (rc=`rc') " as text `"$T_NAME"'
    }
end

capture program drop t_skip
program define t_skip
    global T_SKIP = $T_SKIP + 1
    display as text "SKIP " `"`0'"'
end

* A new empty folder under the temporary directory. Returns r(dir).
capture program drop t_tmpdir
program define t_tmpdir, rclass
    tempfile f
    local base = subinstr(`"`f'"', "\", "/", .)
    local i 1
    while 1 {
        capture mkdir `"`base'_t`i'"'
        if !_rc continue, break
        local ++i
    }
    * tests/run.do removes these folders at the end.
    global T_TMPDIRS `"$T_TMPDIRS `"`base'_t`i'"'"'
    return local dir `"`base'_t`i'"'
end

* Remove the folders t_tmpdir made, and any others given.
capture program drop t_cleanup
program define t_cleanup
    _fw_init
    local dirs `"$T_TMPDIRS `0'"'
    foreach d of local dirs {
        mata: fw_rmtree(st_local("d"))
        mata: st_local("left", strofreal(direxists(st_local("d"))))
        if `left' display as text `"Could not remove `d'"'
    }
    global T_TMPDIRS
end

* Write lines to a file: t_write "path" "line1" "line2" ...
capture program drop t_write
program define t_write
    gettoken path 0 : 0
    tempname fh
    file open `fh' using `"`path'"', write text replace
    while `"`0'"' != "" {
        gettoken line 0 : 0
        file write `fh' `"`line'"' _n
    }
    file close `fh'
end

* Fail unless two strings are equal.
capture program drop t_eq
program define t_eq
    args got want
    if `"`got'"' != `"`want'"' {
        display as error `"  expected: `want'"'
        display as error `"  got:      `got'"'
        exit 9
    }
end

* Capture output in a log: t_log_begin, commands, t_log_end, then t_log_has.
capture program drop t_log_begin
program define t_log_begin
    capture log close t_capture
    t_tmpdir
    global T_LOG `"`r(dir)'/out.log"'
    quietly log using `"$T_LOG"', text replace name(t_capture)
end

capture program drop t_log_end
program define t_log_end
    capture log close t_capture
end

* Fail unless the captured output contains the text.
capture program drop t_log_has
program define t_log_has
    args text
    mata: st_local("found", strofreal(strpos(fw_readfile(st_global("T_LOG")), st_local("text")) > 0))
    if !`found' {
        display as error `"  not in the output: `text'"'
        exit 9
    }
end

* Fail if the captured output contains the text.
capture program drop t_log_lacks
program define t_log_lacks
    args text
    mata: st_local("found", strofreal(strpos(fw_readfile(st_global("T_LOG")), st_local("text")) > 0))
    if `found' {
        display as error `"  unexpected in the output: `text'"'
        exit 9
    }
end
