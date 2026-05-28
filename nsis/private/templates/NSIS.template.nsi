!pragma warning disable 6010 ; Because we are using templates, some installers
                             ; don't use everything defined.

Unicode True

!include LogicLib.nsh
!include MUI2.nsh
!include x64.nsh

!define IsNativeARM32 '${IsNativeMachineArchitecture} 448'

!define PACKAGE_NAME "{{ (ds "in").Product }}"
!define PACKAGE_PATH_NAME "{{ (ds "in").ProductPath }}"
!define PACKAGE_VENDOR "{{ (ds "in").Vendor }}"
!define PACKAGE_VENDOR_PATH "{{ (ds "in").VendorPath }}"
!define PACKAGE_VERSION "{{ (ds "in").Version }}"
!define PACKAGE_DESCRIPTION "{{ (ds "in").Description }}"
!define PACKAGE_COPYRIGHT "{{ (ds "in").Copyright }}"

{{- if eq (ds "in").ExecutionLevel "current" }}
!define INSTALL_ROOT "$LOCALAPPDATA\Programs"
{{- else}}
{{- if (ds "in").InstallRoot }}
!define INSTALL_ROOT "{{(ds "in").InstallRoot}}"
{{- else}}
{{- if (ds "in").ArchitectureIs64}}
!define INSTALL_ROOT "$PROGRAMFILES64"
{{- else}}
!define INSTALL_ROOT "$PROGRAMFILES"
{{- end}}
{{- end}}
{{- end}}

!ifdef OUTFILE
!define OUTFILE_NAME "${OUTFILE}"
!else
!define OUTFILE_NAME "{{ (ds "in").Outfile }}"
!endif

{{- if (ds "in").Icon }}
!define ICON_FILE "{{ (ds "in").Icon }}"
{{- else}}
!define ICON_FILE ""
{{- end}}

{{- if (ds "in").InstallPath}}
!define PACKAGE_PATH "{{(ds "in").InstallPath}}"
{{- else}}
{{- if (ds "in").VendorPath}}
!define PACKAGE_PATH "${PACKAGE_VENDOR_PATH}\${PACKAGE_PATH_NAME}"
{{- else}}
!define PACKAGE_PATH "${PACKAGE_PATH_NAME}"
{{- end}}
{{- end}}

!define UN_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_PATH}"
!define REG_KEY "Software\${PACKAGE_PATH}"

Name "${PACKAGE_NAME}"
OutFile "${OUTFILE_NAME}"
InstallDir "${INSTALL_ROOT}\${PACKAGE_PATH}"

{{- if (ds "in").ExecutionLevel }}
RequestExecutionLevel {{ (ds "in").ExecutionLevel }}
{{- else }}
RequestExecutionLevel admin
{{- end }}

{{- if ne (ds "in").ExecutionLevel "admin"}}
InstallDirRegKey HKCU "${REG_KEY}" "InstallDir"
!define IS_ADMIN_EXECUTION_LEVEL 0
{{- else }}
InstallDirRegKey HKLM "${REG_KEY}" "InstallDir"
!define IS_ADMIN_EXECUTION_LEVEL 1
{{- end}}

SetCompressor {{ (ds "in").Compressor }}
SetCompressorDictSize {{ (ds "in").CompressorDictSize }}

VIProductVersion "${PACKAGE_VERSION}"
VIAddVersionKey "ProductName" "${PACKAGE_NAME}"
VIAddVersionKey "ProductVersion" "${PACKAGE_VERSION}"
VIAddVersionKey "CompanyName" "${PACKAGE_VENDOR}"
VIAddVersionKey "FileDescription" "${PACKAGE_DESCRIPTION}"
VIAddVersionKey "LegalCopyright" "${PACKAGE_COPYRIGHT}"
VIAddVersionKey "FileVersion" "${PACKAGE_VERSION}"

#Var INSTALL_DESKTOP
#Var INSTALL_STARTMENU
#var StartMenuFolder

