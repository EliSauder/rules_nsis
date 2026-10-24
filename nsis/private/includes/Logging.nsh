!ifndef __INCLUDE_LOGGING
!define __INCLUDE_LOGGING

!include LogicLib.nsh
!include Console.nsh

; Logging is opt-in: define LOGGING_ENABLE before including this file.
; The level is selected with one of LOGLEVEL_DEBUG, LOGLEVEL_INFO,
; LOGLEVEL_WARN or LOGLEVEL_ERR (most verbose wins, defaults to INFO).
; ${Log} always writes when logging is enabled, regardless of level.

!ifdef LOGLEVEL_DEBUG
    !define _LOGLEVEL 0
!else ifdef LOGLEVEL_INFO
    !define _LOGLEVEL 1
!else ifdef LOGLEVEL_WARN
    !define _LOGLEVEL 2
!else ifdef LOGLEVEL_ERR
    !define _LOGLEVEL 3
!else
    !define _LOGLEVEL 1
!endif

!macro Log TEXT
!ifdef LOGGING_ENABLE
    ${IfNot} ${Silent}
        DetailPrint `${TEXT}`
    ${EndIf}
    ${Console_WriteLine} `${TEXT}`
!endif
!macroend
!define Log `!insertmacro Log`

!macro LogDebug TEXT
!if ${_LOGLEVEL} <= 0
    !insertmacro Log `DEBUG: ${TEXT}`
!endif
!macroend
!define LogDebug `!insertmacro LogDebug`

!macro LogInfo TEXT
!if ${_LOGLEVEL} <= 1
    !insertmacro Log `INFO: ${TEXT}`
!endif
!macroend
!define LogInfo `!insertmacro LogInfo`

!macro LogWarn TEXT
!if ${_LOGLEVEL} <= 2
    !insertmacro Log `WARN: ${TEXT}`
!endif
!macroend
!define LogWarn `!insertmacro LogWarn`

!macro LogError TEXT
!if ${_LOGLEVEL} <= 3
    !insertmacro Log `ERROR: ${TEXT}`
!endif
!macroend
!define LogError `!insertmacro LogError`

!endif
