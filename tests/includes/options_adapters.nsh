Var __opt_test_a
Var __opt_test_b
Var __opt_test_c

!macro __Options_ForEachPersisted CALLBACK
    !insertmacro ${CALLBACK} test a single
    !insertmacro ${CALLBACK} test b list
    !insertmacro ${CALLBACK} test c multiline
!macroend

!include "Options.nsh"

!macro _HarnessOptionClear PREFIX
    Push $0
    !insertmacro ${PREFIX}GetProductKey $0
    !insertmacro ${PREFIX}RemoveRegistryKey "$0\Options"
    Pop $0
!macroend

!macro HarnessOptionRoundTrip VALUE OUT
    ${Option_Set} test a `${VALUE}`
    ${Option_Get} test a ${OUT}
!macroend

!macro HarnessOptionIsSet VALUE OUT
    ${Option_Set} test a `${VALUE}`
    ${If} test ${Option_IsSet} a
        StrCpy ${OUT} 1
    ${Else}
        StrCpy ${OUT} 0
    ${EndIf}
!macroend

; Makes the list option `test b` hold a copy of the array ITEMS.
!macro _HarnessListSet ITEMS
    ${Option_Set} test b "__opt_test_b"
    ${Array_Copy} "${ITEMS}" __opt_test_b
!macroend

!macro HarnessOptionListContains ITEMS VALUE OUT
    !insertmacro _HarnessListSet "${ITEMS}"
    ${Option_ListContains} test b `${VALUE}` ${OUT}
!macroend

!macro un.HarnessOptionListContains ITEMS VALUE OUT
    !insertmacro _HarnessListSet "${ITEMS}"
    ${un.Option_ListContains} test b `${VALUE}` ${OUT}
!macroend

; Persists VALUE, clobbers the option and loads it back. Another option that
; was never stored keeps its value.
!macro HarnessOptionPersist VALUE OUT
    !insertmacro _HarnessOptionClear ""
    ${Option_Set} test a `${VALUE}`
    ${Option_Set} test b "default"
    ${Option_Persist}
    ${Option_Set} test a "clobbered"
    ${Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
    !insertmacro _HarnessOptionClear ""
!macroend

; With nothing stored, loading keeps the defaults.
!macro HarnessOptionLoadMissing DEFAULT OUT
    !insertmacro _HarnessOptionClear ""
    ${Option_Set} test a `${DEFAULT}`
    ${Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
!macroend

!macro un.HarnessOptionLoadMissing DEFAULT OUT
    !insertmacro _HarnessOptionClear un.
    ${Option_Set} test a `${DEFAULT}`
    ${un.Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
!macroend

!macro _HarnessListOut COUNT ITEMS
    ${Option_ListCount} test b ${COUNT}
    ${Array_Copy} __opt_test_b "${ITEMS}"
!macroend

; Persists a list and multiline text, clobbers them and loads them back. The
; stored values are left for the test to inspect and delete.
!macro HarnessOptionPersistKinds ITEMS TEXT COUNT ITEMS_OUT TEXT_OUT
    !insertmacro _HarnessOptionClear ""
    !insertmacro _HarnessListSet "${ITEMS}"
    ${Option_Set} test c `${TEXT}`
    ${Option_Persist}
    ${Array_Reset} __opt_clobbered
    ${Array_Append} __opt_clobbered "clobbered"
    !insertmacro _HarnessListSet __opt_clobbered
    ${Option_Set} test c "clobbered"
    ${Option_LoadPersisted}
    !insertmacro _HarnessListOut ${COUNT} ${ITEMS_OUT}
    ${Option_Get} test c ${TEXT_OUT}
!macroend

; Loads the values the test stored, without clearing them.
!macro HarnessOptionLoad COUNT ITEMS TEXT
    ${Array_Reset} __opt_empty
    !insertmacro _HarnessListSet __opt_empty
    ${Option_LoadPersisted}
    !insertmacro _HarnessListOut ${COUNT} ${ITEMS}
    ${Option_Get} test c ${TEXT}
!macroend

!macro HarnessOptionTypedPersist KIND VALUE OUT
    Push "${KIND}"
    Push `${VALUE}`
    Push "typed.value"
    Call Option_WriteReg
    Push "${KIND}"
    Push "clobbered"
    Push "typed.value"
    Call Option_ReadReg
    Pop ${OUT}
!macroend

!macro _HarnessOptionTypedRead PREFIX KIND DEFAULT OUT
    Push "${KIND}"
    Push `${DEFAULT}`
    Push "typed.value"
    Call ${PREFIX}Option_ReadReg
    Pop ${OUT}
!macroend

!macro HarnessOptionTypedRead KIND DEFAULT OUT
    !insertmacro _HarnessOptionTypedRead "" "${KIND}" `${DEFAULT}` ${OUT}
!macroend

!macro HarnessOptionUpgrade KIND DEFAULT OUT
    !insertmacro HarnessOptionTypedRead "${KIND}" `${DEFAULT}` ${OUT}
    Push "${KIND}"
    Push ${OUT}
    Push "typed.value"
    Call Option_WriteReg
!macroend

!macro un.HarnessOptionTypedRead KIND DEFAULT OUT
    !insertmacro _HarnessOptionTypedRead "un." "${KIND}" `${DEFAULT}` ${OUT}
!macroend
