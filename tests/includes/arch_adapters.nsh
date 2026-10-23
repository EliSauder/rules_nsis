!include "Arch.nsh"

; ArchAllows32On64 selects the 64bit host for its installer arch at compile
; time. Evaluates every installer arch on a simulated HOST and reports
; "x86_32,x86_64,arm32,arm64" acceptance as a string of 0/1 flags.
!macro _HarnessArchAllows32On64 PREFIX HOST RESULT
    Push $0
    StrCpy $current_arch "${HOST}"
    StrCpy ${RESULT} ""
    !insertmacro ${PREFIX}ArchAllows32On64 "x86_32" $0
    StrCpy ${RESULT} "${RESULT}$0"
    !insertmacro ${PREFIX}ArchAllows32On64 "x86_64" $0
    StrCpy ${RESULT} "${RESULT}$0"
    !insertmacro ${PREFIX}ArchAllows32On64 "arm32" $0
    StrCpy ${RESULT} "${RESULT}$0"
    !insertmacro ${PREFIX}ArchAllows32On64 "arm64" $0
    StrCpy ${RESULT} "${RESULT}$0"
    StrCpy $current_arch ""
    Pop $0
!macroend

!macro HarnessArchAllows32On64 HOST RESULT
    !insertmacro _HarnessArchAllows32On64 "" "${HOST}" ${RESULT}
!macroend

!macro un.HarnessArchAllows32On64 HOST RESULT
    !insertmacro _HarnessArchAllows32On64 "un." "${HOST}" ${RESULT}
!macroend
