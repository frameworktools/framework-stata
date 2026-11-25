* Framework Cloud through curl, against a local mock server.

* scripts/jhpce-test.sh starts the mock server and sets these. Without
* them the Cloud tests start it here with nohup.
local port : environment FW_TEST_MOCK_PORT
local log : environment FW_TEST_MOCK_LOG
if `"`: environment FW_CONFIG_HOME'"' == "" {
    t_skip "cloud: FW_CONFIG_HOME is not set; the login test would write to the real config folder"
    exit
}
if "`port'" == "" {
    tempfile probe
    capture shell python3 -c "print(1)" > "`probe'"
    capture confirm file "`probe'"
    mata: st_local("pyok", strofreal(fileexists(st_local("probe")) & fw_clean(fw_readfile(st_local("probe"))) == "1"))
    if !`pyok' {
        t_skip "cloud: python3 is not available to run the mock server"
        exit
    }
    local port 18765
    tempfile mocklog
    local log `"`mocklog'.jsonl"'
    shell nohup python3 "$FW_TEST_REPO/tests/fixtures/mock_cloud.py" `port' "`log'" > /dev/null 2>&1 &
    sleep 2000
}

t_tmpdir
local root `"`r(dir)'"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  directories:" ///
    "    inputs_final: inputs/final" ///
    "  options:" ///
    "    cloud_ledger: live" ///
    "  publish:" ///
    "    destinations:" ///
    "      lab:" ///
    "        driver: folder" ///
    "        path: site" ///
    "        visibility: private"
* The token is built in two parts, so it never appears in the log.
local ptok = "fw_test_" + "project_token_0123456789"
t_write `"`root'/.env"' ///
    "FW_CLOUD_URL=http://127.0.0.1:`port'" ///
    "FW_PROJECT_TOKEN=`ptok'"
local ptok
quietly cd `"`root'"'
fw_project, quietly

* Requests the mock server saw, as a Mata string vector.
capture program drop t_requests
program define t_requests
    args log
    mata: R = fw_readlines(st_local("log"))
end

t_begin cloud: fw_login completes the browser approval flow
capture noisily {
    fw_login, url(http://127.0.0.1:`port') nobrowser
    t_eq `"`r(account)'"' "Test User"
    * macOS stores the token in the Keychain; elsewhere, a file unless keyring is set up
    local stored `"`r(stored)'"'
    mata: st_local("mac", strofreal(fw_macos()))
    t_eq `"`stored'"' `"`=cond(`mac', "keyring", "file")'"'
    local cfg : environment FW_CONFIG_HOME
    confirm file `"`cfg'/cloud.yml"'
    * Without a keyring, the token file is private to the user.
    if !`mac' {
        confirm file `"`cfg'/cloud-token-127.0.0.1_`port'"'
        tempfile perm
        shell stat -c %a "`cfg'/cloud-token-127.0.0.1_`port'" > "`perm'"
        mata: assert(fw_clean(fw_readfile(st_local("perm"))) == "600")
    }
}
t_end `=_rc'

t_begin cloud: the device flow sent no token until approval
capture noisily {
    t_requests `"`log'"'
    mata: assert(sum(strpos(R, char(34) + "/api/v1/cli/device" + char(34)) :> 0) == 1)
    mata: assert(sum(strpos(R, "/api/v1/cli/device/token") :> 0) == 2)
    mata: dev = select(R, strpos(R, "/api/v1/cli/device") :> 0)
    mata: assert(rows(dev) == sum(strpos(dev, char(34) + "auth" + char(34) + ": " + char(34) + "none") :> 0))
    mata: noua = select(R, strpos(R, "framework-stata") :== 0)
    mata: noua
    mata: assert(rows(noua) == 0)
}
t_end `=_rc'

t_begin cloud: fw_setup reports the login without printing the token
capture noisily {
    t_log_begin
    fw_setup, nopython url(http://127.0.0.1:`port')
    t_log_end
    * Built in two parts, so the token never appears in this log.
    local tok = "fw_test_" + "user_token"
    t_log_lacks "`tok'"
    * The keyring line agrees with where fw_login stored the token.
    mata: st_local("mac", strofreal(fw_macos()))
    if c(os) == "Unix" & !`mac' t_log_has "keyring         none"
}
t_end `=_rc'

