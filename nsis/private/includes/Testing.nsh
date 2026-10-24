!ifndef __INCLUDE_TESTING
!define __INCLUDE_TESTING

!include LogicLib.nsh
!include Cli.nsh

!ifdef TESTABLE_INSTALLER
Var TestId
!endif

!macro SetTestId ID
!ifdef TESTABLE_INSTALLER
    StrCpy $TestId "${ID}"
!endif
!macroend
!define SetTestId `!insertmacro SetTestId`

!macro TestIdInit
!ifdef TESTABLE_INSTALLER
    !ifdef __UNINSTALL__
        ${un.Cli_GetArgValue} "/TESTID" $TestId
    !else
        ${Cli_GetArgValue} "/TESTID" $TestId
    !endif
    ClearErrors
!endif
!macroend
!define TestIdInit `!insertmacro TestIdInit`

!macro GetTestId DST
!ifdef TESTABLE_INSTALLER
    StrCpy ${DST} $TestId
!endif
!macroend
!define GetTestId `!insertmacro GetTestId`

!ifdef TESTABLE_INSTALLER
!define IfTest `${If} $TestId != ""`
!define IfNotTest `${If} $TestId == ""`
!else
!define IfTest `${If} 0 <> 0`
!define IfNotTest `${If} 0 = 0`
!endif

!endif
