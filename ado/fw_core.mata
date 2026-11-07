*! fw_core.mata: Framework for Stata core functions
*! Loaded by _fw_init. Do not run directly.
*
* Mata in a do-file passes through macro expansion. This file therefore
* never writes a backtick, a dollar sign, or a left single quote literally.
* It builds them with char(96), char(36), and char(39).

version 14

mata:
mata set matastrict off

string scalar fw_version() return("0.2.0")

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

string scalar fw_dq() return(char(34))
string scalar fw_sq() return(char(39))
string scalar fw_nl() return(char(10))

// Wrap a string in Stata compound double quotes for stata() calls.
string scalar fw_cq(string scalar s) return(char(96) + char(34) + s + char(34) + char(39))

// A plain double-quoted path for shell scripts and curl configuration.
string scalar fw_shq(string scalar s)
{
    // Single-quote for /bin/sh: close, escape, reopen.
    return(fw_sq() + subinstr(s, fw_sq(), fw_sq() + char(92) + fw_sq() + fw_sq()) + fw_sq())
}

real scalar fw_windows() return(c("os") == "Windows")

real scalar fw_startswith(string scalar s, string scalar p)
    return(substr(s, 1, strlen(p)) == p)

real scalar fw_endswith(string scalar s, string scalar p)
{
    if (strlen(p) > strlen(s)) return(0)
    return(substr(s, strlen(s) - strlen(p) + 1, .) == p)
}

void fw_error(string scalar msg, | real scalar rc_in)
{
    rc = (args() < 2 ? 198 : rc_in)
    // One errprintf per line, so Stata wraps each line on its own.
    rest = msg
    while ((k = strpos(rest, fw_nl())) > 0) {
        errprintf("%s\n", substr(rest, 1, k - 1))
        rest = substr(rest, k + 1, .)
    }
    errprintf("%s\n", rest)
    exit(rc)
}

// Trim spaces and line breaks.
string scalar fw_clean(string scalar s)
    return(strtrim(subinstr(subinstr(s, char(13), " "), char(10), " ")))

void fw_rm(string scalar path)
{
    if (fileexists(path)) unlink(path)
}

string scalar fw_env(string scalar name)
{
    // Stata's extended macro function reads the process environment.
    stata("local __fw_env : environment " + name)
    return(st_local("__fw_env"))
}

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

string colvector fw_readlines(string scalar path)
{
    fh = fopen(path, "r")
    lines = J(0, 1, "")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (fw_endswith(line, char(13))) line = substr(line, 1, strlen(line) - 1)
        lines = lines \ line
    }
    fclose(fh)
    // Drop a UTF-8 byte order mark.
    if (rows(lines) & substr(lines[1], 1, 3) == char((239, 187, 191))) {
        lines[1] = substr(lines[1], 4, .)
    }
    return(lines)
}

string scalar fw_readfile(string scalar path)
{
    fh = fopen(path, "r")
    s = ""
    while ((chunk = fread(fh, 1048576)) != J(0, 0, "")) s = s + chunk
    fclose(fh)
    return(s)
}

void fw_writefile(string scalar path, string scalar s)
{
    if (fileexists(path)) unlink(path)
    fh = fopen(path, "w")
    // fwrite has no length limit issue for long strings; write in chunks.
    n = strlen(s)
    for (i = 1; i <= n; i = i + 1048576) fwrite(fh, substr(s, i, 1048576))
    fclose(fh)
}

real scalar fw_filesize(string scalar path)
{
    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fclose(fh)
    return(n)
}

void fw_mkdirp(string scalar path_in)
{
    path = fw_norm(path_in)
    if (path == "" | direxists(path)) return
    parent = fw_dirname(path)
    if (parent != path & parent != "") fw_mkdirp(parent)
    if (!direxists(path)) {
        rc = _mkdir(path)
        if (rc & !direxists(path)) fw_error("Cannot create the folder " + path + ".", 693)
    }
}

void fw_copy(string scalar from, string scalar to)
{
    rc = _stata("quietly copy " + fw_cq(from) + " " + fw_cq(to) + ", replace")
    if (rc) fw_error("Cannot copy " + from + " to " + to + ".", rc)
}

// Every file under a folder, as paths relative to it, sorted.
string colvector fw_walk(string scalar root, | string scalar rel)
{
    if (args() < 2) rel = ""
    here = (rel == "" ? root : root + "/" + rel)
    out = J(0, 1, "")
    files = sort(dir(here, "files", "*", 0), 1)
    for (i = 1; i <= rows(files); i++) {
        out = out \ (rel == "" ? files[i] : rel + "/" + files[i])
    }
    dirs = sort(dir(here, "dirs", "*", 0), 1)
    for (i = 1; i <= rows(dirs); i++) {
        if (dirs[i] == "." | dirs[i] == "..") continue
        out = out \ fw_walk(root, rel == "" ? dirs[i] : rel + "/" + dirs[i])
    }
    return(sort(out, 1))
}

void fw_copytree(string scalar from, string scalar to)
{
    fw_mkdirp(to)
    files = fw_walk(from)
    for (i = 1; i <= rows(files); i++) {
        fw_mkdirp(fw_dirname(to + "/" + files[i]))
        fw_copy(from + "/" + files[i], to + "/" + files[i])
    }
}

