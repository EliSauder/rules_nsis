!macro _OptionsDump FILE
    Push $0
    Push $1
    FileOpen $0 "${FILE}" w
    ${Option_Get} install_settings enable_extras $1
    FileWrite $0 "enable_extras=$1$\n"
    ${Option_Get} install_settings extras_name $1
    FileWrite $0 "extras_name=$1$\n"
    ${Option_Get} install_settings port $1
    FileWrite $0 "port=$1$\n"
    ${Option_Get} install_settings mode $1
    FileWrite $0 "mode=$1$\n"
    ${Option_Get} advanced_settings level $1
    FileWrite $0 "level=$1$\n"
    ${Option_Get} advanced_settings token $1
    FileWrite $0 "token=$1$\n"
    ${Option_Get} component_settings feature $1
    FileWrite $0 "feature=$1$\n"
    ${Option_Get} component_settings tag $1
    FileWrite $0 "tag=$1$\n"
    FileClose $0
    Pop $1
    Pop $0
!macroend

!macro PostInstall_options_component OUTPATH
    !insertmacro _OptionsDump "${OUTPATH}\options_install.txt"
!macroend
