!macro _ComponentsDump FILE
    Push $0
    FileOpen $0 "${FILE}" w
    FileWrite $0 "core=$SectionSelected_cli_core$\n"
    FileWrite $0 "tools=$SectionSelected_cli_tools$\n"
    FileWrite $0 "docs=$SectionSelected_cli_docs$\n"
    FileWrite $0 "samples=$SectionSelected_cli_samples$\n"
    FileClose $0
    Pop $0
!macroend

!macro PostInstall_cli_core OUTPATH
    !insertmacro _ComponentsDump "${OUTPATH}\components.txt"
!macroend
