!ifndef __INCLUDE_TESTING
!define __INCLUDE_TESTING

!include LogicLib.nsh

!ifdef TESTABLE_INSTALLER
Var TestId
!endif

!macro SetTestId ID
!ifdef TESTABLE_INSTALLER
    StrCpy $TestId "${ID}"
!endif
!macroend

!macro TestIdInit
!ifdef TESTABLE_INSTALLER
    Push $0
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/TESTID=" $TestId
    ClearErrors
    Pop $0
!endif
!macroend

!macro GetTestId DST
!ifdef TESTABLE_INSTALLER
    StrCpy ${DST} $TestId
!endif
!macroend

!ifdef TESTABLE_INSTALLER
!define IfTest `${If} $TestId != ""`
!define IfNotTest `${If} $TestId == ""`
!else
!define IfTest `${If} 0 <> 0`
!define IfNotTest `${If} 0 = 0`
!endif

!endif
