!ifndef __INCLUDE_FORMATTING
!define __INCLUDE_FORMATTING

!include LogicLib.nsh

!macro _CharToASCII PREFIX
Function ${PREFIX}CharToASCII
  Exch $0 ; given character
  Push $1 ; current character
  Push $2 ; current Ascii Code

  StrCpy $2 1 ; right from start
${PREFIX}CharToASCIILoop:
  IntFmt $1 %c $2 ; Get character from current ASCII code
  ${If} $1 S== $0 ; case sensitive string comparison
     StrCpy $0 $2
     Goto ${PREFIX}CharToASCIIDone
  ${EndIf}
  IntOp $2 $2 + 1
  StrCmp $2 255 0 ${PREFIX}CharToASCIILoop ; ascii from 1 to 255
  StrCpy $0 0 ; ASCII code wasn't found -> return 0
${PREFIX}CharToASCIIDone:
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

!insertmacro _CharToASCII ""
!insertmacro _CharToASCII "un."

!define CharToASCII "!insertmacro CharToASCII"
!macro CharToASCII STR DST
  Push "${STR}"
  Call CharToASCII
  Pop ${DST}
!macroend

!define un.CharToASCII "!insertmacro un.CharToASCII"
!macro un.CharToASCII STR DST
  Push "${STR}"
  Call un.CharToASCII
  Pop ${DST}
!macroend

!macro Hex2Bin VALUE OUT
  Push "${VALUE}"
  Call Hex2Bin
  Pop ${OUT}
!macroend
!define Hex2Bin `!insertmacro Hex2Bin`

!macro un.Hex2Bin VALUE OUT
  Push "${VALUE}"
  Call un.Hex2Bin
  Pop ${OUT}
!macroend
!define un.Hex2Bin `!insertmacro un.Hex2Bin`

;Hex2Bin
;
;Converts a hexadecimal string (with an optional 0x/0X prefix) to a binary
;string, e.g. "0x4F" -> "01001111". Hex digits are case-insensitive.
;On invalid input (a non-hex character, or a bare "0x") the error flag is set
;and an empty string is returned. Empty input returns "" without an error.
;
;Push "HexadecimalNumber"
;Call Hex2Bin
;Pop "BinaryNumberVariable"
!macro _Hex2Bin PREFIX
Function ${PREFIX}Hex2Bin
    Exch $0 ; input
    Push $1 ; result
    Push $2 ; input length
    Push $3 ; input index
    Push $4 ; current character
    Push $5 ; nibble value
    Push $6 ; bit mask
    Push $7 ; scratch

    ClearErrors
    StrCpy $1 ""

    StrCpy $4 $0 2
    ${If} $4 == "0x" ; LogicLib == is case-insensitive, so this also matches 0X
        StrCpy $0 $0 "" 2
        StrCmp $0 "" ${PREFIX}Hex2BinInvalid
    ${EndIf}

    StrLen $2 $0
    StrCpy $3 0
${PREFIX}Hex2BinNextChar:
    IntCmp $3 $2 ${PREFIX}Hex2BinDone
    StrCpy $4 $0 1 $3

    ; The nibble value is the character's position in the digit table.
    StrCpy $5 0
${PREFIX}Hex2BinLookup:
    StrCpy $7 "0123456789ABCDEF" 1 $5
    StrCmp $7 "" ${PREFIX}Hex2BinInvalid
    StrCmp $7 $4 ${PREFIX}Hex2BinFound ; StrCmp is case-insensitive
    IntOp $5 $5 + 1
    Goto ${PREFIX}Hex2BinLookup

${PREFIX}Hex2BinFound:
    StrCpy $6 8
${PREFIX}Hex2BinNextBit:
    IntOp $7 $5 & $6
    ${If} $7 = 0
        StrCpy $7 "0"
    ${Else}
        StrCpy $7 "1"
    ${EndIf}
    StrCpy $1 "$1$7"
    IntOp $6 $6 / 2
    IntCmp $6 0 0 0 ${PREFIX}Hex2BinNextBit
    IntOp $3 $3 + 1
    Goto ${PREFIX}Hex2BinNextChar

${PREFIX}Hex2BinInvalid:
    StrCpy $1 ""
    SetErrors
${PREFIX}Hex2BinDone:
    StrCpy $0 $1
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

!insertmacro _Hex2Bin ""
!insertmacro _Hex2Bin "un."

!endif
