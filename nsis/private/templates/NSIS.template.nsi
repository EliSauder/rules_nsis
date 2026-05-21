Unicode True

!include LogicLib.nsh
!include MUI2.nsh

!define PACKAGE_NAME "{{ .PackageName }}"
!define PACKAGE_PATH_NAME "{{ .PackageNamePath }}"
!define PACKAGE_VENDOR "{{ .PackageVendor }}"
!define PACKAGE_VENDOR_PATH "{{ .PackageVendorPath }}"
!define PACKAGE_VERSION "{{ .PackageVersion }}"
!define PACKAGE_DESCRIPTION "{{ .PackageDescription }}"
!define PACKAGE_COPYRIGHT "{{ .PackageCopyright }}"

!define INSTALL_ROOT "{{ default "$PROGRAMFILES64" .InstallRoot }}"
!define OUTFILE_NAME "{{ .OutFile }}"
!define ICON_FILE "{{ .IconFile }}"

!define PACKAGE_PATH "{{ default "${PACKAGE_VENDOR_PATH}\${PACKAGE_PATH_NAME}" .InstallPath }}"

!define UN_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_PATH}"
!define REG_KEY "Software\${PACKAGE_PATH}"

Name "${PACKAGE_NAME}"
OutFile "${OUTFILE_NAME}"
InstallDir "${INSTALL_ROOT}\${PACKAGE_PATH}"
InstallDirRegKey SHCTX "Software\${PACKAGE_PATH}"

{{- if .ExecutionLevel }}
RequestExecutionLevel {{ .ExecutionLevel }}
{{- else }}
RequestExecutionLevel admin
{{- end }}

SetCompressor {{ default "lzma" .Compressor }}
SetCompressorDictSize {{ default "32" .CompressorDictSize }}

VIProductVersion "${PACKAGE_VERSION}"
VIAddVersionKey "ProductName" "${PACKAGE_NAME}"
VIAddVersionKey "ProductVersion" "${PACKAGE_VERSION}"
VIAddVersionKey "CompanyName" "${PACKAGE_VENDOR}"
VIAddVersionKey "FileDescription" "${PACKAGE_DESCRIPTION}"
VIAddVersionKey "LegalCopyright" "${PACKAGE_COPYRIGHT}"
VIAddVersionKey "FileVersion" "${PACKAGE_VERSION}"

Var INSTALL_DESKTOP
Var INSTALL_STARTMENU
var StartMenuFolder


{{- if .IconFile }}
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
{{ end }}

!define MUI_ABORTWARNING

{{- if .HeaderImage }}
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "{{ .HeaderImage }}"
{{ end }}

{{- if .WelcomeFinishImage }}
!define MUI_WELCOMEFINISHPAGE_BITMAP "{{ .WelcomeFinishImage }}"
{{- end }}

!insertmacro MUI_PAGE_WELCOME
{{- if .LicenseFile }}
!insertmacro MUI_PAGE_LICENSE "{{ nsisPath .LicenseFile }}"
{{- end }}

Page custom InstallOptionsPage

!insertmacro MUI_PAGE_DIRECTORY

