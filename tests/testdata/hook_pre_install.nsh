!macro PreInstall_hook_group_component OUTPATH
    Push $0
    CreateDirectory "${OUTPATH}"
    FileOpen $0 "${OUTPATH}\hook_pre.txt" w
    FileWrite $0 "pre"
    FileClose $0
    Pop $0
!macroend
