; The nsArray plugin behind macros, so that the rest of the includes never call
; it directly. Every macro works with an array that does not exist yet, which
; nsArray itself does not: its functions then push nothing and set the error
; flag, and popping their result takes an unrelated value off the stack.
;
;   ${Array_Reset} ARRAY                 an empty array (created when missing)
;   ${Array_Clear} ARRAY                 empties the array (nothing when missing)
;   ${Array_Length} ARRAY OUT            the number of items, 0 when missing
;   ${Array_Set} ARRAY KEY VALUE         sets the item at KEY: an index, or a name
;   ${Array_Append} ARRAY VALUE          adds an item at the end; VALUE must not use $R9
;   ${Array_GetAt} ARRAY INDEX OUT       the item at INDEX (from 0); "" and the error
;                                        flag set when there is none
;   ${Array_GetKey} ARRAY KEY OUT        the item named KEY; "" and the error flag set
;                                        when there is none
;   ${Array_Join} ARRAY SEPARATOR OUT    the items joined; "" when the array is missing
;   ${Array_Split} ARRAY TEXT SEPARATOR  replaces the items with the parts of TEXT
;   ${Array_Copy} SOURCE DEST            DEST becomes a copy of SOURCE, keys included;
;                                        empty when SOURCE is missing
;   ${Array_ToString} ARRAY OUT          "key => value, key => value"; "" when the array
;                                        is missing. The error flag is set when the text
;                                        was cut off at NSIS_MAX_STRLEN
;
; The error flag is cleared, except where it reports a missing item or a cut-off.

!ifndef ARRAY_NSH
!define ARRAY_NSH

!include LogicLib.nsh

!macro Array_Reset ARRAY
    nsArray::Set "${ARRAY}" /key=0 ""
    nsArray::Clear "${ARRAY}"
    ClearErrors
!macroend
!define Array_Reset `!insertmacro Array_Reset`

!macro Array_Clear ARRAY
    nsArray::Clear "${ARRAY}"
    ClearErrors
!macroend
!define Array_Clear `!insertmacro Array_Clear`

!macro Array_Length ARRAY OUT
    ClearErrors
    nsArray::Length "${ARRAY}"
    ${If} ${Errors}
        StrCpy ${OUT} 0
        ClearErrors
    ${Else}
        Pop ${OUT}
    ${EndIf}
!macroend
!define Array_Length `!insertmacro Array_Length`

!macro Array_Set ARRAY KEY VALUE
    nsArray::Set "${ARRAY}" "/key=${KEY}" "${VALUE}"
    ClearErrors
!macroend
!define Array_Set `!insertmacro Array_Set`

!macro Array_Append ARRAY VALUE
    Push $R9
    ${Array_Length} "${ARRAY}" $R9
    nsArray::Set "${ARRAY}" "/key=$R9" "${VALUE}"
    Pop $R9
    ClearErrors
!macroend
!define Array_Append `!insertmacro Array_Append`

!macro Array_GetAt ARRAY INDEX OUT
    ClearErrors
    nsArray::Get "${ARRAY}" "/at=${INDEX}"
    ${If} ${Errors}
        StrCpy ${OUT} ""
        SetErrors
    ${Else}
        Pop ${OUT} ; the key
        Pop ${OUT}
    ${EndIf}
!macroend
!define Array_GetAt `!insertmacro Array_GetAt`

!macro Array_GetKey ARRAY KEY OUT
    ClearErrors
    nsArray::Get "${ARRAY}" "${KEY}"
    ${If} ${Errors}
        StrCpy ${OUT} ""
        SetErrors
    ${Else}
        Pop ${OUT}
    ${EndIf}
!macroend
!define Array_GetKey `!insertmacro Array_GetKey`

!macro Array_Join ARRAY SEPARATOR OUT
    ClearErrors
    nsArray::Join "${ARRAY}" "${SEPARATOR}"
    ${If} ${Errors}
        StrCpy ${OUT} ""
        ClearErrors
    ${Else}
        Pop ${OUT}
    ${EndIf}
!macroend
!define Array_Join `!insertmacro Array_Join`

!macro Array_Split ARRAY TEXT SEPARATOR
    ${Array_Reset} "${ARRAY}"
    nsArray::Split "${ARRAY}" "${TEXT}" "${SEPARATOR}"
    ClearErrors
!macroend
!define Array_Split `!insertmacro Array_Split`

!macro Array_Copy SOURCE DEST
    Push $R9
    ClearErrors
    nsArray::Length "${SOURCE}"
    ${If} ${Errors}
        Pop $R9
        ${Array_Reset} "${DEST}"
    ${Else}
        Pop $R9 ; the length
        nsArray::Copy "${SOURCE}" "${DEST}"
        Pop $R9
        ClearErrors
    ${EndIf}
!macroend
!define Array_Copy `!insertmacro Array_Copy`

!macro Array_ToString ARRAY OUT
    ClearErrors
    nsArray::Length "${ARRAY}"
    ${If} ${Errors}
        StrCpy ${OUT} ""
        ClearErrors
    ${Else}
        Pop ${OUT}
        nsArray::ToString "${ARRAY}"
        Pop ${OUT}
    ${EndIf}
!macroend
!define Array_ToString `!insertmacro Array_ToString`

!endif
