*! fw_dag.mata: causal DAGs as DAGitty text and dag.json
*! Loaded by _fw_init. Do not run directly.
*
* fw_dag builds DAGitty model text from paths such as "age -> smoking ->
* cancer", with node roles, labels, and the command that built it, and writes
* a framework.artifact/v1 document of kind dag. Framework Cloud parses,
* validates, and lays out the graph. See docs/plans/2026-11-21-dag-artifacts.md
* in framework-cloud.

version 14

mata:
mata set matastrict off

// A node name as DAGitty reads it: bare when it is a plain identifier, else
// in double quotes.
string scalar fw_dag_name(string scalar n)
{
    if (regexm(n, "^[A-Za-z_][A-Za-z0-9_.]*$")) return(n)
    s = subinstr(n, char(92), char(92) + char(92))
    s = subinstr(s, fw_dq(), char(92) + fw_dq())
    return(fw_dq() + s + fw_dq())
}

// Check one node name. what names the statement for the message.
void fw__dag_check_name(string scalar n, string scalar what)
{
    if (n == "") fw_error("fw_dag: " + what + " has an arrow with no variable on one side.", 198)
    if (ustrlen(n) > 100) fw_error("fw_dag: the variable name " + n + " is longer than 100 characters.", 198)
    for (c = 0; c < 32; c++) {
        if (strpos(n, char(c))) fw_error("fw_dag: variable names cannot hold tabs or line breaks.", 198)
    }
    if (strpos(n, "{") | strpos(n, "}")) fw_error("fw_dag: " + what + " has a brace inside a name. Braces group whole names, as in {age sex} -> smoking.", 198)
}

// The names in one side of a path: a name, or {a b c} for a group.
string rowvector fw__dag_side(string scalar seg_in, string scalar what)
{
    seg = strtrim(seg_in)
    if (substr(seg, 1, 1) == "{") {
        if (substr(seg, strlen(seg), 1) != "}") fw_error("fw_dag: " + what + " opens a { group without closing it.", 198)
        names = tokens(substr(seg, 2, strlen(seg) - 2))
        if (cols(names) == 0) fw_error("fw_dag: " + what + " has an empty { } group.", 198)
        for (i = 1; i <= cols(names); i++) fw__dag_check_name(names[i], what)
        return(names)
    }
    // Runs of spaces inside a name count as one.
    seg = stritrim(seg)
    fw__dag_check_name(seg, what)
    return(seg)
}

// Add names to the node list, keeping the order they first appear in.
void fw__dag_add(string colvector nodes, string rowvector names)
{
    for (i = 1; i <= cols(names); i++) {
        if (rows(nodes) == 0) nodes = names[i]
        else if (!anyof(nodes, names[i])) nodes = nodes \ names[i]
    }
}

// Parse one statement: a lone name, or names joined by ->, <-, or <->.
// Adds its names to nodes and returns its DAGitty text. Counts edges.
string scalar fw__dag_statement(string scalar st, string colvector nodes, real scalar nedges)
{
    what = fw_dq() + st + fw_dq()
    segs = J(1, 0, "")
    arrows = J(1, 0, "")
    rest = st
    start = 1
    i = 1
    n = strlen(st)
    while (i <= n) {
        a = ""
        if (substr(st, i, 3) == "<->") a = "<->"
        else if (substr(st, i, 2) == "->") a = "->"
        else if (substr(st, i, 2) == "<-") a = "<-"
        else if (substr(st, i, 2) == "--") {
            fw_error("fw_dag: " + what + " has an undirected edge (--). A DAG uses -> or <->.", 198)
        }
        if (a != "") {
            segs = segs, substr(st, start, i - start)
            arrows = arrows, a
            i = i + strlen(a)
            start = i
        }
        else i++
    }
    segs = segs, substr(st, start, .)
    text = ""
    prev = J(1, 0, "")
    for (k = 1; k <= cols(segs); k++) {
        names = fw__dag_side(segs[k], what)
        fw__dag_add(nodes, names)
        if (k > 1) {
            for (p = 1; p <= cols(prev); p++) {
                if (anyof(names, prev[p])) fw_error("fw_dag: " + what + " draws an arrow from " + prev[p] + " to itself.", 198)
            }
            nedges = nedges + cols(prev) * cols(names)
            text = text + " " + arrows[k - 1] + " "
        }
        if (cols(names) == 1 & substr(strtrim(segs[k]), 1, 1) != "{") text = text + fw_dag_name(names[1])
        else {
            g = ""
            for (j = 1; j <= cols(names); j++) g = g + (j > 1 ? " " : "") + fw_dag_name(names[j])
            text = text + "{" + g + "}"
        }
        prev = names
    }
    return(text)
}

