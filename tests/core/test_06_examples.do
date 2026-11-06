* The examples run from start to finish.

foreach ex in 01-project 02-data 03-publish 04-estimates {
    t_begin examples: `ex'.do runs
    capture noisily do `"$FW_TEST_REPO/examples/`ex'.do"'
    local rc = _rc
    quietly cd `"$FW_TEST_REPO"'
    t_end `rc'
}
t_begin examples: the folder site lists every artifact
capture noisily {
    * 03-publish.do draws its figure in batch mode too.
    mata: I = fw_json_read(st_global("FW_EXAMPLE_PROJECT") + "/published/index.json")
    mata: assert(fw_get(I, ".#") == "5")
    confirm file `"$FW_EXAMPLE_PROJECT/published/price/price.png"'
}
t_end `=_rc'

t_begin examples: 05-cleanup.do removes the example project
capture noisily {
    local project `"$FW_EXAMPLE_PROJECT"'
    do `"$FW_TEST_REPO/examples/05-cleanup.do"'
    quietly cd `"$FW_TEST_REPO"'
    mata: assert(!direxists(st_local("project")))
    t_eq `"$FW_EXAMPLE_PROJECT"' ""
}
t_end `=_rc'
