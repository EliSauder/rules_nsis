!ifndef __INCLUDE_CONSOLE
!define __INCLUDE_CONSOLE

!include LogicLib.nsh

; Standard output support for the installer and the uninstaller. The macros
; are expanded inline, so the same names work in both.

; Resolves stdout once and caches it in $__console_handle, which stays empty
; when there is none.
!macro Console_Init
    ; Declared on first use so that builds that never write to the console do
    ; not warn about unused variables.
    !ifndef __CONSOLE_VARS
        !define __CONSOLE_VARS
        Var /GLOBAL __console_handle
        Var /GLOBAL __console_attempted
    !endif
    ; Raw jumps, as LogicLib blocks cannot be opened inside a condition.
    !define _ci_id ${__COUNTER__}
    StrCmp $__console_attempted "" 0 _console_done_${_ci_id}
    StrCpy $__console_attempted "Y"
    Push $0
    Push $1
    ; Prefer an inherited (redirected) stdout; otherwise attach to the
    ; parent's console.
    System::Call 'kernel32::GetStdHandle(i -11)p.r0'
    IntPtrCmp $0 0 _console_attach_${_ci_id}
    IntPtrCmp $0 -1 _console_attach_${_ci_id}
    StrCpy $__console_handle $0
    Goto _console_pop_${_ci_id}
    _console_attach_${_ci_id}:
    System::Call 'kernel32::AttachConsole(i -1)i.r1'
    StrCmp $1 0 _console_pop_${_ci_id}
    System::Call 'kernel32::GetStdHandle(i -11)p.r0'
    StrCpy $__console_handle $0
    _console_pop_${_ci_id}:
    Pop $1
    Pop $0
    _console_done_${_ci_id}:
    !undef _ci_id
!macroend
!define Console_Init `!insertmacro Console_Init`

!macro Console_Write TEXT
    !insertmacro Console_Init
    ${If} $__console_handle != ""
        FileWrite $__console_handle `${TEXT}`
    ${EndIf}
!macroend
!define Console_Write `!insertmacro Console_Write`

!macro Console_WriteLine TEXT
    !insertmacro Console_Write `${TEXT}$\r$\n`
!macroend
!define Console_WriteLine `!insertmacro Console_WriteLine`

!macro _Console_IsAvailable _a _b _t _f
    !insertmacro Console_Init
    StrCmp $__console_handle "" `${_f}` `${_t}`
!macroend
!define Console_IsAvailable `"" Console_IsAvailable ""`

!endif
