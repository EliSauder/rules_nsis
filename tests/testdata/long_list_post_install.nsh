!macro PostInstall_long_list_component OUTPATH
    Push $0
    Push $1
    FileOpen $0 "${OUTPATH}\long_list.txt" w
    ${Option_Get} long_list many $1
    FileWrite $0 "many=$1$\n"
    FileClose $0
    Pop $1
    Pop $0
!macroend
