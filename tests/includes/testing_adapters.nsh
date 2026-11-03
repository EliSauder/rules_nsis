!include "Testing.nsh"

; TestIdInit reads /TESTID= from the command line, which the harness always
; passes (run(test_id=...) overrides it). The generated .onInit already ran it
; once; this runs it again explicitly.
!macro HarnessTestIdInit OUT
    ${TestIdInit}
    ${GetTestId} ${OUT}
!macroend
