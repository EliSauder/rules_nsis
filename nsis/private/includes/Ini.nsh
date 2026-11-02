; INI file helpers. Lists of strings are exchanged as nsArray arrays, which are
; created (empty) when they do not exist and replaced when they do.
;
;   ${Ini_ReadStr} FILE SECTION KEY OUT       first value of the key (errors if missing)
;   ${Ini_ReadList} FILE SECTION KEY ARRAY    every value of a repeated key (errors if none)
;   ${Ini_Sections} FILE ARRAY                the section names
;   ${Ini_Keys} FILE SECTION ARRAY            the key names (repeated keys are repeated)
;   ${Ini_FormatList} ARRAY KEY OUT           one `key=item` line (CRLF ended) per item,
;                                             or `key=` for an empty list
;
; Names are compared case-insensitively, as the Windows INI API does.

!ifndef INI_NSH
!define INI_NSH

!include "LogicLib.nsh"
!include "Array.nsh"

; Stack: pointer to a double-NUL terminated list of strings (top), array. Puts
; the strings in the array.
Function Ini_PtrListToArray
    Exch $0 ; pointer
    Exch
    Exch $1 ; array
    Push $2
    Push $3
    Push $4

    nsArray::Set $1 /key=0 ""
    nsArray::Clear $1
    StrCpy $2 0
    ${Do}
        System::Call 'kernel32::lstrlenW(p r0) i .r3'
        ${If} $3 = 0
            ${Break}
        ${EndIf}
        System::Call 'kernel32::lstrcpyW(w .r4, p r0)'
        nsArray::Set $1 /key=$2 "$4"
        IntOp $2 $2 + 1
        IntOp $3 $3 + 1
        IntOp $3 $3 * 2
        IntPtrOp $0 $0 + $3
    ${Loop}

    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; Stack: section (top), file, array. Puts the `key=value` lines of the section
; in the array.
Function Ini_Lines
    Exch $2 ; section
    Exch
    Exch $0 ; file
    Exch 2
    Exch $1 ; array
    Push $3

    System::Alloc 131072
    Pop $3
    System::Call 'kernel32::GetPrivateProfileSectionW(w r2, p r3, i 65535, w r0)'
    Push $1
    Push $3
    Call Ini_PtrListToArray
    System::Free $3

    Pop $3
    Pop $1
    Pop $2
    Pop $0
FunctionEnd

; Stack: key (top), section, file, array.
Function Ini_ReadList
    Exch $2 ; key
    Exch
    Exch $1 ; section
    Exch 2
    Exch $0 ; file
    Exch 3
    Exch $R0 ; array
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7

    Push "__ini_lines"
    Push $0
    Push $1
    Call Ini_Lines
    nsArray::Set $R0 /key=0 ""
    nsArray::Clear $R0
    ${Array_Length} __ini_lines $3
    StrCpy $4 0 ; line
    StrCpy $5 0 ; found
    ${While} $4 < $3
        nsArray::Get __ini_lines /at=$4
        Pop $6
        Pop $6
        StrCpy $7 0
        ${Do}
            StrCpy $1 $6 1 $7
            ${If} $1 == ""
            ${OrIf} $1 == "="
                ${Break}
            ${EndIf}
            IntOp $7 $7 + 1
        ${Loop}
        StrCpy $1 $6 $7
        ${If} $7 > 0
        ${AndIf} $1 == $2
            IntOp $7 $7 + 1
            StrCpy $1 $6 "" $7
            nsArray::Set $R0 /key=$5 "$1"
            IntOp $5 $5 + 1
        ${EndIf}
        IntOp $4 $4 + 1
    ${EndWhile}
    ClearErrors
    ${If} $5 = 0
        SetErrors
    ${EndIf}

    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $R0
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; Stack: file (top), array.
Function Ini_Sections
    Exch $0 ; file
    Exch
    Exch $1 ; array
    Push $2

    System::Alloc 131072
    Pop $2
    System::Call 'kernel32::GetPrivateProfileSectionNamesW(p r2, i 65535, w r0)'
    Push $1
    Push $2
    Call Ini_PtrListToArray
    System::Free $2

    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; Stack: section (top), file, array.
Function Ini_Keys
    Exch $2 ; section
    Exch
    Exch $0 ; file
    Exch 2
    Exch $1 ; array
    Push $3

    System::Alloc 131072
    Pop $3
    System::Call 'kernel32::GetPrivateProfileStringW(w r2, p 0, w "", p r3, i 65535, w r0)'
    Push $1
    Push $3
    Call Ini_PtrListToArray
    System::Free $3

    Pop $3
    Pop $1
    Pop $2
    Pop $0
FunctionEnd

; Stack: key (top), array. Pushes the lines.
Function Ini_FormatList
    Exch $1 ; key
    Exch
    Exch $0 ; array
    Push $2
    Push $3
    Push $4
    Push $5

    StrCpy $5 ""
    ${Array_Length} $0 $2
    ${If} $2 = 0
        StrCpy $5 "$1=$\r$\n"
    ${EndIf}
    StrCpy $3 0
    ${While} $3 < $2
        nsArray::Get $0 /at=$3
        Pop $4
        Pop $4
        StrCpy $5 "$5$1=$4$\r$\n"
        IntOp $3 $3 + 1
    ${EndWhile}
    StrCpy $1 $5

    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Exch $1
FunctionEnd

!macro Ini_ReadStr FILE SECTION KEY OUT
    ClearErrors
    ReadINIStr ${OUT} "${FILE}" "${SECTION}" "${KEY}"
!macroend
!define Ini_ReadStr `!insertmacro Ini_ReadStr`

!macro Ini_ReadList FILE SECTION KEY ARRAY
    Push "${ARRAY}"
    Push "${FILE}"
    Push "${SECTION}"
    Push "${KEY}"
    Call Ini_ReadList
!macroend
!define Ini_ReadList `!insertmacro Ini_ReadList`

!macro Ini_Sections FILE ARRAY
    Push "${ARRAY}"
    Push "${FILE}"
    Call Ini_Sections
!macroend
!define Ini_Sections `!insertmacro Ini_Sections`

!macro Ini_Keys FILE SECTION ARRAY
    Push "${ARRAY}"
    Push "${FILE}"
    Push "${SECTION}"
    Call Ini_Keys
!macroend
!define Ini_Keys `!insertmacro Ini_Keys`

!macro Ini_FormatList ARRAY KEY OUT
    Push "${ARRAY}"
    Push "${KEY}"
    Call Ini_FormatList
    Pop ${OUT}
!macroend
!define Ini_FormatList `!insertmacro Ini_FormatList`

!endif
