!ifndef __INCLUDE_ICACLS
!define __INCLUDE_ICACLS

!include LogicLib.nsh
!include Logging.nsh

!macro _iCaclsExec ARGS RECURSIVE OUT_RC
    ${If} RECURSIVE > 0
        !insertmacro LogInfo `Executing: $SYSDIR\icacls.exe ${ARGS} /C /Q /T`
    ${Else}
        !insertmacro LogInfo `Executing: $SYSDIR\icacls.exe ${ARGS} /C /Q`
    ${EndIf}
    Push $0
    Push $1
    ${If} RECURSIVE > 0
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /C /Q /T`
    ${Else}
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /C /Q`
    ${EndIf}
    Pop $0
    Pop $1
    !insertmacro LogDebug `Code: $0, Output: $1`
    Pop $1
    Push $0
    Exch
    Pop $0
    Pop ${OUT_RC}
!macroend

!macro iCacls_Grant PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /grant ${SID}:${PERM}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_Deny PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /deny ${SID}:${PERM}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_RemoveGrant PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /remove:g ${SID}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_RemoveDeny PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /remove:d ${SID}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_IntegrityLevel PATH LVL INHERTOPTS RECURSIVE
    ${IF} INHERTOPTS == ""
        !insertmacro _iCaclsExec `${PATH} /setintegritylevel ${LVL}` ${RECURSIVE} ${OUT_RC}
    ${Else}
        !insertmacro _iCaclsExec `${PATH} /setintegritylevel ${INHERTOPTS}${LVL}` ${RECURSIVE} ${OUT_RC}
    ${EndIf}
!macroend

!macro iCacls_Substitute PATH SIDOLD SIDNEW RECURSIVE
    !insertmacro _iCaclsExec`${PATH} /substitute ${SIDOLD} ${SIDNEW}` ${RECURSIVE} ${OUT_RC}
!macroend

!endif