t_begin cloud: fw_setup names the project server when it differs from the login server
capture noisily {
    * fw_login saved its server in cloud.yml; user calls use it.
    if `"`: environment FW_CLOUD_URL'"' == "" {
        mata: assert(fw_cloud_url("") == "http://127.0.0.1:" + st_local("port"))
    }
    t_log_begin
    fw_setup, nopython nonetwork url(http://localhost:`port')
    t_log_end
    t_log_has "project server  http://127.0.0.1:`port'"
    t_log_begin
    fw_setup, nopython nonetwork url(http://127.0.0.1:`port')
    t_log_end
    t_log_lacks "project server"
}
t_end `=_rc'

t_begin cloud: a project without a token or FW_CLOUD_URL uses the saved login, never framework.pub
capture noisily {
    if `"`: environment FW_CLOUD_URL'"' == "" {
        t_tmpdir
        local bare `"`r(dir)'"'
        t_write `"`bare'/.env"' "OTHER=1"
        * fw_login saved http://127.0.0.1:port in cloud.yml.
        mata: assert(fw_cloud_url(st_local("bare")) == "http://127.0.0.1:" + st_local("port"))
        * Without a saved login, nothing names a server: resolution fails, and
        * only fw_login offers framework.pub.
        local cfg : environment FW_CONFIG_HOME
        mata: st_local("rsaved", strofreal(fileexists(fw_r_config_dir() + "/cloud.yml")))
        if !`rsaved' {
            copy `"`cfg'/cloud.yml"' `"`bare'/cloud.yml.saved"'
            erase `"`cfg'/cloud.yml"'
            mata: why = ""
            mata: assert(fw_cloud_resolve(st_local("bare"), "", 0, why) == "")
            mata: assert(strpos(why, "No Framework Cloud server is chosen") > 0)
            mata: assert(fw_cloud_resolve("", "", 0, why) == "")
            mata: assert(fw_cloud_resolve("", "", 1, why) == "https://framework.pub")
            capture mata: fw_cloud_url(st_local("bare"))
            local norc = _rc
            copy `"`bare'/cloud.yml.saved"' `"`cfg'/cloud.yml"'
            if `norc' == 0 exit 9
        }
    }
}
t_end `=_rc'

t_begin cloud: a project token without FW_CLOUD_URL stops instead of using the saved login
capture noisily {
    if `"`: environment FW_CLOUD_URL'"' == "" {
        t_tmpdir
        local tokened `"`r(dir)'"'
        t_write `"`tokened'/.env"' "# FW_CLOUD_URL=" "FW_PROJECT_TOKEN=unused"
        * The saved login names http://127.0.0.1:port, but the project does not.
        mata: why = ""
        mata: assert(fw_cloud_resolve(st_local("tokened"), "", 0, why) == "")
        mata: assert(why == "This project's .env has FW_PROJECT_TOKEN but no FW_CLOUD_URL, so it does not say which Framework Cloud server issued the token. Add FW_CLOUD_URL=<server> to .env.")
        capture mata: fw_cloud_url(st_local("tokened"))
        assert _rc == 198
        * Publishing stops with the same error.
        capture mata: fw_cloud_publish(st_local("tokened"), "x.png", "", "", "", "", "")
        assert _rc == 198
        * An explicit server still counts.
        mata: assert(fw_cloud_url(st_local("tokened"), "http://localhost:" + st_local("port")) == "http://localhost:" + st_local("port"))
        * The ledger says why it skipped and sends nothing.
        t_requests `"`log'"'
        mata: nled = sum(strpos(R, "/api/v1/ledger") :> 0)
        t_log_begin
        mata: fw_ledger_push(st_local("tokened"), "inputs.final.cars", 64 * "a", st_local("tokened") + "/.env")
        t_log_end
        t_log_has "Ledger push skipped: This project's .env"
        t_requests `"`log'"'
        mata: assert(sum(strpos(R, "/api/v1/ledger") :> 0) == nled)
        * Account calls still use the saved login.
        mata: assert(fw_cloud_url("") == "http://127.0.0.1:" + st_local("port"))
    }
}
t_end `=_rc'

t_begin cloud: a project's FW_CLOUD_URL wins over a different saved login
capture noisily {
    if `"`: environment FW_CLOUD_URL'"' == "" {
        t_tmpdir
        local other `"`r(dir)'"'
        t_write `"`other'/.env"' "FW_CLOUD_URL=http://localhost:`port'/" "FW_PROJECT_TOKEN=unused"
        * The saved login is http://127.0.0.1:port.
        mata: assert(fw_cloud_url(st_local("other")) == "http://localhost:" + st_local("port"))
    }
}
t_end `=_rc'

t_begin cloud: fw_publish uploads to the project with its project token
capture noisily {
    sysuse auto, clear
    regress price mpg
    fw_publish, estimates to(cloud) title("Price model")
    t_eq `"`r(version)'"' "3"
    t_eq `"`r(url)'"' "http://127.0.0.1:`port'/d/regress-price"
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: assert(rows(up) == 1)
    mata: U = fw_json_parse(up[1])
    mata: assert(fw_get(U, "auth") == "project")
    mata: assert(fw_get(U, "form.kind") == "model")
    mata: assert(fw_get(U, "form.title") == "Price model")
    mata: assert(fw_get(U, "form.slug") == "regress-price")
    mata: assert(fw_get(U, "form.file.filename") == "regress-price.json")
}
t_end `=_rc'

t_begin cloud: fw_snippet uploads code_snippet.json under its label
capture noisily {
    t_write `"`root'/snippet.do"' ///
        "fw_snippet begin fit-price" ///
        "regress price mpg" ///
        `"fw_snippet end, visibility(unlisted) title("Price on mileage")"'
    do `"`root'/snippet.do"'
    t_eq `"`r(version)'"' "3"
    t_eq `"`r(url)'"' "http://127.0.0.1:`port'/d/fit-price"
    assert r(unchanged) == 0
    assert r(blocks) == 2
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "auth") == "project")
    mata: assert(fw_get(U, "form.kind") == "code_snippet")
    mata: assert(fw_get(U, "form.slug") == "fit-price")
    mata: assert(fw_get(U, "form.title") == "Price on mileage")
    mata: assert(fw_get(U, "form.visibility") == "unlisted")
    mata: assert(fw_get(U, "form.file.filename") == "code_snippet.json")
}
t_end `=_rc'

t_begin cloud: fw_snippet reports an unchanged snippet with its version
capture noisily {
    t_write `"`root'/same.do"' ///
        "fw_snippet begin same" ///
        "display 42" ///
        "fw_snippet end, slug(unchanged-snippet)"
    t_log_begin
    do `"`root'/same.do"'
    local unchanged = r(unchanged)
    local version `"`r(version)'"'
    t_log_end
    assert `unchanged' == 1
    t_eq `"`version'"' "2"
    t_log_has "Unchanged, still version 2"
}
t_end `=_rc'

t_begin cloud: fw_save pushes a ledger entry when the ledger is live
capture noisily {
    sysuse auto, clear
    fw_save inputs.final.cars
    local sha `"`r(sha256)'"'
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/ledger") :> 0)
    mata: assert(rows(up) == 1)
    mata: U = fw_json_parse(up[1])
    mata: assert(fw_get(U, "auth") == "project")
    mata: assert(fw_get(U, "json.name") == "inputs.final.cars")
    mata: assert(fw_get(U, "json.algo") == "sha256")
    mata: assert(fw_get(U, "json.hash") == st_local("sha"))
}
t_end `=_rc'

t_begin cloud: fw_use, check(accept) pushes the new checksum when the ledger is live
capture noisily {
    sysuse auto, clear
    keep in 1/5
    save `"`root'/inputs/final/cars.dta"', replace
    fw_use inputs.final.cars, clear check(accept)
    assert r(accepted) == 1
    local sha `"`r(sha256)'"'
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/ledger") :> 0)
    mata: assert(rows(up) == 2)
    mata: U = fw_json_parse(up[2])
    mata: assert(fw_get(U, "auth") == "project")
    mata: assert(fw_get(U, "json.name") == "inputs.final.cars")
    mata: assert(fw_get(U, "json.hash") == st_local("sha"))
}
t_end `=_rc'

t_begin cloud: folder publishing records metadata on the linked project
capture noisily {
    * private is short for visibility(private), which lab requires.
    fw_publish "inputs/final/cars.dta", to(lab) title("Cars") private
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/artifacts/external") :> 0)
    mata: assert(rows(up) == 1)
    mata: U = fw_json_parse(up[1])
    mata: assert(fw_get(U, "path") == "/api/v1/projects/example-study/artifacts/external")
    mata: assert(fw_get(U, "json.driver") == "folder")
    mata: assert(fw_get(U, "json.visibility") == "private")
    mata: assert(strlen(fw_get(U, "json.sha256")) == 64)
}
t_end `=_rc'