// The names in a role option, such as exposure(smoking "family income").
// Each must be a node.
string rowvector fw__dag_role(string scalar s, string scalar role, string colvector nodes)
{
    names = tokens(s)
    for (i = 1; i <= cols(names); i++) {
        names[i] = stritrim(strtrim(names[i]))
        if (!anyof(nodes, names[i])) {
            fw_error("fw_dag: " + role + "() names " + names[i] + ", which no path in the graph includes.", 198)
        }
    }
    return(names)
}

// Build the graph from paths and roles. Sets the Mata external
// fw__dag_nodes and locals fw_dag_text, fw_dag_nodes, fw_dag_edges.
void fw_dag_build(string scalar paths, string scalar exposure, string scalar outcome,
    string scalar latent, string scalar adjusted, string scalar selected)
{
    external string colvector fw__dag_nodes
    stmts = tokens(paths)
    if (cols(stmts) == 0) fw_error("fw_dag needs paths, such as " + char(96) + fw_dq() + "age -> smoking" + fw_dq() + "'" + ", or a DAGitty file: fw_dag using model.dagitty", 198)
    nodes = J(0, 1, "")
    nedges = 0
    body = J(0, 1, "")
    for (s = 1; s <= cols(stmts); s++) {
        if (anyof(("->", "<-", "<->", "--"), strtrim(stmts[s]))) {
            fw_error("fw_dag: put each path in double quotes, such as " + fw_dq() + "age -> smoking" + fw_dq() + ".", 198)
        }
        // A semicolon or line break separates statements, as in DAGitty.
        parts = tokens(subinstr(stmts[s], char(10), ";"), ";")
        for (p = 1; p <= cols(parts); p++) {
            if (parts[p] == ";" | strtrim(parts[p]) == "") continue
            body = body \ fw__dag_statement(strtrim(parts[p]), nodes, nedges)
        }
    }
    if (rows(nodes) == 0) fw_error("fw_dag: the paths name no variables.", 198)
    if (rows(nodes) > 100) fw_error("fw_dag: Framework Cloud draws at most 100 variables, and this graph has " + strofreal(rows(nodes)) + ".", 198)
    if (nedges > 400) fw_error("fw_dag: Framework Cloud draws at most 400 arrows, and this graph has " + strofreal(nedges) + ".", 198)

    rolenames = ("exposure", "outcome", "latent", "adjusted", "selected")
    rolevals = (exposure, outcome, latent, adjusted, selected)
    attrs = J(rows(nodes), 1, "")
    for (r = 1; r <= cols(rolenames); r++) {
        names = fw__dag_role(rolevals[r], rolenames[r], nodes)
        for (i = 1; i <= cols(names); i++) {
            k = select(1::rows(nodes), nodes :== names[i])
            if (!strpos("," + attrs[k] + ",", "," + rolenames[r] + ",")) {
                attrs[k] = attrs[k] + (attrs[k] != "" ? "," : "") + rolenames[r]
            }
        }
    }
    text = "dag {" + fw_nl()
    for (i = 1; i <= rows(nodes); i++) {
        text = text + fw_dag_name(nodes[i]) + (attrs[i] != "" ? " [" + attrs[i] + "]" : "") + fw_nl()
    }
    for (i = 1; i <= rows(body); i++) {
        // A lone name already has its line above.
        if (strpos(body[i], " -> ") | strpos(body[i], " <- ") | strpos(body[i], " <-> ")) text = text + body[i] + fw_nl()
    }
    text = text + "}"
    fw__dag_nodes = nodes
    st_local("fw_dag_text", text)
    st_local("fw_dag_nodes", strofreal(rows(nodes)))
    st_local("fw_dag_edges", strofreal(nedges))
}

