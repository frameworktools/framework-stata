* Code snippets: fw_snippet, and the split of SMCL logs captured from real
* Stata runs (tests/fixtures/snippets, made by capture.do there).

_fw_init
capture log close fw_snippet
global fw__snippet_label
global fw__snippet_dir
local fx `"$FW_TEST_REPO/tests/fixtures/snippets"'

t_begin snippet: a regression is one code block and its SMCL output
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/regress.smcl"))
    mata: assert(rows(B) == 2)
    mata: assert(B[., 1] == ("code" \ "output"))
    mata: assert(B[1, 2] == "regress price mpg i.foreign")
    * The output goes unchanged, in the style the echo left.
    mata: assert(fw_startswith(B[2, 2], "{com}" + char(10) + "{txt}      Source {c |}"))
    mata: assert(strpos(B[2, 2], "{hline 13}{c TT}") > 0)
    mata: assert(strpos(B[2, 2], "{res}{space 2}-294.1955") > 0)
    * The fw_snippet end line and the log trailer are left out.
    mata: assert(strpos(B[2, 2], "fw_snippet") == 0)
    mata: assert(strpos(B[2, 2], "{smcl}") == 0)
}
t_end `=_rc'

t_begin snippet: each command with output gets its own blocks
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/tabulate.smcl"))
    mata: assert(B[., 1] == ("code" \ "output" \ "code" \ "output"))
    mata: assert(B[1, 2] == "tabulate rep78 foreign")
    mata: assert(B[3, 2] == "list make price in 1/3")
    mata: assert(strpos(B[2, 2], "{hline 11}{c +}{hline 22}{c +}{hline 10}") > 0)
    mata: assert(strpos(B[4, 2], "{c TLC}{hline 13}") > 0)
    * The row numbers of list are output, not commands.
    mata: assert(strpos(B[4, 2], "  1. {c |} {res}AMC Concord") > 0)
}
t_end `=_rc'

t_begin snippet: a continued command keeps its continuation lines
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/continued.smcl"))
    mata: assert(B[., 1] == ("code" \ "output"))
    * A do-file reads three slashes as a continuation, even inside quotes.
    mata: c3 = "//" + "/"
    mata: assert(B[1, 2] == "regress price mpg " + c3 + char(10) + "    weight " + c3 + char(10) + "    length, noheader")
    mata: assert(strpos(B[2, 2], "weight {c |}") > 0)
}
t_end `=_rc'