!define MUI_STARTMENUPAGE_REGISTRY_ROOT "SHCTX"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${REG_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

{{- if .EnableComponentsPage }}
!insertmacro MUI_PAGE_COMPONENTS
{{- end }}

!insertmacro MUI_PAGE_INSTFILES

!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

ReserveFile "NSIS.InstallOptions.ini"
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS
ReserveFile /plugin 'UserInfo.dll'

Function .onInit
{{- if eq .Architecture "amd64" }}
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "This installer requires a 64-bit version of Windows."
    Abort
  ${EndIf}

  SetRegView 64
  StrCpy $Is64BitInstall "1"
{{- else if eq .Architecture "amd32" }}
  SetRegView 32
  StrCpy $Is64BitInstall "0"
{{- else }}
  ${If} ${RunningX64}
    SetRegView 64
    StrCpy $Is64BitInstall "1"
  ${Else}
    SetRegView 32
    StrCpy $Is64BitInstall "0"
  ${EndIf}
{{- end }}

  System::Call 'kernel32::CreateMutex(i 0, i 0, t "${PACKAGE_VENDOR}${PACKAGE_NAME}InstallerMutex") i .r1 ?e'
  Pop $R0
  ${If} $R0 != 0
    MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running."
    Abort
  ${EndIf}
FunctionEnd

Function CheckPreviousInstall
  ReadRegStr $R0 HKLM "${REG_KEY}" "InstallDir"

  ${If} $R0 != ""
    ${If} ${FileExists} "$R0\Uninstall.exe"
      MessageBox MB_YESNO|MB_ICONQUESTION \
        "A previous version of ${PACKAGE_NAME} was found. Do you want to uninstall it first?" \
        IDYES do_uninstall IDNO skip_uninstall

      do_uninstall:
        ExecWait '"$R0\Uninstall.exe" /S _?=$R0'
        Goto done

      skip_uninstall:
        Goto done

      done:
    ${EndIf}
  ${EndIf}
FunctionEnd

Function ConditionalAddToRegistry
  Pop $0
  Pop $1
  ${If} "$0" == ""
    WriteRegStr SHCTX "${UN_REG_KEY}" \
    "$1" "$0"
    ;MessageBox MB_OK "Set Registry: '$1' to '$0'"
    DetailPrint "Set install registry entry: '$1' to '$0'"
  ${EndIf}
FunctionEnd

!macro WinSvcUpdate SvcName DispName Exe Args StartType Depends
    DetailPrint "Updating windows Service: ${SvcName}"

    ${If} "${Args}" == ""
        StrCpy $R0 "${Exe}"
    ${Else}
        StrCpy $R0 '${Exe} ${Args}'
    ${EndIf}

    ExecWait 'sc.exe config "${SvcName}" binPath="$R0" DisplayName="${DispName}" start=${StartType}' $R1

    ${If} "${Depends}" != ""
        ExecWait 'sc.exe config "${SvcName}" depends="${Depends}"' $R1
    ${EndIf}
!macroend

!macro WinSvcCreate SvcName DispName Exe Args StartType Depends
    DetailPrint "Creating windows Service: ${SvcName}"

    ${If} "${Args}" == ""
        StrCpy $R0 "${Exe}"
    ${Else}
        StrCpy $R0 '${Exe} ${Args}'
    ${EndIf}

    ExecWait 'sc.exe create "${SvcName}" binPath="$R0" DisplayName="${DispName}" start=${StartType}' $R1

    ${If} $R1 != 0
        DetailPrint "sc.exe create returned $R1 for service ${SvcName}"
    ${EndIf}

    ${If} "${Depends}" != ""
        ExecWait 'sc.exe config "${SvcName}" depends="${Depends}"' $R1
    ${EndIf}
!macroend

!macro WinSvcSetDesc SERVICE_NAME DESCRIPTION
  ${If} "${DESCRIPTION}" != ""
    DetailPrint "Setting service description: ${SERVICE_NAME}"
    ExecWait 'sc.exe description "${SERVICE_NAME}" "${DESCRIPTION}"' $R1
  ${EndIf}
!macroend

!macro WinSvcDelayedAutoStart SERVICE_NAME
  DetailPrint "Enabling delayed auto-start for service: ${SERVICE_NAME}"
  ExecWait 'sc.exe config "${SERVICE_NAME}" start= delayed-auto' $R1
!macroend

!macro WinSvcStart SERVICE_NAME
  DetailPrint "Starting Windows service: ${SERVICE_NAME}"
  ExecWait 'sc.exe start "${SERVICE_NAME}"' $R1
!macroend

!macro WinSvcStop SERVICE_NAME
  DetailPrint "Stopping Windows service: ${SERVICE_NAME}"
  ExecWait 'sc.exe stop "${SERVICE_NAME}"' $R1
!macroend

!macro WinSvcDelete SERVICE_NAME
  DetailPrint "Deleting Windows service: ${SERVICE_NAME}"
  ExecWait 'sc.exe delete "${SERVICE_NAME}"' $R1
!macroend

; ---------------------
; Installer
; ---------------------

{{- range .InstallTypes }}
InstType "{{.}}"
{{- end }}

{{define "sectionGroupDelete"}}
{{- range .SubGroups }}
    {{ template "sectionGroupDelete" . }}
{{- end}}
{{- range .Components }}
    {{ template "sectionDelete" . }}
{{- end }}
{{ end }}

{{define "sectionGroup"}}
SectionGroup {{if .Value.Expanded "/e " ""}}"{{if .Value.IsBold "!" ""}}{{.Value.DisplayName}}" "{{.Value.Name}}"
{{- range .SubGroups }}
    {{ template "sectionGroup" . }}
{{- end}}
{{- range .Components }}
    {{ template "section" . }}
{{- end }}
SectionGroupEnd
{{ end }}

{{ define "sectionDelete" }}
{{- if .Value.Service }}
!insertmacro WinSvcStop "{{ .Value.Service }}"
Sleep 2000
!insertmacro WinSvcDelete "{{ .Value.Service }}"
Sleep 2000
{{- end }}
{{- range .Value.Files }}
Delete "{{ . }}"
{{- end}}
{{- range .Value.Directories }}
RMDir /r "{{ . }}"
{{- end}}
{{ end }}

; ------------------------
; SECTIONS
{{ define "section" }}
Section {{if .Value.DisabledByDefault "\o", ""}} "{{if .Value.IsHidden "-" ""}}{{.Value.DisplayName}}" "{{.Value.Name}}"
    SectionIn {{if .Value.Required "RO" ""}}{{ .Value.InstallCategories}}
    SetOutPath "$INSTDIR"

    {{- if .Value.Service }}
    !insertmacro WinSvcStop "{{ .Value.Service }}"
    Sleep 2000
    {{- end }}

    {{- range .Value.Files }}
    File /oname={{.Name}} "{{.Source}}"
    {{- end }}

    {{- range .Value.Directories }}
    File /r "{{ . }}\*.*"
    {{- end }}

    {{- if .Value.Service }}
    !insertmacro WinSvcExists "{{ .Value.Service }}" $R1
    ${If} $R0 == 0
        !insertmacro WinSvcUpdate "{{ .Value.Service }}" \
                "${PACKAGE_VENDOR} ${PACKAGE_NAME}" "{{ .Value.ServiceExec }}" \
                "{{ .Value.ServiceArgs }}" "{{ .Value.ServiceStartType }}" \
                "{{ .Value.ServiceDepends }}"
    ${Else}
        !insertmacro WinSvcCreate "{{ .Value.Service }}" \
                "${PACKAGE_VENDOR} ${PACKAGE_NAME}" "{{ .Value.ServiceExec }}" \
                "{{ .Value.ServiceArgs }}" "{{ .Value.ServiceStartType }}" \
                "{{ .Value.ServiceDepends }}"
    ${EndIf}
    {{- end }}
SectionEnd
{{ end }}

{{- range .ComponentGroups }}
{{template "sectionGroup" .}}
!macro RemoveComponents
{{template "sectionGroupDelete" .}}
!macroend
{{- end }}

Section "-Core Installation"
    SetOutPath "$INSTDIR"

    WriteRegStr SHCTX "${REG_KEY}" "InstallDir" "$INSTDIR"
    WriteRegStr SHCTX "${REG_KEY}" "VERSION" "${PACKAGE_VERSION}"
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    Push "DisplayName"
    Push "${PACKAGE_NAME}"
    Call ConditionalAddToRegistry
    Push "DisplayVersion"
    Push "${PACKAGE_VERSION}"
    Call ConditionalAddToRegistry
    Push "Publisher"
    Push "${PACKAGE_VENDOR}"
    Call ConditionalAddToRegistry
    Push "UninstallString"
    Push "$INSTDIR\Uninstall.exe"
    Call ConditionalAddToRegistry
    Push "NoRepair"
    Push "1"
    Call ConditionalAddToRegistry
    Push "NoModify"
    Push "1"
    Call ConditionalAddToRegistry

    Push "DisplayIcon"
    Push "$INSTDIR\${ICON_FILE}"
    Call ConditionalAddToRegistry

    !insertmacro MUI_INSTALLOPTIONS_READ $INSTALL_STARTMENU \
            "NSIS.InstallOptions.ini" "Field 1" "State"

    ${If} "$INSTALL_STARTMENU" == "1"
    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
        CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
        {{- range .Executables }}
        CreateShortCut "$SMPROGRAMS\$StartMenuFolder\{{.}}.lnk" "$INSTDIR\${PACKAGE_PATH}\{{.}}.exe
        {{ end }}
        CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

        Push "StartMenu"
        Push "$StartMenuFolder"
        Call ConditionalAddToRegistry
    !insertmacro MUI_STARTMENU_WRITE_END
    ${EndIf}

SectionEnd

Function InstallOptionsPage
  !insertmacro MUI_HEADER_TEXT "Install Options" "Choose options for installing ${PACKAGE_NAME}"
  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "NSIS.InstallOptions.ini"
FunctionEnd

Function un.onInit
  ClearErrors
  UserInfo::GetName
  ${Unless} ${Errors}
    Pop $0
    UserInfo::GetAccountType
    Pop $1
    ${If} $1 == "Admin"
      SetShellVarContext all
    ${ElseIf} $1 == "Power"
      SetShellVarContext all
    ${EndIf}
  ${EndUnless}
FunctionEnd

Function .onSelChange
  !insertmacro SectionList MaybeSelectionChanged
FunctionEnd

Section "Uninstall"
  {{- if eq .Architecture "x64" }}
    SetRegView 64
  {{- else if eq .Architecture "x86" }}
    SetRegView 32
  {{- else }}
    ${If} ${RunningX64}
      SetRegView 64
    ${Else}
      SetRegView 32
    ${EndIf}
  {{- end }}

  ReadRegStr $StartMenuFolder SHCTX "${UN_REG_KEY}" "StartMenu"
  ${Unless} ${Errors}
    !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
    Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
    RMDir $SMPROGRAMS\$StartMenuFolder
  ${EndUnless}
  ClearErrors

  !insertmacro RemoveComponents

  ;Remove the uninstaller itself.
  Delete "$INSTDIR\Uninstall.exe"
  DeleteRegKey SHCTX "${UN_REG_KEY}"

  RMDir /r "$INSTDIR"

  ; Remove the registry entries.
  DeleteRegKey SHCTX "${REG_KEY}"
  DeleteRegKey /ifempty SHCTX "${REG_KEY}"

SectionEnd
