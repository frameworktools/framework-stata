* Project structure trees: fw_structure walks a project, applies the privacy
* rules, prints the tree, and writes the tree document without publishing.

_fw_init
local here `"`c(pwd)'"'

* The shared fixture of docs/plans/2026-11-25-structure-artifacts.md in
* framework-cloud, with settings.yml so fw_project finds it.
capture program drop t_tree_fixture
program define t_tree_fixture, rclass
    t_tmpdir
    local root `"`r(dir)'/my-project"'
    mkdir `"`root'"'
    foreach d in R data data/raw data/private outputs {
        mkdir `"`root'/`d'"'
    }
    t_write `"`root'/.gitignore"' "data/raw/" "*.rds" ".env"
    foreach f in .env README.md R/clean.R data/raw/a.csv data/raw/b.csv data/private/ids.csv ///
        outputs/fit.rds outputs/draws.rds outputs/table.csv {
        t_write `"`root'/`f'"' "x"
    }
    t_write `"`root'/settings.yml"' "default:" "  project_name: My project"
    return local root `"`root'"'
end

* Nodes of a saved tree as sorted lines: path|type|rule|source|line|hidden|flags.
capture mata: mata drop t_tree_nodes() t_tree_check()
mata:
string colvector t_tree_nodes(string scalar file)
{
    J = fw_json_read(file)
    n = strtoreal(fw_get(J, "nodes.#"))
    out = J(0, 1, "")
    for (i = 0; i < n; i++) {
        k = "nodes." + strofreal(i) + "."
        flags = (fw_get(J, k + "private") == "true" ? "private" : "") + (fw_get(J, k + "depth") == "true" ? "depth" : "")
        out = out \ (fw_get(J, k + "path") + "|" + fw_get(J, k + "type") + "|" + fw_get(J, k + "ignored.rule") + "|" +
            fw_get(J, k + "ignored.source") + "|" + fw_get(J, k + "ignored.line") + "|" + fw_get(J, k + "hidden") + "|" + flags)
    }
    return(sort(out, 1))
}

