!ifndef __INCLUDE_ENVPATH
!define __INCLUDE_ENVPATH

!include LogicLib.nsh
!include Logging.nsh
!include ShellContext.nsh

; Adds and removes one folder of the PATH environment variable with the EnVar
; plugin. PATH is never read into an NSIS string: values longer than
; NSIS_MAX_STRLEN are silently truncated, which would corrupt PATH if it was
; written back (see https://nsis.sourceforge.io/Setting_Environment_Variables).
; EnVar edits the registry value directly, keeps it REG_EXPAND_SZ, ignores
; duplicates, matches whole entries only, and broadcasts the change.
;
; EnVar cannot take SHCTX, so its hive is set from the shell context the same
; way SetShellVarContext is: HKLM in the "admin" context, HKCU otherwise.
; The error flag is set on failure.

; Trailing backslashes are dropped so that the entry matches what other tools
; write, except for a bare drive root such as C:\.
!macro _EnvPath_Normalize VAR
    ${Do}
        StrCpy $9 ${VAR} 1 -1
        ${IfThen} "$9" != "\" ${|} ${ExitDo} ${|}
        StrLen $9 ${VAR}
        ${IfThen} $9 <= 3 ${|} ${ExitDo} ${|}
        IntOp $9 $9 - 1
        StrCpy ${VAR} ${VAR} $9
    ${Loop}
!macroend

!macro _EnvPath PREFIX
Function ${PREFIX}EnvPath_Add
    Exch $0 ; Path
    Push $1
    Push $9

    !insertmacro _EnvPath_Normalize $0
    ClearErrors
    ${IfAdmin}
        EnVar::SetHKLM
    ${Else}
        EnVar::SetHKCU
    ${EndIf}
    EnVar::AddValue "Path" "$0"
    Pop $1
    ${If} $1 = 0
        !insertmacro LogInfo "Added '$0' to PATH."
    ${Else}
        !insertmacro LogError "Failed to add '$0' to PATH (EnVar error $1)."
        SetErrors
    ${EndIf}

    Pop $9
    Pop $1
    Pop $0
FunctionEnd

Function ${PREFIX}EnvPath_Remove
    Exch $0 ; Path
    Push $1
    Push $9

    !insertmacro _EnvPath_Normalize $0
    ClearErrors
    ${IfAdmin}
        EnVar::SetHKLM
    ${Else}
        EnVar::SetHKCU
    ${EndIf}
    EnVar::DeleteValue "Path" "$0"
    Pop $1
    ; 3 and 5 mean PATH or the entry is already gone.
    ${If} $1 = 0
    ${OrIf} $1 = 3
    ${OrIf} $1 = 5
        !insertmacro LogInfo "Removed '$0' from PATH."
    ${Else}
        !insertmacro LogError "Failed to remove '$0' from PATH (EnVar error $1)."
        SetErrors
    ${EndIf}

    Pop $9
    Pop $1
    Pop $0
FunctionEnd
!macroend

!insertmacro _EnvPath ""
!insertmacro _EnvPath "un."

!macro EnvPath_Add PATH
    Push "${PATH}"
    Call EnvPath_Add
!macroend
!define EnvPath_Add `!insertmacro EnvPath_Add`

!macro un.EnvPath_Add PATH
    Push "${PATH}"
    Call un.EnvPath_Add
!macroend
!define un.EnvPath_Add `!insertmacro un.EnvPath_Add`

!macro EnvPath_Remove PATH
    Push "${PATH}"
    Call EnvPath_Remove
!macroend
!define EnvPath_Remove `!insertmacro EnvPath_Remove`

!macro un.EnvPath_Remove PATH
    Push "${PATH}"
    Call un.EnvPath_Remove
!macroend
!define un.EnvPath_Remove `!insertmacro un.EnvPath_Remove`

!endif