t_begin snippet: an error stays output in the err style, for Cloud to mark
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/error.smcl"))
    mata: assert(B[., 1] == ("code" \ "output" \ "code" \ "output"))
    mata: assert(B[1, 2] == "capture noisily regress price nosuchvar")
    mata: assert(B[2, 2] == "{com}{err}variable {bf}nosuchvar{sf} not found" + char(10) + "{txt}")
    mata: assert(B[3, 2] == `"display "after the error""')
}
t_end `=_rc'

t_begin snippet: commands that print nothing join the next code block
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/quietly.smcl"))
    mata: assert(B[., 1] == ("code" \ "output" \ "code" \ "output"))
    * Stata does not echo the body of a quietly block.
    mata: assert(B[1, 2] == "quietly summarize price" + char(10) + "quietly {")
    mata: assert(B[2, 2] == "{com}{res}inside" + char(10) + "{txt}")
    mata: assert(B[3, 2] == "* a comment" + char(10) + "display r(mean)")
    mata: assert(fw_startswith(B[4, 2], "{com}{res}21.29"))
}
t_end `=_rc'

t_begin snippet: a loop's body lines lose their numbers, and braces are restored
capture noisily {
    mata: B = fw_snippet_split(fw_readlines(st_local("fx") + "/loop.smcl"))
    mata: assert(B[., 1] == ("code" \ "output" \ "code" \ "output" \ "code" \ "output"))
    mata: assert(B[1, 2] == "forvalues i = 1/2 {" + char(10) + `"    display "i is "' + char(96) + "i'" + `"""' + char(10) + "}")
    mata: assert(B[2, 2] == "{com}i is 1" + char(10) + "i is 2" + char(10) + "{txt}")
    mata: assert(rows(tokens(B[3, 2], char(10))') == 7)
    mata: assert(B[5, 2] == `"display "braces {res} and dollars "' + char(36) + `"S_DATE""')
}
t_end `=_rc'

t_begin snippet: nooutput keeps the code as one block
capture noisily {
    mata: B = fw_snippet_code_only(fw_snippet_split(fw_readlines(st_local("fx") + "/loop.smcl")))
    mata: assert(rows(B) == 1)
    mata: assert(B[1, 1] == "code")
    mata: assert(fw_startswith(B[1, 2], "forvalues i = 1/2 {"))
    mata: assert(fw_endswith(B[1, 2], char(36) + `"S_DATE""'))
}
t_end `=_rc'

t_begin snippet: command text and visible output
capture noisily {
    mata: assert(fw_snippet_uncmd("display {c -(}a{c )-} {c S|}x {res}{hline 2}") == "display {a} " + char(36) + "x {hline 2}")
    mata: assert(fw_snippet_visible("{txt}" + char(10) + "{res}{txt}  ") == 0)
    mata: assert(fw_snippet_visible("{txt}{hline 3}") == 1)
    mata: assert(fw_snippet_visible("{res}12") == 1)
}
t_end `=_rc'

t_begin snippet: a log that ends a stopped do-file is stale
capture noisily {
    t_tmpdir
    local d `"`r(dir)'"'
    t_write `"`d'/stale.smcl"' "{com}. regress y x" "{err}variable {bf}y{sf} not found" ///
        "{txt}{search r(111), local:r(111);}" "" "end of do-file"
    mata: assert(fw_snippet_stale(st_local("d") + "/stale.smcl") == 1)
    mata: assert(fw_snippet_stale(st_local("fx") + "/regress.smcl") == 0)
}
t_end `=_rc'

t_begin snippet: the commit comes from .git without running git
capture noisily {
    t_tmpdir
    local g `"`r(dir)'"'
    local sha1 = 40 * "a"
    local sha2 = 40 * "b"
    mkdir `"`g'/repo"'
    mkdir `"`g'/repo/.git"'
    mkdir `"`g'/repo/.git/refs"'
    mkdir `"`g'/repo/.git/refs/heads"'
    mkdir `"`g'/repo/project"'
    t_write `"`g'/repo/.git/HEAD"' "ref: refs/heads/main"
    t_write `"`g'/repo/.git/refs/heads/main"' "`sha1'"
    * A project below the repository root finds it.
    mata: assert(fw_snippet_commit(st_local("g") + "/repo/project") == st_local("sha1"))
    * A packed ref, and a worktree whose .git file names its folder.
    erase `"`g'/repo/.git/refs/heads/main"'
    t_write `"`g'/repo/.git/packed-refs"' "# pack-refs with: peeled" "`sha2' refs/heads/main"
    mata: assert(fw_snippet_commit(st_local("g") + "/repo") == st_local("sha2"))
    mkdir `"`g'/repo/.git/worktrees"'
    mkdir `"`g'/repo/.git/worktrees/wt"'
    t_write `"`g'/repo/.git/worktrees/wt/HEAD"' "ref: refs/heads/main"
    t_write `"`g'/repo/.git/worktrees/wt/commondir"' "../.."
    mkdir `"`g'/wt"'
    t_write `"`g'/wt/.git"' "gitdir: `g'/repo/.git/worktrees/wt"
    mata: assert(fw_snippet_commit(st_local("g") + "/wt") == st_local("sha2"))
    * A detached HEAD holds the commit itself.
    t_write `"`g'/repo/.git/HEAD"' "`sha1'"
    mata: assert(fw_snippet_commit(st_local("g") + "/repo") == st_local("sha1"))
}
t_end `=_rc'

* A project with a do-file that publishes nothing: saving() keeps the JSON.
t_tmpdir
local root `"`r(dir)'"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  project_name: snippet-test" ///
    "  publish:" ///
    "    repository: https://github.com/frameworktools/snippet-test"
mkdir `"`root'/analysis"'
t_write `"`root'/analysis/fit.do"' ///
    "sysuse auto, clear" ///
    "fw_snippet begin fit-ols" ///
    "regress price mpg" ///
    "display 1 + 1" ///
    `"fw_snippet end, unfolded nopublish saving("`root'/fit.json", replace) notebook(https://example.org/notebook) model(price-model)"'
quietly cd `"`root'"'
fw_project, quietly