t_begin cloud: fw_dag uploads dag.json with kind dag
capture noisily {
    fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) ///
        title("Smoking and lung cancer") visibility(unlisted)
    t_eq `"`r(slug)'"' "dag-smoking-cancer"
    t_eq `"`r(url)'"' "http://127.0.0.1:`port'/d/dag-smoking-cancer"
    t_eq `"`r(version)'"' "3"
    assert r(nodes) == 3
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "auth") == "project")
    mata: assert(fw_get(U, "form.kind") == "dag")
    mata: assert(fw_get(U, "form.slug") == "dag-smoking-cancer")
    mata: assert(fw_get(U, "form.title") == "Smoking and lung cancer")
    mata: assert(fw_get(U, "form.visibility") == "unlisted")
    mata: assert(fw_get(U, "form.file.filename") == "dag.json")
}
t_end `=_rc'

t_begin cloud: fw_dag using sends a DAGitty file as it is
capture noisily {
    t_write `"`root'/smoking.dagitty"' "dag {" "smoking [exposure]" "cancer [outcome]" "smoking -> cancer" "}"
    fw_dag using smoking.dagitty
    t_eq `"`r(slug)'"' "smoking"
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.kind") == "dag")
    mata: assert(fw_get(U, "form.file.filename") == "smoking.dagitty")
}
t_end `=_rc'

t_begin cloud: fw_structure, publish uploads structure.json with kind tree
capture noisily {
    t_log_begin
    fw_structure, publish title("Project layout") notes(settings.yml "Project settings") display(notes=off ignored=on)
    local slug `"`r(slug)'"'
    local manage `"`r(artifact_url)'"'
    local share `"`r(embed_link)'"'
    local nodes = r(nodes)
    t_log_end
    t_eq `"`slug'"' "structure"
    t_eq `"`share'"' "http://127.0.0.1:`port'/d/structure"
    t_eq `"`manage'"' "http://127.0.0.1:`port'/artifacts/42"
    assert `nodes' > 0
    t_log_has "Uploading structure.json"
    t_log_has "settings.yml"
    t_log_has "Published version 3."
    t_log_has "Share:  http://127.0.0.1:`port'/d/structure"
    t_log_has "Manage: http://127.0.0.1:`port'/artifacts/42"
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.kind") == "tree")
    mata: assert(fw_get(U, "form.slug") == "structure")
    mata: assert(fw_get(U, "form.title") == "Project layout")
    mata: assert(fw_get(U, "form.file.filename") == "structure.json")
    mata: assert(fw_get(U, "form.display") == `"{"notes":false,"ignored":true}"')
    * The title defaults to the folder name and structure.
    fw_structure, publish slug(layout)
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.title") == fw_basename(st_local("root")) + " structure")
    mata: assert(fw_get(U, "form.file.filename") == "layout.json")
}
t_end `=_rc'

t_begin cloud: display settings parse to the JSON Cloud reads
capture noisily {
    mata: assert(fw_display_json("legend=off") == `"{"legend":false}"')
    mata: assert(fw_display_json(" Legend = OFF  analysis=on ") == `"{"legend":false,"analysis":true}"')
    * A repeated key that agrees is kept once.
    mata: assert(fw_display_json("code=off code=off") == `"{"code":false}"')
    mata: assert(fw_display_json("") == "")
}
t_end `=_rc'

t_begin cloud: fw_publish sends display only when given
capture noisily {
    t_write `"`root'/note.txt"' "A note"
    fw_publish "note.txt", to(cloud) slug("display-note") display(title=off description=on)
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: D = fw_json_parse(fw_get(U, "form.display"))
    mata: assert(fw_get(D, "title") == "false")
    mata: assert(fw_get(D, "description") == "true")
    mata: assert(fw_get(D, ".@") == "title" + char(31) + "description")
    fw_publish "note.txt", to(cloud) slug("display-note")
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.display") == "")
}
t_end `=_rc'

t_begin cloud: fw_dag and fw_snippet pass display to the upload
capture noisily {
    fw_dag "x -> y", exposure(x) outcome(y) display(legend=off dagitty=off)
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.kind") == "dag")
    mata: assert(fw_get(U, "form.display") == `"{"legend":false,"dagitty":false}"')
    t_write `"`root'/hidden.do"' ///
        "fw_snippet begin hidden-output" ///
        "display 42" ///
        "fw_snippet end, display(output=off links=off)"
    do `"`root'/hidden.do"'
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.slug") == "hidden-output")
    mata: assert(fw_get(U, "form.display") == `"{"output":false,"links":false}"')
}
t_end `=_rc'

t_begin cloud: a bad display setting stops before any upload
capture noisily {
    t_requests `"`log'"'
    mata: st_local("before", strofreal(rows(R)))
    t_log_begin
    capture noisily fw_publish "note.txt", to(cloud) display(legnd=off)
    local rc1 = _rc
    capture noisily fw_dag "x -> y", display(legend=no)
    local rc2 = _rc
    capture noisily fw_publish "note.txt", to(cloud) display(legend)
    local rc3 = _rc
    capture noisily fw_publish "note.txt", to(cloud) display(code=off code=on)
    local rc4 = _rc
    t_log_end
    assert `rc1' == 198 & `rc2' == 198 & `rc3' == 198 & `rc4' == 198
    t_log_has "display() has no setting legnd. The settings are title, description"
    t_log_has "display() takes on or off for legend, not no."
    t_log_has "display() takes settings as key=on or key=off"
    t_log_has "display() sets code both on and off."
    t_requests `"`log'"'
    mata: assert(rows(R) == strtoreal(st_local("before")))
}
t_end `=_rc'

t_begin cloud: a bad display setting leaves the snippet open
capture noisily {
    t_write `"`root'/badopt.do"' ///
        "fw_snippet begin kept-open" ///
        "display 1" ///
        "capture noisily fw_snippet end, display(outptu=off)" ///
        "assert _rc == 198" ///
        "fw_snippet end, display(output=off)"
    do `"`root'/badopt.do"'
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.slug") == "kept-open")
}
t_end `=_rc'

t_begin cloud: a public artifact prints its version, Share, and Manage
capture noisily {
    t_write `"`root'/embed.txt"' "Embed me"
    t_log_begin
    fw_publish "embed.txt", to(cloud) slug(embed-public) visibility(public)
    local share `"`r(embed_link)'"'
    local manage `"`r(artifact_url)'"'
    local url `"`r(url)'"'
    t_log_end
    t_eq `"`share'"' "http://127.0.0.1:`port'/go/abcd"
    t_eq `"`manage'"' "http://127.0.0.1:`port'/artifacts/42"
    t_eq `"`url'"' "http://127.0.0.1:`port'/d/embed-public"
    mata: L = fw_readlines(st_global("T_LOG"))
    mata: k = select(1::rows(L), L :== "Published version 3.")
    mata: assert(rows(k) == 1)
    mata: assert(L[k + 1] == "Share:  http://127.0.0.1:" + st_local("port") + "/go/abcd")
    mata: assert(L[k + 2] == "Manage: http://127.0.0.1:" + st_local("port") + "/artifacts/42")
    t_log_lacks "Published to cloud"
    t_log_lacks "Embed:"
}
t_end `=_rc'

t_begin cloud: unlisted DAGs and snippets share their own link
capture noisily {
    t_log_begin
    fw_dag "x -> y", exposure(x) outcome(y) slug(embed-dag)
    local dag `"`r(embed_link)'"'
    local dagm `"`r(artifact_url)'"'
    t_write `"`root'/embedsnip.do"' ///
        "fw_snippet begin embed-snippet" ///
        "display 42" ///
        "fw_snippet end"
    do `"`root'/embedsnip.do"'
    local snip `"`r(embed_link)'"'
    local snipm `"`r(artifact_url)'"'
    t_log_end
    t_eq `"`dag'"' "http://127.0.0.1:`port'/d/embed-dag"
    t_eq `"`snip'"' "http://127.0.0.1:`port'/d/embed-snippet"
    t_eq `"`dagm'"' "http://127.0.0.1:`port'/artifacts/42"
    t_eq `"`snipm'"' "http://127.0.0.1:`port'/artifacts/42"
    t_log_has "Share:  http://127.0.0.1:`port'/d/embed-dag"
    t_log_has "Share:  http://127.0.0.1:`port'/d/embed-snippet"
}
t_end `=_rc'

t_begin cloud: a private artifact prints Manage alone
capture noisily {
    t_log_begin
    fw_publish "embed.txt", to(cloud) slug(embed-private) private
    local link `"`r(embed_link)'"'
    local manage `"`r(artifact_url)'"'
    t_log_end
    t_eq `"`link'"' ""
    t_eq `"`manage'"' "http://127.0.0.1:`port'/artifacts/42"
    t_log_has "Published version 3."
    t_log_has "Manage: http://127.0.0.1:`port'/artifacts/42"
    t_log_lacks "Share:"
}
t_end `=_rc'

t_begin cloud: an old server that reports neither link gets the published link
capture noisily {
    t_log_begin
    fw_publish "embed.txt", to(cloud) slug(old-server)
    local link `"`r(embed_link)'"'
    local manage `"`r(artifact_url)'"'
    t_log_end
    t_eq `"`link'"' ""
    t_eq `"`manage'"' ""
    t_log_has "Published to cloud (version 3): http://127.0.0.1:`port'/d/old-server"
    t_log_lacks "Share:"
    t_log_lacks "Manage:"
}
t_end `=_rc'

t_begin cloud: a folder destination prints no Share or Manage link
capture noisily {
    t_log_begin
    fw_publish "embed.txt", to(lab) private
    local link `"`r(embed_link)'`r(artifact_url)'"'
    t_log_end
    t_eq `"`link'"' ""
    t_log_lacks "Share:"
    t_log_lacks "Manage:"
}
t_end `=_rc'

t_begin cloud: fw_dag to a folder destination records kind dag
capture noisily {
    fw_dag "x -> y", exposure(x) outcome(y) to(lab) private
    mata: A = fw_json_read(st_local("root") + "/site/dag-x-y/artifact.json")
    mata: assert(fw_get(A, "kind") == "dag")
    mata: R2 = fw_json_read(st_local("root") + "/site/dag-x-y/representation.json")
    mata: assert(fw_get(R2, "dagitty") == "dag {" + char(10) + "x [exposure]" + char(10) + "y [outcome]" + char(10) + "x -> y" + char(10) + "}")
}
t_end `=_rc'