// Display labels by node name, as a JSON object, or "" when there are none.
// pairs holds name "label" pairs from labels(). With varlabels, a node named
// after a variable in memory takes the variable's label. pairs win.
// nodes is empty for a DAGitty file, whose names fw_dag does not read.
string scalar fw_dag_labels(string scalar pairs, real scalar varlabels)
{
    external string colvector fw__dag_nodes
    nodes = fw__dag_nodes
    names = J(0, 1, "")
    labs = J(0, 1, "")
    if (varlabels) {
        for (i = 1; i <= rows(nodes); i++) {
            if (!st_isname(nodes[i])) continue
            v = _st_varindex(nodes[i], 0)
            if (v >= .) continue
            l = strtrim(st_varlabel(v))
            if (l == "" | l == nodes[i]) continue
            names = names \ nodes[i]
            labs = labs \ l
        }
    }
    t = tokens(pairs)
    if (mod(cols(t), 2)) fw_error("fw_dag: labels() takes pairs of a name and its label, such as labels(smoking " + fw_dq() + "Smoking status" + fw_dq() + ").", 198)
    for (i = 1; i < cols(t); i = i + 2) {
        n = stritrim(strtrim(t[i]))
        if (rows(nodes) & !anyof(nodes, n)) fw_error("fw_dag: labels() names " + n + ", which no path in the graph includes.", 198)
        k = (rows(names) ? select(1::rows(names), names :== n) : J(0, 1, .))
        if (rows(k)) labs[k[1]] = t[i + 1]
        else {
            names = names \ n
            labs = labs \ t[i + 1]
        }
    }
    if (rows(names) == 0) return("")
    s = "{"
    for (i = 1; i <= rows(names); i++) s = s + (i > 1 ? "," : "") + fw_json_str(names[i]) + ":" + fw_json_str(labs[i])
    return(s + "}")
}

// Write the dag.json document. labels is a JSON object or "", code a line of
// Stata or "".
void fw_dag_write(string scalar path, string scalar text, string scalar labels, string scalar code)
{
    s = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.artifact/v1") + "," +
        fw_json_str("kind") + ":" + fw_json_str("dag") + "," +
        fw_json_str("source") + ":{" + fw_json_str("language") + ":" + fw_json_str("stata") + "}," +
        fw_json_str("dagitty") + ":" + fw_json_str(text)
    if (labels != "") s = s + "," + fw_json_str("labels") + ":" + labels
    if (code != "") {
        s = s + "," + fw_json_str("code") + ":{" + fw_json_str("language") + ":" + fw_json_str("stata") + "," +
            fw_json_str("text") + ":" + fw_json_str(code) + "}"
    }
    fw_writefile(path, s + "}" + fw_nl())
}

// Text without the blank lines, spaces, and tabs around it.
string scalar fw_dag_trim(string scalar s_in)
{
    s = s_in
    while (s != "" & anyof((" ", char(9), char(10), char(13)), substr(s, 1, 1))) s = substr(s, 2, .)
    while (s != "" & anyof((" ", char(9), char(10), char(13)), substr(s, strlen(s), 1))) s = substr(s, 1, strlen(s) - 1)
    return(s)
}

// A command line as typed, with each run of spaces outside double quotes cut
// to one, as lines joined at /// leave them.
string scalar fw_dag_cmdline(string scalar s)
{
    out = ""
    inq = 0
    sp = 0
    for (i = 1; i <= strlen(s); i++) {
        ch = substr(s, i, 1)
        if (ch == fw_dq()) inq = !inq
        if (!inq & (ch == " " | ch == char(9))) {
            if (!sp) out = out + " "
            sp = 1
            continue
        }
        sp = 0
        out = out + ch
    }
    return(strtrim(out))
}

// Show DAGitty text as it is, without SMCL reading its braces.
void fw_dag_show(string scalar text)
{
    rest = text
    while ((k = strpos(rest, fw_nl())) > 0) {
        display("  " + substr(rest, 1, k - 1), 1)
        rest = substr(rest, k + 1, .)
    }
    if (rest != "") display("  " + rest, 1)
}

end
