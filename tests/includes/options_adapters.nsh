Var __opt_test_a
Var __opt_test_b

!macro __Options_ForEachPersisted CALLBACK
    !insertmacro ${CALLBACK} test a
    !insertmacro ${CALLBACK} test b
!macroend

!include "Options.nsh"


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
    ${RemoveRegistryKey} "${REG_KEY}\Options"
    ${Option_Set} test a `${VALUE}`
    ${Option_Set} test b "default"
    ${Option_Persist}
    ${Option_Set} test a "clobbered"
    ${Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
    ${RemoveRegistryKey} "${REG_KEY}\Options"
!macroend

; With nothing stored, loading keeps the defaults.
!macro HarnessOptionLoadMissing DEFAULT OUT
    ${RemoveRegistryKey} "${REG_KEY}\Options"
    ${Option_Set} test a `${DEFAULT}`
    ${Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
!macroend

!macro un.HarnessOptionLoadMissing DEFAULT OUT
    ${un.RemoveRegistryKey} "${REG_KEY}\Options"
    ${Option_Set} test a `${DEFAULT}`
    ${un.Option_LoadPersisted}
    ${Option_Get} test a ${OUT}
!macroend
