!include "MoveFileFolder.nsh"

; MoveFile derives its labels from the call site, so repeated expansions in one
; function (including through a wrapper macro) must still compile and run.
!macro HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend

!macro un.HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${un.MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${un.MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend
