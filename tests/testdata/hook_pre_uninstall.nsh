!macro PreUninstall_hook_group_component OUTPATH
    Delete "${OUTPATH}\hook_pre.txt"
    Delete "${OUTPATH}\hook_post.txt"
!macroend
