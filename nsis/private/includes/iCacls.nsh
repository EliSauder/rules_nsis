!ifndef __INCLUDE_ICACLS
!define __INCLUDE_ICACLS

!include LogicLib.nsh
!include Logging.nsh

; Runs icacls and stores its exit code in OUT_RC (0 on success). /C is not
; used: it makes icacls exit 0 even when a path could not be processed, which
; would hide failures from OUT_RC. Recursive operations therefore stop at the
; first error and report it.
!macro _iCaclsExec ARGS RECURSIVE OUT_RC
    ${If} ${RECURSIVE} > 0
        !insertmacro LogInfo `Executing: $SYSDIR\icacls.exe ${ARGS} /Q /T`
    ${Else}
        !insertmacro LogInfo `Executing: $SYSDIR\icacls.exe ${ARGS} /Q`
    ${EndIf}
    Push $0
    Push $1
    ${If} ${RECURSIVE} > 0
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /Q /T`
    ${Else}
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /Q`
    ${EndIf}
    Pop $0
    Pop $1
    ${If} $0 == "0"
        !insertmacro LogDebug `icacls succeeded. Output: $1`
    ${Else}
        !insertmacro LogError `icacls failed with code $0. Output: $1`
    ${EndIf}
    Pop $1
    Push $0
    Exch
    Pop $0
    Pop ${OUT_RC}
!macroend

!macro iCacls_Grant PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `"${PATH}" /grant "${SID}:${PERM}"` ${RECURSIVE} ${OUT_RC}
!macroend
!define iCacls_Grant `!insertmacro iCacls_Grant`

!macro iCacls_Deny PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `"${PATH}" /deny "${SID}:${PERM}"` ${RECURSIVE} ${OUT_RC}
!macroend
!define iCacls_Deny `!insertmacro iCacls_Deny`

!macro iCacls_RemoveGrant PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `"${PATH}" /remove:g "${SID}"` ${RECURSIVE} ${OUT_RC}
!macroend
!define iCacls_RemoveGrant `!insertmacro iCacls_RemoveGrant`

!macro iCacls_RemoveDeny PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `"${PATH}" /remove:d "${SID}"` ${RECURSIVE} ${OUT_RC}
!macroend
!define iCacls_RemoveDeny `!insertmacro iCacls_RemoveDeny`

!macro iCacls_IntegrityLevel PATH LVL INHERTOPTS RECURSIVE OUT_RC
    ${If} "${INHERTOPTS}" == ""
        !insertmacro _iCaclsExec `"${PATH}" /setintegritylevel ${LVL}` ${RECURSIVE} ${OUT_RC}
    ${Else}
        !insertmacro _iCaclsExec `"${PATH}" /setintegritylevel ${INHERTOPTS}${LVL}` ${RECURSIVE} ${OUT_RC}
    ${EndIf}
!macroend
!define iCacls_IntegrityLevel `!insertmacro iCacls_IntegrityLevel`

!macro iCacls_Substitute PATH SIDOLD SIDNEW RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `"${PATH}" /substitute "${SIDOLD}" "${SIDNEW}"` ${RECURSIVE} ${OUT_RC}
!macroend
!define iCacls_Substitute `!insertmacro iCacls_Substitute`

!endif
