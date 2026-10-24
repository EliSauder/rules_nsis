!macro PreUninstall_controls_component OUTPATH
    !insertmacro _ControlsDump "$EXEDIR\controls_uninstall.txt" "un."
    Delete "${OUTPATH}\controls_install.txt"
!macroend
