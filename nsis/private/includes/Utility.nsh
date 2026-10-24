!ifndef __INCLUDE_UTILITY
!define __INCLUDE_UTILITY

!macro _TrimQuotes PREFIX
Function ${PREFIX}TrimQuotes
    Exch $R0
    Push $R1

    StrCpy $R1 $R0 1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 `` 1

    StrCpy $R1 $R0 1 -1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 -1

    Pop $R1
    Exch $R0
FunctionEnd
!macroend

!insertmacro _TrimQuotes ""
!insertmacro _TrimQuotes "un."

!macro TrimQuotes Input Output
    Push "${Input}"
    Call TrimQuotes
    Pop ${Output}
!macroend
!define TrimQuotes `!insertmacro TrimQuotes`

!macro un.TrimQuotes Input Output
    Push "${Input}"
    Call un.TrimQuotes
    Pop ${Output}
!macroend
!define un.TrimQuotes `!insertmacro un.TrimQuotes`

; Splits STRING at every single-character DELIM into the nsArray ARRAY (which
; is cleared first). With NOEMPTY set to 1, empty items are skipped.
;
; This replaces `nsArray::Split`: the plugin allocates its string buffer as
; `string_size + 1 * sizeof(TCHAR)` (missing parentheses), which is only
; string_size + 2 bytes. In the unicode build the buffer holds about 512
; characters, so a longer string overflows the heap, while NSIS strings go up
; to NSIS_MAX_STRLEN. Items are added one by one with /key=, which also keeps
; an item that looks like an nsArray switch (/at=...) from being read as one.
!macro _ArraySplit PREFIX
; Stack: array name, string, delimiter, noempty (top).
Function ${PREFIX}ArraySplit
    Exch $0 ; noempty
    Exch
    Exch $1 ; delimiter
    Exch 2
    Exch $2 ; string
    Exch 3
    Exch $3 ; array
    Push $4 ; position
    Push $5 ; character
    Push $6 ; item
    Push $7 ; item count

    nsArray::Clear $3
    StrCpy $4 0
    StrCpy $6 ""
    StrCpy $7 0
    loop:
        StrCpy $5 $2 1 $4
        IntOp $4 $4 + 1
        StrCmp $5 "" add
        StrCmpS $5 $1 add
        StrCpy $6 "$6$5"
        Goto loop
    add:
        StrCmp $6 "" 0 +2
        StrCmp $0 1 skip
        nsArray::Set $3 "/key=$7" $6
        IntOp $7 $7 + 1
    skip:
        StrCpy $6 ""
        StrCmp $5 "" done loop
    done:

    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $0
    Pop $1
    Pop $2
FunctionEnd
!macroend

!insertmacro _ArraySplit ""
!insertmacro _ArraySplit "un."

!macro ArraySplit ARRAY STRING DELIM NOEMPTY
    Push "${ARRAY}"
    Push `${STRING}`
    Push "${DELIM}"
    Push "${NOEMPTY}"
    Call ArraySplit
!macroend
!define ArraySplit `!insertmacro ArraySplit`

!macro un.ArraySplit ARRAY STRING DELIM NOEMPTY
    Push "${ARRAY}"
    Push `${STRING}`
    Push "${DELIM}"
    Push "${NOEMPTY}"
    Call un.ArraySplit
!macroend
!define un.ArraySplit `!insertmacro un.ArraySplit`

!endif