{{- if (ds "in").Icon }}
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
{{ end }}

!define MUI_ABORTWARNING

{{- if (ds "in").HeaderImage }}
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "{{ (ds "in").HeaderImage }}"
{{ end }}

{{- if (ds "in").MenuImage }}
!define MUI_WELCOMEFINISHPAGE_BITMAP "{{ (ds "in").MenuImage }}"
{{- end }}

!insertmacro MUI_PAGE_WELCOME
{{- if (ds "in").LicenseFile }}
!insertmacro MUI_PAGE_LICENSE "{{ (ds "in").LicenseFile }}"
{{- end }}

#Var Dialog
#Var StartMenuCheckbox
#Var StartMenuCheckboxState
#
#Page custom InstallOptionsPage
#
#Function InstallOptionsPage
#    nsDialogs::Create 1018
#    Pop $Dialog
#    ${If} $Dialog == error
#        Abort
#    ${EndIf}
#
#    ${NSD_CreateCheckbox} 0 30u 100% 10u "&Create Start Menu Entries"
#    Pop $StartMenuCheckbox
#
#    ${NSD_SetState} $StartMenuCheckboxState
#
#    nsDialogs::Show
#FunctionEnd

!insertmacro MUI_PAGE_DIRECTORY

#!define MUI_STARTMENUPAGE_REGISTRY_ROOT "SHCTX"
#!define MUI_STARTMENUPAGE_REGISTRY_KEY "${REG_KEY}"
#!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
#!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

!insertmacro MUI_PAGE_COMPONENTS

!insertmacro MUI_PAGE_INSTFILES

#!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
#!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English" ;first language is the default language
  !insertmacro MUI_LANGUAGE "Afrikaans"
  !insertmacro MUI_LANGUAGE "Albanian"
  !insertmacro MUI_LANGUAGE "Arabic"
  !insertmacro MUI_LANGUAGE "Asturian"
  !insertmacro MUI_LANGUAGE "Basque"
  !insertmacro MUI_LANGUAGE "Belarusian"
  !insertmacro MUI_LANGUAGE "Bosnian"
  !insertmacro MUI_LANGUAGE "Breton"
  !insertmacro MUI_LANGUAGE "Bulgarian"
  !insertmacro MUI_LANGUAGE "Catalan"
  !insertmacro MUI_LANGUAGE "Corsican"
  !insertmacro MUI_LANGUAGE "Croatian"
  !insertmacro MUI_LANGUAGE "Czech"
  !insertmacro MUI_LANGUAGE "Danish"
  !insertmacro MUI_LANGUAGE "Dutch"
  !insertmacro MUI_LANGUAGE "Esperanto"
  !insertmacro MUI_LANGUAGE "Estonian"
  !insertmacro MUI_LANGUAGE "Farsi"
  !insertmacro MUI_LANGUAGE "Finnish"
  !insertmacro MUI_LANGUAGE "French"
  !insertmacro MUI_LANGUAGE "Galician"
  !insertmacro MUI_LANGUAGE "German"
  !insertmacro MUI_LANGUAGE "Greek"
  !insertmacro MUI_LANGUAGE "Hebrew"
  !insertmacro MUI_LANGUAGE "Hungarian"
  !insertmacro MUI_LANGUAGE "Icelandic"
  !insertmacro MUI_LANGUAGE "Indonesian"
  !insertmacro MUI_LANGUAGE "Irish"
  !insertmacro MUI_LANGUAGE "Italian"
  !insertmacro MUI_LANGUAGE "Japanese"
  !insertmacro MUI_LANGUAGE "Korean"
  !insertmacro MUI_LANGUAGE "Kurdish"
  !insertmacro MUI_LANGUAGE "Latvian"
  !insertmacro MUI_LANGUAGE "Lithuanian"
  !insertmacro MUI_LANGUAGE "Luxembourgish"
  !insertmacro MUI_LANGUAGE "Macedonian"
  !insertmacro MUI_LANGUAGE "Malay"
  !insertmacro MUI_LANGUAGE "Mongolian"
  !insertmacro MUI_LANGUAGE "Norwegian"
  !insertmacro MUI_LANGUAGE "NorwegianNynorsk"
  !insertmacro MUI_LANGUAGE "Pashto"
  !insertmacro MUI_LANGUAGE "Polish"
  !insertmacro MUI_LANGUAGE "Portuguese"
  !insertmacro MUI_LANGUAGE "PortugueseBR"
  !insertmacro MUI_LANGUAGE "Romanian"
  !insertmacro MUI_LANGUAGE "Russian"
  !insertmacro MUI_LANGUAGE "ScotsGaelic"
  !insertmacro MUI_LANGUAGE "Serbian"
  !insertmacro MUI_LANGUAGE "SerbianLatin"
  !insertmacro MUI_LANGUAGE "SimpChinese"
  !insertmacro MUI_LANGUAGE "Slovak"
  !insertmacro MUI_LANGUAGE "Slovenian"
  !insertmacro MUI_LANGUAGE "Spanish"
  !insertmacro MUI_LANGUAGE "SpanishInternational"
  !insertmacro MUI_LANGUAGE "Swedish"
  !insertmacro MUI_LANGUAGE "Tatar"
  !insertmacro MUI_LANGUAGE "Thai"
  !insertmacro MUI_LANGUAGE "TradChinese"
  !insertmacro MUI_LANGUAGE "Turkish"
  !insertmacro MUI_LANGUAGE "Ukrainian"
  !insertmacro MUI_LANGUAGE "Uzbek"
  !insertmacro MUI_LANGUAGE "Vietnamese"
  !insertmacro MUI_LANGUAGE "Welsh"


