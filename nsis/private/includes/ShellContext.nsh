!ifndef __INCLUDE_SHELLCONTEXT
!define __INCLUDE_SHELLCONTEXT

!include LogicLib.nsh

Var __shellctx_init
Var current_context

!macro __shellctx_init
    ${If} $__shellctx_init != "y"
!ifdef IS_ADMIN_EXECUTION_LEVEL
        StrCpy $current_context "admin"
!else
        StrCpy $current_context "current"
!endif
        StrCpy $__shellctx_init "y"
    ${EndIf}
!macroend


!define IfAdmin `${If} $current_context == "admin"`
!define IfNotAdmin `${If} $current_context != "admin"`

!macro SetShellContext
    !insertmacro __shellctx_init
    ${IfAdmin}
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
!macroend

!macro UpdateShellContextToAdmin
    StrCpy $current_context "admin"
    StrCpy $__shellctx_init "y"
!macroend

!macro UpdateShellContextToCurrent
    StrCpy $current_context "current"
    StrCpy $__shellctx_init "y"
!macroend

!macro ResetShellContext
!ifdef IS_ADMIN_EXECUTION_LEVEL
    StrCpy $current_context "admin"
!else
    StrCpy $current_context "current"
!endif
    StrCpy $__shellctx_init "y"
!macroend

!endif
