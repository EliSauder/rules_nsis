!ifndef __INCLUDE_FORMATTING
!define __INCLUDE_FORMATTING

!include LogicLib.nsh

; CharToASCII
;
; Returns the code (1-255) of a single-character string, or 0 when the input is
; empty, longer than one character, or outside 1-255. The UTF-16 code unit is
; read directly: string comparison instructions use locale-aware lstrcmp, which
; treats characters such as the soft hyphen (173) as equal to the empty string.
!macro _CharToASCII PREFIX
Function ${PREFIX}CharToASCII
  Exch $0 ; given character
  Push $1

  StrLen $1 $0
  ${If} $1 = 1
    System::Call '*(&t2 r0)p.r1'
    ${If} $1 P<> 0
      System::Call '*$1(&i2 .r0)'
      System::Free $1
      IntOp $0 $0 & 0xFFFF
      ${If} $0 > 255
        StrCpy $0 0
      ${EndIf}
    ${Else}
      StrCpy $0 0
    ${EndIf}
  ${Else}
    StrCpy $0 0
  ${EndIf}

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

; Value parsers
;
; ${ParseBool}, ${ParseInt}, ${ParseDate} and ${ParseIPv4} take "VALUE OUT" and
; ${ParseNetAddress} takes "VALUE FLAGS OUT". OUT receives the canonical form of
; VALUE. Invalid input sets the error flag and OUT is "". Success clears the
; error flag. Each has a "un." variant.

; Internal: pushes 1 when the string is non-empty and consists only of the
; digits 0-9, otherwise 0.
!macro _ParseDigits PREFIX
Function ${PREFIX}ParseDigits
  Exch $0 ; string
  Push $1 ; length
  Push $2 ; index
  Push $3 ; current character
  Push $4 ; digit index
  Push $5 ; digit table character

  StrLen $1 $0
  StrCpy $2 0
  StrCmp $1 0 ${PREFIX}ParseDigitsNo
${PREFIX}ParseDigitsNextChar:
  IntCmp $2 $1 ${PREFIX}ParseDigitsYes
  StrCpy $3 $0 1 $2
  StrCpy $4 0
${PREFIX}ParseDigitsLookup:
  StrCpy $5 "0123456789" 1 $4
  StrCmp $5 "" ${PREFIX}ParseDigitsNo
  StrCmp $5 $3 0 +3
    IntOp $2 $2 + 1
    Goto ${PREFIX}ParseDigitsNextChar
  IntOp $4 $4 + 1
  Goto ${PREFIX}ParseDigitsLookup

${PREFIX}ParseDigitsYes:
  StrCpy $0 1
  Goto ${PREFIX}ParseDigitsDone
${PREFIX}ParseDigitsNo:
  StrCpy $0 0
${PREFIX}ParseDigitsDone:
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

; Internal: removes leading zeros from a digit string, keeping at least one digit.
!macro _ParseTrimZeros PREFIX
Function ${PREFIX}ParseTrimZeros
  Exch $0
  Push $1
${PREFIX}ParseTrimZerosLoop:
  StrLen $1 $0
  IntCmp $1 1 ${PREFIX}ParseTrimZerosDone ${PREFIX}ParseTrimZerosDone
  StrCpy $1 $0 1
  StrCmp $1 "0" 0 ${PREFIX}ParseTrimZerosDone
  StrCpy $0 $0 "" 1
  Goto ${PREFIX}ParseTrimZerosLoop
${PREFIX}ParseTrimZerosDone:
  Pop $1
  Exch $0
FunctionEnd
!macroend

!insertmacro _ParseDigits ""
!insertmacro _ParseDigits "un."
!insertmacro _ParseTrimZeros ""
!insertmacro _ParseTrimZeros "un."

; ParseBool
;
; Accepts 1/0, true/false, t/f, yes/no, y/n and on/off, case-insensitively, and
; returns "1" or "0".
!macro _ParseBool PREFIX
Function ${PREFIX}ParseBool
  Exch $0 ; input, then result
  Push $1

  ClearErrors
  StrLen $1 $0
  IntCmp $1 5 0 0 ${PREFIX}ParseBoolInvalid ; the longest literal is "false"
  ; StrCmp is case-insensitive
  StrCmp $0 "1" ${PREFIX}ParseBoolTrue
  StrCmp $0 "true" ${PREFIX}ParseBoolTrue
  StrCmp $0 "t" ${PREFIX}ParseBoolTrue
  StrCmp $0 "yes" ${PREFIX}ParseBoolTrue
  StrCmp $0 "y" ${PREFIX}ParseBoolTrue
  StrCmp $0 "on" ${PREFIX}ParseBoolTrue
  StrCmp $0 "0" ${PREFIX}ParseBoolFalse
  StrCmp $0 "false" ${PREFIX}ParseBoolFalse
  StrCmp $0 "f" ${PREFIX}ParseBoolFalse
  StrCmp $0 "no" ${PREFIX}ParseBoolFalse
  StrCmp $0 "n" ${PREFIX}ParseBoolFalse
  StrCmp $0 "off" ${PREFIX}ParseBoolFalse
${PREFIX}ParseBoolInvalid:
  StrCpy $0 ""
  SetErrors
  Goto ${PREFIX}ParseBoolDone
${PREFIX}ParseBoolTrue:
  StrCpy $0 1
  Goto ${PREFIX}ParseBoolDone
${PREFIX}ParseBoolFalse:
  StrCpy $0 0
${PREFIX}ParseBoolDone:
  Pop $1
  Exch $0
FunctionEnd
!macroend

; ParseInt
;
; An optional + or - followed by decimal digits, within the signed 32-bit range.
; Returns decimal without a "+" or leading zeros.
!macro _ParseInt PREFIX
Function ${PREFIX}ParseInt
  Exch $0 ; input, then result
  Push $1 ; sign
  Push $2 ; digits
  Push $3 ; length
  Push $4 ; leading digits
  Push $5 ; last digit
  Push $6 ; last digit limit

  ClearErrors
  StrCpy $1 ""
  StrCpy $6 7
  StrCpy $2 $0 1
  StrCmp $2 "+" ${PREFIX}ParseIntSigned
  StrCmp $2 "-" 0 ${PREFIX}ParseIntDigits
  StrCpy $1 "-"
  StrCpy $6 8
${PREFIX}ParseIntSigned:
  StrCpy $0 $0 "" 1
${PREFIX}ParseIntDigits:
  Push $0
  Call ${PREFIX}ParseDigits
  Pop $2
  StrCmp $2 1 0 ${PREFIX}ParseIntInvalid

  Push $0
  Call ${PREFIX}ParseTrimZeros
  Pop $2
  StrLen $3 $2
  IntCmp $3 10 0 ${PREFIX}ParseIntValid ${PREFIX}ParseIntInvalid
  ; Ten digits: compare the leading nine, then the last digit, so the
  ; comparison never overflows.
  StrCpy $4 $2 9
  StrCpy $5 $2 1 9
  IntCmp $4 214748364 0 ${PREFIX}ParseIntValid ${PREFIX}ParseIntInvalid
  IntCmp $5 $6 ${PREFIX}ParseIntValid ${PREFIX}ParseIntValid ${PREFIX}ParseIntInvalid

${PREFIX}ParseIntValid:
  StrCmp $2 "0" 0 +2 ; "-0" is 0
    StrCpy $1 ""
  StrCpy $0 "$1$2"
  Goto ${PREFIX}ParseIntDone
${PREFIX}ParseIntInvalid:
  StrCpy $0 ""
  SetErrors
${PREFIX}ParseIntDone:
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

