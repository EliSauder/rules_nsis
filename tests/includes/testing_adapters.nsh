!include "Testing.nsh"

; TestIdInit reads /TESTID= from the command line, where the harness already
; passes the testid input (GetOptions is case-insensitive), so the macro
; argument itself is unused.
!macro HarnessTestIdInit TESTID OUT
    ${TestIdInit}
    ${GetTestId} ${OUT}
!macroend
