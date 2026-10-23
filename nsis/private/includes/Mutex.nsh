!ifndef __INCLUDE_MUTEX
!define __INCLUDE_MUTEX

!include LogicLib.nsh
!include Logging.nsh

!macro ValidateMutex NAME
    Push $R0
    Push $R1
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${NAME}Mutex") i .R1 ?e'
    Pop $R0
    ${If} $R0 != 0
        !insertmacro LogError "Another instance is already running, aborting"
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        Pop $R1
        Pop $R0
        SetErrorLevel 10
        Abort
    ${EndIf}
    Pop $R1
    Pop $R0
!macroend
!define ValidateMutex `!insertmacro ValidateMutex`

!macro un.ValidateMutex NAME
    Push $R0
    Push $R1
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${NAME}Mutex") i .R1 ?e'
    Pop $R0
    ${If} $R0 != 0
        !insertmacro LogError "Another instance of this installer is already running, aborting"
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        Pop $R1
        Pop $R0
        SetErrorLevel 10
        Abort
    ${EndIf}
    Pop $R1
    Pop $R0
!macroend
!define un.ValidateMutex `!insertmacro un.ValidateMutex`

!endif
