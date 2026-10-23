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

; Pushes the loaded registry view (32 or 64) onto the stack.
!macro _PushRegView PREFIX
!ifdef REGISTRY_VIEW
    Push "${REGISTRY_VIEW}"
!else
    Push $0
    !insertmacro ${PREFIX}GetRegView $0
    Exch $0
!endif
!macroend

; Switches to VIEW (32 or 64) for the next registry access.
!macro _ApplyRegView PREFIX VIEW
    ${If} "${VIEW}" == "64"
        SetRegView 64
    ${ElseIf} "${VIEW}" == "32"
        SetRegView 32
    ${Else}
        !insertmacro LogWarn "Unknown registry view '${VIEW}', using the default view"
        !insertmacro ${PREFIX}DefineRegView
    ${EndIf}
!macroend

; Appends the test id to KEY when running under test. SCRATCH is preserved.
!macro _ApplyRegTestId KEY SCRATCH
!ifdef TESTABLE_INSTALLER
    ${IfTest}
        Push ${SCRATCH}
        !insertmacro GetTestId ${SCRATCH}
        StrCpy ${KEY} "${KEY}\${SCRATCH}"
        Pop ${SCRATCH}
    ${EndIf}
!endif
!macroend

!macro _RemoveRegistryKeyFunction PREFIX
Function ${PREFIX}RemoveRegistryKeyInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $1 ; view
    Exch
    Exch $0 ; key

    !insertmacro _ApplyRegTestId $0 $2
    !insertmacro _ApplyRegView "${PREFIX}" $1
    !insertmacro LogInfo "Removing registry '$0' (view: $1)"
    DeleteRegKey SHCTX "$0"
    !insertmacro ${PREFIX}DefineRegView

    Pop $0
    Pop $1
FunctionEnd

Function ${PREFIX}RemoveRegistryKey
    !insertmacro _PushRegView "${PREFIX}"
    Call ${PREFIX}RemoveRegistryKeyInView
FunctionEnd
!macroend

!insertmacro _RemoveRegistryKeyFunction ""
!insertmacro _RemoveRegistryKeyFunction "un."

!macro RemoveRegistryKeyInView VIEW KEY
    Push "${KEY}"
    Push "${VIEW}"
    Call RemoveRegistryKeyInView
!macroend
!define RemoveRegistryKeyInView `!insertmacro RemoveRegistryKeyInView`

!macro un.RemoveRegistryKeyInView VIEW KEY
    Push "${KEY}"
    Push "${VIEW}"
    Call un.RemoveRegistryKeyInView
!macroend
!define un.RemoveRegistryKeyInView `!insertmacro un.RemoveRegistryKeyInView`

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
Function ${PREFIX}SetRegistrySubKey${TYP}InView
    !insertmacro ${PREFIX}SetShellContext
    Exch $3 ; View
    Exch
    Exch $0 ; Key
    Exch 2
    Exch $1 ; Value
    Exch 3
    Exch $2 ; Subkey

    !insertmacro _ApplyRegTestId $0 $4
    !insertmacro _ApplyRegView "${PREFIX}" $3
    WriteReg${TYP} SHCTX "$0" "$2" $1
    !insertmacro LogInfo "Set ${TYP} registry entry: '$0'.'$2'=$1 (view: $3)"
    !insertmacro ${PREFIX}DefineRegView

    Pop $2
    Pop $3
    Pop $0
    Pop $1
FunctionEnd

Function ${PREFIX}SetRegistrySubKey${TYP}
    !insertmacro _PushRegView "${PREFIX}"
    Call ${PREFIX}SetRegistrySubKey${TYP}InView
FunctionEnd
!macroend

!insertmacro _SetRegistrySubKey "" "Str"
!insertmacro _SetRegistrySubKey "un." "Str"

!insertmacro _SetRegistrySubKey "" "DWORD"
!insertmacro _SetRegistrySubKey "un." "DWORD"

; VALUE must be a literal hex string because WriteRegBin data is resolved at
; compile time, so the Bin variants are macros rather than functions.
!macro _SetRegistrySubKeyBinInView PREFIX VIEW KEY SUBKEY VALUE
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro _ApplyRegView "${PREFIX}" "${VIEW}"
    WriteRegBin SHCTX "${KEY}" "${SUBKEY}" ${VALUE}
    !insertmacro ${PREFIX}DefineRegView
!macroend

!macro SetRegistrySubKeyBinInView VIEW KEY SUBKEY VALUE
    !insertmacro _SetRegistrySubKeyBinInView "" "${VIEW}" "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define SetRegistrySubKeyBinInView `!insertmacro SetRegistrySubKeyBinInView`

!macro un.SetRegistrySubKeyBinInView VIEW KEY SUBKEY VALUE
    !insertmacro _SetRegistrySubKeyBinInView "un." "${VIEW}" "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define un.SetRegistrySubKeyBinInView `!insertmacro un.SetRegistrySubKeyBinInView`

