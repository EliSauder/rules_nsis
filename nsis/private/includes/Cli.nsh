!ifndef __INCLUDE_CLI
!define __INCLUDE_CLI

!include LogicLib.nsh
!include FileFunc.nsh
!include Console.nsh
!include Formatting.nsh
!include Logging.nsh

; Command line support for the installer and the uninstaller.
;
; The command line is split into args, like argc/argv: whitespace separates
; args outside double quotes, and quotes are removed wherever they appear, so
; /name="a b" and "/name=a b" are both the arg /name=a b. Everything from a
; /D= arg onwards is one literal arg, matching NSIS. Names are matched
; case-insensitively, and a switch is either bare (/X) or carries a value
; (/X=value).
;
; Args are stored LF-separated in $__cli_args and counted in $__cli_argc. Every
; macro parses the command line on first use, so ${Cli_Init} is optional.
; Each macro except ${Cli_Fail} has an "un." variant. The macros that return a
; value set the error flag and return "" when there is none, and clear it
; otherwise.

Var /GLOBAL __cli_args
Var /GLOBAL __cli_argc

!macro _Cli_Init PREFIX
Function ${PREFIX}Cli_Init
  StrCmp $__cli_argc "" 0 ${PREFIX}CliInitDone
  Push $0 ; command line
  Push $1 ; index
  Push $2 ; length
  Push $3 ; current character
  Push $4 ; current arg
  Push $5 ; inside quotes
  Push $6 ; arg in progress

  ${GetParameters} $0
  StrLen $2 $0
  StrCpy $1 0
  StrCpy $4 ""
  StrCpy $5 0
  StrCpy $6 0
  StrCpy $__cli_args ""
  StrCpy $__cli_argc 0

${PREFIX}CliInitNext:
  IntCmp $1 $2 ${PREFIX}CliInitEnd
  StrCpy $3 $0 1 $1
  ${If} $6 == 0
  ${AndIf} $5 == 0
    StrCpy $3 $0 3 $1
    ${If} $3 == "/D="
      StrCpy $4 $0 "" $1
      StrCpy $6 1
      Goto ${PREFIX}CliInitEnd
    ${EndIf}
    StrCpy $3 $0 1 $1
  ${EndIf}
  IntOp $1 $1 + 1
  ${If} $3 == '"'
    IntOp $5 1 - $5
    StrCpy $6 1
    Goto ${PREFIX}CliInitNext
  ${EndIf}
  ${If} $5 == 0
    ${If} $3 == " "
    ${OrIf} $3 == "$\t"
      ${If} $6 == 1
        Call ${PREFIX}CliInitAdd
        StrCpy $6 0
      ${EndIf}
      Goto ${PREFIX}CliInitNext
    ${EndIf}
  ${EndIf}
  StrCpy $4 "$4$3"
  StrCpy $6 1
  Goto ${PREFIX}CliInitNext

${PREFIX}CliInitEnd:
  ${If} $6 == 1
    Call ${PREFIX}CliInitAdd
  ${EndIf}

  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Pop $0
${PREFIX}CliInitDone:
FunctionEnd

; Appends $4 to the args and clears it. Called with Cli_Init's registers.
Function ${PREFIX}CliInitAdd
  ${If} $__cli_argc == 0
    StrCpy $__cli_args $4
  ${Else}
    StrCpy $__cli_args "$__cli_args$\n$4"
  ${EndIf}
  IntOp $__cli_argc $__cli_argc + 1
  StrCpy $4 ""
FunctionEnd
!macroend

; Stack: index. Leaves the arg at that index, or "" with the error flag set.
!macro _Cli_GetArg PREFIX
Function ${PREFIX}Cli_GetArg
  Exch $0 ; index, then result
  Push $1 ; remaining args
  Push $2 ; position of the next LF
  Push $3 ; character

  Call ${PREFIX}Cli_Init
  ClearErrors
  ${If} $0 < 0
  ${OrIf} $0 >= $__cli_argc
    StrCpy $0 ""
    SetErrors
    Goto ${PREFIX}CliGetArgDone
  ${EndIf}

  StrCpy $1 $__cli_args
${PREFIX}CliGetArgSkip:
  StrCmp $0 0 ${PREFIX}CliGetArgTake
  IntOp $0 $0 - 1
  StrCpy $2 0
${PREFIX}CliGetArgScan:
  StrCpy $3 $1 1 $2
  StrCmp $3 "$\n" ${PREFIX}CliGetArgNext
  IntOp $2 $2 + 1
  Goto ${PREFIX}CliGetArgScan
${PREFIX}CliGetArgNext:
  IntOp $2 $2 + 1
  StrCpy $1 $1 "" $2
  Goto ${PREFIX}CliGetArgSkip
${PREFIX}CliGetArgTake:
  StrCpy $2 0
