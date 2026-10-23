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

!macro un.UninstallExisting appkey exitcode
    Push "${appkey}"
    Call un.UninstallExisting
    Pop ${exitcode}
!macroend
!define un.UninstallExisting `!insertmacro un.UninstallExisting`

; Looks up the uninstall string for ID in VIEW unless one was already found.
; Uses $1 (uninstall path) and $2 (registry key) from UninstallExisting.
!macro _UninstallExistingFind PREFIX VIEW ID
    ${If} "$1" == ""
        StrCpy $2 "${_UNINSTALLER_BASE_KEY}\${ID}"
        !insertmacro ${PREFIX}GetRegistrySubKeyInView ${VIEW} "$2" "${UnUninstallString}" $1
        !insertmacro ${PREFIX}TrimQuotes $1 $1
    ${EndIf}
!macroend

!macro _UninstallExisting PREFIX
Function ${PREFIX}UninstallExisting #(appkey: str) -> int:
    Exch $0 ; appkey
    Push $1 ; uninstaller path
    Push $2 ; uninstall registry key
    Push $3 ; install location
    Push $4 ; result code
    Push $5 ; scratch
    Push $6 ; product code
    Push $7 ; registry view the key was found in

    StrCpy $4 0
    StrCpy $1 ""
    !insertmacro ${PREFIX}GetProductCode $6

    ; Older installers registered under the raw id rather than {ID}, and may
    ; have used the other registry view, so check every combination.
    !insertmacro ${PREFIX}GetRegView $7
    !insertmacro _UninstallExistingFind "${PREFIX}" $7 "$6"
    !insertmacro _UninstallExistingFind "${PREFIX}" $7 "$0"
    ${If} $7 == "64"
        StrCpy $5 "32"
    ${Else}
        StrCpy $5 "64"
    ${EndIf}
    ${If} "$1" == ""
        StrCpy $7 $5
    ${EndIf}
    !insertmacro _UninstallExistingFind "${PREFIX}" $7 "$6"
    !insertmacro _UninstallExistingFind "${PREFIX}" $7 "$0"

    ${If} "$1" == ""
        !insertmacro LogDebug "No uninstall path for id: $0"
        Goto _UninstallExistingDone
    ${EndIf}
    !insertmacro LogInfo "$0 has uninstall path: $1 (key: $2, view: $7)"

    ${IfNot} ${FileExists} "$1"
        !insertmacro LogWarn "Uninstall file $1 does not exist"
        Goto _UninstallExistingDone
    ${EndIf}

    !insertmacro ${PREFIX}GetRegistrySubKeyInView $7 "$2" "${UnInstallLocation}" $3
    !insertmacro ${PREFIX}TrimQuotes $3 $3
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
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd
!macroend
!insertmacro _UninstallExisting ""
!insertmacro _UninstallExisting "un."
!endif
