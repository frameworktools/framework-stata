*! fw_snippet.mata: code snippets from a do-file's SMCL log
*! Loaded by _fw_init. Do not run directly.
*
* fw_snippet begin opens a named SMCL log, and fw_snippet end splits it into
* code and output blocks. Stata echoes each command above its output, so the
* split is line by line: a command line starts a code block, and the SMCL
* between commands is an output block, sent to Framework Cloud unchanged.
* Cloud translates the SMCL and turns output that starts in {err} into an
* error block. See docs/plans/2026-11-18-code-snippets.md in framework-cloud.

version 14

mata:
mata set matastrict off

// The color directives that set the style of the text after them.
real scalar fw__snip_is_style(string scalar t)
{
    return(anyof(("txt", "text", "res", "result", "err", "error", "com", "inp", "input", "hi"), t))
}

// The style in effect after a line: its last color directive, else the
// style before it.
string scalar fw__snip_style(string scalar line, string scalar style)
{
    s = style
    rest = line
    while ((k = strpos(rest, "{")) > 0) {
        rest = substr(rest, k + 1, .)
        e = strpos(rest, "}")
        if (e == 0) break
        t = substr(rest, 1, e - 1)
        if (fw__snip_is_style(t)) s = t
        rest = substr(rest, e + 1, .)
    }
    return(s)
}

// A command's text as typed. Stata's echo escapes braces as {c -(} and
// {c )-}; style directives inside the echo print nothing.
string scalar fw_snippet_uncmd(string scalar s)
{
    out = ""
    rest = s
    while ((k = strpos(rest, "{")) > 0) {
        out = out + substr(rest, 1, k - 1)
        rest = substr(rest, k, .)
        e = strpos(rest, "}")
        if (e == 0) break
        t = substr(rest, 2, e - 2)
        if (t == "c -(") out = out + "{"
        else if (t == "c )-") out = out + "}"
        else if (t == "c S|") out = out + "$"
        else if (t == "c 'g") out = out + char(96)
        else if (fw__snip_is_style(t) | anyof(("sf", "bf", "it", "rm", "ul on", "ul off", "reset"), t)) out = out
        else out = out + "{" + t + "}"
        rest = substr(rest, e + 1, .)
    }
    return(out + rest)
}

// Whether SMCL prints anything: text other than spaces once the directives
// that only set styles are removed.
real scalar fw_snippet_visible(string scalar smcl)
{
    rest = smcl
    out = ""
    while ((k = strpos(rest, "{")) > 0) {
        out = out + substr(rest, 1, k - 1)
        rest = substr(rest, k, .)
        e = strpos(rest, "}")
        if (e == 0) break
        t = substr(rest, 2, e - 2)
        if (!(fw__snip_is_style(t) | anyof(("sf", "bf", "it", "rm", "ul on", "ul off", "reset", "smcl"), t))) {
            return(1)
        }
        rest = substr(rest, e + 1, .)
    }
    out = out + rest
    out = subinstr(subinstr(subinstr(out, char(10), ""), char(13), ""), char(9), "")
    return(strtrim(out) != "")
}

// When a line is a command echo, its command text, and 1. Three forms:
//   {com}. regress y x          a command
//   . regress y x               a command right after another (still {com})
//   {txt}  2{com}.     display  a line in the body of a loop or program
real scalar fw__snip_cmdline(string scalar line, string scalar style, string scalar text)
{
    text = ""
    if (line == "{com}." | (style == "com" & line == ".")) return(1)
    if (substr(line, 1, 7) == "{com}. ") {
        text = substr(line, 8, .)
        return(1)
    }
    if (style == "com" & substr(line, 1, 2) == ". ") {
        text = substr(line, 3, .)
        return(1)
    }
    if (substr(line, 1, 5) == "{txt}") {
        rest = substr(line, 6, .)
        k = strpos(rest, "{com}.")
        if (k > 1) {
            num = strtrim(substr(rest, 1, k - 1))
            if (num != "" & regexm(num, "^[0-9]+$")) {
                after = substr(rest, k + 6, .)
                if (after == "" | substr(after, 1, 1) == " ") {
                    text = substr(after, 2, .)
                    return(1)
                }
            }
        }
    }
    return(0)
}

// When a line continues the command above it (a /// or #delimit ; line), its
// text, and 1.
real scalar fw__snip_contline(string scalar line, string scalar text)
{
    text = ""
    if (line == ">" | line == "{com}>") return(1)
    if (substr(line, 1, 2) == "> ") {
        text = substr(line, 3, .)
        return(1)
    }
    if (substr(line, 1, 7) == "{com}> ") {
        text = substr(line, 8, .)
        return(1)
    }
    return(0)
}

