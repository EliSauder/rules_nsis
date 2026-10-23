!ifndef __INCLUDE_EVENTLOG
!define __INCLUDE_EVENTLOG

!include Registry.nsh
!include LogicLib.nsh

!define _ROOT_EVENTLOG_KEY "SYSTEM\CurrentControlSet\Services\EventLog"
!define _DEFAULT_EVENTMESSAGEFILE "%SystemRoot%\System32\EventCreate.exe"

; Event sources are always registered under HKLM, the only hive the Event Log
; service reads, regardless of the shell context; this requires administrator
; rights. Message file paths are written as REG_EXPAND_SZ so values such as
; %SystemRoot% are expanded. Under a testable installer the test id is appended
; to the source key, as for the other registry helpers. The error flag is set
; when the source could not be registered.
!macro _EventLog_AddSource PREFIX
Function ${PREFIX}EventLog_AddSource
    Exch $0 ; Key
    Exch 1
    Exch $1 ; Source
    Exch 2
    Exch $2 ; TypeSupport
    Exch 3
    Exch $3 ; EMF
    Exch 4
    Exch $4 ; CMF
    Exch 5
    Exch $5 ; PMF

    StrCpy $0 "${_ROOT_EVENTLOG_KEY}\$0\$1" ; eventlog reg key
    !insertmacro _ApplyRegTestId $0 $1

    ${If} "$2" == ""
        StrCpy $2 "0"
    ${EndIf}
    ${If} "$3" == ""
        StrCpy $3 "${_DEFAULT_EVENTMESSAGEFILE}"
    ${EndIf}

    ClearErrors
    WriteRegDWORD HKLM "$0" "TypesSupported" $2
    WriteRegExpandStr HKLM "$0" "EventMessageFile" "$3"

    ${If} "$4" != ""
        WriteRegExpandStr HKLM "$0" "CategoryMessageFile" "$4"
    ${EndIf}

    ${If} "$5" != ""
        WriteRegExpandStr HKLM "$0" "ParameterMessageFile" "$5"
    ${EndIf}

    ${If} ${Errors}
        !insertmacro LogError "Failed to register event source 'HKLM\$0' (administrator rights are required)."
        SetErrors
    ${Else}
        !insertmacro LogInfo "Registered event source 'HKLM\$0'."
    ${EndIf}

    Pop $5
    Pop $0
    Pop $1
    Pop $2
    Pop $3
    Pop $4
FunctionEnd
!macroend

!insertmacro _EventLog_AddSource ""
!insertmacro _EventLog_AddSource "un."

!macro EventLog_AddSource KEY SOURCE TYPESUPPORT EMF CMF PMF
    Push "${PMF}"
    Push "${CMF}"
    Push "${EMF}"
    Push "${TYPESUPPORT}"
    Push "${SOURCE}"
    Push "${KEY}"
    Call EventLog_AddSource
!macroend
!define EventLog_AddSource `!insertmacro EventLog_AddSource`

!macro un.EventLog_AddSource KEY SOURCE TYPESUPPORT EMF CMF PMF
    Push "${PMF}"
    Push "${CMF}"
    Push "${EMF}"
    Push "${TYPESUPPORT}"
    Push "${SOURCE}"
    Push "${KEY}"
    Call un.EventLog_AddSource
!macroend
!define un.EventLog_AddSource `!insertmacro un.EventLog_AddSource`

!macro _EventLog_RemoveSource KEY SOURCE
    Push $0
    StrCpy $0 "${_ROOT_EVENTLOG_KEY}\${KEY}\${SOURCE}"
    !insertmacro _ApplyRegTestId $0 $1
    !insertmacro LogInfo "Removing event source 'HKLM\$0'"
    DeleteRegKey HKLM "$0"
    Pop $0
!macroend

!macro EventLog_RemoveSource KEY SOURCE
    !insertmacro _EventLog_RemoveSource "${KEY}" "${SOURCE}"
!macroend
!define EventLog_RemoveSource `!insertmacro EventLog_RemoveSource`

!macro un.EventLog_RemoveSource KEY SOURCE
    !insertmacro _EventLog_RemoveSource "${KEY}" "${SOURCE}"
!macroend
!define un.EventLog_RemoveSource `!insertmacro un.EventLog_RemoveSource`
!endif
