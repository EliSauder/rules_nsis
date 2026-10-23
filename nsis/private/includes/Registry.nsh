!ifndef __INCLUDE_REGISTRY
!define __INCLUDE_REGISTRY

!include LogicLib.nsh
!include Formatting.nsh
!include ShellContext.nsh
!include Testing.nsh
!include Logging.nsh
!include Arch.nsh

; REGISTRY_VIEW (32 or 64) pins the registry view used by every function in
; this file. When it is not defined, the native view of the host is used.
!ifdef REGISTRY_VIEW
    !if "${REGISTRY_VIEW}" != "32"
    !if "${REGISTRY_VIEW}" != "64"
        !error "REGISTRY_VIEW must be 32 or 64, got '${REGISTRY_VIEW}'"
    !endif
    !endif
!endif

!macro _DefineRegView PREFIX
!ifdef REGISTRY_VIEW
    SetRegView ${REGISTRY_VIEW}
!else
    Push $0
    !insertmacro ${PREFIX}Is64Bit $0
    ${If} $0 == "1"
        SetRegView 64
    ${Else}
        SetRegView 32
    ${EndIf}
    Pop $0
!endif
!macroend

!macro DefineRegView
    !insertmacro _DefineRegView ""
!macroend
!define DefineRegView `!insertmacro DefineRegView`

!macro un.DefineRegView
    !insertmacro _DefineRegView "un."
!macroend
!define un.DefineRegView `!insertmacro un.DefineRegView`

!macro GetRegView OUT
!ifdef REGISTRY_VIEW
    StrCpy ${OUT} "${REGISTRY_VIEW}"
!else
    !insertmacro Is64Bit ${OUT}
    ${If} ${OUT} == "1"
        StrCpy ${OUT} "64"
    ${Else}
        StrCpy ${OUT} "32"
    ${EndIf}
!endif
!macroend
!define GetRegView `!insertmacro GetRegView`

!macro un.GetRegView OUT
!ifdef REGISTRY_VIEW
    StrCpy ${OUT} "${REGISTRY_VIEW}"
!else
    !insertmacro un.Is64Bit ${OUT}
    ${If} ${OUT} == "1"
        StrCpy ${OUT} "64"
    ${Else}
        StrCpy ${OUT} "32"
    ${EndIf}
!endif
!macroend
!define un.GetRegView `!insertmacro un.GetRegView`

!macro _RemoveRegistryKeyFunction PREFIX
Function ${PREFIX}RemoveRegistryKey
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}DefineRegView
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
!define RemoveRegistryKey `!insertmacro RemoveRegistryKey`

!macro un.RemoveRegistryKey KEY
    Push "${KEY}"
    Call un.RemoveRegistryKey
!macroend
!define un.RemoveRegistryKey `!insertmacro un.RemoveRegistryKey`

!macro _FormatStrToDWORD PREFIX
Function ${PREFIX}FormatStrToDWORD
    Exch $0

    !insertmacro ${PREFIX}CharToASCII "$0" $0
    IntFmt $0 "0x%X" $0

    Exch $0
FunctionEnd
!macroend

!insertmacro _FormatStrToDWORD ""
!insertmacro _FormatStrToDWORD "un."

!macro FormatStrToDWORD VAL OUT
    Push "${VAL}"
    Call FormatStrToDWORD
    Pop ${OUT}
!macroend
!define FormatStrToDWORD `!insertmacro FormatStrToDWORD`

!macro un.FormatStrToDWORD VAL OUT
    Push "${VAL}"
    Call un.FormatStrToDWORD
    Pop ${OUT}
!macroend
!define un.FormatStrToDWORD `!insertmacro un.FormatStrToDWORD`

!macro _FormatStrToBin PREFIX
Function ${PREFIX}FormatStrToBin
    Exch $1 ; whether the input is already numeric
    Exch 1
    Exch $0 ; input value
    Push $2

    ${If} $1 == "1"
        StrCpy $2 $0
    ${Else}
        !insertmacro ${PREFIX}CharToASCII "$0" $2
    ${EndIf}
    IntFmt $2 "0x%X" $2

    !insertmacro ${PREFIX}Hex2Bin "$2" $0

    Pop $2
    Exch $0
    Exch 1
    Pop $1
FunctionEnd
!macroend

!insertmacro _FormatStrToBin ""
!insertmacro _FormatStrToBin "un."

!macro FormatStrToBin VAL ISINT OUT
    Push "${VAL}"
    Push ${ISINT}
    Call FormatStrToBin
    Pop ${OUT}