// Whether a command is fw_snippet end, with or without a prefix.
real scalar fw__snip_is_end(string scalar cmd)
{
    t = tokens(subinstr(strtrim(cmd), ",", " , "))
    i = 1
    while (i <= cols(t)) {
        if (!anyof(("qui", "quietly", "noi", "noisily", "cap", "capture"), t[i])) break
        i++
    }
    if (i + 1 > cols(t)) return(0)
    return(t[i] == "fw_snippet" & t[i + 1] == "end")
}

// Split a log's lines into blocks: an n x 2 matrix of type (code or output)
// and content. Code is the command text without the ". " prompt. Output is
// the SMCL between commands, unchanged except for the style it starts in.
// Commands with nothing printed between them share one code block. Lines
// before the first command (the log header) and from the first
// fw_snippet end on are left out.
string matrix fw_snippet_split(string colvector L)
{
    B = J(0, 2, "")
    style = ""
    code = ""
    hascode = 0
    out = ""
    outstyle = ""
    hasout = 0
    started = 0
    last = ""
    resume = 0
    text = ""
    for (i = 1; i <= rows(L); i++) {
        line = L[i]
        // A log closed and opened again writes {smcl} and a fresh header.
        if (line == "{smcl}") {
            resume = 1
            continue
        }
        if (resume) {
            resume = 0
            if (substr(line, 1, 17) == "{com}{sf}{ul off}" | substr(line, 1, 17) == "{txt}{sf}{ul off}") {
                line = substr(line, 1, 5) + substr(line, 18, .)
            }
        }
        if (fw__snip_cmdline(line, style, text)) {
            cmd = fw_snippet_uncmd(text)
            if (fw__snip_is_end(cmd)) break
            started = 1
            if (hasout) {
                if (fw_snippet_visible(out)) {
                    if (hascode) B = B \ ("code", code)
                    B = B \ ("output", out)
                    code = ""
                    hascode = 0
                }
                out = ""
                hasout = 0
            }
            code = (hascode ? code + char(10) : "") + cmd
            hascode = 1
            last = "code"
            style = fw__snip_style(line, style)
            continue
        }
        if (last == "code" & fw__snip_contline(line, text)) {
            code = code + char(10) + fw_snippet_uncmd(text)
            style = fw__snip_style(line, style)
            continue
        }
        if (!started) {
            style = fw__snip_style(line, style)
            continue
        }
        if (!hasout) {
            // The output starts in the style the echo left behind.
            outstyle = style
            out = (outstyle != "" ? "{" + outstyle + "}" : "") + line
            hasout = 1
        }
        else out = out + char(10) + line
        last = "output"
        style = fw__snip_style(line, style)
    }
    if (hasout & fw_snippet_visible(out)) {
        if (hascode) B = B \ ("code", code)
        B = B \ ("output", out)
    }
    else if (hascode) B = B \ ("code", code)
    return(B)
}

// Code blocks only, with neighbors joined, for nooutput.
string matrix fw_snippet_code_only(string matrix B)
{
    C = J(0, 2, "")
    for (i = 1; i <= rows(B); i++) {
        if (B[i, 1] != "code") continue
        if (rows(C)) C[rows(C), 2] = C[rows(C), 2] + char(10) + B[i, 2]
        else C = B[i, .]
    }
    return(C)
}

// Whether an open snippet log shows that the do-file stopped with an error:
// Stata writes r(#) and "end of do-file" when it stops one.
real scalar fw_snippet_stale(string scalar logfile)
{
    if (!fileexists(logfile)) return(1)
    L = fw_readlines(logfile)
    for (i = 1; i <= rows(L); i++) {
        if (strtrim(L[i]) != "end of do-file") continue
        for (j = max((1, i - 3)); j < i; j++) {
            if (strpos(L[j], "{search r(")) return(1)
        }
    }
    return(0)
}

// ---------------------------------------------------------------------------
// The snippet's source: do-file, lines, and commit
// ---------------------------------------------------------------------------

// Do-files under a folder, as absolute paths. Hidden folders are skipped.
string colvector fw__snip_dofiles(string scalar dir, real scalar depth)
{
    out = J(0, 1, "")
    files = sort(dir(dir, "files", "*.do", 0), 1)
    for (i = 1; i <= rows(files); i++) out = out \ (dir + "/" + files[i])
    if (depth <= 0) return(out)
    dirs = sort(dir(dir, "dirs", "*", 0), 1)
    for (i = 1; i <= rows(dirs); i++) {
        if (substr(dirs[i], 1, 1) == "." | anyof(("renv", "node_modules", "venv", "__pycache__"), dirs[i])) continue
        out = out \ fw__snip_dofiles(dir + "/" + dirs[i], depth - 1)
    }
    return(out)
}

