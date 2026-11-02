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

!macro HarnessOptionListContains LIST VALUE OUT
    ${Option_Set} test a `${LIST}`
    ${Option_ListContains} test a `${VALUE}` ${OUT}
!macroend

!macro un.HarnessOptionListContains LIST VALUE OUT
    ${Option_Set} test a `${LIST}`
    ${un.Option_ListContains} test a `${VALUE}` ${OUT}
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

; Persists a list and multiline text, clobbers them and loads them back. The
; stored values are left for the test to inspect and delete.
!macro HarnessOptionPersistKinds LIST TEXT LIST_OUT TEXT_OUT
    !insertmacro _HarnessOptionClear ""
    ${Option_Set} test b `${LIST}`
    ${Option_Set} test c `${TEXT}`
    ${Option_Persist}
    ${Option_Set} test b "clobbered"
    ${Option_Set} test c "clobbered"
    ${Option_LoadPersisted}
    ${Option_Get} test b ${LIST_OUT}
    ${Option_Get} test c ${TEXT_OUT}
!macroend

; Loads the values the test stored, without clearing them.
!macro HarnessOptionLoad LIST TEXT
    ${Option_LoadPersisted}
    ${Option_Get} test b ${LIST}
    ${Option_Get} test c ${TEXT}
!macroend
