!include "MoveFileFolder.nsh"

; Repeated expansions in one function must still compile and run.
!macro HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend

!macro _HarnessMoveFolderCleanupFailure PREFIX SOURCE REMOVED
    Push $0
    Push $R3
    Push $R6
    Push $R9
    StrCpy $R3 0
    StrCpy $R6 ""
    StrCpy $R9 "${SOURCE}"
    Call ${PREFIX}_MoveFolder_Locate_deleteDir
    Pop $0
    StrCpy ${REMOVED} "$R3"
    Pop $R9
    Pop $R6
    Pop $R3
    Pop $0
!macroend

!macro HarnessMoveFolderCleanupFailure SOURCE REMOVED
    !insertmacro _HarnessMoveFolderCleanupFailure "" "${SOURCE}" "${REMOVED}"
!macroend

!macro un.HarnessMoveFolderCleanupFailure SOURCE REMOVED
    !insertmacro _HarnessMoveFolderCleanupFailure "un." "${SOURCE}" "${REMOVED}"
!macroend

!macro _HarnessMoveFolderLockedDirectory PREFIX SOURCE DESTINATION
    Push $0
    Push $1
    System::Call 'kernel32::CreateFileW(w "${SOURCE}\empty", i 0, i 3, p 0, i 3, i 0x02000000, p 0) p.r0'
    ${If} $0 == -1
        DetailPrint "Could not lock test directory: ${SOURCE}\empty"
        SetErrors
    ${Else}
        ${${PREFIX}MoveFolder} "${SOURCE}" "${DESTINATION}" "*.*"
        StrCpy $1 0
        IfErrors 0 +2
        StrCpy $1 1
        System::Call 'kernel32::CloseHandle(p r0) i.r0'
        ${If} $0 == 0
            DetailPrint "Could not close test directory handle"
            SetErrors
        ${ElseIf} $1 == 1
            SetErrors
        ${EndIf}
    ${EndIf}
    Pop $1
    Pop $0
!macroend

!macro HarnessMoveFolderLockedDirectory SOURCE DESTINATION
    !insertmacro _HarnessMoveFolderLockedDirectory "" "${SOURCE}" "${DESTINATION}"
!macroend

!macro un.HarnessMoveFolderLockedDirectory SOURCE DESTINATION
    !insertmacro _HarnessMoveFolderLockedDirectory "un." "${SOURCE}" "${DESTINATION}"
!macroend

!macro un.HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${un.MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${un.MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend
