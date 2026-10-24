!ifndef __INCLUDE_PRODUCT
!define __INCLUDE_PRODUCT

!include "Registry.nsh"
!include "LogicLib.nsh"
!include "Guid.nsh"

Var product_code
Var product_key

!define _UNINSTALLER_BASE_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
!define _INSTALL_DETAIL_BASE_KEY "SOFTWARE"

!macro SetProductCode GUID
    Push $0
    !insertmacro NormalizeGuid "${GUID}" $0

    ${If} "$0" == ""
        !insertmacro LogError "Invalid uuid/guid ${GUID}"
        Pop $0
        SetErrorLevel 5
        Abort
    ${EndIf}

    StrCpy $product_code "$0"
    Pop $0
!macroend
!define SetProductCode `!insertmacro SetProductCode`

!macro un.SetProductCode GUID
    Push $0
    !insertmacro un.NormalizeGuid "${GUID}" $0

    ${If} "$0" == ""
        !insertmacro LogError "Invalid uuid/guid ${GUID}"
        Pop $0
        SetErrorLevel 5
        Abort
    ${EndIf}

    StrCpy $product_code "$0"
    Pop $0
!macroend
!define un.SetProductCode `!insertmacro un.SetProductCode`

!macro GetProductCode OUT
    ${If} $product_code == ""
        !insertmacro LogError "No product code set"
        SetErrorLevel 6
        Abort
    ${EndIf}
    StrCpy ${OUT} $product_code
!macroend
!define GetProductCode `!insertmacro GetProductCode`

!macro un.GetProductCode OUT
    ${If} $product_code == ""
        !insertmacro LogError "No product code set"
        SetErrorLevel 6
        Abort
    ${EndIf}
    StrCpy ${OUT} $product_code
!macroend
!define un.GetProductCode `!insertmacro un.GetProductCode`

; The product's own registry key, `SOFTWARE\<PATH>` (e.g. PATH is
; `Publisher\Product`). Includes such as Options.nsh store their state under it.
!macro SetProductKey PATH
    ${If} "${PATH}" == ""
        !insertmacro LogError "Empty product key"
        SetErrorLevel 5
        Abort
    ${EndIf}
    StrCpy $product_key "${_INSTALL_DETAIL_BASE_KEY}\${PATH}"
!macroend
!define SetProductKey `!insertmacro SetProductKey`

!macro un.SetProductKey PATH
    !insertmacro SetProductKey `${PATH}`
!macroend
!define un.SetProductKey `!insertmacro un.SetProductKey`

!macro GetProductKey OUT
    ${If} $product_key == ""
        !insertmacro LogError "No product key set"
        SetErrorLevel 6
        Abort
    ${EndIf}
    StrCpy ${OUT} $product_key
!macroend
!define GetProductKey `!insertmacro GetProductKey`

!macro un.GetProductKey OUT
    !insertmacro GetProductKey ${OUT}
!macroend
!define un.GetProductKey `!insertmacro un.GetProductKey`

!macro _UpdateProductRegistry PREFIX
Function ${PREFIX}UpdateProductRegistry
    Exch $0 ; Subkey
    Exch 1
    Exch $1 ; Value
    Push $2
    !insertmacro ${PREFIX}GetProductKey $2
    !insertmacro ${PREFIX}SetRegistrySubKeyStr "$2" "$0" $1
    Pop $2
    Pop $1
    Pop $0
FunctionEnd
!macroend

!insertmacro _UpdateProductRegistry ""
!insertmacro _UpdateProductRegistry "un."

!macro UpdateProductRegistry SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call UpdateProductRegistry
!macroend
!define UpdateProductRegistry `!insertmacro UpdateProductRegistry`

!macro un.UpdateProductRegistry SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call un.UpdateProductRegistry
!macroend
!define un.UpdateProductRegistry `!insertmacro un.UpdateProductRegistry`

!macro _GetProductRegistry PREFIX SUBKEY OUT
    Push $0
    !insertmacro ${PREFIX}GetProductKey $0
    !insertmacro ${PREFIX}GetRegistrySubKey "$0" "${SUBKEY}" $0
    Exch $0
    Pop ${OUT}
!macroend

!macro GetProductRegistry SUBKEY OUT
    !insertmacro _GetProductRegistry "" "${SUBKEY}" ${OUT}
!macroend
!define GetProductRegistry `!insertmacro GetProductRegistry`

!macro un.GetProductRegistry SUBKEY OUT
    !insertmacro _GetProductRegistry "un." "${SUBKEY}" ${OUT}
