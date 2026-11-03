!include "LogicLib.nsh"
!include "Array.nsh"

; Every macro must cope with an array that was never created, and leave the
; stack as it found it (the harness checks the registers).
!macro HarnessArrayMissing COUNT ITEM ITEM_MISSING JOINED KEY_MISSING
    ${Array_Length} harness_never ${COUNT}
    ${Array_GetAt} harness_never 0 ${ITEM}
    ${If} ${Errors}
        StrCpy ${ITEM_MISSING} 1
    ${Else}
        StrCpy ${ITEM_MISSING} 0
    ${EndIf}
    ${Array_Join} harness_never "," ${JOINED}
    ${Array_Clear} harness_never
    ${Array_GetKey} harness_never "k" ${ITEM}
    ${If} ${Errors}
        StrCpy ${KEY_MISSING} 1
    ${Else}
        StrCpy ${KEY_MISSING} 0
    ${EndIf}
!macroend

!macro HarnessArrayItems A B COUNT FIRST SECOND JOINED NAMED
    ${Array_Reset} harness_items
    ${Array_Append} harness_items `${A}`
    ${Array_Append} harness_items `${B}`
    ${Array_Length} harness_items ${COUNT}
    ${Array_GetAt} harness_items 0 ${FIRST}
    ${Array_GetAt} harness_items 1 ${SECOND}
    ${Array_Join} harness_items "," ${JOINED}
    ${Array_Set} harness_named "k" `${A}`
    ${Array_GetKey} harness_named "k" ${NAMED}
!macroend