Var Is64BitInstall
Var IsArmInstall

Function .onInit
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
{{- if eq (ds "in").Architecture "x86_64" }}
    ${IfNot} ${IsNativeAMD64}
        DetailPrint "Not AMD64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit x86 version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "x86_32" }}
    ${IfNot} ${IsNativeIA32}
        DetailPrint "Not IA32, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 32-bit x86 version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 32
    StrCpy $Is64BitInstall "0"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "arm64" }}
    ${IfNot} ${IsNativeARM64}
        DetailPrint "Not ARM64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit ARM version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "1"
{{- else if eq (ds "in").Architecture "arm32" }}
    ${IfNot} ${IsNativeARM32}
        DetailPrint "Not ARM32, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 32-bit ARM version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 32
    StrCpy $Is64BitInstall "0"
    StrCpy $IsArmInstall "1"
{{- else }}
    ${If} ${IsNativeX64}
        SetRegView 64
        StrCpy $Is64BitInstall "1"
        StrCpy $IsArmInstall "0"
    ${ElseIf} ${IsNativeIA32}
        StrCpy $Is64BitInstall "0"
        StrCpy $IsArmInstall "0"
    ${ElseIf} ${IsNativeARM64}
        StrCpy $Is64BitInstall "1"
        StrCpy $IsArmInstall "1"
    ${ElseIf} ${IsNativeARM32}
        StrCpy $Is64BitInstall "0"
        StrCpy $IsArmInstall "1"
    ${ElseIf} ${RunningX64}
        SetRegView 64
        StrCpy $Is64BitInstall "1"
        StrCpy $IsArmInstall "0"
    ${Else}
        SetRegView 32
        StrCpy $Is64BitInstall "0"
        StrCpy $IsArmInstall "0"
    ${EndIf}
{{- end }}

    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${PACKAGE_VENDOR}${PACKAGE_NAME}InstallerMutex") i .r1 ?e'
    Pop $R0
    ${If} $R0 != 0
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        DetailPrint "Another instance is already running, aborting"
        Abort
    ${EndIf}
FunctionEnd

