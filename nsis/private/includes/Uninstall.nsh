!ifndef __INCLUDE_UNINSTALL
!define __INCLUDE_UNINSTALL

!include Product.nsh
!include Utility.nsh
!include Logging.nsh
!include Testing.nsh

!macro UninstallExisting appkey exitcode
    Push "${appkey}"
    Call UninstallExisting
    Pop ${exitcode}
!macroend

Function UninstallExisting #(appkey: str) -> int:
    Exch $0

    Push $1

    !insertmacro GetUninstallRegistry "${UnUninstallString}" $1

    !insertmacro TrimQuotes $1 $1
    ${If} "$1" == ""
        !insertmacro LogDebug "No uninstall path for id: $0"
        Pop $1
        Pop $0
        Push 0
        Return
    ${EndIf}
    !insertmacro LogInfo "$0 has uninstall path: $1"

    IfFileExists "$1" exists notexist
notexist:
    !insertmacro LogWarn "Uninstall file $1 does not exist"
    # If not exist
    Pop $1
    Pop $0
    Push 0
    Return

exists:
    Push $2
    Push $3
    !insertmacro GetUninstallRegistry "${UnInstallLocation}" $3
    Pop $3
    !insertmacro TrimQuotes $3 $3
    ${If} "$3" == ""
        !insertmacro LogError "App $0 has no ${REG_KEY_INSTLOC} path. Please uninstall manually first."
        MessageBox MB_ICONSTOP "App $0 has no ${REG_KEY_INSTLOC} path defined. Please uninstall manually first." /SD IDOK
        Pop $3
        Pop $2
        Pop $1
        Pop $0
        Push 1
        Return
    ${EndIf}

    Push $4
    Push $5

!ifdef TESTABLE_INSTALLER
    ${IfNotTest}
        nsExec::ExecToStack `"$1" /S _?=$3`
        Pop $4
        Pop $5
    ${Else}
        !insertmacro GetTestId $2
        nsExec::ExecToStack `"$1" /S /TESTID=$2 _?=$3`
        Pop $4
        Pop $5
    ${EndIf}
!else
    nsExec::ExecToStack `"$1" /S _?=$3`
    Pop $4
    Pop $5
!endif
    !insertmacro LogDebug `Result of uninstall existing: Code: $4, Output: $5`
    IntOp $2 $4 + 0
    Pop $5
    Pop $4


    ${If} $2 = 0
        !insertmacro LogInfo `Successful uninstall: Deleting '$1', Removind '$3'`
        Delete "$1"
        RMDir "$3"
        Pop $3
        Pop $2
        Pop $1
        Pop $0
        Push 0
        Return
    ${EndIf}

    Pop $3
    Exch $2
    Exch
    Pop $1
    Exch
    Pop $0
FunctionEnd
!endif
