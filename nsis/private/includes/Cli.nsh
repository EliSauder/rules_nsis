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
; /name="a b" and "/name=a b" are both the arg /name=a b. NSIS consumes a /D=
; arg and everything after it before the script runs, so parsing stops there
; too. Names are matched case-insensitively, and a switch is either bare (/X)
; or carries a value (/X=value). When a name is given more than once, the last
; one wins.
;
; The args are kept in the nsArray array __cli_args (indexed, so an arg may
; contain any character, including LF) and counted in $__cli_argc, which also
; marks the command line as parsed. Every named arg is also recorded in the
; keyed array __cli_named, under its lower-cased name, so a lookup does not
; scan the args. Every macro parses the command line on first use, so
; ${Cli_Init} is optional.
;
; The full command line is read from the process (GetCommandLineW) in chunks,
; so its total length is not limited to NSIS_MAX_STRLEN. Each single arg is:
; a longer one is truncated, a warning is logged and ${Cli_Init} sets the error
; flag (the other macros report only their own result).
;
; Each macro except ${Cli_Fail} has an "un." variant. The macros that return a
; value set the error flag and return "" when there is none, and clear it
; otherwise.

Var /GLOBAL __cli_argc

; Longest arg, and how many characters are read at a time. A chunk plus the
; couple of characters carried over from the one before must fit in a string.
!define /math _CLI_ARG_MAX ${NSIS_MAX_STRLEN} - 1
!define /math _CLI_CHUNK ${NSIS_MAX_STRLEN} - 8

; Lower-cases the string in the register $REGISTER (a digit 0-9), in place. The
; one place that defines how names are compared.
!macro _Cli_Lower REGISTER
  Push $R9
  StrLen $R9 $${REGISTER}
  System::Call 'user32::CharLowerBuffW(w r${REGISTER}r${REGISTER}, i R9)'
  Pop $R9
!macroend

!macro _Cli_Init PREFIX
Function ${PREFIX}Cli_Init
  StrCmp $__cli_argc "" 0 ${PREFIX}CliInitDone
  Push $0 ; characters being tokenized
  Push $1 ; index
  Push $2 ; length
  Push $3 ; current character
  Push $4 ; current arg
  Push $5 ; inside quotes
  Push $6 ; arg in progress
  Push $7 ; pointer to the unread command line
  Push $8 ; unread characters
  Push $9 ; chunk
  Push $R0 ; characters to tokenize
  Push $R1 ; an arg was too long
  Push $R2 ; length of the current arg
  Push $R3 ; scratch

  StrCpy $__cli_argc 0
  nsArray::Clear __cli_args
  nsArray::Clear __cli_named
  ClearErrors

  StrCpy $4 ""
  StrCpy $5 0
  StrCpy $6 0
  StrCpy $R1 0
  StrCpy $R2 0
  System::Call 'kernel32::GetCommandLineW() p .r7'
  System::Call 'kernel32::lstrlenW(p r7) i .r8'

  ; Skip the program name the way ${GetParameters} does: it ends at the
  ; separator found from the third character on, a quote when the line starts
  ; with one and a space otherwise. A name longer than a chunk leaves no args.
  Call ${PREFIX}CliInitRead
  StrCpy $3 $9 1
  StrCmp $3 '"' +2
    StrCpy $3 " "
  StrCpy $1 2
${PREFIX}CliInitName:
  IntCmp $1 $R3 ${PREFIX}CliInitNoArgs 0 ${PREFIX}CliInitNoArgs
  StrCpy $0 $9 1 $1
  IntOp $1 $1 + 1
  StrCmp $0 $3 0 ${PREFIX}CliInitName
  StrCpy $0 $9 "" $1
  Goto ${PREFIX}CliInitBuffer
${PREFIX}CliInitNoArgs:
  StrCpy $0 ""
  StrCpy $8 0

${PREFIX}CliInitBuffer:
  StrLen $2 $0
  StrCpy $1 0
  StrCpy $R0 $2
  ; Another chunk follows, so leave the last two characters for the next
  ; round: the /D= check needs to see three.
  ${If} $8 > 0
    IntOp $R0 $2 - 2
  ${EndIf}

${PREFIX}CliInitNext:
  IntCmp $1 $R0 ${PREFIX}CliInitChunkEnd 0 ${PREFIX}CliInitChunkEnd
  StrCpy $3 $0 1 $1
  ${If} $6 == 0
  ${AndIf} $5 == 0
    StrCpy $3 $0 3 $1
    ${If} $3 == "/D="
      StrCpy $8 0
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
  StrCpy $6 1
  ${If} $R2 >= ${_CLI_ARG_MAX}
    StrCpy $R1 1
  ${Else}
    StrCpy $4 "$4$3"
    IntOp $R2 $R2 + 1
  ${EndIf}
  Goto ${PREFIX}CliInitNext

${PREFIX}CliInitChunkEnd:
  ${If} $8 > 0
    StrCpy $0 $0 "" $1
    Call ${PREFIX}CliInitRead
    StrCpy $0 "$0$9"
    Goto ${PREFIX}CliInitBuffer
  ${EndIf}

