*! fw_cloud.mata: Framework Cloud requests through curl
*! Loaded by _fw_init. Do not run directly.

version 14

mata:
mata set matastrict off

real scalar fw_loaded() return(1)

// A value in a curl configuration file.
string scalar fw_cfgq(string scalar s_in)
{
    s = subinstr(s_in, char(92), char(92) + char(92))
    s = subinstr(s, fw_dq(), char(92) + fw_dq())
    s = subinstr(s, char(10), char(92) + "n")
    s = subinstr(s, char(13), char(92) + "r")
    return(fw_dq() + s + fw_dq())
}

// A file name inside curl's -F syntax: file=@"name".
string scalar fw_formfile(string scalar field, string scalar path)
{
    p = fw_norm(path)
    p = subinstr(p, char(92), char(92) + char(92))
    p = subinstr(p, fw_dq(), char(92) + fw_dq())
    return(field + "=@" + fw_dq() + p + fw_dq())
}

string scalar fw_user_agent() return("framework-stata/" + fw_version() + " (Stata " + strofreal(c("stata_version")) + "; " + c("os") + ")")

// Write a curl configuration. form is n x 3: name, value, is_file ("1"/"0").
string scalar fw_curl_cfg(string scalar dir, string scalar name, string scalar method,
    string scalar url, string scalar jsonbody, string matrix form, string scalar output,
    real scalar timeout)
{
    cfg = dir + "/" + name + ".cfg"
    s = "url = " + fw_cfgq(url) + fw_nl()
    if (method != "GET") s = s + "request = " + fw_cfgq(method) + fw_nl()
    s = s + "header = " + fw_cfgq("Accept: application/json") + fw_nl()
    s = s + "user-agent = " + fw_cfgq(fw_user_agent()) + fw_nl()
    if (jsonbody != "") {
        bodyfile = dir + "/" + name + "-body.json"
        fw_writefile(bodyfile, jsonbody)
        s = s + "header = " + fw_cfgq("Content-Type: application/json") + fw_nl()
        s = s + "data-binary = " + fw_cfgq("@" + fw_norm(bodyfile)) + fw_nl()
    }
    for (i = 1; i <= rows(form); i++) {
        if (form[i, 3] == "1") s = s + "form = " + fw_cfgq(fw_formfile(form[i, 1], form[i, 2])) + fw_nl()
        else s = s + "form-string = " + fw_cfgq(form[i, 1] + "=" + form[i, 2]) + fw_nl()
    }
    s = s + "output = " + fw_cfgq(fw_norm(output)) + fw_nl()
    s = s + "write-out = " + fw_cfgq("%{http_code}") + fw_nl()
    s = s + "silent" + fw_nl() + "show-error" + fw_nl()
    s = s + "connect-timeout = 20" + fw_nl()
    s = s + "max-time = " + strofreal(timeout) + fw_nl()
    if (fw_env("FW_CLOUD_INSECURE") != "") s = s + "insecure" + fw_nl()
    fw_writefile(cfg, s)
    return(cfg)
}

// net install keeps only Stata file types, so the scripts ship as .ihlp
// files. Each call copies the right one into the private scratch folder.
string scalar fw_cloud_script(string scalar dir)
{
    name = fw_windows() ? "fw_cloud_ps1.ihlp" : "fw_cloud_sh.ihlp"
    rc = _stata("quietly findfile " + name)
    if (rc) fw_error("The framework package is incomplete: " + name + " is missing. Reinstall the package.", 601)
    script = dir + (fw_windows() ? "/fw_cloud.ps1" : "/fw_cloud.sh")
    if (!fileexists(script)) fw_writefile(script, fw_readfile(st_global("r(fn)")))
    return(script)
}

real scalar fw_cloud_call(string rowvector args, string scalar dir, | real scalar timeout)
{
    if (args() < 3) timeout = 300
    script = fw_cloud_script(dir)
    if (fw_windows()) {
        cmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + fw_dq() + subinstr(script, "/", char(92)) + fw_dq()
        for (i = 1; i <= cols(args); i++) cmd = cmd + " " + fw_dq() + args[i] + fw_dq()
    }
    else {
        cmd = "/bin/sh " + fw_shq(script)
        for (i = 1; i <= cols(args); i++) cmd = cmd + " " + fw_shq(args[i])
    }
    return(fw_run(cmd, dir, timeout))
}