#Function CheckPreviousInstall
#  ReadRegStr $R0 HKLM "${REG_KEY}" "InstallDir"
#
#  ${If} $R0 != ""
#    ${If} ${FileExists} "$R0\Uninstall.exe"
#      MessageBox MB_YESNO|MB_ICONQUESTION \
#        "A previous version of ${PACKAGE_NAME} was found. Do you want to uninstall it first?" \
#        IDYES do_uninstall IDNO skip_uninstall
#
#      do_uninstall:
#        ExecWait '"$R0\Uninstall.exe" /S _?=$R0'
#        Goto done
#
#      skip_uninstall:
#        Goto done
#
#      done:
#    ${EndIf}
#  ${EndIf}
#FunctionEnd

Function AddToRegistry
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
      SetShellVarContext all
  ${Else}
      SetShellVarContext current
  ${EndIf}
  Pop $0
  Pop $1
  WriteRegStr SHCTX "${UN_REG_KEY}" \
  "$1" "$0"
  DetailPrint "Set install registry entry: '$1' to '$0'"
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


Function WinSvcExists
    Exch $R0
    Push $R1

    DetailPrint "Querying Windows service: $R0"

    ExecWait '$SYSDIR\sc.exe query "$R0"' $R1

    ${If} $R1 == 0
        StrCpy $R0 1
    ${Else}
        StrCpy $R0 0
    ${EndIf}

    Pop $R1

    Exch $R0
FunctionEnd



!macro WinSvcDelete SERVICE_NAME
  DetailPrint "Deleting Windows service: ${SERVICE_NAME}"
  ExecWait 'sc.exe delete "${SERVICE_NAME}"' $R1
!macroend

; ---------------------
; Installer
; ---------------------

{{- range (ds "in").InstallTypes }}
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
SectionGroup {{if .Expanded}}"/e"{{end}}"{{if .IsBold}}!{{end}}{{.DisplayName}}" "{{.Name}}"
    DetailPrint "Entering Section Group {{.Name}}-{{.DisplayName}}"
{{- range .Components }}
    {{ template "section" . }}
{{- end }}
{{- range .SubGroups }}
    {{ template "sectionGroup" . }}
{{- end}}
SectionGroupEnd
{{ end }}

#Var RootPath

{{ define "sectionDelete" }}
{{- if .Service }}
!insertmacro WinSvcStop "{{ .Name }}"
Sleep 2000
!insertmacro WinSvcDelete "{{ .Name }}"
Sleep 2000
{{- end }}
{{- with $d := .Directory}}
{{- range .Files }}
Delete "{{$d}}\{{ .Name }}"
{{- end}}
{{- end}}
{{- range .Directories }}
RMDir /r "{{ .Name }}"
{{- end}}
{{ end }}

; ------------------------
; SECTIONS
{{ define "section" }}
Section {{if .DisabledByDefault}}\o{{end}} "{{if .IsHidden}}-{{end}}{{.DisplayName}}" "{{.Name}}"
    DetailPrint "Entering Section {{.Name}}-{{.DisplayName}}"
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}

    SectionIn {{if .Required}}RO {{end}}{{ .InstallCategories}}
    SetOutPath "$INSTDIR\{{.Directory}}"

    {{- if .Service }}
    !insertmacro WinSvcStop "{{ .Name }}"
    Sleep 2000
    {{- end }}

    {{- range .Files }}
    File /oname={{.Name}} "{{.Source}}"
    {{- end }}

    {{- range .Directories }}
    File /r "{{ . }}\*.*"
    {{- end }}

    {{- if .Service }}
    Push $0
    Push "{{.Name}}"
    Call WinSvcExists
    Pop $0
    ${If} $0 == 0
        !insertmacro WinSvcUpdate "{{ .Name }}" "${PACKAGE_VENDOR} ${PACKAGE_NAME} {{.DisplayName}}" "$OUTDIR\{{ .ServiceExecutable.Name }}" "{{ .ServiceArgs }}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}"
    ${Else}
        !insertmacro WinSvcCreate "{{ .Name }}" "${PACKAGE_VENDOR} ${PACKAGE_NAME} {{.DisplayName}}" "$OUTDIR\{{ .ServiceExecutable.Name }}" "{{ .ServiceArgs }}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}"
    ${EndIf}
    Pop $0
    {{- end }}
