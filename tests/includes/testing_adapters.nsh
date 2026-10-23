!include "Testing.nsh"

!macro HarnessSetTestId ID RESULT
    ${SetTestId} "${ID}"
    ${GetTestId} ${RESULT}
!macroend
