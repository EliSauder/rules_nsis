!ifndef __INCLUDE_SC
!define __INCLUDE_SC

!include Logging.nsh

; OUT_TEXT receives the command output. Pass OUT_RC again as OUT_TEXT to discard it.
!macro _ServiceScExec ARGS OUT_RC OUT_TEXT
    !insertmacro LogInfo `Executing: $SYSDIR\sc.exe ${ARGS}`
    Push $0
    Push $1

    nsExec::ExecToStack `"$SYSDIR\sc.exe" ${ARGS}`
    Pop $0
    Pop $1
    !insertmacro LogDebug `Code: $0, Output: $1`

    Push $1
    Push $0
    Exch 3
    Pop $0
    Exch
    Pop $1
    ; OUT_RC is popped last so it wins when it is also passed as OUT_TEXT
    Pop ${OUT_TEXT}
    Pop ${OUT_RC}
!macroend

!macro Service_Create SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `create "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"` \
    ${OUT_RC} ${OUT_RC}
!macroend
!define Service_Create `!insertmacro Service_Create`

; OUT_STATE is the numeric STATE code from the sc output (1 = STOPPED, 4 = RUNNING, ...),
; or empty when it could not be read. The code is numeric so localization does not matter.
!macro Service_Query SERVICE_NAME OUT_RC OUT_STATE
    Push $0
    Push $1
    Push $2
    Push $3

    !insertmacro _ServiceScExec `query "${SERVICE_NAME}"` $0 $3

    StrCpy $2 ""
    ${If} $0 = 0
        StrCpy $1 0
        ${Do}
            StrCpy $2 $3 6 $1
            ${If} $2 == ""
                ${Break}
            ${EndIf}
            ${If} $2 S== "STATE "
                IntOp $1 $1 + 6
                ${Do}
                    StrCpy $2 $3 1 $1
                    ${If} $2 == ""
                    ${OrIf} $2 == ":"
                        ${Break}
                    ${EndIf}
                    IntOp $1 $1 + 1
                ${Loop}
                IntOp $1 $1 + 1
                ${Do}
                    StrCpy $2 $3 1 $1
                    ${If} $2 != " "
                        ${Break}
                    ${EndIf}
                    IntOp $1 $1 + 1
                ${Loop}
                ${Break}
            ${EndIf}
            IntOp $1 $1 + 1
        ${Loop}
    ${EndIf}

    Push $0
    Push $2
    Exch 5
    Pop $0
    Exch
    Pop $3
    Exch
    Pop $2
    Exch
    Pop $1
    Pop ${OUT_RC}
    Pop ${OUT_STATE}
!macroend
!define Service_Query `!insertmacro Service_Query`

!macro Service_Update SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `config "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"`  \
    ${OUT_RC} ${OUT_RC}
!macroend
!define Service_Update `!insertmacro Service_Update`

!macro Service_Start SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `start "${SERVICE_NAME}"` \
    ${OUT_RC} ${OUT_RC}
!macroend
!define Service_Start `!insertmacro Service_Start`

!macro Service_Stop SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `stop "${SERVICE_NAME}"` \
    ${OUT_RC} ${OUT_RC}
!macroend
!define Service_Stop `!insertmacro Service_Stop`

; Stops the service and polls until it reports STOPPED or TIMEOUT_MS elapses.
; OUT_RC is 0 when stopped (or not installed / not running), the sc exit code if the
; stop request failed, 1 on timeout.
!macro Service_StopAndWait SERVICE_NAME TIMEOUT_MS OUT_RC
    Push $0
    Push $1
    Push $2
    Push $3

    !insertmacro Service_Stop "${SERVICE_NAME}" $0
    ; 1060: service does not exist, 1062: service not started,
    ; 1061: service cannot accept control messages (e.g. a stop is already pending)
    ${If} $0 = 1060
    ${OrIf} $0 = 1062
        StrCpy $3 0
    ${ElseIf} $0 = 0
    ${OrIf} $0 = 1061
        StrCpy $1 0
        StrCpy $3 1
        ${Do}
            !insertmacro Service_Query "${SERVICE_NAME}" $0 $2
            ${If} $2 == 1
            ${OrIf} $0 = 1060
                StrCpy $3 0
                ${Break}
            ${EndIf}
            ${If} $1 >= ${TIMEOUT_MS}
                ${Break}
            ${EndIf}
            Sleep 250
            IntOp $1 $1 + 250
        ${Loop}
    ${Else}
        StrCpy $3 $0
    ${EndIf}
    ${If} $3 = 0
        !insertmacro LogInfo `Service ${SERVICE_NAME} stopped`
    ${ElseIf} $3 = 1
        !insertmacro LogInfo `Timed out waiting for service ${SERVICE_NAME} to stop`
    ${Else}
        !insertmacro LogInfo `Failed to stop service ${SERVICE_NAME}: $3`
    ${EndIf}

    Push $3
    Exch 4
    Pop $0
    Pop $3
    Pop $2
    Pop $1
    Pop ${OUT_RC}