!macroend
!define un.GetProductRegistry `!insertmacro un.GetProductRegistry`

; Removes CHILD under the product key, or the product key itself when CHILD is
; empty.
!macro _RemoveProductRegistry PREFIX CHILD
    Push $0
    !insertmacro ${PREFIX}GetProductKey $0
    StrCmp `${CHILD}` "" +2
        StrCpy $0 "$0\${CHILD}"
    !insertmacro ${PREFIX}RemoveRegistryKey "$0"
    Pop $0
!macroend

!macro RemoveProductRegistry CHILD
    !insertmacro _RemoveProductRegistry "" `${CHILD}`
!macroend
!define RemoveProductRegistry `!insertmacro RemoveProductRegistry`

!macro un.RemoveProductRegistry CHILD
    !insertmacro _RemoveProductRegistry "un." `${CHILD}`
!macroend
!define un.RemoveProductRegistry `!insertmacro un.RemoveProductRegistry`

!define ProdInstallDir "InstallDir"
!define ProdVersion "Version"

!macro GetUninstallRegistry SUBKEY OUT
    Push $0
    !insertmacro GetProductCode $0
    !insertmacro GetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$0" "${SUBKEY}" $0
    Exch $0
    Pop ${OUT}
!macroend
!define GetUninstallRegistry `!insertmacro GetUninstallRegistry`

!macro un.GetUninstallRegistry SUBKEY OUT
    Push $0
    !insertmacro un.GetProductCode $0
    !insertmacro un.GetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$0" "${SUBKEY}" $0
    Exch $0
    Pop ${OUT}
!macroend
!define un.GetUninstallRegistry `!insertmacro un.GetUninstallRegistry`

!macro _UpdateUninstallRegistry PREFIX SUFFIX TYP
Function ${PREFIX}UpdateUninstallRegistry${SUFFIX}
    Exch $0 ; Subkey
    Exch 1
    Exch $1 ; Value
    Push $2
    !insertmacro ${PREFIX}GetProductCode $2
    !insertmacro ${PREFIX}SetRegistrySubKey${TYP} "${_UNINSTALLER_BASE_KEY}\$2" "$0" $1
    Pop $2
    Pop $1
    Pop $0
FunctionEnd
!macroend

!insertmacro _UpdateUninstallRegistry "" "" "Str"
!insertmacro _UpdateUninstallRegistry "un." "" "Str"
!insertmacro _UpdateUninstallRegistry "" "DWORD" "DWORD"
!insertmacro _UpdateUninstallRegistry "un." "DWORD" "DWORD"

!macro UpdateUninstallRegistry SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call UpdateUninstallRegistry
!macroend
!define UpdateUninstallRegistry `!insertmacro UpdateUninstallRegistry`

!macro un.UpdateUninstallRegistry SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call un.UpdateUninstallRegistry
!macroend
!define un.UpdateUninstallRegistry `!insertmacro un.UpdateUninstallRegistry`

!macro UpdateUninstallRegistryDWORD SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call UpdateUninstallRegistryDWORD
!macroend
!define UpdateUninstallRegistryDWORD `!insertmacro UpdateUninstallRegistryDWORD`

!macro un.UpdateUninstallRegistryDWORD SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Call un.UpdateUninstallRegistryDWORD
!macroend
!define un.UpdateUninstallRegistryDWORD `!insertmacro un.UpdateUninstallRegistryDWORD`

!macro RemoveUninstallRegistry
    Push $0
    !insertmacro GetProductCode $0
    !insertmacro RemoveRegistryKey "${_UNINSTALLER_BASE_KEY}\$0"
    Pop $0
!macroend
!define RemoveUninstallRegistry `!insertmacro RemoveUninstallRegistry`

!macro un.RemoveUninstallRegistry
    Push $0
    !insertmacro un.GetProductCode $0
    !insertmacro un.RemoveRegistryKey "${_UNINSTALLER_BASE_KEY}\$0"
    Pop $0
!macroend
!define un.RemoveUninstallRegistry `!insertmacro un.RemoveUninstallRegistry`

