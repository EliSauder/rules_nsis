!ifndef __INCLUDE_MUTEX
!define __INCLUDE_MUTEX

!include LogicLib.nsh

!macro ValidateMutex NAME
    Push $R0
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${NAME}Mutex") i .r1 ?e'
    Pop $R0
    ${If} $R0 != 0
        !insertmacro LogError "Another instance is already running, aborting"
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        Abort 10
    ${EndIf}
    Pop $R0
!macroend

!endif