real scalar fw_have_curl(string scalar dir)
{
    if (fw_windows()) return(fw_which("curl.exe", dir) != "")
    return(fw_which("curl", dir) != "")
}

// One HTTP request. kind: project, user, or none. Returns the HTTP status,
// or a negative value when the request could not be sent. The response body
// is at dir/<name>.json.
real scalar fw_http(string scalar name, string scalar method, string scalar url, string scalar kind,
    string scalar root, string scalar dir, string scalar jsonbody, string matrix form,
    | real scalar timeout)
{
    if (args() < 9) timeout = 120
    fw_rm(dir + "/status.txt"); fw_rm(dir + "/problem.txt"); fw_rm(dir + "/curl.err")
    out = dir + "/" + name + ".json"
    fw_rm(out)
    cfg = fw_curl_cfg(dir, name, method, url, jsonbody, form, out, timeout)
    rc = fw_cloud_call(("http", cfg, kind, root, fw_url_host(url), dir), dir, timeout + 30)
    if (rc == 3) {
        problem = fw_clean(fw_readfile(dir + "/problem.txt"))
        if (problem == "no-project-token") return(-3)
        return(-4)
    }
    if (rc) {
        st_local("fw_http_error", fileexists(dir + "/curl.err") ? fw_clean(fw_readfile(dir + "/curl.err")) : "")
        return(-rc - 100)
    }
    status = strtoreal(fw_clean(fw_readfile(dir + "/status.txt")))
    return(status == . ? -1 : status)
}

// A short reason for a failed request.
string scalar fw_http_reason(real scalar status, string scalar dir, string scalar name, string scalar url)
{
    host = fw_url_host(url)
    if (status == -3) return("This project has no Framework Cloud project token. Add FW_PROJECT_TOKEN to the project's .env file. The Cloud documentation explains how: " + fw_cloud_base(url) + "/docs/getting-started")
    if (status == -4) return("This computer is not connected to " + host + ". Run fw_login.")
    if (status < -100) return("The request to " + host + " failed: " + st_local("fw_http_error"))
    if (status < 0) return("The request to " + host + " could not be sent. Run fw_setup to check curl.")
    msg = fw__response_message(dir + "/" + name + ".json")
    if (status == 401 | status == 403) return(host + " rejected the token (HTTP " + strofreal(status) + "). " + (msg != "" ? msg : "Check the token, or run fw_login again."))
    if (status == 402) return(msg != "" ? msg : host + " needs paid hosting for this upload (HTTP 402).")
    if (status == 404) return(host + " returned HTTP 404 for " + url + ". " + msg)
    return(host + " returned HTTP " + strofreal(status) + ". " + msg)
}

// The message or error in a JSON response body, or "".
string scalar fw__response_message(string scalar file)
{
    msg = ""
    if (fileexists(file)) {
        raw = fw_readfile(file)
        if (fw_startswith(strtrim(raw), "{")) {
            J = fw_json_parse(raw)
            msg = fw_get(J, "message")
            if (msg == "") msg = fw_get(J, "error")
        }
    }
    return(msg)
}

string scalar fw_cloud_base(string scalar url)
{
    if (regexm(url, "^(https?://[^/]+)")) return(regexs(1))
    return(url)
}

// ---------------------------------------------------------------------------
// The integrity ledger
// ---------------------------------------------------------------------------