!macro _SetRegistrySubKeyBin PREFIX KEY SUBKEY VALUE
!ifdef REGISTRY_VIEW
    !insertmacro _SetRegistrySubKeyBinInView "${PREFIX}" "${REGISTRY_VIEW}" "${KEY}" "${SUBKEY}" ${VALUE}
!else
    ; KEY may reference $0, so avoid using a register to hold the view.
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}DefineRegView
    WriteRegBin SHCTX "${KEY}" "${SUBKEY}" ${VALUE}
!endif
!macroend

!macro SetRegistrySubKeyBin KEY SUBKEY VALUE
    !insertmacro _SetRegistrySubKeyBin "" "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define SetRegistrySubKeyBin `!insertmacro SetRegistrySubKeyBin`

!macro un.SetRegistrySubKeyBin KEY SUBKEY VALUE
    !insertmacro _SetRegistrySubKeyBin "un." "${KEY}" "${SUBKEY}" ${VALUE}
!macroend
!define un.SetRegistrySubKeyBin `!insertmacro un.SetRegistrySubKeyBin`

!macro SetRegistrySubKeyStrInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Push "${VIEW}"
    Call SetRegistrySubKeyStrInView
!macroend
!define SetRegistrySubKeyStrInView `!insertmacro SetRegistrySubKeyStrInView`

!macro SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Call SetRegistrySubKeyStr
!macroend
!define SetRegistrySubKeyStr `!insertmacro SetRegistrySubKeyStr`

!macro SetRegistrySubKeyDWORDInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Push "${VIEW}"
    Call SetRegistrySubKeyDWORDInView
!macroend
!define SetRegistrySubKeyDWORDInView `!insertmacro SetRegistrySubKeyDWORDInView`

!macro SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Call SetRegistrySubKeyDWORD
!macroend
!define SetRegistrySubKeyDWORD `!insertmacro SetRegistrySubKeyDWORD`

!macro un.SetRegistrySubKeyStrInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Push "${VIEW}"
    Call un.SetRegistrySubKeyStrInView
!macroend
!define un.SetRegistrySubKeyStrInView `!insertmacro un.SetRegistrySubKeyStrInView`

!macro un.SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Call un.SetRegistrySubKeyStr
!macroend
!define un.SetRegistrySubKeyStr `!insertmacro un.SetRegistrySubKeyStr`

!macro un.SetRegistrySubKeyDWORDInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Push "${VIEW}"
    Call un.SetRegistrySubKeyDWORDInView
!macroend
!define un.SetRegistrySubKeyDWORDInView `!insertmacro un.SetRegistrySubKeyDWORDInView`

!macro un.SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push ${VALUE}
    Push "${KEY}"
    Call un.SetRegistrySubKeyDWORD
!macroend
!define un.SetRegistrySubKeyDWORD `!insertmacro un.SetRegistrySubKeyDWORD`

!macro _GetRegistrySubKey PREFIX
Function ${PREFIX}GetRegistrySubKeyInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $2 ; view
    Exch
    Exch $0 ; key
    Exch 2
    Exch $1 ; subkey

    !insertmacro _ApplyRegTestId $0 $3
    !insertmacro _ApplyRegView "${PREFIX}" $2
    ReadRegStr $0 SHCTX "$0" "$1"
    !insertmacro ${PREFIX}DefineRegView

    Pop $1
    Pop $2
    Exch $0
FunctionEnd

Function ${PREFIX}GetRegistrySubKey
    !insertmacro _PushRegView "${PREFIX}"
    Call ${PREFIX}GetRegistrySubKeyInView
FunctionEnd
!macroend

!insertmacro _GetRegistrySubKey ""
!insertmacro _GetRegistrySubKey "un."

!macro GetRegistrySubKeyInView VIEW KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call GetRegistrySubKeyInView
    Pop ${OUT}
!macroend
!define GetRegistrySubKeyInView `!insertmacro GetRegistrySubKeyInView`

!macro GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call GetRegistrySubKey
    Pop ${OUT}
!macroend
!define GetRegistrySubKey `!insertmacro GetRegistrySubKey`

!macro un.GetRegistrySubKeyInView VIEW KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call un.GetRegistrySubKeyInView
    Pop ${OUT}
!macroend
!define un.GetRegistrySubKeyInView `!insertmacro un.GetRegistrySubKeyInView`

!macro un.GetRegistrySubKey KEY SUBKEY OUT
    Push "${SUBKEY}"
    Push "${KEY}"
    Call un.GetRegistrySubKey
    Pop ${OUT}
!macroend
!define un.GetRegistrySubKey `!insertmacro un.GetRegistrySubKey`
!endif
