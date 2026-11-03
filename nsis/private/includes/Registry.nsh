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

;FormatStrToBin
;
;Converts a value to a binary string. When ISINT is "1" the value is treated as
;an integer, otherwise as a single character whose ASCII code is used.
;The error flag from Hex2Bin is forwarded: if conversion fails the error flag
;is set and an empty string is returned.
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
    IntFmt $2 "%X" $2

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
    Push "${ISINT}"
    Call FormatStrToBin
    Pop ${OUT}
!macroend
!define FormatStrToBin `!insertmacro FormatStrToBin`

!macro un.FormatStrToBin VAL ISINT OUT
    Push "${VAL}"
    Push "${ISINT}"
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
; compile time, so the Bin variants are macros rather than functions. KEY,
; SUBKEY and VIEW may reference registers, so they are pushed (evaluated) before
; $0-$2 are swapped in to hold them; all registers are restored afterwards.
!macro _SetRegistrySubKeyBinInView PREFIX VIEW KEY SUBKEY VALUE
    Push "${VIEW}"
    Push "${KEY}"
    Push "${SUBKEY}"
    Exch $2 ; subkey
    Exch
    Exch $0 ; key
    Exch 2
    Exch $1 ; view
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro _ApplyRegTestId $0 $3
    !insertmacro _ApplyRegView "${PREFIX}" $1
    WriteRegBin SHCTX "$0" "$2" ${VALUE}
    !insertmacro ${PREFIX}DefineRegView
    Pop $1
    Pop $2
    Pop $0
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
    Push "${KEY}"
    Push "${SUBKEY}"
    Exch $1 ; subkey
    Exch
    Exch $0 ; key
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro _ApplyRegTestId $0 $2
    !insertmacro ${PREFIX}DefineRegView
    WriteRegBin SHCTX "$0" "$1" ${VALUE}
    Pop $0
    Pop $1
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
    Push "${VALUE}"
    Push "${KEY}"
    Push "${VIEW}"
    Call SetRegistrySubKeyStrInView
!macroend
!define SetRegistrySubKeyStrInView `!insertmacro SetRegistrySubKeyStrInView`

!macro SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Call SetRegistrySubKeyStr
!macroend
!define SetRegistrySubKeyStr `!insertmacro SetRegistrySubKeyStr`

!macro SetRegistrySubKeyDWORDInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Push "${VIEW}"
    Call SetRegistrySubKeyDWORDInView
!macroend
!define SetRegistrySubKeyDWORDInView `!insertmacro SetRegistrySubKeyDWORDInView`

!macro SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Call SetRegistrySubKeyDWORD
!macroend
!define SetRegistrySubKeyDWORD `!insertmacro SetRegistrySubKeyDWORD`

!macro un.SetRegistrySubKeyStrInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Push "${VIEW}"
    Call un.SetRegistrySubKeyStrInView
!macroend
!define un.SetRegistrySubKeyStrInView `!insertmacro un.SetRegistrySubKeyStrInView`

!macro un.SetRegistrySubKeyStr KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Call un.SetRegistrySubKeyStr
!macroend
!define un.SetRegistrySubKeyStr `!insertmacro un.SetRegistrySubKeyStr`

!macro un.SetRegistrySubKeyDWORDInView VIEW KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Push "${VIEW}"
    Call un.SetRegistrySubKeyDWORDInView
!macroend
!define un.SetRegistrySubKeyDWORDInView `!insertmacro un.SetRegistrySubKeyDWORDInView`

!macro un.SetRegistrySubKeyDWORD KEY SUBKEY VALUE
    Push "${SUBKEY}"
    Push "${VALUE}"
    Push "${KEY}"
    Call un.SetRegistrySubKeyDWORD
!macroend
!define un.SetRegistrySubKeyDWORD `!insertmacro un.SetRegistrySubKeyDWORD`

; REG_MULTI_SZ values are handled through the System plugin (advapi32), the
; way https://nsis.sourceforge.io/REG_MULTI_SZ_Reader does, because NSIS has no
; instruction for them. The strings of a value are exchanged with the callers
; as an nsArray array (the name of the array is passed), one element per
; string, so a string can hold any character.
;
; Pushes the hive handle matching the shell context and the access mask for
; VIEW (32 or 64, anything else selects the default view) combined with ACCESS.
!macro _RegMultiSzAccess PREFIX VIEW ACCESS HIVE MASK
    StrCpy ${HIVE} 0x80000001
    ${IfAdmin}
        StrCpy ${HIVE} 0x80000002
    ${EndIf}
    ${If} ${VIEW} != "32"
    ${AndIf} ${VIEW} != "64"
        !insertmacro ${PREFIX}GetRegView ${VIEW}
    ${EndIf}
    ${If} ${VIEW} == "64"
        IntOp ${MASK} ${ACCESS} | 0x100
    ${Else}
        IntOp ${MASK} ${ACCESS} | 0x200
    ${EndIf}
!macroend

