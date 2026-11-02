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

; Makes the list option `test b` hold an empty array, then adds the items
; that are not empty.
!macro _HarnessListReset
    ${Option_Set} test b "__opt_test_b"
    ${Array_Reset} __opt_test_b
!macroend

!macro _HarnessListAdd ITEM
    ${If} `${ITEM}` != ""
        ${Array_Append} __opt_test_b `${ITEM}`
    ${EndIf}
!macroend

!macro HarnessOptionListContains A B C VALUE OUT
    !insertmacro _HarnessListReset
    !insertmacro _HarnessListAdd `${A}`
    !insertmacro _HarnessListAdd `${B}`
    !insertmacro _HarnessListAdd `${C}`
    ${Option_ListContains} test b `${VALUE}` ${OUT}
!macroend

!macro un.HarnessOptionListContains A B C VALUE OUT
    !insertmacro _HarnessListReset
    !insertmacro _HarnessListAdd `${A}`
    !insertmacro _HarnessListAdd `${B}`
    !insertmacro _HarnessListAdd `${C}`
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

!macro _HarnessListOut COUNT FIRST SECOND
    ${Option_ListCount} test b ${COUNT}
    ${Option_ListGet} test b 0 ${FIRST}
    ${Option_ListGet} test b 1 ${SECOND}
!macroend

; Persists a list of up to two items and multiline text, clobbers them and
; loads them back. The stored values are left for the test to inspect and
; delete.
!macro HarnessOptionPersistKinds A B TEXT COUNT FIRST SECOND TEXT_OUT
    !insertmacro _HarnessOptionClear ""
    !insertmacro _HarnessListReset
    !insertmacro _HarnessListAdd `${A}`
    !insertmacro _HarnessListAdd `${B}`
    ${Option_Set} test c `${TEXT}`
    ${Option_Persist}
    !insertmacro _HarnessListReset
    !insertmacro _HarnessListAdd "clobbered"
    ${Option_Set} test c "clobbered"
    ${Option_LoadPersisted}
    !insertmacro _HarnessListOut ${COUNT} ${FIRST} ${SECOND}
    ${Option_Get} test c ${TEXT_OUT}
!macroend

; Loads the values the test stored, without clearing them.
!macro HarnessOptionLoad COUNT FIRST SECOND TEXT
    !insertmacro _HarnessListReset
    ${Option_LoadPersisted}
    !insertmacro _HarnessListOut ${COUNT} ${FIRST} ${SECOND}
    ${Option_Get} test c ${TEXT}
!macroend
