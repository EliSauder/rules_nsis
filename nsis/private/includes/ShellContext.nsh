!ifndef __INCLUDE_SHELLCONTEXT
!define __INCLUDE_SHELLCONTEXT

!include LogicLib.nsh

Var current_context
!ifdef IS_ADMIN_EXECUTION_LEVEL
StrCpy $current_context "admin"
!endif
!ifndef IS_ADMIN_EXECUTION_LEVEL
StrCpy $current_context "current"
!endif

!define IfAdmin `${If} $current_context == "admin"`
!define IfNotAdmin `${If} $current_context != "admin"`

!macro SetShellContext
    ${IfAdmin}
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
!macroend

!macro UpdateShellContextToAdmin
    StrCpy $current_context "admin"
!macroend

!macro UpdateShellContextToCurrent
    StrCpy $current_context "current"
!macroend

!macro ResetShellContext
!ifdef IS_ADMIN_EXECUTION_LEVEL
    StrCpy $current_context "admin"
!else
    StrCpy $current_context "current"
!endif
!macroend

!endif