// The first and last line between fw_snippet begin <label> and the next
// fw_snippet end in a do-file, or J(1, 0, .) when the file has no such pair
// or names the label twice.
real rowvector fw_snippet_lines(string scalar file, string scalar label)
{
    if (!fileexists(file)) return(J(1, 0, .))
    L = fw_readlines(file)
    found = J(1, 0, .)
    for (i = 1; i <= rows(L); i++) {
        t = tokens(subinstr(strtrim(L[i]), ",", " , "))
        if (cols(t) < 3) continue
        if (t[1] != "fw_snippet" | t[2] != "begin" | t[3] != label) continue
        if (cols(found)) return(J(1, 0, .))
        for (j = i + 1; j <= rows(L); j++) {
            if (fw__snip_is_end(L[j])) {
                found = (i + 1, j - 1)
                break
            }
        }
        if (!cols(found)) return(J(1, 0, .))
    }
    // & does not short-circuit in Mata.
    if (!cols(found)) return(found)
    if (found[2] < found[1]) return(J(1, 0, .))
    return(found)
}

// Find the do-file that holds the snippet. Sets locals fw_snip_file
// (relative to the project root), fw_snip_from, fw_snip_to, and
// fw_snip_note when the file could not be told apart.
void fw_snippet_source(string scalar root, string scalar given, string scalar label)
{
    st_local("fw_snip_file", "")
    st_local("fw_snip_from", "")
    st_local("fw_snip_to", "")
    st_local("fw_snip_note", "")
    file = ""
    lines = J(1, 0, .)
    if (given != "") {
        file = fw_abs(given, root != "" ? root : pwd())
        if (!fileexists(file)) fw_error("file(): " + given + " was not found.", 601)
        lines = fw_snippet_lines(file, label)
    }
    else if (root != "") {
        F = fw__snip_dofiles(root, 6)
        hits = J(0, 1, "")
        for (i = 1; i <= rows(F); i++) {
            l = fw_snippet_lines(F[i], label)
            if (cols(l)) {
                hits = hits \ F[i]
                lines = l
            }
        }
        if (rows(hits) == 1) file = hits[1]
        else if (rows(hits) > 1) {
            lines = J(1, 0, .)
            st_local("fw_snip_note", "Several do-files hold fw_snippet begin " + label + ", so the snippet names none. Name its do-file with file().")
        }
    }
    if (file == "") return
    rel = (root != "" ? fw_relpath(file, root) : "")
    // A file outside the project goes by its name alone, without lines.
    if (rel == "" | fw_isabs(rel)) {
        rel = fw_basename(file)
        lines = J(1, 0, .)
    }
    st_local("fw_snip_file", rel)
    if (cols(lines)) {
        st_local("fw_snip_from", strofreal(lines[1]))
        st_local("fw_snip_to", strofreal(lines[2]))
    }
}

// The git commit checked out at the project root, or "". It reads .git at
// the root or above, so it needs no git program; a git that cannot run, as
// under Rosetta on a Mac, does not matter. git rev-parse is the fallback.
string scalar fw_snippet_commit(string scalar root)
{
    if (root == "" | !direxists(root)) return("")
    sha = fw__snip_git_head(root)
    if (sha != "") return(sha)
    d = fw_scratch()
    git = fw_which(fw_windows() ? "git.exe" : "git", d)
    if (git != "") {
        rc = fw_run(fw__cliarg(git) + " -C " + fw__cliarg(root) + " rev-parse HEAD", d, 30)
        out = fw_clean(fw_run_out(d))
        if (!rc & fw__snip_is_sha(out)) sha = out
    }
    fw_scratch_done(d)
    return(sha)
}

real scalar fw__snip_is_sha(string scalar s) return(strlen(s) >= 7 & strlen(s) <= 64 & regexm(s, "^[0-9a-f]+$"))

// HEAD's commit from the .git folder, or "".
string scalar fw__snip_git_head(string scalar root)
{
    dir = fw_norm(root)
    gd = ""
    for (i = 1; i <= 30 & dir != ""; i++) {
        if (direxists(dir + "/.git")) {
            gd = dir + "/.git"
            break
        }
        if (fileexists(dir + "/.git")) {
            // A worktree or submodule: .git names the real folder.
            line = fw_clean(fw_readfile(dir + "/.git"))
            if (fw_startswith(line, "gitdir:")) gd = fw_abs(strtrim(substr(line, 8, .)), dir)
            break
        }
        up = fw_dirname(dir)
        if (up == dir | up == "") break
        dir = up
    }
    if (gd == "" | !fileexists(gd + "/HEAD")) return("")
    head = fw_clean(fw_readfile(gd + "/HEAD"))
    if (!fw_startswith(head, "ref:")) return(fw__snip_is_sha(head) ? head : "")
    ref = strtrim(substr(head, 5, .))
    common = gd
    if (fileexists(gd + "/commondir")) common = fw_abs(fw_clean(fw_readfile(gd + "/commondir")), gd)
    dirs = (gd, common)
    for (i = 1; i <= 2; i++) {
        if (fileexists(dirs[i] + "/" + ref)) {
            sha = fw_clean(fw_readfile(dirs[i] + "/" + ref))
            return(fw__snip_is_sha(sha) ? sha : "")
        }
    }
    if (fileexists(common + "/packed-refs")) {
        L = fw_readlines(common + "/packed-refs")
        for (i = 1; i <= rows(L); i++) {
            t = tokens(L[i])
            if (cols(t) == 2) {
                if (t[2] == ref & fw__snip_is_sha(t[1])) return(t[1])
            }
        }
    }
    return("")
}