!macro _RegMultiSzFunctions PREFIX
; Stack: view (top), key, array, subkey. Replaces the value with a REG_MULTI_SZ
; one holding the elements of the array (in order); sets the error flag on
; failure. An array that does not exist is stored as an empty list.
Function ${PREFIX}SetRegistrySubKeyMultiStrInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $3 ; view
    Exch
    Exch $0 ; key
    Exch 2
    Exch $1 ; array
    Exch 3
    Exch $2 ; subkey
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9
    Push $R0
    Push $R1
    Push $R2
    Push $R3

    ClearErrors
    !insertmacro _ApplyRegTestId $0 $4
    !insertmacro _RegMultiSzAccess "${PREFIX}" $3 6 $4 $5

    nsArray::Length $1
    Pop $6
    IfErrors 0 +2
        StrCpy $6 0
    ClearErrors

    ; Room for every character, a terminator per string and the final
    ; terminator. System::Alloc zeroes the memory.
    StrCpy $R3 2
    StrCpy $9 0
    sizeloop:
        IntCmp $9 $6 sizedone 0 sizedone
        nsArray::Get $1 /at=$9
        Pop $R0
        Pop $R1
        StrLen $R2 $R1
        IntOp $R2 $R2 + 1
        IntOp $R3 $R3 + $R2
        IntOp $9 $9 + 1
        Goto sizeloop
    sizedone:
    IntOp $R3 $R3 * 2
    System::Alloc $R3
    Pop $7
    StrCpy $8 $7 ; end of the data written so far
    StrCpy $9 0
    copyloop:
        IntCmp $9 $6 write 0 write
        nsArray::Get $1 /at=$9
        Pop $R0
        Pop $R1
        System::Call 'kernel32::lstrcpyW(p r8, w r11)'
        StrLen $R2 $R1
        IntOp $R2 $R2 + 1
        IntOp $R2 $R2 * 2
        IntPtrOp $8 $8 + $R2
        IntOp $9 $9 + 1
        Goto copyloop
    write:
    IntPtrOp $8 $8 - $7
    IntPtrOp $8 $8 + 2
    System::Call 'advapi32::RegCreateKeyExW(i r4, w r0, i 0, p 0, i 0, i r5, p 0, *p .r9, p 0) i .r6'
    StrCmp $6 0 0 failed
    System::Call 'advapi32::RegSetValueExW(p r9, w r2, i 0, i 7, p r7, i r8) i .r6'
    System::Call 'advapi32::RegCloseKey(p r9)'
    StrCmp $6 0 finish
    failed:
    SetErrors
    !insertmacro LogWarn "Failed to set MultiStr registry entry: '$0'.'$2' (error: $6)"
    Goto freed
    finish:
    !insertmacro LogInfo "Set MultiStr registry entry: '$0'.'$2' (view: $3)"
    freed:
    System::Free $7

    Pop $R3
    Pop $R2
    Pop $R1
    Pop $R0
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $2
    Pop $3
    Pop $0
    Pop $1
FunctionEnd

Function ${PREFIX}SetRegistrySubKeyMultiStr
    !insertmacro _PushRegView "${PREFIX}"
    Call ${PREFIX}SetRegistrySubKeyMultiStrInView
FunctionEnd

; Stack: view (top), key, subkey, array. Replaces the elements of the array
; with the strings of the value. Only REG_MULTI_SZ values are read: the error
; flag is set (and the array left empty) when the value is missing or has
; another type.
Function ${PREFIX}GetRegistrySubKeyMultiStrInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $3 ; view
    Exch
    Exch $0 ; key
    Exch 2
    Exch $1 ; subkey
    Exch 3
    Exch $2 ; array
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9
    Push $R0
    Push $R1
    Push $R2
    Push $R3

    nsArray::Clear $2
    ClearErrors
    !insertmacro _ApplyRegTestId $0 $4
    !insertmacro _RegMultiSzAccess "${PREFIX}" $3 1 $4 $5
    System::Call 'advapi32::RegOpenKeyExW(i r4, w r0, i 0, i r5, *p .r6) i .r7'
    StrCmp $7 0 0 failed
    ; $7 = type, $8 = size in bytes
    System::Call 'advapi32::RegQueryValueExW(p r6, w r1, p 0, *i .r7, p 0, *i .r8) i .r5'
    StrCmp $5 0 0 closefail
    StrCmp $7 7 0 closefail

    IntOp $9 $8 + 4
    System::Alloc $9
    Pop $9
    System::Call '*(i r8) p .r10'
    System::Call 'advapi32::RegQueryValueExW(p r6, w r1, p 0, p 0, p r9, p r10) i .r5'
    System::Free $R0
    StrCmp $5 0 0 freefail

    ; Stop before the final terminator so empty strings in the list are kept.
    StrCpy $R1 $9
    IntPtrOp $R2 $9 + $8
    IntPtrOp $R2 $R2 - 2
    StrCpy $R3 0
    loop:
        IntPtrCmp $R1 $R2 done 0 done
        System::Call 'kernel32::lstrcpyW(w .r4, p r11)'
        System::Call 'kernel32::lstrlenW(p r11) i .r7'
        nsArray::Set $2 /key=$R3 "$4"
        IntOp $R3 $R3 + 1
        IntOp $7 $7 + 1
        IntOp $7 $7 * 2
        IntPtrOp $R1 $R1 + $7
        Goto loop
    done:
    System::Free $9
    System::Call 'advapi32::RegCloseKey(p r6)'
    ClearErrors
    Goto finished
    freefail:
    System::Free $9
    closefail:
    System::Call 'advapi32::RegCloseKey(p r6)'
    failed:
    SetErrors
    finished:

    Pop $R3
    Pop $R2
    Pop $R1
    Pop $R0
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $2
    Pop $3
    Pop $0
    Pop $1
