; Helpers for the nsArray plugin.
;
;   ${Array_Length} ARRAY OUT   the number of items, 0 when the array does not
;                               exist (the error flag is cleared)
;
; nsArray::Length pushes nothing for an array that does not exist, so popping
; its result unconditionally takes an unrelated value off the stack.

!ifndef ARRAY_NSH
!define ARRAY_NSH

!macro Array_Length ARRAY OUT
    ClearErrors
    nsArray::Length "${ARRAY}"
    IfErrors +3
    Pop ${OUT}
    Goto +2
    StrCpy ${OUT} 0
    ClearErrors
!macroend
!define Array_Length `!insertmacro Array_Length`

!endif