void fw_ledger_push(string scalar root, string scalar name, string scalar sha, string scalar path)
{
    if (sha == "") {
        printf("{txt}Ledger push skipped: no SHA-256 tool was found.\n")
        return
    }
    url = fw_cloud_url(root)
    d = fw_scratch()
    body = "{" + fw_json_str("name") + ":" + fw_json_str(name) + "," +
        fw_json_str("algo") + ":" + fw_json_str("sha256") + "," +
        fw_json_str("hash") + ":" + fw_json_str(sha) + "," +
        fw_json_str("size_bytes") + ":" + fw_json_num(fw_filesize(path)) + "," +
        fw_json_str("recorded_at") + ":" + fw_json_str(fw_now_utc(d)) + "," +
        fw_json_str("client") + ":{" + fw_json_str("device") + ":" + fw_json_str(c("hostname")) + "," +
        fw_json_str("package_version") + ":" + fw_json_str("framework-stata " + fw_version()) + "}}"
    status = fw_http("ledger", "POST", url + "/api/v1/ledger", "project", root, d, body, J(0, 3, ""), 30)
    if (status == -3) {
        printf("{txt}Ledger push skipped: this project has no project token. Add FW_PROJECT_TOKEN to .env, or set FW_LEDGER=off.\n")
        fw_scratch_done(d)
        return
    }
    if (status < 200 | status >= 300) {
        printf("{txt}Ledger push skipped: %s\n", fw_http_reason(status, d, "ledger", url))
        fw_scratch_done(d)
        return
    }
    J = fw_json_read(d + "/ledger.json")
    printf("{txt}[ok] Ledger entry #%s recorded on %s\n", fw_get(J, "sequence"), fw_url_host(url))
    fw_scratch_done(d)
}

// ---------------------------------------------------------------------------
// Login and logout
// ---------------------------------------------------------------------------

void fw_consent_notice(string scalar url)
{
    printf("{txt}Connecting this computer to %s enables Cloud features\n", url)
    printf("{txt}that send data to that service when you use them:\n")
    printf("{txt}  - integrity ledger: file digests, sizes, and this computer's name\n")
    printf("{txt}    (fw_save and fw_use, check(accept), only with the ledger on. It is off unless\n")
    printf("{txt}    the project sets options: cloud_ledger: live or you set FW_LEDGER=live)\n")
    printf("{txt}  - publishing: files you explicitly publish with fw_publish\n")
    printf("{txt}Your data files are never uploaded unless you publish them.\n")
    printf("{txt}Details: %s/privacy\n\n", url)
}

