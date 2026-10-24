!macro PostInstall_hook_group_component OUTPATH
    Push $0
    FileOpen $0 "${OUTPATH}\hook_post.txt" w
    FileWrite $0 "post"
    FileClose $0
    Pop $0
!macroend
