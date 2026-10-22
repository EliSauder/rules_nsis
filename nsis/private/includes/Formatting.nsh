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

;Converts a hexadecimal number string to binary.

;Push "HexadecimalNumber"
;Call bin2dec
;Pop "BinaryNumberVariable"
!macro _Hex2Bin PREFIX
Function ${PREFIX}Hex2Bin
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7

    StrCpy $1 ""
    StrLen $2 $0
    StrCpy $3 0
${PREFIX}Hex2BinNextChar:
    StrCmp $3 $2 ${PREFIX}Hex2BinDone
    StrCpy $4 $0 1 $3
    ClearErrors
    IntOp $4 0x$4 & 0xF
    IfErrors ${PREFIX}Hex2BinInvalid
    StrCpy $5 8
    StrCpy $6 ""
${PREFIX}Hex2BinNextBit:
    IntOp $7 $4 & $5
    ${If} $7 == 0
        StrCpy $7 "0"
    ${Else}
        StrCpy $7 "1"
    ${EndIf}
    StrCpy $6 "$6$7"
    IntOp $5 $5 / 2
    StrCmp $5 0 ${PREFIX}Hex2BinNextNibble
    Goto ${PREFIX}Hex2BinNextBit
${PREFIX}Hex2BinNextNibble:
    StrCpy $1 "$1$6"
    IntOp $3 $3 + 1
    Goto ${PREFIX}Hex2BinNextChar
${PREFIX}Hex2BinInvalid:
    StrCpy $1 ""
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