void fw_rmtree(string scalar path)
{
    if (fileexists(path) & !direxists(path)) {
        fw_rm(path)
        return
    }
    if (!direxists(path)) return
    files = dir(path, "files", "*", 0)
    for (i = 1; i <= rows(files); i++) rc = _unlink(path + "/" + files[i])
    dirs = dir(path, "dirs", "*", 0)
    for (i = 1; i <= rows(dirs); i++) {
        if (dirs[i] == "." | dirs[i] == "..") continue
        fw_rmtree(path + "/" + dirs[i])
    }
    rc = _rmdir(path)
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

// Mata passes arguments by reference, so these path helpers copy their
// arguments before changing them. Callers keep their own values.
string scalar fw_norm(string scalar p_in)
{
    p = subinstr(p_in, char(92), "/")
    while (strpos(p, "//") > 1) p = subinstr(p, "//", "/")
    if (strlen(p) > 1 & fw_endswith(p, "/") & !regexm(p, "^[A-Za-z]:/$")) {
        p = substr(p, 1, strlen(p) - 1)
    }
    return(p)
}

real scalar fw_isabs(string scalar p_in)
{
    p = subinstr(p_in, char(92), "/")
    return(fw_startswith(p, "/") | fw_startswith(p, "~") | regexm(p, "^[A-Za-z]:/"))
}

string scalar fw_home()
{
    h = fw_env("HOME")
    if (h == "") h = fw_env("USERPROFILE")
    return(fw_norm(h))
}

// An absolute, normalized path. Relative paths resolve against base.
string scalar fw_abs(string scalar p_in, | string scalar base_in)
{
    base = (args() < 2 ? pwd() : base_in)
    p = fw_norm(p_in)
    if (fw_startswith(p, "~/") | p == "~") p = fw_home() + substr(p, 2, .)
    if (!fw_isabs(p)) p = fw_norm(base) + "/" + p
    // Remove . and .. segments textually.
    parts = tokens(p, "/")
    parts = select(parts, parts :!= "/")
    out = J(1, 0, "")
    for (i = 1; i <= cols(parts); i++) {
        if (parts[i] == ".") continue
        if (parts[i] == "..") {
            if (cols(out) > 0) out = out[|1 \ cols(out) - 1|]
            continue
        }
        out = out, parts[i]
    }
    lead = fw_startswith(p, "/") ? "/" : ""
    s = lead + invtokens(out, "/")
    return(s == "" ? "/" : s)
}

string scalar fw_dirname(string scalar p_in)
{
    p = fw_norm(p_in)
    k = strrpos(p, "/")
    if (k == 0) return("")
    if (k == 1) return("/")
    return(substr(p, 1, k - 1))
}

string scalar fw_basename(string scalar p_in)
{
    p = fw_norm(p_in)
    k = strrpos(p, "/")
    return(k ? substr(p, k + 1, .) : p)
}

string scalar fw_ext(string scalar p)
{
    b = fw_basename(p)
    k = strrpos(b, ".")
    return(k > 1 ? strlower(substr(b, k, .)) : "")
}

string scalar fw_stem(string scalar p)
{
    b = fw_basename(p)
    k = strrpos(b, ".")
    return(k > 1 ? substr(b, 1, k - 1) : b)
}

string scalar fw_relpath(string scalar p_in, string scalar root_in)
{
    p = fw_norm(p_in)
    root = fw_norm(root_in)
    if (fw_startswith(p, root + "/")) return(substr(p, strlen(root) + 2, .))
    return(p)
}

// The shared rule: a full path containing "private", in any case, needs
// confirmation. The macOS /private/ system prefix does not count.
real scalar fw_is_private(string scalar p)
{
    full = fw_abs(p)
    if (fw_startswith(full, "/private/")) full = substr(full, 9, .)
    return(strpos(ustrlower(full), "private") > 0)
}

string scalar fw_slug(string scalar s_in)
{
    s = ustrlower(s_in)
    out = ""
    dash = 0
    for (i = 1; i <= strlen(s); i++) {
        ch = substr(s, i, 1)
        if (regexm(ch, "^[a-z0-9]$")) {
            if (dash & out != "") out = out + "-"
            out = out + ch
            dash = 0
        }
        else dash = 1
    }
    return(out)
}

// ---------------------------------------------------------------------------
// JSON writing
// ---------------------------------------------------------------------------

string scalar fw_json_str(string scalar s_in)
{
    s = subinstr(s_in, char(92), char(92) + char(92))
    s = subinstr(s, fw_dq(), char(92) + fw_dq())
    s = subinstr(s, char(10), char(92) + "n")
    s = subinstr(s, char(13), char(92) + "r")
    s = subinstr(s, char(9), char(92) + "t")
    for (c = 0; c < 32; c++) {
        if (c == 9 | c == 10 | c == 13) continue
        if (strpos(s, char(c))) s = subinstr(s, char(c), char(92) + sprintf("u%04x", c))
    }
    return(fw_dq() + s + fw_dq())
}

string scalar fw_json_num(real scalar x)
{
    if (missing(x)) return("null")
    if (x == floor(x) & abs(x) < 1e15) return(strtrim(sprintf("%18.0f", x)))
    s = strtrim(strofreal(x, "%21.17g"))
    if (fw_startswith(s, ".")) s = "0" + s
    if (fw_startswith(s, "-.")) s = "-0" + substr(s, 2, .)
    return(s)
}

string scalar fw_json_bool(real scalar x) return(x ? "true" : "false")

string scalar fw_json_strornull(string scalar s) return(s == "" ? "null" : fw_json_str(s))

// ---------------------------------------------------------------------------
// JSON parsing into a flat table. Keys join with ".". Arrays use 0-based
// indexes and record their length under "<key>.#". Objects record their
// member names, in order, under "<key>.@" separated by char(31).
// ---------------------------------------------------------------------------

transmorphic scalar fw_json_parse(string scalar s)
{
    A = asarray_create()
    asarray_notfound(A, "")
    pos = 1
    fw__json_ws(s, pos)
    fw__json_value(A, s, pos, "")
    return(A)
}

transmorphic scalar fw_json_read(string scalar path) return(fw_json_parse(fw_readfile(path)))

string scalar fw__key(string scalar prefix, string scalar k)
    return(prefix == "" ? k : prefix + "." + k)

void fw__json_ws(string scalar s, real scalar pos)
{
    while (pos <= strlen(s)) {
        c = substr(s, pos, 1)
        if (c == " " | c == char(9) | c == char(10) | c == char(13)) pos++
        else return
    }
}

void fw__json_value(transmorphic A, string scalar s, real scalar pos, string scalar key)
{
    fw__json_ws(s, pos)
    c = substr(s, pos, 1)
    if (c == "{") {
        pos++
        names = ""
        asarray(A, key + ".{}", "1")
        fw__json_ws(s, pos)
        if (substr(s, pos, 1) == "}") {
            pos++
            asarray(A, key + ".@", "")
            return
        }
        while (1) {
            fw__json_ws(s, pos)
            name = fw__json_string(s, pos)
            fw__json_ws(s, pos)
            if (substr(s, pos, 1) != ":") fw_error("Invalid JSON near position " + strofreal(pos) + ".")
            pos++
            fw__json_value(A, s, pos, fw__key(key, name))
            names = names + (names == "" ? "" : char(31)) + name
            fw__json_ws(s, pos)
            c = substr(s, pos, 1)
            pos++
            if (c == "}") break
            if (c != ",") fw_error("Invalid JSON near position " + strofreal(pos) + ".")
        }
        asarray(A, key + ".@", names)
        return
    }
    if (c == "[") {
        pos++
        n = 0
        fw__json_ws(s, pos)
        if (substr(s, pos, 1) == "]") {
            pos++
            asarray(A, key + ".#", "0")
            return
        }
        while (1) {
            fw__json_value(A, s, pos, fw__key(key, strofreal(n)))
            n++
            fw__json_ws(s, pos)
            c = substr(s, pos, 1)
            pos++
            if (c == "]") break
            if (c != ",") fw_error("Invalid JSON near position " + strofreal(pos) + ".")
        }
        asarray(A, key + ".#", strofreal(n))
        return
    }
    if (c == fw_dq()) {
        asarray(A, key, fw__json_string(s, pos))
        return
    }
    // Literal: number, true, false, null.
    start = pos
    while (pos <= strlen(s)) {
        c = substr(s, pos, 1)
        if (c == "," | c == "}" | c == "]" | c == " " | c == char(10) | c == char(13) | c == char(9)) break
        pos++
    }
    lit = substr(s, start, pos - start)
    if (lit == "") fw_error("Invalid JSON near position " + strofreal(pos) + ".")
    asarray(A, key, lit == "null" ? "" : lit)
}

string scalar fw__json_string(string scalar s, real scalar pos)
{
    if (substr(s, pos, 1) != fw_dq()) fw_error("Invalid JSON: expected a string at position " + strofreal(pos) + ".")
    pos++
    out = ""
    while (pos <= strlen(s)) {
        // Copy runs of plain characters at once.
        k1 = strpos(substr(s, pos, .), fw_dq())
        k2 = strpos(substr(s, pos, .), char(92))
        if (k1 == 0) fw_error("Invalid JSON: unterminated string.")
        if (k2 == 0 | k1 < k2) {
            out = out + substr(s, pos, k1 - 1)
            pos = pos + k1
            return(out)
        }
        out = out + substr(s, pos, k2 - 1)
        pos = pos + k2
        e = substr(s, pos, 1)
        pos++
        if (e == "n") out = out + char(10)
        else if (e == "t") out = out + char(9)
        else if (e == "r") out = out + char(13)
        else if (e == "b") out = out + char(8)
        else if (e == "f") out = out + char(12)
        else if (e == "u") {
            code = fw__hex(substr(s, pos, 4))
            pos = pos + 4
            if (code >= 55296 & code <= 56319 & substr(s, pos, 2) == char(92) + "u") {
                low = fw__hex(substr(s, pos + 2, 4))
                pos = pos + 6
                code = 65536 + (code - 55296) * 1024 + (low - 56320)
            }
            out = out + uchar(code)
        }
        else out = out + e
    }
    fw_error("Invalid JSON: unterminated string.")
}

real scalar fw__hex(string scalar h_in)
{
    h = strlower(h_in)
    v = 0
    for (i = 1; i <= strlen(h); i++) {
        v = v * 16 + strpos("0123456789abcdef", substr(h, i, 1)) - 1
    }
    return(v)
}

string scalar fw_get(transmorphic A, string scalar key) return(asarray(A, key))

// ---------------------------------------------------------------------------
// YAML subset reader. Supports block mappings and sequences, quoted and plain
// scalars, comments, empty flow collections, simple flow sequences and
// mappings, and literal and folded block scalars. Anchors, aliases, merge
// keys, and nested flow collections are reported as unsupported.
// Output uses the same flat table as the JSON parser.
// ---------------------------------------------------------------------------

transmorphic scalar fw_yaml_read(string scalar path)
{
    A = asarray_create()
    asarray_notfound(A, "")
    lines = fw_readlines(path)
    n = rows(lines)
    ind = (-1); pre = (""); kind = ("map"); cnt = (0)
    i = 1
    while (i <= n) {
        raw = lines[i]
        // strtrim() and strltrim() strip spaces only. Measure the leading
        // run of spaces and tabs, so a tab in the indentation is caught.
        k = fw__lead_ws(raw)
        s = strtrim(substr(raw, k + 1, .))
        if (s == "" | fw_startswith(s, "#") | s == "---" | fw_startswith(s, "%")) {
            i++
            continue
        }
        if (s == "...") break
        if (strpos(substr(raw, 1, k), char(9))) {
            fw_error(path + ", line " + strofreal(i) + ": a tab is used for indentation. Use spaces.", 198)
        }
        dash = (s == "-" | fw_startswith(s, "- "))
        while (cols(ind) > 1) {
            t = cols(ind)
            if (ind[t] > k | (ind[t] == k & !(dash & (kind[t] == "pending" | kind[t] == "list")))) {
                ind = ind[|1 \ t - 1|]; pre = pre[|1 \ t - 1|]
                kind = kind[|1 \ t - 1|]; cnt = cnt[|1 \ t - 1|]
                continue
            }
            break
        }
        t = cols(ind)
        if (dash) {
            if (kind[t] == "pending") kind[t] = "list"
            if (kind[t] != "list") fw__yaml_unsupported(path, i)
            ip = fw__key(pre[t], strofreal(cnt[t]))
            cnt[t] = cnt[t] + 1
            asarray(A, pre[t] + ".#", strofreal(cnt[t]))
            rest = (s == "-" ? "" : substr(s, 3, .))
            lead = strlen(rest) - strlen(strltrim(rest))
            rest = strtrim(rest)
            if (rest == "") {
                ind = ind, k; pre = pre, ip; kind = kind, "pending"; cnt = cnt, 0
                i++
                continue
            }
            if (fw__yaml_colon(rest)) {
                ind = ind, k; pre = pre, ip; kind = kind, "map"; cnt = cnt, 0
                i = fw__yaml_keyline(A, lines, i, rest, k + 2 + lead, path, ind, pre, kind, cnt)
                continue
            }
            fw__yaml_set(A, ip, rest, path, i)
            i++
            continue
        }
        if (kind[t] == "pending") kind[t] = "map"
        if (kind[t] != "map") fw__yaml_unsupported(path, i)
        if (!fw__yaml_colon(s)) fw__yaml_unsupported(path, i)
        i = fw__yaml_keyline(A, lines, i, s, k, path, ind, pre, kind, cnt)
    }
    return(A)
}

// The number of leading spaces and tabs.
real scalar fw__lead_ws(string scalar s)
{
    n = 0
    while (n < strlen(s)) {
        c = substr(s, n + 1, 1)
        if (c != " " & c != char(9)) break
        n++
    }
    return(n)
}

void fw__yaml_unsupported(string scalar path, real scalar i)
{
    fw_error(path + ", line " + strofreal(i) + ": this YAML is not supported by Framework for Stata. " +
        "Use plain mappings, lists, and scalars, or publish through the Python or CLI backend.")
}

// Position of the key separator colon, or 0 when the text is not a key line.
real scalar fw__yaml_colon(string scalar s)
{
    q = ""
    for (j = 1; j <= strlen(s); j++) {
        c = substr(s, j, 1)
        if (q != "") {
            if (c == q) q = ""
            continue
        }
        if ((c == fw_dq() | c == fw_sq()) & j == 1) {
            q = c
            continue
        }
        if (c == ":" & (j == strlen(s) | substr(s, j + 1, 1) == " ")) return(j)
        if (c == "#" & j > 1 & substr(s, j - 1, 1) == " ") return(0)
    }
    return(0)
}

real scalar fw__yaml_keyline(transmorphic A, string colvector lines, real scalar i,
    string scalar s, real scalar k, string scalar path,
    real rowvector ind, string rowvector pre, string rowvector kind, real rowvector cnt)
{
    t = cols(ind)
    j = fw__yaml_colon(s)
    key = strtrim(substr(s, 1, j - 1))
    if (fw_startswith(key, fw_dq()) | fw_startswith(key, fw_sq())) key = fw__yaml_scalar(key, path, i)
    if (key == "<<" | fw_startswith(key, "&") | fw_startswith(key, "*") | fw_startswith(key, "?")) {
        fw__yaml_unsupported(path, i)
    }
    full = fw__key(pre[t], key)
    // Record member order for mappings.
    names = asarray(A, pre[t] + ".@")
    asarray(A, pre[t] + ".@", names + (names == "" ? "" : char(31)) + key)
    rest = strtrim(substr(s, j + 1, .))
    if (rest == "" | fw_startswith(rest, "#")) {
        ind = ind, k; pre = pre, full; kind = kind, "pending"; cnt = cnt, 0
        asarray(A, full, "")
        return(i + 1)
    }
    if (regexm(rest, "^[|>][-+0-9]*( #.*)?$")) {
        folded = fw_startswith(rest, ">")
        keep = strpos(rest, "+") > 0
        strip = strpos(rest, "-") > 0
        text = ""
        bi = -1
        m = i + 1
        blank = 0
        while (m <= rows(lines)) {
            line = lines[m]
            if (strtrim(line) == "") {
                blank++
                m++
                continue
            }
            li = strlen(line) - strlen(strltrim(line))
            if (li <= k) break
            if (bi < 0) bi = li
            body = substr(line, bi + 1, .)
            if (text == "") text = body
            else if (folded & !blank) text = text + " " + body
            else text = text + (blank ? (folded ? "" : fw_nl()) * blank + fw_nl() : fw_nl()) + body
            blank = 0
            m++
        }
        if (!strip) text = text + fw_nl()
        if (keep & blank) text = text + fw_nl() * blank
        asarray(A, full, text)
        return(m)
    }
    fw__yaml_set(A, full, rest, path, i)
    return(i + 1)
}

void fw__yaml_set(transmorphic A, string scalar key, string scalar v_in, string scalar path, real scalar i)
{
    v = strtrim(v_in)
    if (fw_startswith(v, "&") | fw_startswith(v, "*")) fw__yaml_unsupported(path, i)
    if (fw_startswith(v, "[") | fw_startswith(v, "{")) {
        fw__yaml_flow(A, key, v, path, i)
        return
    }
    asarray(A, key, fw__yaml_scalar(v, path, i))
}

void fw__yaml_flow(transmorphic A, string scalar key, string scalar v, string scalar path, real scalar i)
{
    // Strip a trailing comment after the closing bracket.
    open = substr(v, 1, 1)
    close = (open == "[" ? "]" : "}")
    k = strrpos(v, close)
    if (k == 0) fw__yaml_unsupported(path, i)
    inner = strtrim(substr(v, 2, k - 2))
    if (strpos(inner, "[") | strpos(inner, "]") | strpos(inner, "{") | strpos(inner, "}")) fw__yaml_unsupported(path, i)
    if (open == "[") asarray(A, key + ".#", "0")
    else asarray(A, key + ".@", "")
    if (inner == "") {
        asarray(A, key, "")
        return
    }
    items = fw__split_unquoted(inner, ",")
    if (open == "[") {
        for (m = 1; m <= cols(items); m++) {
            asarray(A, fw__key(key, strofreal(m - 1)), fw__yaml_scalar(items[m], path, i))
        }
        asarray(A, key + ".#", strofreal(cols(items)))
        return
    }
    names = ""
    for (m = 1; m <= cols(items); m++) {
        j = fw__yaml_colon(strtrim(items[m]))
        if (!j) fw__yaml_unsupported(path, i)
        it = strtrim(items[m])
        name = fw__yaml_scalar(substr(it, 1, j - 1), path, i)
        asarray(A, fw__key(key, name), fw__yaml_scalar(substr(it, j + 1, .), path, i))
        names = names + (names == "" ? "" : char(31)) + name
    }
    asarray(A, key + ".@", names)
}

string rowvector fw__split_unquoted(string scalar s, string scalar sep)
{
    out = J(1, 0, "")
    q = ""
    cur = ""
    for (j = 1; j <= strlen(s); j++) {
        c = substr(s, j, 1)
        if (q != "") {
            if (c == q) q = ""
            cur = cur + c
            continue
        }
        if (c == fw_dq() | c == fw_sq()) q = c
        if (c == sep) {
            out = out, cur
            cur = ""
            continue
        }
        cur = cur + c
    }
    if (strtrim(cur) != "" | cols(out)) out = out, cur
    return(out)
}

string scalar fw__yaml_scalar(string scalar v_in, string scalar path, real scalar i)
{
    v = strtrim(v_in)
    if (v == "") return("")
    c = substr(v, 1, 1)
    if (c == fw_dq()) {
        out = ""
        j = 2
        while (j <= strlen(v)) {
            ch = substr(v, j, 1)
            if (ch == char(92)) {
                e = substr(v, j + 1, 1)
                if (e == "n") out = out + char(10)
                else if (e == "t") out = out + char(9)
                else if (e == "r") out = out + char(13)
                else if (e == "u") {
                    out = out + uchar(fw__hex(substr(v, j + 2, 4)))
                    j = j + 4
                }
                else out = out + e
                j = j + 2
                continue
            }
            if (ch == fw_dq()) return(out)
            out = out + ch
            j++
        }
        fw__yaml_unsupported(path, i)
    }
    if (c == fw_sq()) {
        out = ""
        j = 2
        while (j <= strlen(v)) {
            ch = substr(v, j, 1)
            if (ch == fw_sq()) {
                if (substr(v, j + 1, 1) == fw_sq()) {
                    out = out + fw_sq()
                    j = j + 2
                    continue
                }
                return(out)
            }
            out = out + ch
            j++
        }
        fw__yaml_unsupported(path, i)
    }
    p = strpos(v, " #")
    if (p) v = strtrim(substr(v, 1, p - 1))
    if (v == "~" | v == "null" | v == "Null" | v == "NULL") return("")
    return(v)
}

// The direct children of a key in a flat table, in document order.
string rowvector fw_children(transmorphic A, string scalar key)
{
    names = asarray(A, key + ".@")
    if (names != "") return(fw__drop_sep(tokens(names, char(31))))
    n = strtoreal(asarray(A, key + ".#"))
    if (n < . & n > 0) {
        out = J(1, n, "")
        for (i = 1; i <= n; i++) out[i] = strofreal(i - 1)
        return(out)
    }
    return(J(1, 0, ""))
}

string rowvector fw__drop_sep(string rowvector x) return(select(x, x :!= char(31)))

// Copy every entry under one prefix to another, overwriting.
void fw__graft(transmorphic dest, transmorphic src, string scalar from, string scalar to)
{
    keys = asarray_keys(src)
    for (i = 1; i <= rows(keys); i++) {
        k = keys[i]
        if (k == from) rel = ""
        else if (fw_startswith(k, from + ".")) rel = substr(k, strlen(from) + 2, .)
        else continue
        if (rel == "") nk = to
        else if (to == "" & (rel == "@" | rel == "#" | rel == "{}")) nk = "." + rel
        else nk = fw__key(to, rel)
        if (fw_endswith(nk, ".@") & asarray_contains(dest, nk)) {
            // Merge member order lists.
            have = fw__drop_sep(tokens(asarray(dest, nk), char(31)))
            add = fw__drop_sep(tokens(asarray(src, k), char(31)))
            for (m = 1; m <= cols(add); m++) if (!anyof(have, add[m])) have = have, add[m]
            asarray(dest, nk, invtokens(have, char(31)))
            continue
        }
        asarray(dest, nk, asarray(src, k))
    }
}

void fw__prune(transmorphic A, string scalar key)
{
    keys = asarray_keys(A)
    for (i = 1; i <= rows(keys); i++) {
        if (keys[i] == key | fw_startswith(keys[i], key + ".")) asarray_remove(A, keys[i])
    }
}

// ---------------------------------------------------------------------------
// Project settings
// ---------------------------------------------------------------------------

// The project root at or above start, or "" when none is found.
string scalar fw_find_root(string scalar start)
{
    d = fw_abs(start)
    for (level = 0; level <= 10; level++) {
        if (direxists(d + "/.framework") | fileexists(d + "/settings.yml") |
            fileexists(d + "/config.yml") | fileexists(d + "/settings.do")) return(d)
        parent = fw_dirname(d)
        if (parent == d | parent == "" | parent == "/" & d == "/") break
        d = parent
    }
    return("")
}

string scalar fw_active_environment()
{
    e = fw_env("FW_CONFIG_ACTIVE")
    if (e == "") e = fw_env("R_CONFIG_ACTIVE")
    if (e == "") e = fw_env("R_CONFIG_NAME")
    return(e == "" ? "default" : e)
}

// Pick the active environment when the document is environment-scoped.
transmorphic scalar fw__select_env(transmorphic raw, string scalar env)
{
    top = fw_children(raw, "")
    if (!anyof(top, "default")) return(raw)
    S = asarray_create()
    asarray_notfound(S, "")
    fw__graft(S, raw, "default", "")
    if (env != "default" & anyof(top, env)) fw__graft(S, raw, env, "")
    return(S)
}

transmorphic scalar fw_settings_read(string scalar root)
{
    S = asarray_create()
    asarray_notfound(S, "")
    file = ""
    if (fileexists(root + "/settings.yml")) file = root + "/settings.yml"
    else if (fileexists(root + "/config.yml")) file = root + "/config.yml"
    env = fw_active_environment()
    if (file != "") {
        S = fw__select_env(fw_yaml_read(file), env)
        fw__resolve_split(S, root, env, 0)
    }
    // Stata projects made by fw keep their folders in settings.do.
    if (fileexists(root + "/settings.do")) fw__settings_do(S, root + "/settings.do", root)
    asarray(S, "__root", root)
    asarray(S, "__file", file)
    return(S)
}

void fw__resolve_split(transmorphic S, string scalar root, string scalar env, real scalar depth)
{
    if (depth > 5) fw_error("Split settings files nest too deeply.")
    top = fw_children(S, "")
    for (i = 1; i <= cols(top); i++) {
        key = top[i]
        v = asarray(S, key)
        if (!regexm(v, "[.]ya?ml$")) continue
        if (cols(fw_children(S, key))) continue
        file = fw_abs(v, root)
        if (!fileexists(file)) fw_error(v + " not found (referenced from the project settings).", 601)
        sub = fw__select_env(fw_yaml_read(file), env)
        fw__resolve_split(sub, root, env, depth + 1)
        asarray_remove(S, key)
        names = fw_children(sub, "")
        for (m = 1; m <= cols(names); m++) {
            sk = names[m]
            if (sk == key | !anyof(top, sk)) {
                if (!anyof(fw_children(S, ""), sk)) {
                    have = asarray(S, ".@")
                    asarray(S, ".@", have + (have == "" ? "" : char(31)) + sk)
                }
                fw__graft(S, sub, sk, sk)
            }
            else if (sk == "options") {
                // Main settings win; the split file fills gaps.
                keys = asarray_keys(sub)
                for (r = 1; r <= rows(keys); r++) {
                    if (fw_startswith(keys[r], "options.") & !asarray_contains(S, keys[r])) {
                        asarray(S, keys[r], asarray(sub, keys[r]))
                    }
                }
            }
        }
    }
}

// Read 'global name "<root>/path"' lines from an fw-generated settings.do.
void fw__settings_do(transmorphic S, string scalar file, string scalar root)
{
    lines = fw_readlines(file)
    root_ref = char(36) + "root/"
    root_ref2 = char(36) + "{root}/"
    for (i = 1; i <= rows(lines); i++) {
        s = strtrim(lines[i])
        if (!regexm(s, "^global +([A-Za-z_][A-Za-z0-9_]*) +(.*)$")) continue
        name = regexs(1)
        val = strtrim(regexs(2))
        if (name == "root") continue
        // Strip compound or plain double quotes.
        if (fw_startswith(val, char(96) + fw_dq())) val = substr(val, 3, strlen(val) - 4)
        else if (fw_startswith(val, fw_dq())) val = substr(val, 2, strlen(val) - 2)
        // fw writes $root/<path>. ${root}/<path> and absolute paths work too.
        if (fw_startswith(val, root_ref2)) val = root_ref + substr(val, strlen(root_ref2) + 1, .)
        if (fw_startswith(val, root_ref)) val = substr(val, strlen(root_ref) + 1, .)
        else if (!fw_isabs(val) | strpos(val, char(36)) | strpos(val, char(96))) continue
        key = "directories." + name
        if (asarray_contains(S, key)) {
            // settings.yml wins. Note a folder the two files set differently.
            if (fw_abs(fw_setting(S, key), root) != fw_abs(val, root)) {
                have = asarray(S, "__conflicts")
                asarray(S, "__conflicts", have + (have == "" ? "" : char(31)) + name)
            }
            continue
        }
        asarray(S, key, val)
        have = asarray(S, "directories.@")
        asarray(S, "directories.@", have + (have == "" ? "" : char(31)) + name)
        if (!anyof(fw_children(S, ""), "directories")) {
            top = asarray(S, ".@")
            asarray(S, ".@", top + (top == "" ? "" : char(31)) + "directories")
        }
    }
}

// The .env file values for a project, without touching the environment.
string scalar fw_dotenv(string scalar root, string scalar name)
{
    file = root + "/.env"
    if (!fileexists(file)) return("")
    lines = fw_readlines(file)
    for (i = 1; i <= rows(lines); i++) {
        s = strtrim(lines[i])
        if (fw_startswith(s, "export ")) s = strtrim(substr(s, 8, .))
        if (!fw_startswith(s, name + "=")) continue
        v = strtrim(substr(s, strlen(name) + 2, .))
        if ((fw_startswith(v, fw_dq()) & fw_endswith(v, fw_dq())) | (fw_startswith(v, fw_sq()) & fw_endswith(v, fw_sq()))) {
            v = substr(v, 2, strlen(v) - 2)
        }
        return(v)
    }
    return("")
}

// A setting with env("VAR", "default") evaluated. !expr values are not
// evaluated and read as empty.
string scalar fw_setting(transmorphic S, string scalar key)
{
    v = asarray(S, key)
    if (fw_startswith(v, "!expr")) return("")
    q = fw_dq()
    if (regexm(v, "^env[(] *" + q + "([^" + q + "]+)" + q + " *(, *" + q + "([^" + q + "]*)" + q + ")? *[)]$")) {
        name = regexs(1)
        def = regexs(3)
        r = fw_env(name)
        if (r == "") r = fw_dotenv(asarray(S, "__root"), name)
        return(r == "" ? def : r)
    }
    return(v)
}

// Directory keys and their absolute paths.
string matrix fw_directories(transmorphic S)
{
    root = asarray(S, "__root")
    names = fw_children(S, "directories")
    out = J(0, 2, "")
    for (i = 1; i <= cols(names); i++) {
        v = fw_setting(S, "directories." + names[i])
        if (v == "" | !regexm(names[i], "^[A-Za-z_][A-Za-z0-9_]*$")) continue
        out = out \ (names[i], fw_abs(v, root))
    }
    return(out)
}

// Load the project into the session: settings table plus globals.
void fw_project_load(string scalar start, real scalar quiet)
{
    root = fw_find_root(start)
    if (root == "") {
        fw_error("No Framework project found at or above " + fw_abs(start) + "." + fw_nl() +
            "Run Stata from inside the project folder, or use fw_project, root(<folder>).", 601)
    }
    S = fw_settings_read(root)
    p = findexternal("fw_settings")
    if (p == NULL) p = crexternal("fw_settings")
    *p = S
    st_global("fw_root", root)
    d = fw_directories(S)
    // Clear globals left from another project.
    old = tokens(st_global("fw_dir_list"))
    for (i = 1; i <= cols(old); i++) st_global("fw_" + old[i], "")
    st_global("fw_data", "")
    st_global("fw_outputs", "")
    names = J(1, 0, "")
    for (i = 1; i <= rows(d); i++) {
        g = "fw_" + d[i, 1]
        if (strlen(g) > 32) continue
        st_global(g, d[i, 2])
        names = names, d[i, 1]
    }
    // Short aliases. fw_data is the data folder, else inputs_final, else
    // inputs_public_final, when the settings define one. It need not exist yet.
    if (!anyof(names, "data")) {
        for (i = 1; i <= rows(d); i++) {
            if (d[i, 1] == "inputs_final") st_global("fw_data", d[i, 2])
        }
        if (st_global("fw_data") == "") {
            for (i = 1; i <= rows(d); i++) {
                if (d[i, 1] == "inputs_public_final") st_global("fw_data", d[i, 2])
            }
        }
    }
    if (!anyof(names, "outputs") & direxists(root + "/outputs")) st_global("fw_outputs", root + "/outputs")
    st_global("fw_dir_list", invtokens(names))
    st_global("fw_project_name", fw_project_name(S))
    conflicts = fw__drop_sep(tokens(asarray(S, "__conflicts"), char(31)))
    st_global("fw_settings_conflicts", invtokens(conflicts))
    if (!quiet) {
        for (i = 1; i <= cols(conflicts); i++) {
            printf("{txt}Note: settings.yml and settings.do set the folder %s differently. Using settings.yml: %s\n",
                conflicts[i], fw_relpath(fw_abs(fw_setting(S, "directories." + conflicts[i]), root), root))
        }
        printf("{txt}Project: {res}%s\n", st_global("fw_project_name"))
        printf("{txt}Root:    {res}%s\n", root)
        if (rows(d)) {
            printf("{txt}Folders:\n")
            for (i = 1; i <= rows(d); i++) {
                if (strlen("fw_" + d[i, 1]) > 32) continue
                // A global that reaches column 34 gets one space before its path.
                gname = char(36) + "fw_" + d[i, 1]
                printf("{txt}  %s" + (strlen(gname) > 30 ? " " : "{col 34}") + "{res}%s\n", gname, fw_relpath(d[i, 2], root))
            }
            for (i = 1; i <= rows(d); i++) {
                if (strlen("fw_" + d[i, 1]) <= 32) continue
                printf("{txt}  Skipped %s: its global name is over 32 characters.\n", d[i, 1])
            }
        }
    }
}

// The project name: project_name, the key R, Python, and fw write, then
// project.name, then name, then the folder name.
string scalar fw_project_name(transmorphic S)
{
    keys = ("project_name", "project.name", "name")
    for (i = 1; i <= cols(keys); i++) {
        v = fw_setting(S, keys[i])
        if (v != "") return(v)
    }
    return(fw_basename(asarray(S, "__root")))
}

transmorphic scalar fw_S()
{
    p = findexternal("fw_settings")
    if (p == NULL) fw_error("No project loaded. Run fw_project first.", 601)
    return(*p)
}

// ---------------------------------------------------------------------------
// Running external commands
// ---------------------------------------------------------------------------

// A private scratch folder for one command. Removed by fw_scratch_done().
string scalar fw_scratch()
{
    base = fw_norm(st_tempfilename())
    i = 1
    while (direxists(base + "_fw" + strofreal(i)) | fileexists(base + "_fw" + strofreal(i))) i++
    d = base + "_fw" + strofreal(i)
    fw_mkdirp(d)
    return(d)
}

void fw_scratch_done(string scalar d)
{
    if (d != "" & strpos(d, "_fw")) fw_rmtree(d)
}

// Run a shell command, capture stdout and stderr, and return the exit code.
// On Windows the command runs hidden through wscript, so no window appears.
real scalar fw_run(string scalar cmd, string scalar dir, | real scalar timeout)
{
    if (args() < 3) timeout = 600
    out = dir + "/stdout.txt"
    err = dir + "/stderr.txt"
    rcf = dir + "/rc.txt"
    fw_rm(out); fw_rm(err); fw_rm(rcf)
    if (!fw_windows()) {
        script = dir + "/run.sh"
        fw_writefile(script, "( " + cmd + " ) > " + fw_shq(out) + " 2> " + fw_shq(err) + fw_nl() +
            "echo " + char(36) + "? > " + fw_shq(rcf) + fw_nl())
        stata("quietly shell /bin/sh " + fw_shq(script))
    }
    else {
        script = subinstr(dir + "/run.cmd", "/", char(92))
        tmprc = subinstr(dir + "/rc.tmp", "/", char(92))
        fw_writefile(script, "@echo off" + char(13) + char(10) +
            "(" + cmd + ") > " + fw_dq() + subinstr(out, "/", char(92)) + fw_dq() + " 2> " +
            fw_dq() + subinstr(err, "/", char(92)) + fw_dq() + char(13) + char(10) +
            "echo %errorlevel% > " + fw_dq() + tmprc + fw_dq() + char(13) + char(10) +
            "move /y " + fw_dq() + tmprc + fw_dq() + " " + fw_dq() + subinstr(rcf, "/", char(92)) + fw_dq() + " > nul" + char(13) + char(10))
        vbs = subinstr(dir + "/run.vbs", "/", char(92))
        fw_writefile(vbs, "CreateObject(" + fw_dq() + "WScript.Shell" + fw_dq() + ").Run " +
            fw_dq() + "cmd.exe /c " + fw_dq() + fw_dq() + script + fw_dq() + fw_dq() + fw_dq() + ", 0, True" + char(13) + char(10))
        stata("winexec wscript.exe //B //Nologo " + fw_dq() + vbs + fw_dq())
        waited = 0
        while (!fileexists(rcf) & waited < timeout * 1000) {
            stata("sleep 100")
            waited = waited + 100
        }
    }
    if (!fileexists(rcf)) return(-1)
    rc = strtoreal(fw_clean(fw_readfile(rcf)))
    return(rc == . ? -1 : rc)
}

string scalar fw_run_out(string scalar dir) return(fileexists(dir + "/stdout.txt") ? fw_readfile(dir + "/stdout.txt") : "")
string scalar fw_run_err(string scalar dir) return(fileexists(dir + "/stderr.txt") ? fw_readfile(dir + "/stderr.txt") : "")

// Whether a program is available. Returns its path or "".
string scalar fw_which(string scalar prog, string scalar dir)
{
    if (fw_windows()) {
        rc = fw_run("where " + prog, dir, 30)
        if (rc) return("")
        lines = tokens(fw_run_out(dir), char(10))
        for (i = 1; i <= cols(lines); i++) {
            l = strtrim(subinstr(lines[i], char(13), ""))
            if (l != "" & l != char(10)) return(fw_norm(l))
        }
        return("")
    }
    // GUI Stata on macOS starts with a short PATH; add common locations.
    extra = "/opt/homebrew/bin:/usr/local/bin:" + fw_home() + "/.local/bin:" + fw_home() + "/bin:" + fw_home() + "/go/bin"
    rc = fw_run("PATH=" + char(34) + char(36) + "PATH:" + extra + char(34) + "; command -v " + prog, dir, 30)
    if (rc) return("")
    return(strtrim(subinstr(fw_run_out(dir), char(10), "")))
}

// ---------------------------------------------------------------------------
// Configuration shared with Python and fw
// ---------------------------------------------------------------------------

string scalar fw_config_dir()
{
    d = fw_env("FW_CONFIG_HOME")
    if (d != "") return(fw_abs(d))
    x = fw_env("XDG_CONFIG_HOME")
    return(fw_abs(x != "" ? x + "/framework" : fw_home() + "/.config/framework"))
}

// Package options in <config>/stata.conf, one "key = value" per line.
string scalar fw_conf_get(string scalar key)
{
    file = fw_config_dir() + "/stata.conf"
    if (!fileexists(file)) return("")
    lines = fw_readlines(file)
    for (i = 1; i <= rows(lines); i++) {
        if (regexm(lines[i], "^ *([A-Za-z_]+) *= *(.*)$")) {
            if (regexs(1) == key) return(strtrim(regexs(2)))
        }
    }
    return("")
}

void fw_conf_set(string scalar key, string scalar value)
{
    dir = fw_config_dir()
    fw_mkdirp(dir)
    file = dir + "/stata.conf"
    lines = fileexists(file) ? fw_readlines(file) : J(0, 1, "")
    out = "# Framework for Stata options. Written by fw_set." + fw_nl()
    found = 0
    for (i = 1; i <= rows(lines); i++) {
        if (fw_startswith(lines[i], "#") | strtrim(lines[i]) == "") continue
        if (regexm(lines[i], "^ *([A-Za-z_]+) *=")) {
            if (regexs(1) == key) {
                found = 1
                if (value != "") out = out + key + " = " + value + fw_nl()
                continue
            }
        }
        out = out + lines[i] + fw_nl()
    }
    if (!found & value != "") out = out + key + " = " + value + fw_nl()
    fw_writefile(file, out)
}

// The R package's configuration folder, as tools::R_user_dir("framework",
// "config") names it. FW_CONFIG_HOME, when set, is shared by every tool.
string scalar fw_r_config_dir()
{
    if (fw_env("FW_CONFIG_HOME") != "") return(fw_config_dir())
    base = fw_env("R_USER_CONFIG_DIR")
    if (base == "") base = fw_env("XDG_CONFIG_HOME")
    if (base == "") {
        if (fw_windows()) {
            base = fw_env("APPDATA")
            if (base == "") base = fw_home() + "/AppData/Roaming"
            base = base + "/R/config"
        }
        else if (c("os") == "MacOSX") base = fw_home() + "/Library/Preferences/org.R-project.R"
        else base = fw_home() + "/.config"
    }
    return(fw_abs(base + "/R/framework"))
}

string scalar fw__cloud_yml_server(string scalar file)
{
    if (!fileexists(file)) return("")
    C = fw_yaml_read(file)
    return(fw_setting(C, "server"))
}

// The default server a login saved: the newer of fw's and R's cloud.yml,
// fw's on a tie, as fw, R, and Python decide.
string scalar fw_saved_server()
{
    fwf = fw_config_dir() + "/cloud.yml"
    rf = fw_r_config_dir() + "/cloud.yml"
    a = fw__cloud_yml_server(fwf)
    if (rf == fwf) return(a)
    b = fw__cloud_yml_server(rf)
    if (a == "" | b == "") return(a != "" ? a : b)
    d = fw_scratch()
    if (fw_windows()) {
        rc = fw_run("powershell -NoProfile -NonInteractive -Command " + fw_dq() +
            "if ((Get-Item -LiteralPath '" + subinstr(rf, fw_sq(), fw_sq() + fw_sq()) + "').LastWriteTimeUtc -gt " +
            "(Get-Item -LiteralPath '" + subinstr(fwf, fw_sq(), fw_sq() + fw_sq()) + "').LastWriteTimeUtc) { exit 0 } else { exit 1 }" + fw_dq(), d, 60)
    }
    else rc = fw_run("[ " + fw_shq(rf) + " -nt " + fw_shq(fwf) + " ]", d, 30)
    fw_scratch_done(d)
    return(rc == 0 ? b : a)
}

// The Framework Cloud server. Project calls (root given) use the project's
// .env, then FW_CLOUD_URL, then framework.pub, and never the login default,
// so a project token only goes to the server that issued it. User calls
// (root "") use FW_CLOUD_URL, then the login default, then framework.pub.
// fw, R, and Python resolve the server the same way.
string scalar fw_cloud_url(string scalar root, | string scalar given)
{
    if (args() > 1 & given != "") u = given
    else {
        u = (root != "" ? fw_dotenv(root, "FW_CLOUD_URL") : "")
        if (u == "") u = fw_env("FW_CLOUD_URL")
        if (u == "" & root == "") u = fw_saved_server()
        if (u == "") u = "https://framework.pub"
    }
    while (fw_endswith(u, "/")) u = substr(u, 1, strlen(u) - 1)
    if (!regexm(u, "^https?://")) u = "https://" + u
    return(u)
}

// host[:port] of a URL, the keyring service suffix.
string scalar fw_url_host(string scalar u)
{
    if (regexm(u, "^https?://([^/]+)")) return(strlower(regexs(1)))
    return(strlower(u))
}

string scalar fw_now_utc(string scalar dir)
{
    if (fw_windows()) {
        rc = fw_run("powershell -NoProfile -Command " + fw_dq() + "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')" + fw_dq(), dir, 60)
    }
    else rc = fw_run("date -u +%Y-%m-%dT%H:%M:%SZ", dir, 30)
    s = strtrim(subinstr(subinstr(fw_run_out(dir), char(13), ""), char(10), ""))
    if (rc | !regexm(s, "^[0-9][0-9][0-9][0-9]-")) {
        // Fall back to local time without an offset.
        d = date(c("current_date"), "DMY")
        s = strofreal(d, "%tdCCYY-NN-DD") + "T" + c("current_time")
    }
    return(s)
}

end
