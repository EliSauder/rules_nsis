!macro _ControlsDump FILE PREFIX
    Push $0
    Push $1
    FileOpen $0 "${FILE}" w
    ${Option_Get} value_controls release_date $1
    FileWrite $0 "release_date=$1$\n"
    ${Option_Get} value_controls server_ip $1
    FileWrite $0 "server_ip=$1$\n"
    ${Option_Get} value_controls gateway $1
    FileWrite $0 "gateway=$1$\n"
    ${Option_Get} value_controls peer $1
    FileWrite $0 "peer=$1$\n"
    ${Option_Get} list_controls flavor $1
    FileWrite $0 "flavor=$1$\n"
    ${Option_Get} list_controls toppings $1
    FileWrite $0 "toppings=$1$\n"
    ${Option_Get} list_controls extras $1
    FileWrite $0 "extras=$1$\n"
    ${Option_Get} text_controls note $1
    FileWrite $0 "note=$1$\n"
    !insertmacro ${PREFIX}Option_GetMultiline text_controls note $1
    FileWrite $0 "note_text=$1$\n"
    ${Option_Get} text_controls config_file $1
    FileWrite $0 "config_file=$1$\n"
    ${Option_Get} text_controls data_dir $1
    FileWrite $0 "data_dir=$1$\n"
    ${Option_Get} text_controls host_name $1
    FileWrite $0 "host_name=$1$\n"
    FileClose $0
    Pop $1
    Pop $0
!macroend

!macro PostInstall_controls_component OUTPATH
    !insertmacro _ControlsDump "${OUTPATH}\controls_install.txt" ""
!macroend