${PREFIX}CliGetArgEnd:
  StrCpy $3 $1 1 $2
  StrCmp $3 "" ${PREFIX}CliGetArgCut
  StrCmp $3 "$\n" ${PREFIX}CliGetArgCut
  IntOp $2 $2 + 1
  Goto ${PREFIX}CliGetArgEnd
${PREFIX}CliGetArgCut:
  StrCpy $0 $1 $2

${PREFIX}CliGetArgDone:
  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd
!macroend

; Stack: name. Leaves the value of the last arg matching the name on top and
; its state below it: 0 when there is no such arg, 1 for a bare switch, 2 when
; it has a value (possibly empty).
!macro _Cli_Lookup PREFIX
Function ${PREFIX}Cli_Lookup
  Exch $0 ; name
  Push $1 ; index
  Push $2 ; arg
  Push $3 ; name length
  Push $4 ; arg prefix, then the character after the name
  Push $5 ; value
  Push $6 ; state

  Call ${PREFIX}Cli_Init
  StrLen $3 $0
  StrCpy $5 ""
  StrCpy $6 0
  StrCpy $1 0
${PREFIX}CliLookupNext:
  IntCmp $1 $__cli_argc ${PREFIX}CliLookupDone
  Push $1
  Call ${PREFIX}Cli_GetArg
  Pop $2
  IntOp $1 $1 + 1
  StrCpy $4 $2 $3
  StrCmp $4 $0 0 ${PREFIX}CliLookupNext
  StrCpy $4 $2 1 $3
  StrCmp $4 "" 0 +4
    StrCpy $5 ""
    StrCpy $6 1
    Goto ${PREFIX}CliLookupNext
  StrCmp $4 "=" 0 ${PREFIX}CliLookupNext
  IntOp $4 $3 + 1
  StrCpy $5 $2 "" $4
  StrCpy $6 2
  Goto ${PREFIX}CliLookupNext
${PREFIX}CliLookupDone:
  StrCpy $0 $5
  StrCpy $1 $6
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Exch $1
  Exch
  Exch $0
FunctionEnd
!macroend

; Stack: name. Leaves the value, or "" with the error flag set when the arg is
; absent or bare.
!macro _Cli_GetArgValue PREFIX
Function ${PREFIX}Cli_GetArgValue
  Exch $0 ; name, then result
  Push $1 ; state

  Push $0
  Call ${PREFIX}Cli_Lookup
  Pop $0
  Pop $1
  ClearErrors
  StrCmp $1 2 +3
    StrCpy $0 ""
    SetErrors

  Pop $1
  Exch $0
FunctionEnd
!macroend

; Stack: name. Leaves "1" or "0": a bare switch is 1, otherwise the value goes
; through ParseBool. Sets the error flag, leaving "", when the arg is absent or
; the value is not a bool.
!macro _Cli_GetArgBool PREFIX
Function ${PREFIX}Cli_GetArgBool
  Exch $0 ; name, then result
  Push $1 ; state

  Push $0
  Call ${PREFIX}Cli_Lookup
  Pop $0
  Pop $1
  ClearErrors
  StrCmp $1 0 ${PREFIX}CliGetArgBoolAbsent
  StrCmp $1 1 ${PREFIX}CliGetArgBoolBare
  Push $0
  Call ${PREFIX}ParseBool
  Pop $0
  Goto ${PREFIX}CliGetArgBoolDone
${PREFIX}CliGetArgBoolBare:
  StrCpy $0 1
  Goto ${PREFIX}CliGetArgBoolDone
${PREFIX}CliGetArgBoolAbsent:
  StrCpy $0 ""
  SetErrors
${PREFIX}CliGetArgBoolDone:

  Pop $1
  Exch $0
FunctionEnd
!macroend

; Stack: name. Leaves the canonical integer, or "" with the error flag set when
; the arg is absent, bare, or not an integer.
!macro _Cli_GetArgInt PREFIX
Function ${PREFIX}Cli_GetArgInt
  Exch $0 ; name, then result
  Push $1 ; state

  Push $0
  Call ${PREFIX}Cli_Lookup
  Pop $0
  Pop $1
  ClearErrors
  StrCmp $1 2 +4
    StrCpy $0 ""
    SetErrors
    Goto ${PREFIX}CliGetArgIntDone
  Push $0
  Call ${PREFIX}ParseInt
  Pop $0
${PREFIX}CliGetArgIntDone:

  Pop $1
  Exch $0
FunctionEnd
!macroend

; Stack: name. Sets the error flag when no arg matches.
!macro _Cli_DefineHasArg PREFIX
Function ${PREFIX}Cli_HasArg
  Exch $0 ; name
  Push $1 ; state

  Push $0
  Call ${PREFIX}Cli_Lookup
  Pop $0
  Pop $1
  ClearErrors
  StrCmp $1 0 0 +2
    SetErrors

  Pop $1
  Pop $0
