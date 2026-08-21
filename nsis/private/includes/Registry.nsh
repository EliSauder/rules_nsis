!ifndef __INCLUDE_REGISTRY
!define __INCLUDE_REGISTRY

!include LogicLib.nsh
!include ShellContext.nsh
!include Testing.nsh
!include Logging.nsh

!macro _RemoveRegistryKeyFunction PREFIX
Function ${PREFIX}RemoveRegistryKey
    !insertmacro SetVarContext
    Exch $0

!ifdef TESTABLE_INSTALLER
    ${IfTest}
        Push $1
        !insertmacro GetTestId $1
        !insertmacro LogInfo "Removing registry '$0\$1'"
        DeleteRegKey SHCTX "$0\$1"
        Pop $1
    ${Else}
        !insertmacro LogInfo "Removing registry '$0'"
        DeleteRegKey SHCTX "$0"
    ${EndIf}
!else
    !insertmacro LogInfo "Removing registry '$0'"
    DeleteRegKey SHCTX "$0"
!endif

    Pop $0
FunctionEnd
!macroend

!insertmacro _RemoveRegistryKeyFunction ""
!insertmacro _RemoveRegistryKeyFunction "un."

!macro RemoveRegistryKey KEY
    Push "${KEY}"
    Call RemoveRegistryKey
!macroend

!macro un.RemoveRegistryKey KEY
    Push "${KEY}"
    Call un.RemoveRegistryKey
!macroend

!macro _SetRegistrySubKey PREFIX
Function ${PREFIX}SetRegistrySubKey
    !insertmacro SetVarContext
    Exch $0 ; Key
    Exch 1
    Exch $1 ; Value
    Exch 2
    Exch $2 ; Subkey

    !ifdef TESTABLE_INSTALLER
    ${IfTest}
        Push $3
        !insertmacro GetTestId $3
        StrCpy $0 "$0\$3"
        Pop $3
    ${EndIf}
    !endif

    WriteRegStr SHCTX "$0" "$2" $1
    !insertmacro LogInfo "Set registry entry: '$0'.'$2'=$1"

    Pop $2
    Pop $0
    Pop $1
FunctionEnd
!macroend

!insertmacro _SetRegistrySubKey ""
!insertmacro _SetRegistrySubKey "un."

!macro SetRegistrySubKey KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call SetRegistrySubKey
!macroend

!macro un.RemoveRegistryKey KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call un.SetRegistrySubKey
!macroend

!macro _GetRegistrySubKey PREFIX
Function ${PREFIX}GetRegistrySubKey
    !insertmacro SetVarContext
    Exch $0
    Exch
    Exch $1

!ifdef TESTABLE_INSTALLER
    ${IfTest}
        Push $3
        !insertmacro GetTestId $3
        StrCpy $0 "$0\$3"
        Pop $3
    ${EndIf}
!endif

    ReadRegStr $0 SHCTX "$0" "$1"
    Pop $1
    Exch $0
FunctionEnd
!macroend

!insertmacro _GetRegistrySubKey ""
!insertmacro _GetRegistrySubKey "un."

!macro GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call GetRegistrySubKey
    Pop ${OUT}
!macroend

!macro un.GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call un.GetRegistrySubKey
    Pop ${OUT}
!macroend

!endif
