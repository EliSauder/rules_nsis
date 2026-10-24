; Uninstall does not yet remove files from directory artifacts (#77).
!macro PreUninstall_shortcut_tree_component OUTPATH
    Delete "${OUTPATH}\README.md"
!macroend