FunctionEnd

Function ${PREFIX}GetRegistrySubKeyMultiStr
    !insertmacro _PushRegView "${PREFIX}"
    Call ${PREFIX}GetRegistrySubKeyMultiStrInView
FunctionEnd
!macroend

!insertmacro _RegMultiSzFunctions ""
!insertmacro _RegMultiSzFunctions "un."

!macro SetRegistrySubKeyMultiStrInView VIEW KEY SUBKEY ARRAY
    Push "${SUBKEY}"
    Push "${ARRAY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call SetRegistrySubKeyMultiStrInView
!macroend
!define SetRegistrySubKeyMultiStrInView `!insertmacro SetRegistrySubKeyMultiStrInView`

!macro SetRegistrySubKeyMultiStr KEY SUBKEY ARRAY
    Push "${SUBKEY}"
    Push "${ARRAY}"
    Push "${KEY}"
    Call SetRegistrySubKeyMultiStr
!macroend
!define SetRegistrySubKeyMultiStr `!insertmacro SetRegistrySubKeyMultiStr`

!macro un.SetRegistrySubKeyMultiStrInView VIEW KEY SUBKEY ARRAY
    Push "${SUBKEY}"
    Push "${ARRAY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call un.SetRegistrySubKeyMultiStrInView
!macroend
!define un.SetRegistrySubKeyMultiStrInView `!insertmacro un.SetRegistrySubKeyMultiStrInView`

!macro un.SetRegistrySubKeyMultiStr KEY SUBKEY ARRAY
    Push "${SUBKEY}"
    Push "${ARRAY}"
    Push "${KEY}"
    Call un.SetRegistrySubKeyMultiStr
!macroend
!define un.SetRegistrySubKeyMultiStr `!insertmacro un.SetRegistrySubKeyMultiStr`

!macro GetRegistrySubKeyMultiStrInView VIEW KEY SUBKEY ARRAY
    Push "${ARRAY}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call GetRegistrySubKeyMultiStrInView
!macroend
!define GetRegistrySubKeyMultiStrInView `!insertmacro GetRegistrySubKeyMultiStrInView`

!macro GetRegistrySubKeyMultiStr KEY SUBKEY ARRAY
    Push "${ARRAY}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Call GetRegistrySubKeyMultiStr
!macroend
!define GetRegistrySubKeyMultiStr `!insertmacro GetRegistrySubKeyMultiStr`

!macro un.GetRegistrySubKeyMultiStrInView VIEW KEY SUBKEY ARRAY
    Push "${ARRAY}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Push "${VIEW}"
    Call un.GetRegistrySubKeyMultiStrInView
!macroend
!define un.GetRegistrySubKeyMultiStrInView `!insertmacro un.GetRegistrySubKeyMultiStrInView`

!macro un.GetRegistrySubKeyMultiStr KEY SUBKEY ARRAY
    Push "${ARRAY}"
    Push "${SUBKEY}"
    Push "${KEY}"
    Call un.GetRegistrySubKeyMultiStr
!macroend
!define un.GetRegistrySubKeyMultiStr `!insertmacro un.GetRegistrySubKeyMultiStr`

; Reads REG_SZ and REG_DWORD values as is. REG_MULTI_SZ values are read as
; their strings separated by line feeds; use GetRegistrySubKeyMultiStr to get
; them exactly.
!macro _GetRegistrySubKey PREFIX
Function ${PREFIX}GetRegistrySubKeyInView
    !insertmacro ${PREFIX}SetShellContext
    Exch $2 ; view
    Exch
    Exch $0 ; key
    Exch 2
    Exch $1 ; subkey
    Push $3

    Push "__registry_multisz"
    Push $1
    Push $0
    Push $2
    Call ${PREFIX}GetRegistrySubKeyMultiStrInView
    IfErrors legacy
        nsArray::Join "__registry_multisz" "$\n"
        Pop $3
        ClearErrors
        Goto found
    legacy:
    !insertmacro _ApplyRegTestId $0 $3
    !insertmacro _ApplyRegView "${PREFIX}" $2
    ClearErrors
    ReadRegStr $3 SHCTX "$0" "$1"
    !insertmacro ${PREFIX}DefineRegView
    found:
    StrCpy $0 $3

    Pop $3
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
