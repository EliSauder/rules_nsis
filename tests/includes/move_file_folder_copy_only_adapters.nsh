!ifndef TESTABLE_INSTALLER
!error "Copy-only move fault injection is test-only"
!endif

; Reproduce the documented successful copy with failed source deletion.
!macro _MoveFileFolderRename SOURCE DESTINATION FLAGS RESULT LAST_ERROR
    System::Call 'kernel32::CopyFileW(w ${SOURCE}, w ${DESTINATION}, i 0) i.${RESULT} ?e'
    Pop ${LAST_ERROR}
!macroend

!include "MoveFileFolder.nsh"