; ParseDate
;
; YYYY-MM-DD with years 1601-9999, valid days per month and leap years.
!macro _ParseDate PREFIX
Function ${PREFIX}ParseDate
  Exch $0 ; input, then result
  Push $1 ; year
  Push $2 ; month
  Push $3 ; day
  Push $4 ; scratch
  Push $5 ; days in month

  ClearErrors
  StrLen $4 $0
  StrCmp $4 10 0 ${PREFIX}ParseDateInvalid
  StrCpy $4 $0 1 4
  StrCmp $4 "-" 0 ${PREFIX}ParseDateInvalid
  StrCpy $4 $0 1 7
  StrCmp $4 "-" 0 ${PREFIX}ParseDateInvalid

  StrCpy $1 $0 4
  StrCpy $2 $0 2 5
  StrCpy $3 $0 2 8
  Push "$1$2$3"
  Call ${PREFIX}ParseDigits
  Pop $4
  StrCmp $4 1 0 ${PREFIX}ParseDateInvalid

  ; A leading zero would make IntCmp parse the number as octal.
  StrCpy $4 $1 1
  StrCmp $4 "0" ${PREFIX}ParseDateInvalid ; also rejects years below 1000
  IntCmp $1 1601 0 ${PREFIX}ParseDateInvalid
  Push $2
  Call ${PREFIX}ParseTrimZeros
  Pop $2
  Push $3
  Call ${PREFIX}ParseTrimZeros
  Pop $3
  IntCmp $2 1 0 ${PREFIX}ParseDateInvalid
  IntCmp $2 12 0 0 ${PREFIX}ParseDateInvalid
  IntCmp $3 1 0 ${PREFIX}ParseDateInvalid

  IntOp $4 $2 - 1
  IntOp $4 $4 * 2
  StrCpy $5 "312831303130313130313031" 2 $4
  StrCmp $2 2 0 ${PREFIX}ParseDateCheckDay
  ; February: leap years are divisible by 4, except centuries not divisible by 400
  IntOp $4 $1 % 4
  StrCmp $4 0 0 ${PREFIX}ParseDateCheckDay
  IntOp $4 $1 % 100
  StrCmp $4 0 0 ${PREFIX}ParseDateLeap
  IntOp $4 $1 % 400
  StrCmp $4 0 0 ${PREFIX}ParseDateCheckDay
${PREFIX}ParseDateLeap:
  StrCpy $5 29
${PREFIX}ParseDateCheckDay:
  IntCmp $3 $5 0 0 ${PREFIX}ParseDateInvalid
  Goto ${PREFIX}ParseDateDone

${PREFIX}ParseDateInvalid:
  StrCpy $0 ""
  SetErrors
${PREFIX}ParseDateDone:
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

; ParseIPv4
;
; A dotted quad with octets 0-255, each of at most three digits. Leading zeros
; are accepted and removed from the result.
!macro _ParseIPv4 PREFIX
Function ${PREFIX}ParseIPv4
  Exch $0 ; input, then result
  Push $1 ; result
  Push $2 ; length
  Push $3 ; index
  Push $4 ; current character
  Push $5 ; current octet
  Push $6 ; octet count

  ClearErrors
  StrCpy $1 ""
  StrCpy $5 ""
  StrCpy $6 0
  StrCpy $0 "$0." ; the trailing dot terminates the last octet
  StrLen $2 $0
  StrCpy $3 0
${PREFIX}ParseIPv4NextChar:
  IntCmp $3 $2 ${PREFIX}ParseIPv4Finish
  StrCpy $4 $0 1 $3
  IntOp $3 $3 + 1
  StrCmp $4 "." ${PREFIX}ParseIPv4Octet
  StrCpy $5 "$5$4"
  Goto ${PREFIX}ParseIPv4NextChar

${PREFIX}ParseIPv4Octet:
  StrLen $4 $5
  IntCmp $4 3 0 0 ${PREFIX}ParseIPv4Invalid
  Push $5
  Call ${PREFIX}ParseDigits
  Pop $4
  StrCmp $4 1 0 ${PREFIX}ParseIPv4Invalid
  Push $5
  Call ${PREFIX}ParseTrimZeros
  Pop $5
  IntCmp $5 255 0 0 ${PREFIX}ParseIPv4Invalid
  IntOp $6 $6 + 1
  StrCmp $1 "" 0 +3
    StrCpy $1 $5
    Goto +2
  StrCpy $1 "$1.$5"
  StrCpy $5 ""
  Goto ${PREFIX}ParseIPv4NextChar

${PREFIX}ParseIPv4Finish:
  StrCmp $6 4 0 ${PREFIX}ParseIPv4Invalid
  StrCpy $0 $1
  Goto ${PREFIX}ParseIPv4Done
${PREFIX}ParseIPv4Invalid:
  StrCpy $0 ""
  SetErrors
${PREFIX}ParseIPv4Done:
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