t_begin cloud: r(slug) matches the uploaded slug for an HTML report
capture noisily {
    mkdir `"`root'/report_files"'
    t_write `"`root'/report.html"' "<!doctype html><title>Report</title><img src=report_files/a.png>"
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/report_files/a.png"'
    fw_publish "report.html", to(cloud) slug("my-report.html")
    t_eq `"`r(slug)'"' "my-report"
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.slug") == "my-report")
    * A slug does not set visibility: Cloud keeps it, or makes a new artifact unlisted.
    mata: assert(fw_get(U, "form.readable") == "")
    mata: assert(fw_get(U, "form.visibility") == "")
}
t_end `=_rc'

t_begin cloud: visibility goes to Cloud only when asked for
capture noisily {
    fw_publish "report.html", to(cloud) slug("my-report") private
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.visibility") == "private")
    mata: assert(fw_get(U, "form.readable") == "")
}
t_end `=_rc'

t_begin cloud: a folder uploads as one bundle with its front page
capture noisily {
    mkdir `"`root'/figs"'
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/figs/a.png"'
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/figs/b.png"'
    fw_publish "figs/*.png", to(cloud) title("Figures")
    t_eq `"`r(slug)'"' "figs"
    assert r(files) == 2
    t_requests `"`log'"'
    mata: up = select(R, strpos(R, "/api/v1/documents") :> 0)
    mata: U = fw_json_parse(up[rows(up)])
    mata: assert(fw_get(U, "form.slug") == "figs")
    mata: assert(fw_get(U, "form.entrypoint") == "index.html")
    mata: assert(fw_get(U, "form.bundle.filename") == "bundle.zip")
    mata: assert(fw_get(U, "form.title") == "Figures")
}
t_end `=_rc'

t_begin cloud: a missing project token names the fix
capture noisily {
    t_write `"`root'/.env"' "FW_CLOUD_URL=http://127.0.0.1:`port'"
    t_log_begin
    capture noisily fw_publish, estimates to(cloud)
    local rc = _rc
    t_log_end
    assert `rc' == 677
    t_log_has "FW_PROJECT_TOKEN"
    * The token check comes before the upload message.
    t_log_lacks "Uploading"
}
t_end `=_rc'