!macroend
!define FormatStrToBin `!insertmacro FormatStrToBin`

!macro un.FormatStrToBin VAL ISINT OUT
    Push "${VAL}"
    Push ${ISINT}
    Call un.FormatStrToBin
    Pop ${OUT}
!macroend
!define un.FormatStrToBin `!insertmacro un.FormatStrToBin`

!macro _SetRegistrySubKey PREFIX TYP
Function ${PREFIX}SetRegistrySubKey${TYP}
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}DefineRegView
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

    WriteReg${TYP} SHCTX "$0" "$2" $1
    !insertmacro LogInfo "Set ${TYP} registry entry: '$0'.'$2'=$1"

    Pop $2
    Pop $0
    Pop $1
FunctionEnd
!macroend

!insertmacro _SetRegistrySubKey "" "Str"
!insertmacro _SetRegistrySubKey "un." "Str"

!insertmacro _SetRegistrySubKey "" "DWORD"
!insertmacro _SetRegistrySubKey "un." "DWORD"

!macro SetRegistrySubKeyBin KEY SUBKEY VALUE
    WriteRegBin SHCTX "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define SetRegistrySubKeyBin `!insertmacro SetRegistrySubKeyBin`

!macro un.SetRegistrySubKeyBin KEY SUBKEY VALUE
    WriteRegBin SHCTX "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define un.SetRegistrySubKeyBin `!insertmacro un.SetRegistrySubKeyBin`

!macro SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call SetRegistrySubKeyStr
!macroend
!define SetRegistrySubKeyStr `!insertmacro SetRegistrySubKeyStr`

!macro un.SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call un.SetRegistrySubKeyStr
!macroend
!define un.SetRegistrySubKeyStr `!insertmacro un.SetRegistrySubKeyStr`

!macro SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call SetRegistrySubKeyDWORD
!macroend
!define SetRegistrySubKeyDWORD `!insertmacro SetRegistrySubKeyDWORD`

!macro un.SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    PUSH "${KEY}"
    Call un.SetRegistrySubKeyDWORD
!macroend
!define un.SetRegistrySubKeyDWORD `!insertmacro un.SetRegistrySubKeyDWORD`

!macro _GetRegistrySubKey PREFIX
Function ${PREFIX}GetRegistrySubKey
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}DefineRegView
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

; Reads from an explicit registry view (32 or 64), then restores the default view.
!macro _GetRegistrySubKeyInView PREFIX
Function ${PREFIX}GetRegistrySubKeyInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $0 ; key
    Exch
    Exch $1 ; subkey
    Exch 2
    Exch $2 ; view

!ifdef TESTABLE_INSTALLER
    ${IfTest}
        Push $3
        !insertmacro GetTestId $3
        StrCpy $0 "$0\$3"
        Pop $3
    ${EndIf}
!endif

    ${If} $2 == "64"
        SetRegView 64
    ${ElseIf} $2 == "32"
        SetRegView 32
    ${Else}
        !insertmacro LogWarn "Unknown registry view '$2', using the default view"
        !insertmacro ${PREFIX}DefineRegView
    ${EndIf}

    ReadRegStr $0 SHCTX "$0" "$1"
    !insertmacro ${PREFIX}DefineRegView

    Pop $2
    Exch
    Pop $1
    Exch $0
FunctionEnd
!macroend

!insertmacro _GetRegistrySubKeyInView ""
!insertmacro _GetRegistrySubKeyInView "un."

!macro GetRegistrySubKeyInView VIEW KEY SUBKEY OUT
    Push "${VIEW}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Call GetRegistrySubKeyInView
    Pop ${OUT}
!macroend
!define GetRegistrySubKeyInView `!insertmacro GetRegistrySubKeyInView`

!macro un.GetRegistrySubKeyInView VIEW KEY SUBKEY OUT
    Push "${VIEW}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Call un.GetRegistrySubKeyInView
    Pop ${OUT}
!macroend
!define un.GetRegistrySubKeyInView `!insertmacro un.GetRegistrySubKeyInView`

!macro GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call GetRegistrySubKey
    Pop ${OUT}
!macroend
!define GetRegistrySubKey `!insertmacro GetRegistrySubKey`

!macro un.GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call un.GetRegistrySubKey
    Pop ${OUT}
!macroend
!define un.GetRegistrySubKey `!insertmacro un.GetRegistrySubKey`
!endif