// Stop unless a saved tree has exactly the nodes in want, a list of quoted lines.
void t_tree_check(string scalar file, string scalar want_in)
{
    got = t_tree_nodes(file)
    want = sort(tokens(want_in)', 1)
    if (rows(got) == rows(want)) {
        if (got == want) return
    }
    printf("{err}  got:\n")
    for (i = 1; i <= rows(got); i++) printf("{err}    %s\n", got[i])
    printf("{err}  wanted:\n")
    for (i = 1; i <= rows(want); i++) printf("{err}    %s\n", want[i])
    exit(9)
}
end

* The fixture's published nodes, as the plan lists them.
local fixture_nodes `""|ignored|.env|.gitignore|3|1|" ".gitignore|file|||||" "R|dir|||||" "R/clean.R|file|||||" "README.md|file|||||" "data|dir|||||" "data/private|dir||||1|private" "data/raw|dir|data/raw/|.gitignore|1|2|" "outputs|dir|||||" "outputs|ignored|*.rds|.gitignore|2|2|" "outputs/table.csv|file|||||" "settings.yml|file|||||""'

capture program drop t_tree_same
program define t_tree_same
    args file want
    mata: t_tree_check(st_local("file"), st_local("want"))
end

* Whether git runs here.
mata: d = fw_scratch(); st_local("gitcmd", fw__tr_gitcmd(d)); fw_scratch_done(d)

t_begin structure: the shared fixture publishes the plan's nodes and no ignored or private names
capture noisily {
    if `"`gitcmd'"' == "" {
        display as text "  (git is not available; the fixture runs without it)"
    }
    else {
        t_tree_fixture
        local root `"`r(root)'"'
        mata: d = fw_scratch(); rc = fw_run(st_local("gitcmd") + " -C " + fw__cliarg(st_local("root")) + " init -q", d); fw_scratch_done(d); assert(rc == 0)
        quietly cd `"`root'"'
        fw_project, quietly
        fw_structure, saving(`"`root'/../tree.json"')
        t_eq `"`r(method)'"' "git"
        t_eq `"`r(root)'"' "my-project"
        t_eq `"`r(base)'"' ""
        t_eq `"`r(slug)'"' "structure"
        assert r(nodes) == 12
        t_tree_same `"`root'/../tree.json"' `"`fixture_nodes'"'
        mata: s = fw_readfile(st_local("root") + "/../tree.json")
        foreach leak in a.csv b.csv ids.csv fit.rds draws.rds {
            mata: assert(!strpos(s, "`leak'"))
        }
        mata: J = fw_json_read(st_local("root") + "/../tree.json")
        mata: assert(fw_get(J, "schema") == "framework.artifact/v1")
        mata: assert(fw_get(J, "kind") == "tree")
        mata: assert(fw_get(J, "source.language") == "stata")
        mata: assert(fw_get(J, "root") == "my-project")
        mata: assert(fw_get(J, "method") == "git")
        mata: assert(fw_get(J, "open") == "" & fw_get(J, "highlight") == "")
    }
}
t_end `=_rc'

t_begin structure: without git, the root .gitignore gives the same nodes
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    quietly cd `"`root'"'
    fw_project, quietly
    fw_structure, saving(`"`root'/../tree.json"')
    t_eq `"`r(method)'"' "gitignore"
    t_tree_same `"`root'/../tree.json"' `"`fixture_nodes'"'
    mata: s = fw_readfile(st_local("root") + "/../tree.json")
    foreach leak in a.csv b.csv ids.csv fit.rds draws.rds {
        mata: assert(!strpos(s, "`leak'"))
    }
    * With no .gitignore, nothing is ignored.
    erase `"`root'/.gitignore"'
    fw_structure, saving(`"`root'/../none.json"')
    t_eq `"`r(method)'"' "none"
    mata: assert(anyof(t_tree_nodes(st_local("root") + "/../none.json"), "outputs/fit.rds|file|||||"))
    mata: assert(anyof(t_tree_nodes(st_local("root") + "/../none.json"), "data/private|dir||||1|private"))
}
t_end `=_rc'

t_begin structure: the local tree lists ignored files by name and the published one groups them
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    quietly cd `"`root'"'
    fw_project, quietly
    t_log_begin
    fw_structure, notes(R "Reusable functions" README.md "Start here")
    t_log_end
    t_log_has "my-project/"
    t_log_has "├── R/             Reusable functions"
    t_log_has "│   └── clean.R"
    t_log_has "│   ├── private/   private · 1 file"
    t_log_has "│   └── raw/       ignored by data/raw/ (.gitignore:1) · 2 files"
    t_log_has "│   ├── draws.rds  ignored by *.rds (.gitignore:2)"
    t_log_has "│   └── fit.rds    ignored by *.rds (.gitignore:2)"
    t_log_has "└── .env           ignored by .env (.gitignore:3)"
    t_log_has "├── README.md      Start here"
    t_log_lacks "a.csv"
    t_log_lacks "ids.csv"
    mata: assert(fw__tr_files(1) == "1 file")
    mata: assert(fw__tr_files(1520) == "1,520 files")
    mata: assert(fw__tr_files(10000) == "10,000+ files")
}
t_end `=_rc'

t_begin structure: a private folder that is also ignored names its rule after private
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    t_write `"`root'/.gitignore"' "data/raw/" "*.rds" ".env" "data/private/"
    quietly cd `"`root'"'
    fw_project, quietly
    t_log_begin
    fw_structure
    t_log_end
    t_log_has "│   ├── private/   private · ignored by data/private/ (.gitignore:4) · 1 file"
    t_log_lacks "ids.csv"
}
t_end `=_rc'

t_begin structure: more than 20 ignored files under one rule list 20 and a count
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    forvalues i = 1/25 {
        t_write `"`root'/outputs/m`i'.rds"' "x"
    }
    quietly cd `"`root'"'
    fw_project, quietly
    t_log_begin
    fw_structure outputs
    t_log_end
    t_log_has "└── … 7 more   ignored by *.rds (.gitignore:2)"
    t_log_has "m25.rds"
    t_log_lacks "m3.rds"
    fw_structure outputs, saving(`"`root'/../out.json"')
    mata: assert(anyof(t_tree_nodes(st_local("root") + "/../out.json"), "|ignored|*.rds|.gitignore|2|27|"))
}
t_end `=_rc'

t_begin structure: gitignore patterns match as git does
capture noisily {
    t_tmpdir
    local d `"`r(dir)'"'
    t_write `"`d'/.gitignore"' "# comment" "" "*.log" "!keep.log" "build/" "/top.txt" "docs/*.pdf" "**/cache" "a/**/z" "file?.csv" "\#hash" "logs/**"
    mata: R = fw_tree_gitignore(st_local("d") + "/.gitignore")
    mata: assert(rows(R) == 10)
    mata: assert(fw_tree_match(R, "x.log", 0) == 1)
    mata: assert(fw_tree_match(R, "deep/x.log", 0) == 1)
    mata: assert(fw_tree_match(R, "keep.log", 0) == 0)
    mata: assert(fw_tree_match(R, "build", 1) == 3)
    mata: assert(fw_tree_match(R, "src/build", 1) == 3)
    mata: assert(fw_tree_match(R, "build", 0) == 0)
    mata: assert(fw_tree_match(R, "top.txt", 0) == 4)
    mata: assert(fw_tree_match(R, "sub/top.txt", 0) == 0)
    mata: assert(fw_tree_match(R, "docs/a.pdf", 0) == 5)
    mata: assert(fw_tree_match(R, "docs/sub/a.pdf", 0) == 0)
    mata: assert(fw_tree_match(R, "x/y/cache", 1) == 6)
    mata: assert(fw_tree_match(R, "cache", 1) == 6)
    mata: assert(fw_tree_match(R, "a/z", 1) == 7)
    mata: assert(fw_tree_match(R, "a/b/c/z", 0) == 7)
    mata: assert(fw_tree_match(R, "file1.csv", 0) == 8)
    mata: assert(fw_tree_match(R, "file10.csv", 0) == 0)
    mata: assert(fw_tree_match(R, "#hash", 0) == 9)
    mata: assert(fw_tree_match(R, "logs/a/b", 0) == 10)
    mata: assert(R[1, 4] == "*.log" & R[1, 5] == "3")
}
t_end `=_rc'

t_begin structure: depth, exclude, and ignored(hide)
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    quietly cd `"`root'"'
    fw_project, quietly
    fw_structure, depth(1) saving(`"`root'/../depth.json"')
    mata: N = t_tree_nodes(st_local("root") + "/../depth.json")
    mata: assert(anyof(N, "R|dir||||1|depth"))
    mata: assert(anyof(N, "outputs|dir||||3|depth"))
    mata: assert(anyof(N, "data/raw|dir|data/raw/|.gitignore|1|2|") == 0)
    mata: assert(!anyof(N, "R/clean.R|file|||||"))
    fw_structure, exclude(outputs "*.md") saving(`"`root'/../ex.json"')
    mata: s = fw_readfile(st_local("root") + "/../ex.json")
    mata: assert(!strpos(s, "outputs") & !strpos(s, "README"))
    fw_structure, ignored(hide) saving(`"`root'/../hide.json"')
    mata: N = t_tree_nodes(st_local("root") + "/../hide.json")
    mata: assert(!anyof(N, "data/raw|dir|data/raw/|.gitignore|1|2|"))
    mata: assert(!anyof(N, "outputs|ignored|*.rds|.gitignore|2|2|"))
    mata: assert(anyof(N, "data/private|dir||||1|private"))
    * A private folder that is also ignored goes with ignored(hide).
    t_write `"`root'/.gitignore"' "data/raw/" "*.rds" ".env" "data/private/"
    fw_structure, ignored(hide) saving(`"`root'/../hide2.json"')
    mata: assert(!strpos(fw_readfile(st_local("root") + "/../hide2.json"), "private"))
    fw_structure, saving(`"`root'/../both.json"')
    mata: J = fw_json_read(st_local("root") + "/../both.json")
    mata: N = t_tree_nodes(st_local("root") + "/../both.json")
    mata: assert(anyof(N, "data/private|dir|data/private/|.gitignore|4|1|private"))
}
t_end `=_rc'

t_begin structure: notes, open, and highlight name paths in the tree
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    quietly cd `"`root'"'
    fw_project, quietly
    fw_structure, notes(R/ "Reusable functions" data/raw "Raw files") open(R) highlight(README.md) ///
        saving(`"`root'/../marks.json"')
    mata: J = fw_json_read(st_local("root") + "/../marks.json")
    mata: s = fw_readfile(st_local("root") + "/../marks.json")
    mata: assert(strpos(s, `"{"path":"R","type":"dir","note":"Reusable functions"}"') > 0)
    mata: assert(strpos(s, `""path":"data/raw","type":"dir","note":"Raw files""') > 0)
    mata: assert(strpos(s, `""open":["R"],"highlight":["README.md"]"') > 0)
    t_log_begin
    capture noisily fw_structure, notes(nowhere "x")
    assert _rc == 198
    capture noisily fw_structure, notes(outputs/fit.rds "an ignored file")
    assert _rc == 198
    capture noisily fw_structure, highlight(data/raw/a.csv)
    assert _rc == 198
    capture noisily fw_structure, notes(R)
    assert _rc == 198
    capture noisily fw_structure, depth(0)
    assert _rc == 198
    capture noisily fw_structure, ignored(all)
    assert _rc == 198
    capture noisily fw_structure, title("Not published")
    assert _rc == 198
    capture noisily fw_structure nowhere
    assert _rc == 601
    capture noisily fw_structure data data/raw
    assert _rc == 198
    t_log_end
    t_log_has "notes() names nowhere, which is not in the tree"
    t_log_has "highlight() names data/raw/a.csv, which is not in the tree"
    t_log_has "notes() takes pairs"
    t_log_has "depth() takes a number of levels"
    t_log_has "ignored() takes rules or hide"
    t_log_has "go with publish"
    t_log_has "data/raw is inside data"
}
t_end `=_rc'

t_begin structure: a subfolder, several folders, and settings folders marked private
capture noisily {
    t_tree_fixture
    local root `"`r(root)'"'
    mkdir `"`root'/secret"'
    t_write `"`root'/secret/notes.txt"' "x"
    t_write `"`root'/settings.yml"' "default:" "  directories:" "    inputs_private_raw: secret"
    quietly cd `"`root'"'
    fw_project, quietly
    fw_structure data, saving(`"`root'/../sub.json"')
    t_eq `"`r(root)'"' "data"
    t_eq `"`r(base)'"' "data"
    t_eq `"`r(slug)'"' "structure-data"
    t_tree_same `"`root'/../sub.json"' `""private|dir||||1|private" "raw|dir|data/raw/|.gitignore|1|2|""'
    fw_structure R outputs, saving(`"`root'/../multi.json"')
    t_eq `"`r(root)'"' "my-project"
    t_eq `"`r(base)'"' ""
    t_eq `"`r(slug)'"' "structure"
    t_tree_same `"`root'/../multi.json"' `""R|dir|||||" "R/clean.R|file|||||" "outputs|dir|||||" "outputs|ignored|*.rds|.gitignore|2|2|" "outputs/table.csv|file|||||""'
    fw_structure, saving(`"`root'/../settings.json"')
    mata: N = t_tree_nodes(st_local("root") + "/../settings.json")
    mata: assert(anyof(N, "secret|dir||||1|private"))
    mata: assert(!strpos(fw_readfile(st_local("root") + "/../settings.json"), "notes.txt"))
    * A private folder's own structure does not publish.
    capture noisily fw_structure data/private, publish
    assert _rc == 198
}
t_end `=_rc'

t_begin structure: symbolic links are files and are not followed
capture noisily {
    if c(os) == "Windows" {
        display as text "  (Windows: skipped)"
    }
    else {
        t_tree_fixture
        local root `"`r(root)'"'
        shell ln -s ../R "`root'/data/linked" && ln -s nowhere "`root'/broken"
        quietly cd `"`root'"'
        fw_project, quietly
        fw_structure, saving(`"`root'/../links.json"')
        mata: N = t_tree_nodes(st_local("root") + "/../links.json")
        mata: assert(anyof(N, "data/linked|file|||||"))
        mata: assert(anyof(N, "broken|file|||||"))
        mata: assert(!anyof(N, "data/linked/clean.R|file|||||"))
    }
}
t_end `=_rc'

quietly cd `"`here'"'