; The NET_STRING_* flags of iphlpapi.h, for ${ParseNetAddress}.
!define NET_STRING_IPV4_ADDRESS 0x00000001
!define NET_STRING_IPV4_SERVICE 0x00000002
!define NET_STRING_IPV4_NETWORK 0x00000004
!define NET_STRING_IPV6_ADDRESS 0x00000008
!define NET_STRING_IPV6_ADDRESS_NO_SCOPE 0x00000010
!define NET_STRING_IPV6_SERVICE 0x00000020
!define NET_STRING_IPV6_SERVICE_NO_SCOPE 0x00000040
!define NET_STRING_IPV6_NETWORK 0x00000080
!define NET_STRING_NAMED_ADDRESS 0x00000100
!define NET_STRING_NAMED_SERVICE 0x00000200
!define NET_STRING_IP_ADDRESS 0x00000009
!define NET_STRING_IP_ADDRESS_NO_SCOPE 0x00000011
!define NET_STRING_IP_SERVICE 0x00000022
!define NET_STRING_IP_SERVICE_NO_SCOPE 0x00000066
!define NET_STRING_IP_NETWORK 0x00000084

; ParseNetAddress
;
; Validates VALUE with iphlpapi::ParseNetworkString for the NET_STRING_* mask
; FLAGS. OUT is VALUE unchanged.
!macro _ParseNetAddress PREFIX
Function ${PREFIX}ParseNetAddress
  Exch $1 ; NET_STRING_* flags
  Exch
  Exch $0 ; input, then result
  Push $2

  ClearErrors
  StrCmp $0 "" ${PREFIX}ParseNetAddressInvalid
  System::Call 'iphlpapi::ParseNetworkString(w r0, i r1, p 0, p 0, p 0) i .r2'
  StrCmp $2 0 ${PREFIX}ParseNetAddressDone ; ERROR_SUCCESS
${PREFIX}ParseNetAddressInvalid:
  StrCpy $0 ""
  SetErrors
${PREFIX}ParseNetAddressDone:
  Pop $2
  Exch
  Pop $1
  Exch $0
FunctionEnd
!macroend

!insertmacro _ParseBool ""
!insertmacro _ParseBool "un."
!insertmacro _ParseInt ""
!insertmacro _ParseInt "un."
!insertmacro _ParseDate ""
!insertmacro _ParseDate "un."
!insertmacro _ParseIPv4 ""
!insertmacro _ParseIPv4 "un."
!insertmacro _ParseNetAddress ""
!insertmacro _ParseNetAddress "un."

!macro _ParseValue PREFIX NAME VALUE OUT
  Push "${VALUE}"
  Call ${PREFIX}${NAME}
  Pop ${OUT}
!macroend

!macro ParseBool VALUE OUT
  !insertmacro _ParseValue "" ParseBool "${VALUE}" ${OUT}
!macroend
!define ParseBool `!insertmacro ParseBool`
!macro un.ParseBool VALUE OUT
  !insertmacro _ParseValue "un." ParseBool "${VALUE}" ${OUT}
!macroend
!define un.ParseBool `!insertmacro un.ParseBool`

!macro ParseInt VALUE OUT
  !insertmacro _ParseValue "" ParseInt "${VALUE}" ${OUT}
!macroend
!define ParseInt `!insertmacro ParseInt`
!macro un.ParseInt VALUE OUT
  !insertmacro _ParseValue "un." ParseInt "${VALUE}" ${OUT}
!macroend
!define un.ParseInt `!insertmacro un.ParseInt`

!macro ParseDate VALUE OUT
  !insertmacro _ParseValue "" ParseDate "${VALUE}" ${OUT}
!macroend
!define ParseDate `!insertmacro ParseDate`
!macro un.ParseDate VALUE OUT
  !insertmacro _ParseValue "un." ParseDate "${VALUE}" ${OUT}
!macroend
!define un.ParseDate `!insertmacro un.ParseDate`

!macro ParseIPv4 VALUE OUT
  !insertmacro _ParseValue "" ParseIPv4 "${VALUE}" ${OUT}
!macroend
!define ParseIPv4 `!insertmacro ParseIPv4`
!macro un.ParseIPv4 VALUE OUT
  !insertmacro _ParseValue "un." ParseIPv4 "${VALUE}" ${OUT}
!macroend
!define un.ParseIPv4 `!insertmacro un.ParseIPv4`

!macro ParseNetAddress VALUE FLAGS OUT
  Push "${VALUE}"
  Push ${FLAGS}
  Call ParseNetAddress
  Pop ${OUT}
!macroend
!define ParseNetAddress `!insertmacro ParseNetAddress`
!macro un.ParseNetAddress VALUE FLAGS OUT
  Push "${VALUE}"
  Push ${FLAGS}
  Call un.ParseNetAddress
  Pop ${OUT}
!macroend
!define un.ParseNetAddress `!insertmacro un.ParseNetAddress`

!endif