// ---------------------------------------------------------------------------
// The framework.artifact/v1 document
// ---------------------------------------------------------------------------

// folded: 1 folds every output block, 0 unfolds them, missing leaves it to
// Cloud. model is an artifact slug in the project or an https URL.
string scalar fw_snippet_json(string matrix B, string scalar label, string scalar file,
    real rowvector lines, string scalar commit, string scalar repository, real scalar width,
    real scalar folded, string scalar notebook, string scalar model)
{
    src = fw_json_str("language") + ":" + fw_json_str("stata")
    if (file != "") src = src + "," + fw_json_str("file") + ":" + fw_json_str(file)
    if (label != "") src = src + "," + fw_json_str("label") + ":" + fw_json_str(label)
    if (cols(lines) == 2 & !missing(lines)) src = src + "," + fw_json_str("lines") + ":[" + fw_json_num(lines[1]) + "," + fw_json_num(lines[2]) + "]"
    if (commit != "") src = src + "," + fw_json_str("commit") + ":" + fw_json_str(commit)
    if (repository != "") src = src + "," + fw_json_str("repository") + ":" + fw_json_str(repository)
    blocks = ""
    for (i = 1; i <= rows(B); i++) {
        b = "{" + fw_json_str("type") + ":" + fw_json_str(B[i, 1]) + ","
        if (B[i, 1] == "code") b = b + fw_json_str("text") + ":" + fw_json_str(B[i, 2])
        else {
            b = b + fw_json_str("smcl") + ":" + fw_json_str(B[i, 2])
            if (folded != .) b = b + "," + fw_json_str("folded") + ":" + fw_json_bool(folded)
        }
        blocks = blocks + (i > 1 ? "," : "") + b + "}"
    }
    links = ""
    if (notebook != "") links = "{" + fw_json_str("rel") + ":" + fw_json_str("notebook") + "," + fw_json_str("url") + ":" + fw_json_str(notebook) + "}"
    if (model != "") {
        m = "{" + fw_json_str("rel") + ":" + fw_json_str("model") + "," + (fw_startswith(model, "https://") ? fw_json_str("url") : fw_json_str("artifact")) + ":" + fw_json_str(model) + "}"
        links = links + (links != "" ? "," : "") + m
    }
    s = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.artifact/v1") + "," +
        fw_json_str("kind") + ":" + fw_json_str("code_snippet") + "," +
        fw_json_str("source") + ":{" + src + "}," +
        fw_json_str("snippet") + ":{" + fw_json_str("width") + ":" + fw_json_num(width) + "," + fw_json_str("blocks") + ":[" + blocks + "]}"
    if (links != "") s = s + "," + fw_json_str("display") + ":{" + fw_json_str("links") + ":[" + links + "]}"
    return(s + "}" + fw_nl())
}

// Read the closed log and write the snippet. Sets locals fw_snip_blocks,
// fw_snip_code, and fw_snip_output (block counts).
void fw_snippet_write(string scalar logfile, string scalar outfile, string scalar label,
    real scalar nooutput, string scalar file, real rowvector lines, string scalar commit,
    string scalar repository, real scalar folded, string scalar notebook, string scalar model)
{
    B = fw_snippet_split(fw_readlines(logfile))
    if (nooutput) B = fw_snippet_code_only(B)
    ncode = rows(B) ? sum(B[., 1] :== "code") : 0
    if (ncode == 0) fw_error("The snippet " + label + " ran no commands between fw_snippet begin and fw_snippet end. Nothing was published.", 198)
    fw_writefile(outfile, fw_snippet_json(B, label, file, lines, commit, repository, c("linesize"), folded, notebook, model))
    st_local("fw_snip_blocks", strofreal(rows(B)))
    st_local("fw_snip_code", strofreal(ncode))
    st_local("fw_snip_output", strofreal(rows(B) - ncode))
}

end
