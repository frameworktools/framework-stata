* Causal DAGs: fw_dag builds DAGitty text and dag.json without publishing.

_fw_init
t_tmpdir
local d `"`r(dir)'"'
local nl = char(10)

t_begin dag: names that are not plain identifiers go in quotes
capture noisily {
    mata: assert(fw_dag_name("smoking") == "smoking")
    mata: assert(fw_dag_name("x_1.b") == "x_1.b")
    mata: assert(fw_dag_name("family income") == char(34) + "family income" + char(34))
    mata: assert(fw_dag_name("1st") == char(34) + "1st" + char(34))
    mata: assert(fw_dag_name("a-b") == char(34) + "a-b" + char(34))
}
t_end `=_rc'

t_begin dag: the command keeps one space where continued lines joined
capture noisily {
    mata: assert(fw_dag_cmdline(`"fw_dag "a -> b",     exposure(a)  outcome(b) "') == `"fw_dag "a -> b", exposure(a) outcome(b)"')
    mata: assert(fw_dag_cmdline(`"fw_dag "a  ->  b", labels(a "two  spaces")"') == `"fw_dag "a  ->  b", labels(a "two  spaces")"')
}
t_end `=_rc'

t_begin dag: paths, roles, and chains become DAGitty text
capture noisily {
    fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) ///
        nopublish saving(`"`d'/smoking.dagitty"') novarlabels
    assert r(nodes) == 3
    assert r(edges) == 3
    t_eq `"`r(file)'"' `"`d'/smoking.dagitty"'
    local want "dag {`nl'age`nl'smoking [exposure]`nl'cancer [outcome]`nl'age -> smoking -> cancer`nl'age -> cancer`nl'}"
    t_eq `"`r(dagitty)'"' `"`want'"'
    mata: assert(fw_readfile(st_local("d") + "/smoking.dagitty") == st_local("want") + char(10))
}
t_end `=_rc'

t_begin dag: groups, spaces in names, bidirected edges, and lone names
capture noisily {
    fw_dag "{age sex} -> tar deposits -> cancer" "smoking <-> cancer" "income", ///
        latent("tar deposits") adjusted(age sex) selected(income) ///
        nopublish saving(`"`d'/groups.json"') novarlabels
    * {age sex} -> tar deposits is two arrows.
    assert r(edges) == 4
    assert r(nodes) == 6
    mata: J = fw_json_read(st_local("d") + "/groups.json")
    mata: t = fw_get(J, "dagitty")
    mata: assert(strpos(t, "age [adjusted]") > 0)
    mata: assert(strpos(t, "sex [adjusted]") > 0)
    mata: assert(strpos(t, char(34) + "tar deposits" + char(34) + " [latent]") > 0)
    mata: assert(strpos(t, "income [selected]") > 0)
    mata: assert(strpos(t, "{age sex} -> " + char(34) + "tar deposits" + char(34) + " -> cancer") > 0)
    mata: assert(strpos(t, "smoking <-> cancer") > 0)
}
t_end `=_rc'

t_begin dag: dag.json holds labels, variable labels, and the command
capture noisily {
    preserve
    clear
    set obs 1
    generate smoking = 1
    label variable smoking "Smoking status"
    generate age = 1
    generate cancer_long = 1
    label variable cancer_long "Not a node"
    fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) ///
        labels(cancer "Lung cancer") nopublish saving(`"`d'/labels.json"')
    restore
    mata: J = fw_json_read(st_local("d") + "/labels.json")
    mata: assert(fw_get(J, "schema") == "framework.artifact/v1")
    mata: assert(fw_get(J, "kind") == "dag")
    mata: assert(fw_get(J, "source.language") == "stata")
    mata: assert(fw_get(J, "labels.smoking") == "Smoking status")
    mata: assert(fw_get(J, "labels.cancer") == "Lung cancer")
    * age has no variable label, and abbreviations never match a variable.
    mata: assert(fw_get(J, "labels.age") == "")
    mata: assert(fw_get(J, "labels.cancer_long") == "")
    mata: assert(fw_get(J, "code.language") == "stata")
    mata: assert(fw_startswith(fw_get(J, "code.text"), "fw_dag " + char(34) + "age -> smoking -> cancer" + char(34)))
    mata: assert(strpos(fw_get(J, "code.text"), "exposure(smoking) outcome(cancer)") > 0)
}
t_end `=_rc'

t_begin dag: labels() wins over a variable label, and nocode leaves out the command
capture noisily {
    preserve
    clear
    set obs 1
    generate smoking = 1
    label variable smoking "Smoking status"
    fw_dag "smoking -> cancer", labels(smoking "Smoker") nocode nopublish saving(`"`d'/nocode.json"')
    restore
    mata: J = fw_json_read(st_local("d") + "/nocode.json")
    mata: assert(fw_get(J, "labels.smoking") == "Smoker")
    mata: assert(fw_get(J, "code.text") == "")
}
t_end `=_rc'

t_begin dag: a DAGitty file is read as it is, and labels() turn it into dag.json
capture noisily {
    t_write `"`d'/model.dagitty"' "" "dag {" "x [exposure]" "y [outcome]" "x -> y" "}" ""
    fw_dag using `"`d'/model.dagitty"', labels(x "Treatment") nopublish saving(`"`d'/model.json"')
    assert missing(r(nodes))
    mata: J = fw_json_read(st_local("d") + "/model.json")
    mata: assert(fw_get(J, "kind") == "dag")
    mata: assert(fw_get(J, "dagitty") == "dag {" + char(10) + "x [exposure]" + char(10) + "y [outcome]" + char(10) + "x -> y" + char(10) + "}")
    mata: assert(fw_get(J, "labels.x") == "Treatment")
    * The code that built a file is not this command.
    mata: assert(fw_get(J, "code.text") == "")
}
t_end `=_rc'

t_begin dag: mistakes stop with a message
capture noisily {
    t_log_begin
    capture noisily fw_dag age -> smoking, nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> a", nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -- b", nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> b", exposure(z) nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> b", labels(a) nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> b", nopublish
    assert _rc == 198
    capture noisily fw_dag "a -> b" using `"`d'/model.dagitty"', nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag using `"`d'/model.dagitty"', exposure(x) nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> b", visibility(secret) nopublish saving(`"`d'/x.json"')
    assert _rc == 198
    capture noisily fw_dag "a -> b", nopublish saving(`"`d'/model.json"')
    assert _rc == 602
    t_log_end
    t_log_has "put each path in double quotes"
    t_log_has "draws an arrow from a to itself"
    t_log_has "undirected edge"
    t_log_has "exposure() names z, which no path in the graph includes"
    t_log_has "labels() takes pairs"
    t_log_has "nopublish needs saving()"
    t_log_has "not both"
    t_log_has "A DAGitty file sets its own roles"
    t_log_has "visibility() must be"
    t_log_has "already exists"
    capture confirm file `"`d'/x.json"'
    assert _rc
}
t_end `=_rc'