void fw_login_run(string scalar given, real scalar noopen)
{
    url = fw_cloud_url("", given)
    host = fw_url_host(url)
    d = fw_scratch()
    if (!fw_have_curl(d)) {
        fw_scratch_done(d)
        fw_error("fw_login needs curl. It ships with macOS, Linux, and Windows 10 or later. Run fw_setup for details.", 601)
    }
    fw_consent_notice(url)
    body = "{" + fw_json_str("client_name") + ":" + fw_json_str("Stata on " + c("hostname")) + "}"
    status = fw_http("device", "POST", url + "/api/v1/cli/device", "none", "", d, body, J(0, 3, ""), 30)
    if (status == 404 | status == 405) {
        fw_scratch_done(d)
        fw_error(host + " does not offer browser login. Create a token at " + url + "/tokens, then connect with fw login --paste, or with cloud_login() in R or Python.", 198)
    }
    if (status == 401 | status == 403) {
        // The device request carries no token, so the server refused the login itself.
        smsg = fw__response_message(d + "/device.json")
        msg = host + " refused the login request (HTTP " + strofreal(status) + "). No token was sent." +
            (smsg != "" ? " " + smsg : "")
        fw_scratch_done(d)
        fw_error(msg, 677)
    }
    if (status != 200 & status != 201) {
        msg = fw_http_reason(status, d, "device", url)
        fw_scratch_done(d)
        fw_error(msg, 677)
    }
    J = fw_json_read(d + "/device.json")
    code = fw_get(J, "device_code")
    user_code = fw_get(J, "user_code")
    vurl = fw_get(J, "verification_url")
    vfull = fw_get(J, "verification_url_complete")
    if (vfull == "") vfull = vurl
    interval = strtoreal(fw_get(J, "interval"))
    if (interval == . | interval < 1) interval = 5
    expires = strtoreal(fw_get(J, "expires_in"))
    if (expires == .) expires = 600
    printf("{txt}Approve this computer in your browser.\n")
    printf("{txt}  Code: {res}%s\n", user_code)
    printf("{txt}  Page: {browse " + char(34) + "%s" + char(34) + "}\n", vfull)
    if (!noopen & c("mode") != "batch") {
        rc = _stata("view browse " + fw_cq(vfull), 1)
        printf("{txt}The page should open in your browser. If it does not, open the link above.\n")
    }
    printf("{txt}Waiting for approval. Press Break to stop.\n")
    pollbody = "{" + fw_json_str("device_code") + ":" + fw_json_str(code) + "}"
    waited = 0
    while (waited < expires) {
        stata("sleep " + strofreal(interval * 1000))
        waited = waited + interval
        fw_rm(d + "/status.txt"); fw_rm(d + "/problem.txt"); fw_rm(d + "/stored.txt")
        cfg = fw_curl_cfg(d, "poll", "POST", url + "/api/v1/cli/device/token", pollbody, J(0, 3, ""), d + "/poll.json", 30)
        rc = fw_cloud_call(("poll", cfg, host, url, d), d, 120)
        if (rc == 5) {
            fw_scratch_done(d)
            fw_error(host + " rejected the new token. Run fw_login again.", 677)
        }
        if (rc) {
            msg = fileexists(d + "/curl.err") ? fw_clean(fw_readfile(d + "/curl.err")) : ""
            fw_scratch_done(d)
            fw_error("Login stopped: the request to " + host + " failed. " + msg, 677)
        }
        status = strtoreal(fw_clean(fw_readfile(d + "/status.txt")))
        fw_rm(d + "/poll.json")
        if (status == 428) continue
        if (status == 429) {
            interval = interval + 5
            continue
        }
        if (status == 403) {
            fw_scratch_done(d)
            fw_error("The login request was denied in the browser.", 677)
        }
        if (status == 410) {
            fw_scratch_done(d)
            fw_error("The login code expired. Run fw_login again.", 677)
        }
        if (status != 200) {
            fw_scratch_done(d)
            fw_error(host + " returned HTTP " + strofreal(status) + " while waiting for approval.", 677)
        }
        stored = fw_clean(fw_readfile(d + "/stored.txt"))
        M = fw_json_read(d + "/me.json")
        who = fw_get(M, "user.name")
        if (who == "") who = fw_get(M, "name")
        email = fw_get(M, "user.email")
        if (email == "") email = fw_get(M, "email")
        fw_scratch_done(d)
        fw_save_server(url)
        printf("{txt}Connected to {res}%s{txt}%s.\n", host, who != "" ? " as " + who + (email != "" ? " (" + email + ")" : "") : "")
        if (stored == "keyring") printf("{txt}The token is in the system keyring, shared with R, Python, and fw.\n")
        else printf("{txt}The token is in a private file in %s, shared with Python and fw.\n", fw_config_dir())
        st_local("fw_account", who)
        st_local("fw_stored", stored)
        return
    }
    fw_scratch_done(d)
    fw_error("The login code expired. Run fw_login again.", 677)
}

// Remember the default server, as cloud_login() does.
void fw_save_server(string scalar url)
{
    dir = fw_config_dir()
    fw_mkdirp(dir)
    fw_writefile(dir + "/cloud.yml", "server: " + url + fw_nl())
}

void fw_logout_run(string scalar given)
{
    url = fw_cloud_url("", given)
    host = fw_url_host(url)
    d = fw_scratch()
    // The script revokes the stored token on the server, then removes it.
    rc = fw_cloud_call(("logout", host, url, d), d, 120)
    out = fw_run_out(d)
    fw_scratch_done(d)
    if (rc) fw_error("Logout failed. " + out, 198)
    lines = tokens(subinstr(out, char(13), ""), char(10))
    removed = ""
    rfile = ""
    revoke = ""
    for (i = 1; i <= cols(lines); i++) {
        if (lines[i] == "revoked" | lines[i] == "not-revoked") revoke = lines[i]
        if (fw_startswith(lines[i], "removed")) removed = strtrim(substr(lines[i], 8, .))
        if (fw_startswith(lines[i], "r-file ")) rfile = substr(lines[i], 8, .)
    }
    if (removed == "") printf("{txt}No stored token for %s was found.\n", host)
    else printf("{txt}Removed the token for %s from: %s\n", host, removed)
    if (revoke == "not-revoked") {
        printf("{txt}The token could not be revoked on %s.\n", host)
        printf("{txt}Revoke it on the tokens page: %s/tokens\n", url)
    }
    if (rfile != "") printf("{txt}R keeps its own token file at %s. Remove it with cloud_logout() in R.\n", rfile)
    if (fw_env("FW_CLOUD_TOKEN") != "") printf("{txt}FW_CLOUD_TOKEN is still set in the environment.\n")
}

