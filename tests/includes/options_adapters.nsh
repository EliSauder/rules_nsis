Var __opt_test_a
Var __opt_test_b

!macro __Options_ForEachPersisted CALLBACK
    !insertmacro ${CALLBACK} test a
    !insertmacro ${CALLBACK} test b
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

!macro HarnessOptionListCount LIST OUT
    ${Option_Set} test a `${LIST}`
    Push `$__opt_test_a`
    Call Option_ListCount
    Pop ${OUT}
!macroend

!macro un.HarnessOptionListCount LIST OUT
    ${Option_Set} test a `${LIST}`
    Push `$__opt_test_a`
    Call un.Option_ListCount
    Pop ${OUT}
!macroend

; Split without empty items and join again, as the list canonicalisation of the
; generated option checks does.
!macro HarnessOptionListJoin LIST OUT
    ${ArraySplit} __opt_harness `${LIST}` "|" 1
    ClearErrors
    nsArray::Join __opt_harness "|"
    Pop ${OUT}
!macroend

!macro un.HarnessOptionListJoin LIST OUT
    ${un.ArraySplit} __opt_harness `${LIST}` "|" 1
    ClearErrors
    nsArray::Join __opt_harness "|"
    Pop ${OUT}
!macroend

; Long lists are generated here: the command line the harness reads its inputs
; from is capped at NSIS_MAX_STRLEN characters in total.
!macro _HarnessGenList PREFIX
; Stack: count. Pushes "i000|i001|..." with that many items.
Function ${PREFIX}HarnessGenList
    Exch $0 ; count
    Push $1
    Push $2
    Push $3

    StrCpy $1 0
    StrCpy $2 ""
    loop:
        IntCmp $1 $0 done body done
    body:
        IntFmt $3 "%03d" $1
        StrCmp $2 "" 0 +3
            StrCpy $2 "i$3"
            Goto next
        StrCpy $2 "$2|i$3"
        next:
        IntOp $1 $1 + 1
        Goto loop
    done:
    StrCpy $0 $2

    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd
!macroend
!insertmacro _HarnessGenList ""
!insertmacro _HarnessGenList "un."

!macro HarnessOptionListContainsLong COUNT VALUE OUT
    Push ${COUNT}
    Call HarnessGenList
    Pop $__opt_test_a
    ${Option_ListContains} test a `${VALUE}` ${OUT}
!macroend

!macro un.HarnessOptionListContainsLong COUNT VALUE OUT
    Push ${COUNT}
    Call un.HarnessGenList
    Pop $__opt_test_a
    ${un.Option_ListContains} test a `${VALUE}` ${OUT}
!macroend

!macro HarnessOptionListCountLong COUNT OUT
    Push ${COUNT}
    Call HarnessGenList
    Pop $__opt_test_a
    Push `$__opt_test_a`
    Call Option_ListCount
    Pop ${OUT}
!macroend

!macro un.HarnessOptionListCountLong COUNT OUT
    Push ${COUNT}
    Call un.HarnessGenList
    Pop $__opt_test_a
    Push `$__opt_test_a`
    Call un.Option_ListCount
    Pop ${OUT}
!macroend

!macro HarnessOptionListJoinLong COUNT OUT
    Push ${COUNT}
    Call HarnessGenList
    Pop $__opt_test_a
    ${ArraySplit} __opt_harness `$__opt_test_a` "|" 1
    ClearErrors
    nsArray::Join __opt_harness "|"
    Pop ${OUT}
!macroend

!macro un.HarnessOptionListJoinLong COUNT OUT
    Push ${COUNT}
    Call un.HarnessGenList
    Pop $__opt_test_a
    ${un.ArraySplit} __opt_harness `$__opt_test_a` "|" 1
    ClearErrors
    nsArray::Join __opt_harness "|"
    Pop ${OUT}
!macroend
