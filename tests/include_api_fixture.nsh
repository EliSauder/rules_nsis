!define TESTABLE_INSTALLER
!include "Arch.nsh"
!include "EventLog.nsh"
!include "Formatting.nsh"
!include "Guid.nsh"
!include "Logging.nsh"
!include "MoveFileFolder.nsh"
!include "Mutex.nsh"
!include "Product.nsh"
!include "Registry.nsh"
!include "Sc.nsh"
!include "ShellContext.nsh"
!include "Testing.nsh"
!include "Uninstall.nsh"
!include "Utility.nsh"
!include "Version.nsh"
!include "iCacls.nsh"

; Child processes used to exercise UninstallExisting's success/failure cleanup.
!macro HarnessChildExit
    SetErrorLevel ${TEST_CHILD_EXITCODE}
    Quit
!macroend

!ifdef TEST_CHILD_EXITCODE
Function .onInit
    !insertmacro HarnessChildExit
FunctionEnd
!endif

; WriteRegBin accepts a compile-time hex literal, so the test adapter fixes it here.
!macro HarnessSetRegistryBinary KEY SUBKEY
    !insertmacro SetRegistrySubKeyBin "${KEY}" "${SUBKEY}" 000102FF
!macroend

!macro un.HarnessSetRegistryBinary KEY SUBKEY
    !insertmacro un.SetRegistrySubKeyBin "${KEY}" "${SUBKEY}" 000102FF
!macroend

; KEY and SUBKEY arrive in registers the Bin macro itself uses as scratch space.
!macro HarnessSetRegistryBinaryRegister KEY SUBKEY
    Push $0
    Push $1
    StrCpy $0 "${KEY}"
    StrCpy $1 "${SUBKEY}"
    !insertmacro SetRegistrySubKeyBin "$0" "$1" 0A0B
    Pop $1
    Pop $0
!macroend

!macro un.HarnessSetRegistryBinaryRegister KEY SUBKEY
    Push $0
    Push $1
    StrCpy $0 "${KEY}"
    StrCpy $1 "${SUBKEY}"
    !insertmacro un.SetRegistrySubKeyBin "$0" "$1" 0A0B
    Pop $1
    Pop $0
!macroend

; U+00AD cannot be passed on the command line: GetOptions treats this
; zero-weight character as the end of the value, so it is embedded here.
!macro HarnessCharToASCIISoftHyphen RESULT
    ${CharToASCII} "${U+00AD}" ${RESULT}
!macroend

; MoveFile derives its labels from the call site, so repeated expansions in one
; function (including through a wrapper macro) must still compile and run.
!macro HarnessMoveFileTwice FIRST_SOURCE FIRST_DESTINATION SECOND_SOURCE SECOND_DESTINATION
    ${MoveFile} "${FIRST_SOURCE}" "${FIRST_DESTINATION}"
    ${MoveFile} "${SECOND_SOURCE}" "${SECOND_DESTINATION}"
!macroend

; Exercise the public output operand alias that previously lost the result.
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

!macro HarnessIfTest RESULT
    ${IfTest}
        StrCpy ${RESULT} "matched"
    ${Else}
        StrCpy ${RESULT} "not-matched"
    ${EndIf}
!macroend

!macro HarnessIfNotTest RESULT
    ${IfNotTest}
        StrCpy ${RESULT} "matched"
    ${Else}
        StrCpy ${RESULT} "not-matched"
    ${EndIf}
!macroend

!macro HarnessSetTestId ID RESULT
    ${SetTestId} "${ID}"
    ${GetTestId} ${RESULT}
!macroend

!macro HarnessTrimQuotesSpecial QUOTED EMPTY LEFT
    ${TrimQuotes} "$\"quoted value$\"" ${QUOTED}
    ${TrimQuotes} "$\"$\"" ${EMPTY}
    ${TrimQuotes} "$\"left only" ${LEFT}
!macroend

!macro HarnessShellContext MODE RESULT
    ${If} "${MODE}" == "admin"
        !insertmacro UpdateShellContextToAdmin
    ${Else}
        !insertmacro UpdateShellContextToCurrent
    ${EndIf}
    ${If} "${MODE}" == "reset"
        !insertmacro UpdateShellContextToAdmin
        !insertmacro ResetShellContext
    ${EndIf}
    !insertmacro SetShellContext
    ${IfAdmin}
        StrCpy ${RESULT} "admin"
    ${Else}
        StrCpy ${RESULT} "current"
    ${EndIf}
!macroend

!macro HarnessNativeArch RESULT
    ${If} ${IsNativeARM32}
        StrCpy ${RESULT} "arm32"
    ${Else}
        StrCpy ${RESULT} "other"
    ${EndIf}
!macroend

!ifdef TEST_PRODUCT_CODE
Function .onInit
    ${SetProductCode} "${TEST_PRODUCT_CODE}"
FunctionEnd

Function un.onInit
    ${un.SetProductCode} "${TEST_PRODUCT_CODE}"
FunctionEnd
!endif

!ifdef TEST_INITIAL_ID
Function .onInit
    ${SetTestId} "${TEST_INITIAL_ID}"
FunctionEnd

Function un.onInit
    ${SetTestId} "${TEST_INITIAL_ID}"
FunctionEnd
!endif
