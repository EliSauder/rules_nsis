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
!define UninstallExisting `!insertmacro UninstallExisting`

Function UninstallExisting #(appkey: str) -> int:
    Exch $0 ; appkey
    Push $1 ; uninstaller path
    Push $2 ; uninstall registry key
    Push $3 ; install location
    Push $4 ; result code
    Push $5 ; scratch

    StrCpy $4 0

    !insertmacro GetProductCode $2
    StrCpy $2 "${_UNINSTALLER_BASE_KEY}\$2"
    !insertmacro GetRegistrySubKey "$2" "${UnUninstallString}" $1
    !insertmacro TrimQuotes $1 $1
    ${If} "$1" == ""
        ; Older installers registered under the raw id rather than {ID}.
        StrCpy $2 "${_UNINSTALLER_BASE_KEY}\$0"
        !insertmacro GetRegistrySubKey "$2" "${UnUninstallString}" $1
        !insertmacro TrimQuotes $1 $1
    ${EndIf}

    ${If} "$1" == ""
        !insertmacro LogDebug "No uninstall path for id: $0"
        Goto _UninstallExistingDone
    ${EndIf}
    !insertmacro LogInfo "$0 has uninstall path: $1 (key: $2)"

    ${IfNot} ${FileExists} "$1"
        !insertmacro LogWarn "Uninstall file $1 does not exist"
        Goto _UninstallExistingDone
    ${EndIf}

    !insertmacro GetRegistrySubKey "$2" "${UnInstallLocation}" $3
    !insertmacro TrimQuotes $3 $3
    ${If} "$3" == ""
        !insertmacro LogError "App $0 has no InstallDir path. Please uninstall manually first."
        MessageBox MB_ICONSTOP "App $0 has no InstallDir path defined. Please uninstall manually first." /SD IDOK
        StrCpy $4 1
        Goto _UninstallExistingDone
    ${EndIf}

!ifdef TESTABLE_INSTALLER
    ${IfTest}
        !insertmacro GetTestId $5
        nsExec::ExecToStack `"$1" /S /TESTID=$5 _?=$3`
    ${Else}
        nsExec::ExecToStack `"$1" /S _?=$3`
    ${EndIf}
!else
    nsExec::ExecToStack `"$1" /S _?=$3`
!endif
    Pop $4 ; exit code, or "error"/"timeout"
    Pop $5 ; output
    !insertmacro LogDebug `Result of uninstall existing: Code: $4, Output: $5`

    ${If} $4 == "error"
    ${OrIf} $4 == "timeout"
        StrCpy $4 1
    ${EndIf}

    ${If} $4 = 0
        !insertmacro LogInfo `Successful uninstall: Deleting '$1', Removing '$3'`
        Delete "$1"
        RMDir "$3"
    ${EndIf}

_UninstallExistingDone:
    StrCpy $0 $4
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd
!endif
