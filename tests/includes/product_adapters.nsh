!include "Product.nsh"

; The result register is also used inside GetUninstallRegistry, which
; previously lost the value.
!macro HarnessGetUninstallRegistryRegister SUBKEY RESULT
    Push $0
    ${GetUninstallRegistry} "${SUBKEY}" $0
    StrCpy ${RESULT} $0
    Pop $0
!macroend

!macro un.HarnessGetUninstallRegistryRegister SUBKEY RESULT
    Push $0
    ${un.GetUninstallRegistry} "${SUBKEY}" $0
    StrCpy ${RESULT} $0
    Pop $0
!macroend