SectionEnd
{{ end }}

{{- range (ds "in").Components }}
{{template "section" .}}
{{- end}}

{{- range (ds "in").ComponentGroups }}
{{template "sectionGroup" .}}
{{- end }}

!macro RemoveComponents
{{- range (ds "in").Components }}
{{template "sectionDelete" .}}
{{- end}}
{{- range (ds "in").ComponentGroups }}
{{template "sectionGroupDelete" .}}
{{- end }}
!macroend

Section "-Core Installation"
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}

    SetOutPath "$INSTDIR"

    WriteRegStr SHCTX "${REG_KEY}" "InstallDir" "$INSTDIR"
    WriteRegStr SHCTX "${REG_KEY}" "Version" "${PACKAGE_VERSION}"
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    Push "DisplayName"
    Push "${PACKAGE_NAME}"
    Call AddToRegistry
    Push "DisplayVersion"
    Push "${PACKAGE_VERSION}"
    Call AddToRegistry
    Push "Publisher"
    Push "${PACKAGE_VENDOR}"
    Call AddToRegistry
    Push "UninstallString"
    Push "$INSTDIR\Uninstall.exe"
    Call AddToRegistry
    Push "NoRepair"
    Push "1"
    Call AddToRegistry
    Push "NoModify"
    Push "1"
    Call AddToRegistry

    ${If} "${ICON_FILE}" != ""
        Push "DisplayIcon"
        Push "$INSTDIR\${ICON_FILE}"
        Call AddToRegistry
    ${Else}
        Push "DisplayIcon"
        Push ""
        Call AddToRegistry
    ${EndIf}

    #${If} "$INSTALL_STARTMENU" == "1"
    #!insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    #    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    #    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

    #    Push "StartMenu"
    #    Push "$StartMenuFolder"
    #    Call AddToRegistry
    #!insertmacro MUI_STARTMENU_WRITE_END
    #${EndIf}

SectionEnd

#Function InstallOptionsPage
#  !insertmacro MUI_HEADER_TEXT "Install Options" "Choose options for installing ${PACKAGE_NAME}"
#  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "NSIS(ds "in").InstallOptions.ini"
#FunctionEnd

Function un.onInit
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
FunctionEnd

# TODO: HANDLE DEPENDENCIES
#Function .onSelChange
#  !insertmacro SectionList MaybeSelectionChanged
#FunctionEnd

Section "Uninstall"
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
      SetShellVarContext all
  ${Else}
      SetShellVarContext current
  ${EndIf}

  {{- if eq (ds "in").Architecture "x64" }}
    SetRegView 64
  {{- else if eq (ds "in").Architecture "x86" }}
    SetRegView 32
  {{- else }}
    ${If} ${RunningX64}
      SetRegView 64
    ${Else}
      SetRegView 32
    ${EndIf}
  {{- end }}

  #ReadRegStr $StartMenuFolder SHCTX "${UN_REG_KEY}" "StartMenu"
  #${Unless} ${Errors}
  #  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  #  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
  #  RMDir $SMPROGRAMS\$StartMenuFolder
  #${EndUnless}
  #ClearErrors

  !insertmacro RemoveComponents

  ;Remove the uninstaller itself.
  Delete "$INSTDIR\Uninstall.exe"
  DeleteRegKey SHCTX "${UN_REG_KEY}"

  RMDir /r "$INSTDIR"

  ; Remove the registry entries.
  DeleteRegKey SHCTX "${REG_KEY}"
  DeleteRegKey /ifempty SHCTX "${REG_KEY}"

SectionEnd