t_begin cloud: a live ledger without a project token says it skipped the push
capture noisily {
    sysuse auto, clear
    t_log_begin
    fw_save inputs.final.cars_untracked, replace
    t_log_end
    t_log_has "Ledger push skipped"
    t_log_has "no project token"
}
t_end `=_rc'

t_begin cloud: a refused login request does not mention a token it never sent
capture noisily {
    t_log_begin
    capture noisily fw_login, url(http://127.0.0.1:`port'/reject) nobrowser
    local rc = _rc
    t_log_end
    assert `rc' == 677
    t_log_has "refused the login request (HTTP 401)"
    t_log_lacks "rejected the token"
}
t_end `=_rc\'

t_begin cloud: fw_logout revokes the token on the server, then removes the file
capture noisily {
    t_log_begin
    fw_logout, url(http://127.0.0.1:`port')
    t_log_end
    local cfg : environment FW_CONFIG_HOME
    capture confirm file `"`cfg'/cloud-token-127.0.0.1_`port'"'
    assert _rc
    t_requests `"`log'"'
    mata: rv = select(R, strpos(R, char(34) + "/api/v1/token" + char(34)) :> 0)
    mata: assert(rows(rv) == 1)
    mata: U = fw_json_parse(rv[1])
    mata: assert(fw_get(U, "method") == "DELETE")
    mata: assert(fw_get(U, "auth") == "user")
    t_log_lacks "could not be revoked"
    local tok = "fw_test_" + "user_token"
    t_log_lacks "`tok'"
}
t_end `=_rc'

t_begin cloud: fw_logout treats a rejected token as already revoked
capture noisily {
    local cfg : environment FW_CONFIG_HOME
    t_write `"`cfg'/cloud-token-127.0.0.1_`port'"' "fw_already_invalid_token"
    t_log_begin
    fw_logout, url(http://127.0.0.1:`port')
    t_log_end
    capture confirm file `"`cfg'/cloud-token-127.0.0.1_`port'"'
    assert _rc
    t_log_lacks "could not be revoked"
}
t_end `=_rc'

t_begin cloud: fw_logout removes the token when the server cannot be reached
capture noisily {
    local cfg : environment FW_CONFIG_HOME
    t_write `"`cfg'/cloud-token-127.0.0.1_9"' "fw_unreachable_token"
    t_log_begin
    fw_logout, url(http://127.0.0.1:9)
    t_log_end
    capture confirm file `"`cfg'/cloud-token-127.0.0.1_9"'
    assert _rc
    t_log_has "could not be revoked on 127.0.0.1:9"
    t_log_has "http://127.0.0.1:9/tokens"
}
t_end `=_rc'

quietly cd `"$FW_TEST_REPO"'
