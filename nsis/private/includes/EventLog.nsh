!ifndef __INCLUDE_EVENTLOG
!define __INCLUDE_EVENTLOG

!include Registry.nsh
!include LogicLib.nsh

!define _ROOT_EVENTLOG_KEY "SYSTEM\CurrentControlSet\Services\EventLog"
!define _DEFAULT_EVENTMESSAGEFILE "%SystemRoot%\System32\EventCreate.exe"

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

    ${If} "$2" == ""
        StrCpy $2 "0"
    ${EndIf}
    ${If} "$3" == ""
        StrCpy $3 "${_DEFAULT_EVENTMESSAGEFILE}"
    ${EndIf}

    !insertmacro SetRegistrySubKey "$0" "TypesSupported" "$2"
    !insertmacro SetRegistrySubKey "$0" "EventMessageFile" "$3"

    ${If} "$4" != ""
        !insertmacro SetRegistrySubKey "$0" "CategoryMessageFile" "$4"
    ${EndIf}

    ${If} "$5" != ""
        !insertmacro SetRegistrySubKey "$0" "ParameterMessageFile" "$5"
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

!macro un.EventLog_AddSource KEY SOURCE TYPESUPPORT EMF CMF PMF
    Push "${PMF}"
    Push "${CMF}"
    Push "${EMF}"
    Push "${TYPESUPPORT}"
    Push "${SOURCE}"
    Push "${KEY}"
    Call un.EventLog_AddSource
!macroend

!macro EventLog_RemoveSource KEY SOURCE
    !insertmacro RemoveRegistryKey "${_ROOT_EVENTLOG_KEY}\${KEY}\${SOURCE}"
!macroend

!macro un.EventLog_RemoveSource KEY SOURCE
    !insertmacro un.RemoveRegistryKey "${_ROOT_EVENTLOG_KEY}\${KEY}\${SOURCE}"
!macroend
!endif
