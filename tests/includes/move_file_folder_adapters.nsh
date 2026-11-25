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
    System::Call 'kernel32::CreateFileW(w "${SOURCE}\empty", i 0x80000000, i 3, p 0, i 3, i 0x02000000, p 0) p.r0'
    ${If} $0 == -1
        DetailPrint "Could not lock test directory: ${SOURCE}\empty"
        SetErrorLevel 71
        SetErrors
    ${Else}
        ${${PREFIX}MoveFolder} "${SOURCE}" "${DESTINATION}" "*.*"
        StrCpy $1 0
        IfErrors 0 +2
        StrCpy $1 1
        System::Call 'kernel32::CloseHandle(p r0) i.r0'
        ${If} $0 == 0
            DetailPrint "Could not close test directory handle"
            SetErrorLevel 72
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

!macro _HarnessMoveFileLocked PREFIX SOURCE DESTINATION LOCKED
    Push $0
    Push $1
    System::Call 'kernel32::CreateFileW(w "${LOCKED}", i 0x80000000, i 1, p 0, i 3, i 0, p 0) p.r0'
    ${If} $0 == -1
        DetailPrint "Could not lock test file: ${LOCKED}"
        SetErrorLevel 71
        SetErrors
    ${Else}
        ${${PREFIX}MoveFile} "${SOURCE}" "${DESTINATION}"
        StrCpy $1 0
        IfErrors 0 +2
        StrCpy $1 1
        System::Call 'kernel32::CloseHandle(p r0) i.r0'
        ${If} $0 == 0
            DetailPrint "Could not close test file handle"
            SetErrorLevel 72
            SetErrors
        ${ElseIf} $1 == 1
            SetErrors
        ${EndIf}
    ${EndIf}
    Pop $1
    Pop $0
!macroend

!macro HarnessMoveFileLocked SOURCE DESTINATION LOCKED
    !insertmacro _HarnessMoveFileLocked "" "${SOURCE}" "${DESTINATION}" "${LOCKED}"
!macroend

!macro un.HarnessMoveFileLocked SOURCE DESTINATION LOCKED
    !insertmacro _HarnessMoveFileLocked "un." "${SOURCE}" "${DESTINATION}" "${LOCKED}"
!macroend

!macro _HarnessMoveRecovery PREFIX SOURCE DESTINATION FIRST_FAILED IS_FOLDER
    !if ${IS_FOLDER} == 1
        ${${PREFIX}MoveFolder} "${SOURCE}.missing" "${DESTINATION}" "*"
    !else
        ${${PREFIX}MoveFile} "${SOURCE}.missing" "${DESTINATION}"
    !endif
    StrCpy ${FIRST_FAILED} 0
    IfErrors 0 +2
    StrCpy ${FIRST_FAILED} 1
    SetErrors
    !if ${IS_FOLDER} == 1
        ${${PREFIX}MoveFolder} "${SOURCE}" "${DESTINATION}" "*"
    !else
        ${${PREFIX}MoveFile} "${SOURCE}" "${DESTINATION}"
    !endif
!macroend

!macro HarnessMoveFileRecovery SOURCE DESTINATION FIRST_FAILED
    !insertmacro _HarnessMoveRecovery "" "${SOURCE}" "${DESTINATION}" "${FIRST_FAILED}" 0
!macroend

!macro un.HarnessMoveFileRecovery SOURCE DESTINATION FIRST_FAILED
    !insertmacro _HarnessMoveRecovery "un." "${SOURCE}" "${DESTINATION}" "${FIRST_FAILED}" 0
!macroend

!macro HarnessMoveFolderRecovery SOURCE DESTINATION FIRST_FAILED
    !insertmacro _HarnessMoveRecovery "" "${SOURCE}" "${DESTINATION}" "${FIRST_FAILED}" 1
!macroend

!macro un.HarnessMoveFolderRecovery SOURCE DESTINATION FIRST_FAILED
    !insertmacro _HarnessMoveRecovery "un." "${SOURCE}" "${DESTINATION}" "${FIRST_FAILED}" 1
!macroend

!macro un.HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${un.MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${un.MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend
