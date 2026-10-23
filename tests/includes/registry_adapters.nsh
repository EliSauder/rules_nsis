!include "Registry.nsh"

; KEY and SUBKEY arrive in registers the Bin macro itself uses as scratch space.
!macro _HarnessSetRegistryBinaryRegister PREFIX KEY SUBKEY
    Push $0
    Push $1
    StrCpy $0 "${KEY}"
    StrCpy $1 "${SUBKEY}"
    !insertmacro ${PREFIX}SetRegistrySubKeyBin "$0" "$1" 0A0B
    Pop $1
    Pop $0
!macroend

!macro HarnessSetRegistryBinaryRegister KEY SUBKEY
    !insertmacro _HarnessSetRegistryBinaryRegister "" "${KEY}" "${SUBKEY}"
!macroend

!macro un.HarnessSetRegistryBinaryRegister KEY SUBKEY
    !insertmacro _HarnessSetRegistryBinaryRegister "un." "${KEY}" "${SUBKEY}"
!macroend
