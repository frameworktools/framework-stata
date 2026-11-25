*! fw_flatten: keep only an artifact's newest version on Framework Cloud
*! Part of the framework package
program define fw_flatten, rclass
    version 14
    syntax anything(name=artifact id="artifact") [, PROJect(string) CONFIRM]
    _fw_init
    gettoken artifact rest : artifact
    if `"`rest'"' != "" {
        display as error "fw_flatten takes one artifact at a time."
        exit 198
    }
    * A project's token reaches its own artifacts. Outside a project, the
    * account token from fw_login is used.
    capture mata: fw_S()
    if _rc capture fw_project, quietly
    local root
    capture mata: fw_S()
    if !_rc local root `"$fw_root"'

    display as text `"Flattening `artifact' keeps its newest version as version 1."'
    display as text "Framework Cloud deletes every older version and its files for good, Trash included."
    if "`confirm'" == "" {
        if c(mode) == "batch" {
            display as error "Not flattening without confirmation. Add the confirm option: fw_flatten `artifact', confirm"
            exit 198
        }
        display as text "Flatten it? Type y and press Enter: " _request(_fw_answer)
        if !inlist(lower(trim(`"$_fw_answer"')), "y", "yes") {
            macro drop _fw_answer
            display as error "Cancelled. Nothing was changed."
            exit 1
        }
        macro drop _fw_answer
    }

    mata: fw_flatten_run(st_local("root"), st_local("artifact"), st_local("project"))
    local s = cond("`fw_removed'" == "1", "", "s")
    display as text `"Flattened `fw_flat_name' to version `fw_version'; removed `fw_removed' older version`s'."'
    if regexm(`"`fw_artifact_url'"', "^https?://") display as text "Manage: " as result `"{browse "`fw_artifact_url'"}"'
    return local artifact_url `"`fw_artifact_url'"'
    return local artifact `"`fw_flat_name'"'
    return local version "`fw_version'"
    return scalar removed = real("`fw_removed'")
end
