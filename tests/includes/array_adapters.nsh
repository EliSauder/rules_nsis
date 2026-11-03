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

!macro HarnessArrayCopy A B COPY_COUNT COPY_JOINED SOURCE_COUNT NAMED MISSING_COUNT TEXT TEXT_MISSING
    ${Array_Reset} harness_source
    ${Array_Append} harness_source `${A}`
    ${Array_Append} harness_source `${B}`
    ${Array_Copy} harness_source harness_copy
    ${Array_Append} harness_source "z"
    ${Array_Length} harness_copy ${COPY_COUNT}
    ${Array_Join} harness_copy "," ${COPY_JOINED}
    ${Array_Length} harness_source ${SOURCE_COUNT}
    ${Array_ToString} harness_source ${TEXT}
    ${Array_Set} harness_named "k" `${A}`
    ${Array_Copy} harness_named harness_named_copy
    ${Array_GetKey} harness_named_copy "k" ${NAMED}
    ${Array_Append} harness_filled "stale"
    ${Array_Copy} harness_never harness_filled
    ${Array_Length} harness_filled ${MISSING_COUNT}
    ${Array_ToString} harness_never ${TEXT_MISSING}
!macroend
