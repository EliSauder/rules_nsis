!ifndef __INCLUDE_SC
!define __INCLUDE_SC

!include Logging.nsh

!macro _ServiceScExec ARGS OUT_RC
    !insertmacro LogInfo `Executing: $SYSDIR\sc.exe ${ARGS}`
    Push $0
    Push $1

    nsExec::ExecToStack `"$SYSDIR\sc.exe" ${ARGS}`
    Pop $0
    Pop $1
    !insertmacro LogDebug `Code: $0, Output: $1`
    Pop $1

    Push $0
    Exch
    Pop $0

    Pop ${OUT_RC}
!macroend

!macro Service_Create SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `create "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"` \
    ${OUT_RC}
!macroend

!macro Service_Query SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `query "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Update SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `config "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"`  \
    ${OUT_RC}
!macroend

!macro Service_Start SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `start "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Stop SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `stop "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Delete SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `delete "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_SetDescription SERVICE_NAME DESCRIPTION OUT_RC
    !insertmacro _ServiceScExec \
        `description "${SERVICE_NAME}" "${DESCRIPTION}"` ${OUT_RC}
!macroend

!endif