${PREFIX}CliInitEnd:
  ${If} $6 == 1
    Call ${PREFIX}CliInitAdd
  ${EndIf}
  ${If} $R1 == 1
    !insertmacro LogWarn "An argument of the command line is longer than ${_CLI_ARG_MAX} characters and was truncated."
  ${EndIf}
  ; Popping leaves the error flag alone.
  ${If} $R1 == 1
    SetErrors
  ${EndIf}

  Pop $R3
  Pop $R2
  Pop $R1
  Pop $R0
  Pop $9
  Pop $8
  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Pop $0
${PREFIX}CliInitDone:
FunctionEnd

; Reads the next chunk of the command line into $9, and its length into $R3,
; moving $7 and $8 past it. Called with Cli_Init's registers.
Function ${PREFIX}CliInitRead
  StrCpy $9 ""
  StrCpy $R3 0
  ${If} $8 > 0
    StrCpy $R3 $8
    ${If} $R3 > ${_CLI_CHUNK}
      StrCpy $R3 ${_CLI_CHUNK}
    ${EndIf}
    System::Call '*$7(&w$R3 .r9)'
    ; The pointer moves in bytes, and a character is two.
    IntPtrOp $7 $7 + $R3
    IntPtrOp $7 $7 + $R3
    IntOp $8 $8 - $R3
  ${EndIf}
FunctionEnd

; Adds $4 to the args and the named args, and clears it and the length in $R2.
; Called with Cli_Init's registers. The name is what precedes the first =; a
; later arg with the same name replaces the earlier one.
Function ${PREFIX}CliInitAdd
  nsArray::Set __cli_args /key=$__cli_argc $4
  IntOp $__cli_argc $__cli_argc + 1

  Push $0 ; index
  Push $1 ; character
  Push $2 ; name
  Push $3 ; marker and value
  StrCpy $0 0
${PREFIX}CliInitAddScan:
  StrCpy $1 $4 1 $0
  StrCmp $1 "" ${PREFIX}CliInitAddBare
  StrCmp $1 "=" ${PREFIX}CliInitAddValue
  IntOp $0 $0 + 1
  Goto ${PREFIX}CliInitAddScan
${PREFIX}CliInitAddBare:
  StrCpy $2 $4
  StrCpy $3 "B"
  Goto ${PREFIX}CliInitAddSet
${PREFIX}CliInitAddValue:
  StrCpy $2 $4 $0
  IntOp $0 $0 + 1
  StrCpy $3 $4 "" $0
  StrCpy $3 "V$3"
${PREFIX}CliInitAddSet:
  StrCmp $2 "" ${PREFIX}CliInitAddDone
  !insertmacro _Cli_Lower 2
  nsArray::Set __cli_named /key=$2 $3
${PREFIX}CliInitAddDone:
  Pop $3
  Pop $2
  Pop $1
  Pop $0
  StrCpy $4 ""
  StrCpy $R2 0
FunctionEnd
!macroend

; Stack: index. Leaves the arg at that index, or "" with the error flag set.
!macro _Cli_GetArg PREFIX
Function ${PREFIX}Cli_GetArg
  Exch $0 ; index, then result
  Push $1 ; key

  Call ${PREFIX}Cli_Init
  ClearErrors
  ${If} $0 < 0
  ${OrIf} $0 >= $__cli_argc
    StrCpy $0 ""
    SetErrors
  ${Else}
    nsArray::Get __cli_args /at=$0
    Pop $1
    Pop $0
  ${EndIf}

  Pop $1
  Exch $0
FunctionEnd
!macroend

; Stack: name. Leaves the value of the arg matching the name on top and its
; state below it: 0 when there is no such arg, 1 for a bare switch, 2 when it
; has a value (possibly empty).
!macro _Cli_Lookup PREFIX
Function ${PREFIX}Cli_Lookup
  Exch $0 ; name
  Push $1 ; state
  Push $2 ; value

  Call ${PREFIX}Cli_Init
  StrCpy $1 0
  StrCpy $2 ""
  ; An arg's name never contains =, and a name that did would be read by
  ; nsArray as an option.
  StrCmp $0 "" ${PREFIX}CliLookupDone
  StrCpy $2 0
${PREFIX}CliLookupScan:
  StrCpy $1 $0 1 $2
  StrCmp $1 "" ${PREFIX}CliLookupFind
  StrCmp $1 "=" ${PREFIX}CliLookupAbsent
  IntOp $2 $2 + 1
  Goto ${PREFIX}CliLookupScan
${PREFIX}CliLookupFind:
  !insertmacro _Cli_Lower 0
  ClearErrors
  nsArray::Get __cli_named $0
  ; A missing name leaves nothing on the stack.
  IfErrors ${PREFIX}CliLookupAbsent
  Pop $2
  StrCpy $1 $2 1
  StrCpy $2 $2 "" 1
  StrCmp $1 "B" 0 +3
    StrCpy $1 1
    Goto ${PREFIX}CliLookupDone
  StrCpy $1 2
  Goto ${PREFIX}CliLookupDone
${PREFIX}CliLookupAbsent:
  StrCpy $1 0
  StrCpy $2 ""
${PREFIX}CliLookupDone:
  StrCpy $0 $2
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
