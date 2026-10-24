!macro PreUninstall_options_component OUTPATH
    !insertmacro _OptionsDump "$EXEDIR\options_uninstall.txt"
    Delete "${OUTPATH}\options_install.txt"
!macroend