!define UnDisplayName "DisplayName"
!define UnDisplayVersion "DisplayVersion"
!define UnDisplayIcon "DisplayIcon"
!define UnPublisher "Publisher"
!define UnVersionMinor "VersionMinor"
!define UnVersionMajor "VersionMajor"
!define UnHelpLink "HelpLink"
!define UnHelpTelephone "HelpTelephone"
!define UnInstallDate "InstallDate"
!define UnInstallDateToday "InstallDateToday"
!define UnInstallLocation "InstallLocation"
!define UnInstallSource "InstallSource"
!define UnUrlAboutInfo "UrlAboutInfo"
!define UnUrlUpdateInfo "UrlUpdateInfo"
!define UnAuthorizedCdfPrefix "AuthorizedCdfPrefix"
!define UnComments "Comments"
!define UnContact "Contact"
!define UnEstimatedSize "EstimatedSize"
!define UnLanguage "Language"
!define UnModifyPath "ModifyPath"
!define UnReadme "Readme"
!define UnUninstallString "UninstallString"
!define UnQuietUninstallString "QuietUninstallString"
!define UnSettingsIdentifier "SettingsIdentifier"
!define UnNoModify "NoModify"
!define UnNoRepair "NoRepair"
!define UnNoRemove "NoRemove"
!define UnProductID "ProductID"
!define UnSystemComponent "SystemComponent"

!macro _UpdateInstallDetail PREFIX
Function ${PREFIX}UpdateInstallDetail
    Exch $0 ; PUB
    Exch 1
    Exch $1 ; PROD
    Exch 2
    Exch $2 ; COMP
    Exch 3
    Exch $3 ; SUBKEY
    Exch 4
    Exch $4 ; VALUE

    ${If} "$0" != 0
        StrCpy $0 "${_INSTALL_DETAIL_BASE_KEY}\$0"
    ${Else}
        StrCpy $0 "${_INSTALL_DETAIL_BASE_KEY}"
    ${Endif}

    StrCpy $0 "$0\$1"

    ${If} "$2" != 0
        StrCpy $0 "$0\Components\$2"
    ${Endif}

    !insertmacro ${PREFIX}SetRegistrySubKeyStr "$0" "$3" $4

    Pop $4
    Pop $0
    Pop $1
    Pop $2
    Pop $3
FunctionEnd
!macroend

!insertmacro _UpdateInstallDetail ""
!insertmacro _UpdateInstallDetail "un."

!macro UpdateInstallDetail PUBLISHER PRODUCT COMPONENT SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Push "${COMPONENT}"
    Push "${PRODUCT}"
    Push "${PUBLISHER}"
    Call UpdateInstallDetail
!macroend
!define UpdateInstallDetail `!insertmacro UpdateInstallDetail`

!macro un.UpdateInstallDetail PUBLISHER PRODUCT COMPONENT SUBKEY VALUE
    Push "${VALUE}"
    Push "${SUBKEY}"
    Push "${COMPONENT}"
    Push "${PRODUCT}"
    Push "${PUBLISHER}"
    Call un.UpdateInstallDetail
!macroend
!define un.UpdateInstallDetail `!insertmacro un.UpdateInstallDetail`

!macro _GetInstallDetail PREFIX
Function ${PREFIX}GetInstallDetail
    Exch $0 ; PUB
    Exch 1
    Exch $1 ; PROD
    Exch 2
    Exch $2 ; COMP
    Exch 3
    Exch $3 ; SUBKEY

    ${If} "$0" != 0
        StrCpy $0 "${_INSTALL_DETAIL_BASE_KEY}\$0"
    ${Else}
        StrCpy $0 "${_INSTALL_DETAIL_BASE_KEY}"
    ${Endif}

    StrCpy $0 "$0\$1"

    ${If} "$2" != 0
        StrCpy $0 "$0\Components\$2"
    ${Endif}

    !insertmacro ${PREFIX}GetRegistrySubKey "$0" "$3" $2

    Pop $3
    Pop $0
    Pop $1
    Exch $2
FunctionEnd
!macroend

!insertmacro _GetInstallDetail ""
!insertmacro _GetInstallDetail "un."

!macro GetInstallDetail PUBLISHER PRODUCT COMPONENT SUBKEY OUT
    Push "${SUBKEY}"
    Push "${COMPONENT}"
    Push "${PRODUCT}"
    Push "${PUBLISHER}"
    Call GetInstallDetail
    Pop ${OUT}
!macroend
!define GetInstallDetail `!insertmacro GetInstallDetail`

!macro un.GetInstallDetail PUBLISHER PRODUCT COMPONENT SUBKEY OUT
    Push "${SUBKEY}"
    Push "${COMPONENT}"
    Push "${PRODUCT}"
    Push "${PUBLISHER}"
    Call un.GetInstallDetail
    Pop ${OUT}
!macroend
!define un.GetInstallDetail `!insertmacro un.GetInstallDetail`

!define InsInstallLocation "InstallLocation"
!define InsInstalled "Installed"
!define InsDirectory "Directory"
!define InsEventLogSource "EventLogSource"

!endif
