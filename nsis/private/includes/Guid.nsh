!ifndef __INCLUDE_GUID
!define __INCLUDE_GUID

!include "LogicLib.nsh"

; ---------------------------------------------------------------------------
; _GuidHexUpper  (internal helper)
;   in  (stack): a single character
;   out (stack): the upper-case hex digit if the char is [0-9a-fA-F],
;                otherwise "" (empty string)
; ---------------------------------------------------------------------------
!macro __GuidHexUpper PREFIX
Function ${PREFIX}_GuidHexUpper
  Exch $0                          ; $0 = input char (orig $0 saved on stack)
  Push $1                          ; lowercase reference set
  Push $2                          ; uppercase reference set
  Push $3                          ; index into the sets
  Push $4                          ; probe char

  StrCpy $1 "0123456789abcdef"
  StrCpy $2 "0123456789ABCDEF"
  StrCpy $3 0

  guh_loop:
    StrCpy $4 $2 1 $3              ; upper[$3]
    StrCmp $4 "" guh_bad          ; end of set -> not a hex digit
    StrCmp $4 $0 guh_ok           ; matched an already-uppercase hex digit
    StrCpy $4 $1 1 $3             ; lower[$3]
    StrCmp $4 $0 guh_ok2          ; matched a lowercase hex digit
    IntOp $3 $3 + 1
    Goto guh_loop

  guh_ok2:
    StrCpy $4 $2 1 $3             ; canonicalize to the uppercase form
  guh_ok:
    StrCpy $0 $4
    Goto guh_done
  guh_bad:
    StrCpy $0 ""
  guh_done:

  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0                          ; result replaces the input char on the stack
FunctionEnd
!macroend

!insertmacro __GuidHexUpper ""
!insertmacro __GuidHexUpper "un."

; ---------------------------------------------------------------------------
; NormalizeGuid
;   in  (stack): UUID or GUID string (braces optional)
;   out (stack): "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" if valid, else ""
; ---------------------------------------------------------------------------
!macro _NormalizeGuid PREFIX
Function ${PREFIX}NormalizeGuid
  Exch $0                          ; $0 = input string
  Push $1                          ; brace-stripped core
  Push $2                          ; length / scratch
  Push $3                          ; loop index
  Push $4                          ; current char
  Push $5                          ; accumulator (canonical core)

  ; --- Strip surrounding braces if present ---------------------------------
  StrCpy $1 $0
  StrCpy $2 $0 1 0                 ; first char
  ${If} $2 == "{"
    StrCpy $2 $0 1 -1             ; last char
    StrCmp $2 "}" 0 ng_invalid    ; '{' without matching '}' -> invalid
    StrLen $2 $0
    IntOp $2 $2 - 2
    StrCpy $1 $0 $2 1            ; drop leading '{' and trailing '}'
  ${EndIf}

  ; --- Core must be exactly 36 chars (8-4-4-4-12 with hyphens) -------------
  StrLen $2 $1
  ${If} $2 != 36
    Goto ng_invalid
  ${EndIf}

  ; --- Validate every position and build the canonical (upper) form -------
  StrCpy $5 ""
  StrCpy $3 0
  ng_loop:
    ${If} $3 >= 36
      Goto ng_valid
    ${EndIf}
    StrCpy $4 $1 1 $3             ; current char at offset $3

    ; Offsets 8, 13, 18, 23 must be '-'; everything else must be hex.
    ${If} $3 = 8
    ${OrIf} $3 = 13
    ${OrIf} $3 = 18
    ${OrIf} $3 = 23
      StrCmp $4 "-" 0 ng_invalid
      StrCpy $5 "$5-"
    ${Else}
      Push $4
      Call ${PREFIX}_GuidHexUpper
      Pop $4
      StrCmp $4 "" ng_invalid
      StrCpy $5 "$5$4"
    ${EndIf}

    IntOp $3 $3 + 1
    Goto ng_loop

  ng_valid:
    StrCpy $0 "{$5}"
    Goto ng_done
  ng_invalid:
    StrCpy $0 ""
  ng_done:

  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch $0                          ; return value replaces the input on the stack
FunctionEnd
!macroend

!insertmacro _NormalizeGuid ""
!insertmacro _NormalizeGuid "un."

!macro NormalizeGuid TEXT OUT
    Push "${TEXT}"
    Call NormalizeGuid
    Pop ${OUT}
!macroend

!macro un.NormalizeGuid TEXT OUT
    Push "${TEXT}"
        Call un.NormalizeGuid
    Pop ${OUT}
!macroend
!endif
