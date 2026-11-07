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
    t_eq `"`r(stored)'"' "file"
    local cfg : environment FW_CONFIG_HOME
    confirm file `"`cfg'/cloud-token-127.0.0.1_`port'"'
    confirm file `"`cfg'/cloud.yml"'
    * The token file is private to the user.
    tempfile perm
    shell stat -c %a "`cfg'/cloud-token-127.0.0.1_`port'" > "`perm'"
    mata: assert(fw_clean(fw_readfile(st_local("perm"))) == "600")
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
    if c(os) == "Unix" t_log_has "keyring         none"
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
