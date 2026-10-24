!ifndef __INCLUDE_SHORTCUT
!define __INCLUDE_SHORTCUT

!include LogicLib.nsh
!include Win\COM.nsh
!include Logging.nsh

; IShellLink::GetPath flag: return the path without expanding environment variables.
!define /ifndef SLGP_RAWPATH 0x4

; Returns the parent of a path (without its last "\" and component), or "" when
; the path has no "\".
!macro _Shortcut_ParentDir PREFIX
Function ${PREFIX}_Shortcut_ParentDir
    Exch $R0
    Push $R1
    Push $R2

    StrLen $R1 $R0
    ${While} $R1 > 0
        IntOp $R1 $R1 - 1
        StrCpy $R2 $R0 1 $R1
        ${If} $R2 == "\"
            StrCpy $R0 $R0 $R1
            ${ExitWhile}
        ${EndIf}
    ${EndWhile}
    ${If} $R1 == 0
        StrCpy $R0 ""
    ${EndIf}

    Pop $R2
    Pop $R1
    Exch $R0
FunctionEnd
!macroend

; Stack: link. Leaves the target, or "" with the error flag set.
!macro _Shortcut_GetTarget PREFIX
Function ${PREFIX}Shortcut_GetTarget
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5

    ClearErrors
    StrCpy $3 ""
    StrCpy $1 0
    StrCpy $2 0
    System::Call 'ole32::CoInitialize(p 0)i.r5'
    !insertmacro ComHlpr_CreateInProcInstance ${CLSID_ShellLink} ${IID_IShellLink} r1 .r4
    ${If} $4 >= 0
    ${AndIf} $1 P<> 0
        ${IUnknown::QueryInterface} $1 '("${IID_IPersistFile}", .r2).r4'
        ${If} $4 >= 0
        ${AndIf} $2 P<> 0
            ${IPersistFile::Load} $2 '(r0, ${STGM_READ}).r4'
            ${If} $4 >= 0
                ${IShellLink::GetPath} $1 '(.r3, ${NSIS_MAX_STRLEN}, 0, ${SLGP_RAWPATH}).r4'
            ${EndIf}
        ${EndIf}
    ${EndIf}
    !insertmacro ComHlpr_SafeRelease $2
    !insertmacro ComHlpr_SafeRelease $1
    ${If} $5 >= 0
        System::Call 'ole32::CoUninitialize()'
    ${EndIf}

    ${If} $4 < 0
    ${OrIf} $3 == ""
        StrCpy $3 ""
        SetErrors
    ${EndIf}

    StrCpy $0 $3
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd
!macroend

; Stack: link, prefix. The calling macro preserves $0-$5.
!macro _Shortcut_RemoveIfOwned PREFIX
Function ${PREFIX}Shortcut_RemoveIfOwned
    Pop $1
    Pop $0

    ClearErrors
    ${IfNot} ${FileExists} $0
        Goto done
    ${EndIf}

    StrCpy $4 $1 1 -1
    ${If} $4 == "\"
        StrCpy $1 $1 -1
    ${EndIf}

    Push $0
    Call ${PREFIX}Shortcut_GetTarget
    Pop $2
    ${If} $2 == ""
        !insertmacro LogWarn `Keeping shortcut $0: unable to read its target`
        SetErrors
        Goto done
    ${EndIf}

    StrLen $3 $1
    StrCpy $4 $2 $3
    StrCpy $5 $2 1 $3
    ${If} $4 == $1
    ${AndIf} $5 == "\"
        Delete $0
        ${If} ${FileExists} $0
            !insertmacro LogWarn `Unable to delete shortcut $0`
            SetErrors
        ${Else}
            ClearErrors
        ${EndIf}
    ${Else}
        !insertmacro LogWarn `Keeping shortcut $0: its target $2 is not under $1`
        SetErrors
    ${EndIf}
done:
FunctionEnd
!macroend

; Stack: dir, stopAt. The calling macro preserves $0-$5.
!macro _Shortcut_RemoveEmptyDirs PREFIX
Function ${PREFIX}Shortcut_RemoveEmptyDirs
    Pop $1
    Pop $0

    StrCpy $4 $0 1 -1
    ${If} $4 == "\"
        StrCpy $0 $0 -1
    ${EndIf}
    StrCpy $4 $1 1 -1
    ${If} $4 == "\"
        StrCpy $1 $1 -1
    ${EndIf}

    ; Only folders strictly below stopAt are removed.
    StrLen $2 $1
    ${Do}
        StrLen $3 $0
        ${If} $3 <= $2
            ${Break}
        ${EndIf}
        StrCpy $4 $0 $2
        StrCpy $5 $0 1 $2
        ${If} $4 != $1
        ${OrIf} $5 != "\"
            ${Break}
        ${EndIf}
        RMDir $0
        ${If} ${FileExists} "$0\*.*"
            ${Break}
        ${EndIf}
        Push $0
        Call ${PREFIX}_Shortcut_ParentDir
        Pop $0
    ${Loop}
    ClearErrors
FunctionEnd
!macroend

!insertmacro _Shortcut_ParentDir ""
!insertmacro _Shortcut_ParentDir "un."
!insertmacro _Shortcut_GetTarget ""
!insertmacro _Shortcut_GetTarget "un."
!insertmacro _Shortcut_RemoveIfOwned ""
!insertmacro _Shortcut_RemoveIfOwned "un."
!insertmacro _Shortcut_RemoveEmptyDirs ""
!insertmacro _Shortcut_RemoveEmptyDirs "un."

; Registers are saved below the arguments so that the arguments may refer to
; them.
!macro _Shortcut_Call PREFIX FUNCTION ARG1 ARG2
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push `${ARG1}`
    Push `${ARG2}`
    Call ${PREFIX}${FUNCTION}
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
!macroend

; CreateShortCut only accepts a literal icon index, so ICON_INDEX must be a
; compile-time number (or empty).
!macro _Shortcut_Create PREFIX LINK TARGET ARGS ICON ICON_INDEX DESCRIPTION
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push `${LINK}`
    Push `${TARGET}`
    Push `${ARGS}`
    Push `${ICON}`
    Push `${DESCRIPTION}`
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0

    Push $0
    Call ${PREFIX}_Shortcut_ParentDir
    Pop $5
    ${If} $5 != ""
        CreateDirectory $5
    ${EndIf}

    ; "Start in" is taken from the output path.
    Push $1
    Call ${PREFIX}_Shortcut_ParentDir
    Pop $5
    StrCpy $6 $OUTDIR
    ${If} $5 != ""
        SetOutPath $5
    ${EndIf}
    CreateShortCut $0 $1 $2 $3 ${ICON_INDEX} SW_SHOWNORMAL "" $4
    ${If} $6 != ""
        SetOutPath $6
    ${EndIf}

    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
!macroend

!macro Shortcut_Create LINK TARGET ARGS ICON ICON_INDEX DESCRIPTION
    !insertmacro _Shortcut_Create "" `${LINK}` `${TARGET}` `${ARGS}` `${ICON}` ${ICON_INDEX} `${DESCRIPTION}`
!macroend
!define Shortcut_Create `!insertmacro Shortcut_Create`

!macro un.Shortcut_Create LINK TARGET ARGS ICON ICON_INDEX DESCRIPTION
    !insertmacro _Shortcut_Create "un." `${LINK}` `${TARGET}` `${ARGS}` `${ICON}` ${ICON_INDEX} `${DESCRIPTION}`
!macroend
!define un.Shortcut_Create `!insertmacro un.Shortcut_Create`

!macro Shortcut_GetTarget LINK OUT
    Push `${LINK}`
    Call Shortcut_GetTarget
    Pop ${OUT}
!macroend
!define Shortcut_GetTarget `!insertmacro Shortcut_GetTarget`

!macro un.Shortcut_GetTarget LINK OUT
    Push `${LINK}`
    Call un.Shortcut_GetTarget
    Pop ${OUT}
!macroend
!define un.Shortcut_GetTarget `!insertmacro un.Shortcut_GetTarget`

!macro Shortcut_RemoveIfOwned LINK PREFIX
    !insertmacro _Shortcut_Call "" Shortcut_RemoveIfOwned "${LINK}" "${PREFIX}"
!macroend
!define Shortcut_RemoveIfOwned `!insertmacro Shortcut_RemoveIfOwned`

!macro un.Shortcut_RemoveIfOwned LINK PREFIX
    !insertmacro _Shortcut_Call "un." Shortcut_RemoveIfOwned "${LINK}" "${PREFIX}"
!macroend
!define un.Shortcut_RemoveIfOwned `!insertmacro un.Shortcut_RemoveIfOwned`

!macro Shortcut_RemoveEmptyDirs DIR STOP_AT
    !insertmacro _Shortcut_Call "" Shortcut_RemoveEmptyDirs "${DIR}" "${STOP_AT}"
!macroend
!define Shortcut_RemoveEmptyDirs `!insertmacro Shortcut_RemoveEmptyDirs`

!macro un.Shortcut_RemoveEmptyDirs DIR STOP_AT
    !insertmacro _Shortcut_Call "un." Shortcut_RemoveEmptyDirs "${DIR}" "${STOP_AT}"
!macroend
!define un.Shortcut_RemoveEmptyDirs `!insertmacro un.Shortcut_RemoveEmptyDirs`

!endif
