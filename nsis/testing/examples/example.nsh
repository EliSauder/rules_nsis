!macro Echo INPUT OUTPUT
    StrCpy ${OUTPUT} "${INPUT}"
!macroend
!define Echo `!insertmacro Echo`
!define Answer "42"

!macro _EchoFunction PREFIX
Function ${PREFIX}Echo
FunctionEnd
!macroend
!insertmacro _EchoFunction ""
!insertmacro _EchoFunction "un."

!macro CreateFile PATH OUTPUT
    Push $0
    FileOpen $0 "${PATH}" w
    FileWrite $0 "hello"
    FileClose $0
    StrCpy ${OUTPUT} "${PATH}"
    Pop $0
!macroend

!macro Emit TEXT
    Push $0
    Push $1
    System::Call 'kernel32::GetStdHandle(i -11) p.r0'
    System::Call 'kernel32::WriteFile(p r0, m "${TEXT}", i 5, *i .r1, p 0)'
    System::Call 'kernel32::GetStdHandle(i -12) p.r0'
    System::Call 'kernel32::WriteFile(p r0, m "${TEXT}", i 5, *i .r1, p 0)'
    Pop $1
    Pop $0
!macroend

!macro Registry KEY VALUE OUTPUT
    WriteRegStr HKCU "Software\RulesNsisFrameworkTests\${KEY}" "Value" "${VALUE}"
    StrCpy ${OUTPUT} "${KEY}"
!macroend

!macro Append VALUE
    StrCpy ${VALUE} "${VALUE}-appended"
!macroend

!macro CorruptRegisters
    StrCpy $0 "clobbered"
    StrCpy $R9 "clobbered"
!macroend

!macro Typed NUMBER ENABLED
    IntOp ${NUMBER} ${NUMBER} + 1
    IntOp ${ENABLED} ${ENABLED} ^ 1
!macroend

!macro LeakStack
    Push "leaked"
!macroend

!macro ConsumeStack
    Pop $_example_scratch
!macroend
Var _example_scratch

!macro SetErrorFlag CLEAR
    ${If} ${CLEAR} = 1
        ClearErrors
    ${Else}
        SetErrors
    ${EndIf}
!macroend

; Two stack inputs and two stack outputs pin the function calling convention:
; the first input is on top on entry, the first output on top on return.
!macro _DivModFunction PREFIX
Function ${PREFIX}DivMod
    Exch $0 ; dividend
    Exch
    Exch $1 ; divisor
    Push $2
    IntOp $2 $0 / $1
    IntOp $0 $0 % $1
    StrCpy $1 $2
    Pop $2
    Exch $1
    Exch
    Exch $0
    Exch
FunctionEnd
!macroend
!insertmacro _DivModFunction ""
!insertmacro _DivModFunction "un."

; Uses a harness define and mixes parameter directions and types.
!macro un.Example SECOND FIRST THIRD
    ${If} ${SECOND} > 0
        StrCpy ${FIRST} 1
    ${Else}
        StrCpy ${FIRST} 0
    ${EndIf}
    StrCpy ${THIRD} "${THIRD}|${TEST_MODE}"
!macroend
!define un.Example `!insertmacro un.Example`
