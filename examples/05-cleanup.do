* Example 5: remove the example project.
* Run it after the other examples. It deletes the folder 01-project.do made
* in Stata's temporary folder, with everything published there.

if `"$FW_EXAMPLE_PROJECT"' == "" {
    display as text "No example project to remove. Run 01-project.do first."
    exit
}
* Leave the folder before removing it.
cd `"`c(tmpdir)'"'
if c(os) == "Windows" {
    local folder = subinstr(`"$FW_EXAMPLE_PROJECT"', "/", "\", .)
    shell rmdir /s /q "`folder'"
}
else shell rm -rf "$FW_EXAMPLE_PROJECT"
display as text "Removed $FW_EXAMPLE_PROJECT"
global FW_EXAMPLE_PROJECT
