!ifndef __INCLUDE_LOGGING
!define __INCLUDE_LOGGING

!include LogicLib.nsh

!ifdef ENABLE_LOGGING
Var StdOutHandle
Var StdOutAttempted
Var LogLevel
!endif

!ifdef LOGLEVEL_DEBUG
!undef LOGLEVEL_WARN
!undef LOGLEVEL_INFO
!undef LOGLEVEL_ERR
!endif

!ifdef LOGLEVEL_INFO
!undef LOGLEVEL_WARN
!undef LOGLEVEL_ERR
!undef LOGLEVEL_DEBUG
!endif

!ifdef LOGLEVEL_WARN
!undef LOGLEVEL_INFO
!undef LOGLEVEL_ERR
!undef LOGLEVEL_DEBUG
!endif

!ifdef LOGLEVEL_ERR
!undef LOGLEVEL_INFO
!undef LOGLEVEL_WARN
!undef LOGLEVEL_DEBUG
!endif

!macro LogDebug TEXT
!ifdef LOGLEVEL_DEBUG
    !insertmacro Log `DEBUG: ${TEXT}`
!endif
!macroend

!macro LogInfo TEXT
!ifdef LOGLEVEL_DEBUG
    !insertmacro Log `INFO: ${TEXT}`
!endif
!ifdef LOGLEVEL_INFO
    !insertmacro Log `INFO: ${TEXT}`
!endif
!macroend

!macro LogWarn TEXT
!ifdef LOGLEVEL_DEBUG
    !insertmacro Log `WARN: ${TEXT}`
!endif
!ifdef LOGLEVEL_INFO
    !insertmacro Log `WARN: ${TEXT}`
!endif
!ifdef LOGLEVEL_WARN
    !insertmacro Log `WARN: ${TEXT}`
!endif
!macroend

!macro LogError TEXT
!ifdef LOGLEVEL_DEBUG
    !insertmacro Log `ERROR: ${TEXT}`
!endif
!ifdef LOGLEVEL_INFO
    !insertmacro Log `ERROR: ${TEXT}`
!endif
!ifdef LOGLEVEL_WARN
    !insertmacro Log `ERROR: ${TEXT}`
!endif
!ifdef LOGLEVEL_ERR
    !insertmacro Log `ERROR: ${TEXT}`
!endif
!macroend

!macro Log TEXT
!ifdef LOGGING_ENABLE
    ${IfNot} ${Silent}
        DetailPrint `${TEXT}`
    ${EndIf}
    ${If} $StdOutHandle == ""
    ${AndIf} $StdOutAttempted == ""
        StrCpy $StdOutAttempted "Y"
        Push $0
        Push $1
        System::Call 'kernel32::AttachConsole(i -1)i.r1'
        ${If} $1 != 0
            System::Call 'kernel32::GetStdHandle(i -11)i.r0'
            StrCpy $StdOutHandle $0
        ${EndIf}
        Pop $1
        Pop $0
    ${EndIf}

    ${If} $StdOutHandle != ""
        FileWrite $StdOutHandle `${TEXT}$\r$\n`
    ${EndIf}
!endif
!macroend