// Where the user token for a server comes from: environment, keyring, file, or none.
string scalar fw_token_source(string scalar url, string scalar dir)
{
    rc = fw_cloud_call(("status", fw_url_host(url)), dir, 60)
    if (rc) return("unknown")
    return(strtrim(subinstr(fw_run_out(dir), char(10), "")))
}

// ---------------------------------------------------------------------------
// fw_setup checks
// ---------------------------------------------------------------------------

void fw__setup_tools()
{
    d = fw_scratch()
    curl = fw_which(fw_windows() ? "curl.exe" : "curl", d)
    st_local("have_curl", curl != "" ? "1" : "0")
    if (curl != "") {
        rc = fw_run(fw__cliarg(curl) + " --version", d, 30)
        v = tokens(fw_clean(fw_run_out(d)))
        printf("{txt}  curl            {res}%s{txt} (%s)\n", cols(v) >= 2 ? v[2] : "found", curl)
    }
    else printf("{txt}  curl            {err}not found{txt}\n")
    f = d + "/probe.txt"
    fw_writefile(f, "abc")
    h = fw_sha256(f, d)[1]
    ok = (h == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    st_local("have_sha", ok ? "1" : "0")
    tool = fw_windows() ? "PowerShell Get-FileHash" : (fw_which("sha256sum", d) != "" ? "sha256sum" : "shasum")
    if (ok) printf("{txt}  SHA-256         {res}%s{txt}\n", tool)
    else printf("{txt}  SHA-256         {err}not available{txt}\n")
    if (fw_windows()) ring = "Windows Credential Manager"
    else if (c("os") == "MacOSX") ring = "macOS Keychain (security)"
    else {
        // Ask the Cloud script, so fw_setup and fw_login agree on the keyring.
        rc = fw_cloud_call(("keyring"), d, 60)
        ring = (!rc & strtrim(fw_run_out(d)) == "secret-service" ? "Secret Service (secret-tool)" :
            "none; tokens go in a private file in " + fw_config_dir())
    }
    printf("{txt}  keyring         {res}%s{txt}\n", ring)
    fw_scratch_done(d)
}

string scalar fw__setup_token(string scalar url)
{
    d = fw_scratch()
    s = fw_token_source(url, d)
    fw_scratch_done(d)
    return(s == "" ? "none" : s)
}

void fw__setup_me(string scalar url)
{
    d = fw_scratch()
    rc = fw_cloud_call(("check", fw_url_host(url), url, d), d, 60)
    if (rc) {
        printf("{txt}  connection      {err}could not reach %s{txt}\n", fw_url_host(url))
        fw_scratch_done(d)
        return
    }
    status = strtoreal(fw_clean(fw_readfile(d + "/status.txt")))
    if (status == 200) {
        M = fw_json_read(d + "/me.json")
        who = fw_get(M, "user.name")
        if (who == "") who = fw_get(M, "name")
        printf("{txt}  account         {res}%s{txt}\n", who != "" ? who : "connected")
    }
    else printf("{txt}  connection      {err}token rejected (HTTP %s){txt}. Run fw_login.\n", strofreal(status))
    fw_scratch_done(d)
}

void fw__setup_fw()
{
    d = fw_scratch()
    fw = fw_find_fw(d)
    st_local("fwexe", fw)
    st_local("fwstale", fw_fw_path_stale())
    if (fw != "") {
        rc = fw_run(fw__cliarg(fw) + " version", d, 30)
        v = fw_clean(fw_run_out(d))
        printf("{txt}  fw              {res}%s{txt} (%s)\n", v != "" ? v : "found", fw)
    }
    fw_scratch_done(d)
}

end