FunctionEnd
!macroend

!insertmacro _Cli_Init ""
!insertmacro _Cli_Init "un."
!insertmacro _Cli_GetArg ""
!insertmacro _Cli_GetArg "un."
!insertmacro _Cli_Lookup ""
!insertmacro _Cli_Lookup "un."
!insertmacro _Cli_GetArgValue ""
!insertmacro _Cli_GetArgValue "un."
!insertmacro _Cli_GetArgBool ""
!insertmacro _Cli_GetArgBool "un."
!insertmacro _Cli_GetArgInt ""
!insertmacro _Cli_GetArgInt "un."
!insertmacro _Cli_DefineHasArg ""
!insertmacro _Cli_DefineHasArg "un."

!macro _Cli_Query PREFIX FUNCTION NAME OUT
  Push `${NAME}`
  Call ${PREFIX}${FUNCTION}
  Pop ${OUT}
!macroend

!macro Cli_Init
  Call Cli_Init
!macroend
!define Cli_Init `!insertmacro Cli_Init`
!macro un.Cli_Init
  Call un.Cli_Init
!macroend
!define un.Cli_Init `!insertmacro un.Cli_Init`

!macro Cli_ArgCount OUT
  Call Cli_Init
  StrCpy ${OUT} $__cli_argc
!macroend
!define Cli_ArgCount `!insertmacro Cli_ArgCount`
!macro un.Cli_ArgCount OUT
  Call un.Cli_Init
  StrCpy ${OUT} $__cli_argc
!macroend
!define un.Cli_ArgCount `!insertmacro un.Cli_ArgCount`

!macro Cli_GetArg INDEX OUT
  !insertmacro _Cli_Query "" Cli_GetArg `${INDEX}` ${OUT}
!macroend
!define Cli_GetArg `!insertmacro Cli_GetArg`
!macro un.Cli_GetArg INDEX OUT
  !insertmacro _Cli_Query "un." Cli_GetArg `${INDEX}` ${OUT}
!macroend
!define un.Cli_GetArg `!insertmacro un.Cli_GetArg`

!macro Cli_GetArgValue NAME OUT
  !insertmacro _Cli_Query "" Cli_GetArgValue `${NAME}` ${OUT}
!macroend
!define Cli_GetArgValue `!insertmacro Cli_GetArgValue`
!macro un.Cli_GetArgValue NAME OUT
  !insertmacro _Cli_Query "un." Cli_GetArgValue `${NAME}` ${OUT}
!macroend
!define un.Cli_GetArgValue `!insertmacro un.Cli_GetArgValue`

!macro Cli_GetArgBool NAME OUT
  !insertmacro _Cli_Query "" Cli_GetArgBool `${NAME}` ${OUT}
!macroend
!define Cli_GetArgBool `!insertmacro Cli_GetArgBool`
!macro un.Cli_GetArgBool NAME OUT
  !insertmacro _Cli_Query "un." Cli_GetArgBool `${NAME}` ${OUT}
!macroend
!define un.Cli_GetArgBool `!insertmacro un.Cli_GetArgBool`

!macro Cli_GetArgInt NAME OUT
  !insertmacro _Cli_Query "" Cli_GetArgInt `${NAME}` ${OUT}
!macroend
!define Cli_GetArgInt `!insertmacro Cli_GetArgInt`
!macro un.Cli_GetArgInt NAME OUT
  !insertmacro _Cli_Query "un." Cli_GetArgInt `${NAME}` ${OUT}
!macroend
!define un.Cli_GetArgInt `!insertmacro un.Cli_GetArgInt`

; ${If} ${Cli_HasArg} "/HELP"
!macro _Cli_HasArg _a _b _t _f
  Push `${_b}`
  Call Cli_HasArg
  IfErrors `${_f}` `${_t}`
!macroend
!define Cli_HasArg `"" Cli_HasArg`
!macro _un.Cli_HasArg _a _b _t _f
  Push `${_b}`
  Call un.Cli_HasArg
  IfErrors `${_f}` `${_t}`
!macroend
!define un.Cli_HasArg `"" un.Cli_HasArg`

; Reports a fatal command line error and quits: exit code 2 when silent,
; otherwise a message box. The same macro serves the installer and the
; uninstaller. With logging enabled the message is written by ${LogError}, which
; also prints to the console.
!macro Cli_Fail MESSAGE
  !ifdef LOGGING_ENABLE
    ${LogError} `${MESSAGE}`
  !else
    ${Console_WriteLine} `ERROR: ${MESSAGE}`
  !endif
  ${If} ${Silent}
    SetErrorLevel 2
  ${Else}
    MessageBox MB_OK|MB_ICONSTOP `${MESSAGE}`
  ${EndIf}
  Quit
!macroend
!define Cli_Fail `!insertmacro Cli_Fail`

!endif
