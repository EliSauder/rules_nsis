!ifndef __INCLUDE_FORMATTING
!define __INCLUDE_FORMATTING

!include LogicLib.nsh

!define CharToASCII "!insertmacro CharToASCII"

!macro CharToASCII STR DST
  Push "${STR}"
  Call CharToASCII
  Pop ${DST}
!macroend

Function CharToASCII
  Exch $0 ; given character
  Push $1 ; current character
  Push $2 ; current Ascii Code

  StrCpy $2 1 ; right from start
Loop:
  IntFmt $1 %c $2 ; Get character from current ASCII code
  ${If} $1 S== $0 ; case sensitive string comparison
     StrCpy $0 $2
     Goto Done
  ${EndIf}
  IntOp $2 $2 + 1
  StrCmp $2 255 0 Loop ; ascii from 1 to 255
  StrCpy $0 0 ; ASCII code wasn't found -> return 0
Done:
  Pop $2
  Pop $1
  Exch $0
FunctionEnd

;Hex2Bin

;Converts a hexadecimal number string to binary.

;Push "HexadecimalNumber"
;Call bin2dec
;Pop "BinaryNumberVariable"
Function Hex2Bin
    Push $0
    Exch
    Exch $1
    Exch
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7

    ; Set/Get Source Hex Number
    StrLen $0 $1
    StrCpy $3 $0

    ; loop - Get 1 Letter per loop from right for process
NextLetter:
    StrCpy $4 '$5 $4'
    StrCpy $5 ''

    StrCmp $3 '0' End

    IntOP $3 $3 - 1
    StrCpy $2 $1 1 $3
    StrCpy $6 '256'

    IntOP $6 $6 / 2
    IntOP $7 0x$2 & $6
    IntCmp $7 '0' +2
        StrCpy $7 '1'
    StrCpy $5 '$5$7'
    StrCmp $6 '1' NextLetter -5

End:

    StrCpy $1 $4 "" 4
    StrCpy $1 $1 4

    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Exch $1
FunctionEnd

!endif