!macroend
!define Service_StopAndWait `!insertmacro Service_StopAndWait`

; Starts the service and polls until it reports RUNNING or TIMEOUT_MS elapses.
; OUT_RC is 0 when running, the sc exit code if the start request failed, 1 on timeout.
!macro Service_StartAndWait SERVICE_NAME TIMEOUT_MS OUT_RC
    Push $0
    Push $1
    Push $2
    Push $3

    !insertmacro Service_Start "${SERVICE_NAME}" $0
    ; 1056: service already running
    ${If} $0 = 0
    ${OrIf} $0 = 1056
        StrCpy $1 0
        StrCpy $3 1
        ${Do}
            !insertmacro Service_Query "${SERVICE_NAME}" $0 $2
            ${If} $2 == 4
                StrCpy $3 0
                ${Break}
            ${EndIf}
            ${If} $1 >= ${TIMEOUT_MS}
                ${Break}
            ${EndIf}
            Sleep 250
            IntOp $1 $1 + 250
        ${Loop}
        ${If} $3 = 0
            !insertmacro LogInfo `Service ${SERVICE_NAME} running`
        ${Else}
            !insertmacro LogInfo `Timed out waiting for service ${SERVICE_NAME} to start`
        ${EndIf}
    ${Else}
        StrCpy $3 $0
        !insertmacro LogInfo `Failed to start service ${SERVICE_NAME}: $3`
    ${EndIf}

    Push $3
    Exch 4
    Pop $0
    Pop $3
    Pop $2
    Pop $1
    Pop ${OUT_RC}
!macroend
!define Service_StartAndWait `!insertmacro Service_StartAndWait`

!macro Service_Delete SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `delete "${SERVICE_NAME}"` \
    ${OUT_RC} ${OUT_RC}
!macroend
!define Service_Delete `!insertmacro Service_Delete`

; Deletes the service and polls until it no longer exists or TIMEOUT_MS elapses.
; sc delete only marks a service for deletion; it is removed once it is stopped and
; all handles to it are closed. OUT_RC is 0 when removed (or not installed), the sc
; exit code if the delete request failed, 1 on timeout.
!macro Service_DeleteAndWait SERVICE_NAME TIMEOUT_MS OUT_RC
    Push $0
    Push $1
    Push $2
    Push $3

    !insertmacro Service_Delete "${SERVICE_NAME}" $0
    ; 1060: service does not exist, 1072: service already marked for deletion
    ${If} $0 = 1060
        StrCpy $3 0
    ${ElseIf} $0 = 0
    ${OrIf} $0 = 1072
        StrCpy $1 0
        StrCpy $3 1
        ${Do}
            !insertmacro Service_Query "${SERVICE_NAME}" $0 $2
            ${If} $0 = 1060
                StrCpy $3 0
                ${Break}
            ${EndIf}
            ${If} $1 >= ${TIMEOUT_MS}
                ${Break}
            ${EndIf}
            Sleep 250
            IntOp $1 $1 + 250
        ${Loop}
    ${Else}
        StrCpy $3 $0
    ${EndIf}
    ${If} $3 = 0
        !insertmacro LogInfo `Service ${SERVICE_NAME} deleted`
    ${ElseIf} $3 = 1
        !insertmacro LogInfo `Timed out waiting for service ${SERVICE_NAME} to be deleted`
    ${Else}
        !insertmacro LogInfo `Failed to delete service ${SERVICE_NAME}: $3`
    ${EndIf}

    Push $3
    Exch 4
    Pop $0
    Pop $3
    Pop $2
    Pop $1
    Pop ${OUT_RC}
!macroend
!define Service_DeleteAndWait `!insertmacro Service_DeleteAndWait`

!macro Service_SetDescription SERVICE_NAME DESCRIPTION OUT_RC
    !insertmacro _ServiceScExec \
        `description "${SERVICE_NAME}" "${DESCRIPTION}"` ${OUT_RC} ${OUT_RC}
!macroend
!define Service_SetDescription `!insertmacro Service_SetDescription`

!endif