t_begin snippet: fw_snippet records the do-file, its lines, and the settings repository
capture noisily {
    do `"`root'/analysis/fit.do"'
    capture quietly log query fw_snippet
    assert _rc
    mata: J = fw_json_read(st_local("root") + "/fit.json")
    mata: assert(fw_get(J, "schema") == "framework.artifact/v1")
    mata: assert(fw_get(J, "kind") == "code_snippet")
    mata: assert(fw_get(J, "source.language") == "stata")
    mata: assert(fw_get(J, "source.label") == "fit-ols")
    mata: assert(fw_get(J, "source.file") == "analysis/fit.do")
    mata: assert(fw_get(J, "source.lines.0") == "3")
    mata: assert(fw_get(J, "source.lines.1") == "4")
    mata: assert(fw_get(J, "source.repository") == "https://github.com/frameworktools/snippet-test")
    * The test folder is not a git repository.
    mata: assert(fw_get(J, "source.commit") == "")
    mata: assert(fw_get(J, "snippet.width") == strofreal(c("linesize")))
    mata: assert(fw_get(J, "snippet.blocks.#") == "4")
    mata: assert(fw_get(J, "snippet.blocks.0.text") == "regress price mpg")
    mata: assert(fw_get(J, "snippet.blocks.1.type") == "output")
    mata: assert(fw_get(J, "snippet.blocks.1.text") == "")
    mata: assert(fw_get(J, "snippet.blocks.1.folded") == "false")
    mata: assert(fw_get(J, "snippet.blocks.2.text") == "display 1 + 1")
    mata: assert(fw_get(J, "snippet.blocks.3.smcl") != "")
    mata: assert(fw_get(J, "display.links.0.url") == "https://example.org/notebook")
    mata: assert(fw_get(J, "display.links.1.artifact") == "price-model")
}
t_end `=_rc'

* Each test below runs its snippet as a do-file, as a user would.

t_begin snippet: nooutput and folded
capture noisily {
    t_write `"`root'/quick.do"' ///
        "fw_snippet begin quick" ///
        `"display "printed""' ///
        `"display "again""' ///
        `"fw_snippet end, nooutput nopublish saving("`root'/quick.json", replace)"'
    do `"`root'/quick.do"'
    assert r(blocks) == 1
    assert r(output_blocks) == 0
    t_eq `"`r(label)'"' "quick"
    mata: J = fw_json_read(st_local("root") + "/quick.json")
    mata: assert(fw_get(J, "snippet.blocks.#") == "1")
    mata: assert(fw_get(J, "snippet.blocks.0.text") == `"display "printed""' + char(10) + `"display "again""')
    * The do-file is found by its label.
    mata: assert(fw_get(J, "source.file") == "quick.do")
    mata: assert(fw_get(J, "source.lines.0") == "2")
    t_write `"`root'/folded.do"' ///
        "fw_snippet begin folded" ///
        `"display "printed""' ///
        `"fw_snippet end, folded nopublish saving("`root'/folded.json", replace)"'
    do `"`root'/folded.do"'
    mata: J = fw_json_read(st_local("root") + "/folded.json")
    mata: assert(fw_get(J, "snippet.blocks.1.folded") == "true")
}
t_end `=_rc'

t_begin snippet: end without begin, and nested begin, stop with a message
capture noisily {
    t_write `"`root'/nested.do"' ///
        "fw_snippet begin outer" ///
        `"display "in outer""' ///
        "capture noisily fw_snippet begin inner" ///
        "assert _rc == 198" ///
        `"display "still outer""' ///
        `"fw_snippet end, nopublish saving("`root'/outer.json", replace)"'
    t_log_begin
    capture noisily fw_snippet end, nopublish saving(`"`root'/x.json"')
    local rc1 = _rc
    do `"`root'/nested.do"'
    t_log_end
    assert `rc1' == 198
    t_log_has "No snippet is open"
    t_log_has "The snippet outer is still open. Snippets cannot nest."
    * The outer snippet kept going, with the failed begin in it.
    mata: J = fw_json_read(st_local("root") + "/outer.json")
    mata: assert(fw_get(J, "source.label") == "outer")
    mata: assert(fw_get(J, "snippet.blocks.0.text") == `"display "in outer""')
    mata: assert(strpos(fw_readfile(st_local("root") + "/outer.json"), "still outer") > 0)
}
t_end `=_rc'

t_begin snippet: begin closes a snippet left open by a do-file that stopped
capture noisily {
    t_write `"`root'/broken.do"' ///
        "fw_snippet begin broken" ///
        "regress price nosuchvar"
    capture noisily do `"`root'/broken.do"'
    assert _rc == 111
    capture quietly log query fw_snippet
    assert !_rc
    t_write `"`root'/fixed.do"' ///
        "fw_snippet begin fixed" ///
        `"display "fresh""' ///
        `"fw_snippet end, nopublish saving("`root'/fixed.json", replace)"'
    t_log_begin
    do `"`root'/fixed.do"'
    t_log_end
    t_log_has "closed the snippet broken"
    mata: J = fw_json_read(st_local("root") + "/fixed.json")
    mata: assert(fw_get(J, "source.label") == "fixed")
    mata: assert(fw_get(J, "snippet.blocks.0.text") == `"display "fresh""')
    mata: assert(strpos(fw_readfile(st_local("root") + "/fixed.json"), "nosuchvar") == 0)
}
t_end `=_rc'

t_begin snippet: a snippet with no commands is not published
capture noisily {
    t_write `"`root'/empty.do"' ///
        "fw_snippet begin empty" ///
        `"capture noisily fw_snippet end, nopublish saving("`root'/empty.json", replace)"' ///
        "assert _rc == 198"
    do `"`root'/empty.do"'
    capture confirm file `"`root'/empty.json"'
    assert _rc
}
t_end `=_rc'

t_begin snippet: options are checked before the log closes
capture noisily {
    t_write `"`root'/opts.do"' ///
        "fw_snippet begin opts" ///
        `"display "kept""' ///
        `"capture noisily fw_snippet end, visibility(secret) nopublish saving("`root'/opts.json", replace)"' ///
        "assert _rc == 198" ///
        `"fw_snippet end, nopublish saving("`root'/opts.json", replace)"'
    do `"`root'/opts.do"'
    mata: J = fw_json_read(st_local("root") + "/opts.json")
    * The failed end and its message are left out with it.
    mata: assert(fw_get(J, "snippet.blocks.#") == "2")
    mata: assert(strpos(fw_readfile(st_local("root") + "/opts.json"), "visibility") == 0)
}
t_end `=_rc'

capture log close fw_snippet
quietly cd `"$FW_TEST_REPO"'
