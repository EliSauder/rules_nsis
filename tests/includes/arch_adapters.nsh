!include "Arch.nsh"

; DetectArch only fills globals, so its result is read back through the
; public getters, which skip detection once it has run.
!macro HarnessDetectArch ARCH IS64 IS32
    ${DetectArch}
    ${GetArch} ${ARCH}
    ${Is64Bit} ${IS64}
    ${Is32Bit} ${IS32}
!macroend

!macro un.HarnessDetectArch ARCH IS64 IS32
    ${un.DetectArch}
    ${un.GetArch} ${ARCH}
    ${un.Is64Bit} ${IS64}
    ${un.Is32Bit} ${IS32}
!macroend
