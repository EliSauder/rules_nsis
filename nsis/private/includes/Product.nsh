!ifndef __INCLUDE_PRODUCT
!define __INCLUDE_PRODUCT

!include "Registry.nsh"
!include "LogicLib.nsh"
!include "Guid.nsh"

Var product_code

!define _UNINSTALLER_BASE_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
!define _INSTALL_DETAIL_BASE_KEY "SOFTWARE"

!macro SetProductCode GUID
    Push $0
    !insertmacro NormalizeGuid "${GUID}" $0

    ${If} "$0" == ""
        !insertmacro LogError "Invalid uuid/guid ${GUID}"
        Abort 5
        Pop $0
    ${EndIf}

    StrCpy $product_code "${GUID}"
    Pop $0
!macroend

!macro un.SetProductCode GUID
    Push $0
    !insertmacro NormalizeGuid "${GUID}" $0

    ${If} "$0" == ""
        !insertmacro LogError "Invalid uuid/guid ${GUID}"
        Pop $0
        Abort 5
    ${EndIf}

    StrCpy $product_code "${GUID}"
    Pop $0
!macroend

!macro GetProductCode OUT
    ${If} $product_code != ""
        !insertmacro LogError "No product code set"
        Pop $0
        Abort 6
    ${EndIf}
    StrCpy ${OUT} $product_code
!macroend

!macro un.GetProductCode OUT
    ${If} $product_code != ""
        !insertmacro LogError "No product code set"
        Pop $0
        Abort 6
    ${EndIf}
    StrCpy ${OUT} $product_code
!macroend

!macro GetUninstallRegistry SUBKEY OUT
    Push $0
    !insertmacro GetProductCode $0
    !insertmacro GetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$0" "${SUBKEY}" ${OUT}
    Pop $0
!macroend

!macro un.GetUninstallRegistry SUBKEY OUT
    Push $0
    !insertmacro un.GetProductCode $0
    !insertmacro un.GetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$0" "${SUBKEY}" ${OUT}
    Pop $0
!macroend

!macro UpdateUninstallRegistry SUBKEY VALUE
Function UpdateUninstallRegistry
    Exch $0 ; Subkey
    Exch
    Exch $1 ; Value
    Push $2
    !insertmacro GetProductCode $2
    !insertmacro SetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$2" "$0" $1
    Pop $2
    Pop $1
    Pop $0
!macroend

!macro un.UpdateUninstallRegistry SUBKEY VALUE
    Push $0
    !insertmacro un.GetProductCode $0
    !insertmacro un.SetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$0" "${SUBKEY}" ${VALUE}
    Pop $0
!macroend

!macro RemoveUninstallRegistry
    Push $0
    !insertmacro GetProductCode $0
    !insertmacro RemoveRegistryKey "${_UNINSTALLER_BASE_KEY}\$0"
    Pop $0
!macroend

!macro un.RemoveUninstallRegistry
    Push $0
    !insertmacro un.GetProductCode $0
    !insertmacro un.RemoveRegistryKey "${_UNINSTALLER_BASE_KEY}\$0"
    Pop $0
!macroend

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

    !insertmacro ${PREFIX}SetRegistrySubKey "$0" "$3" $4

    Pop $4
    Pop $0
    Pop $1
    Pop $2
    Pop $3
FunctionEnd
!macroend

!insertmacro _UpdateInstallDetail ""
!insertmacro _UpdateInstallDetail "un."

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

!define InsInstallLocation "InstallLocation"
!define InsInstalled "Installed"
!define InsDirectory "Directory"
!define InsEventLogSource "EventLogSource"

!endif
