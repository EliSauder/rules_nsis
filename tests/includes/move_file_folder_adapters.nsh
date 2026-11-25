!include "MoveFileFolder.nsh"

!macro _HarnessMoveFolderLimits PREFIX SOURCE PARENT LEAF
    Push $0
    StrCpy $0 "${PARENT}\${LEAF}"
    ${${PREFIX}MoveFolder} "${SOURCE}" "$0" "*"
    Pop $0
!macroend

!macro HarnessMoveFolderLimits SOURCE PARENT LEAF
    !insertmacro _HarnessMoveFolderLimits "" "${SOURCE}" "${PARENT}" "${LEAF}"
!macroend

!macro un.HarnessMoveFolderLimits SOURCE PARENT LEAF
    !insertmacro _HarnessMoveFolderLimits "un." "${SOURCE}" "${PARENT}" "${LEAF}"
!macroend

!macro _HarnessMoveFolderDriveRoot PREFIX SOURCE DESTINATION WORKING
    Push $0
    Push $1
    Push $2
    System::Call 'kernel32::GetCurrentDirectoryW(i ${NSIS_MAX_STRLEN}, w .r0) i.r1'
    ${If} $1 == 0
        SetErrorLevel 71
        SetErrors
    ${Else}
        System::Call 'kernel32::SetCurrentDirectoryW(w "${WORKING}") i.r1'
        ${If} $1 == 0
            SetErrorLevel 71
            SetErrors
        ${Else}
            ${${PREFIX}MoveFolder} "${SOURCE}" "${DESTINATION}" "*"
            StrCpy $2 0
            IfErrors 0 +2
            StrCpy $2 1
            System::Call 'kernel32::SetCurrentDirectoryW(w r0) i.r1'
            ${If} $1 == 0
                SetErrorLevel 72
                SetErrors
            ${ElseIf} $2 == 1
                SetErrors
            ${Else}
                ClearErrors
            ${EndIf}
        ${EndIf}
    ${EndIf}
    Pop $2
    Pop $1
    Pop $0
!macroend

!macro HarnessMoveFolderDriveRoot SOURCE DESTINATION WORKING
    !insertmacro _HarnessMoveFolderDriveRoot "" "${SOURCE}" "${DESTINATION}" "${WORKING}"
!macroend

!macro un.HarnessMoveFolderDriveRoot SOURCE DESTINATION WORKING
    !insertmacro _HarnessMoveFolderDriveRoot "un." "${SOURCE}" "${DESTINATION}" "${WORKING}"
!macroend

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

!macro _HarnessMoveFileLocked PREFIX SOURCE DESTINATION LOCKED IS_FOLDER
    Push $0
    Push $1
    System::Call 'kernel32::CreateFileW(w "${LOCKED}", i 0x80000000, i 1, p 0, i 3, i 0, p 0) p.r0'
    ${If} $0 == -1
        DetailPrint "Could not lock test file: ${LOCKED}"
        SetErrorLevel 71
        SetErrors
    ${Else}
        !if ${IS_FOLDER} == 1
            ${${PREFIX}MoveFolder} "${SOURCE}" "${DESTINATION}" "*"
        !else
            ${${PREFIX}MoveFile} "${SOURCE}" "${DESTINATION}"
        !endif
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
    !insertmacro _HarnessMoveFileLocked "" "${SOURCE}" "${DESTINATION}" "${LOCKED}" 0
!macroend

!macro un.HarnessMoveFileLocked SOURCE DESTINATION LOCKED
    !insertmacro _HarnessMoveFileLocked "un." "${SOURCE}" "${DESTINATION}" "${LOCKED}" 0
!macroend

!macro HarnessMoveFolderLocked SOURCE DESTINATION LOCKED
    !insertmacro _HarnessMoveFileLocked "" "${SOURCE}" "${DESTINATION}" "${LOCKED}" 1
!macroend

!macro un.HarnessMoveFolderLocked SOURCE DESTINATION LOCKED
    !insertmacro _HarnessMoveFileLocked "un." "${SOURCE}" "${DESTINATION}" "${LOCKED}" 1
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

!macro HarnessBackupTwice FIRST_SOURCE SECOND_SOURCE
    ${BackupFile} "${FIRST_SOURCE}"
    ${BackupFolder} "${SECOND_SOURCE}"
!macroend

!macro un.HarnessBackupTwice FIRST_SOURCE SECOND_SOURCE
    ${un.BackupFile} "${FIRST_SOURCE}"
    ${un.BackupFolder} "${SECOND_SOURCE}"
!macroend

!macro un.HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${un.MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${un.MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend
