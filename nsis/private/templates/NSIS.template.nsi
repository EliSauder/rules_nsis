!pragma warning disable 6010 ; Because we are using templates, some installers
                             ; don't use everything defined.
Unicode True

!include LogicLib.nsh
!include MUI2.nsh
!include x64.nsh
!include Sections.nsh

!include FileFunc.nsh

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

!define UNINSTALLER_NAME "Uninstall.exe"

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

!define REG_KEY_INSTLOC "InstallDir"

Name "${PACKAGE_NAME}"
OutFile "${OUTFILE_NAME}"
InstallDir "${INSTALL_ROOT}\${PACKAGE_PATH}"

{{- if (ds "in").ExecutionLevel }}
RequestExecutionLevel {{ (ds "in").ExecutionLevel }}
{{- else }}
RequestExecutionLevel admin
{{- end }}

{{- if ne (ds "in").ExecutionLevel "admin"}}
InstallDirRegKey HKCU "${REG_KEY}" "${REG_KEY_INSTLOC}"
!define IS_ADMIN_EXECUTION_LEVEL 0
{{- else }}
InstallDirRegKey HKLM "${REG_KEY}" "${REG_KEY_INSTLOC}"
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
#Var CreateShortcuts
#
#Function InstallOptionsPageCreate
#    nsDialogs::Create 1018
#    Pop $Dialog
#    ${If} $Dialog == error
#        Abort
#    ${EndIf}
#
#    ${NSD_CreateCheckbox} 0 30u 100% 10u "&Create Start Menu Entries"
#    Pop $StartMenuCheckbox
#
#    ${NSD_Checked} $StartMenuCheckbox
#    ${NSD_GetState} $StartMenuCheckbox $StartMenuCheckboxState
#
#    nsDialogs::Show
#FunctionEnd
#
#Function InstallOptionsPageLeave
#    ${NSD_GetState} $StartMenuCheckbox $StartMenuCheckboxState
#FunctionEnd

!insertmacro MUI_PAGE_DIRECTORY

#!define MUI_STARTMENUPAGE_REGISTRY_ROOT "SHCTX"
#!define MUI_STARTMENUPAGE_REGISTRY_KEY "${REG_KEY}"
#!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
#!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

!insertmacro MUI_PAGE_COMPONENTS

#Page custom InstallOptionsPageCreate InstallOptionsPageLeave

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

Var StdOutHandle
Var StdOutAttempted

!macro Log TEXT
    ${IfNot} ${Silent}
        DetailPrint `${TEXT}`
    ${EndIf}
    ${If} $StdOutHandle == ""
    ${AndIf} $StdOutAttempted == ""
        StrCpy $StdOutAttempted "Yes"
        System::Call 'kernel32::AttachConsole(i -1)i.r1'
        ${If} $1 != 0
            System::Call 'kernel32::GetStdHandle(i -11)i.r0'
            StrCpy $StdOutHandle $0
        ${EndIf}
    ${EndIf}

    ${If} $StdOutHandle != ""
        FileWrite $StdOutHandle `${TEXT}$\r$\n`
    ${EndIf}
!macroend

!macro UnLog TEXT
    !insertmacro Log `${TEXT}`
!macroend

Var Is64BitInstall
Var IsArmInstall

!macro SetRegView
{{- if eq (ds "in").Architecture "x86_64" }}
    ${IfNot} ${IsNativeAMD64}
        !insertmacro Log "Not AMD64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit x86 version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "x86_32" }}
    ${IfNot} ${IsNativeIA32}
        !insertmacro Log "Not IA32, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 32-bit x86 version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 32
    StrCpy $Is64BitInstall "0"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "arm64" }}
    ${IfNot} ${IsNativeARM64}
        !insertmacro Log "Not ARM64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit ARM version of Windows." /SD IDOK
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "1"
{{- else if eq (ds "in").Architecture "arm32" }}
    ${IfNot} ${IsNativeARM32}
        !insertmacro Log "Not ARM32, Aborting"
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
!macroend

!macro ValidateMutex
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${PACKAGE_VENDOR}${PACKAGE_NAME}InstallerMutex") i .r1 ?e'
    Pop $R0
    ${If} $R0 != 0
        !insertmacro Log "Another instance is already running, aborting"
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        Abort
    ${EndIf}
!macroend

!macro SetVarCtx
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} == 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
!macroend

{{define "sectionSelChangeVar"}}
Var SelectRefCnt_{{.Name}}
Var SelectedExplicit_{{.Name}}
Var SectionSelected_{{.Name}}
{{end}}

{{define "sectionGroupSelChangeVar"}}
{{- range .Components }}
{{template "sectionSelChangeVar" .}}
{{- end}}
{{end}}

{{- range (ds "in").Components }}
{{template "sectionSelChangeVar" .}}
{{- end}}
{{- range (ds "in").ComponentGroups }}
{{template "sectionGroupSelChangeVar" .}}
{{- end }}

{{define "sectionVarInit"}}
    IntOp $SelectRefCnt_{{.Name}} 0 & 0
    IntOp $SelectedExplicit_{{.Name}} 0 & 0

    SectionGetFlags {{printf "${%v}" .Name}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntOp $SectionSelected_{{.Name}} $0 + 0

    ${If} $0 > 0
        IntOp $SelectedExplicit_{{.Name}} 1 + 0
    ${EndIf}
{{end}}

{{define "sectionGroupVarInit"}}
{{- range .Components }}
{{template "sectionVarInit" .}}
{{- end}}
{{end}}

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

Var TestId

Function un.RemoveRegistry
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
      SetShellVarContext all
  ${Else}
      SetShellVarContext current
  ${EndIf}
  Pop $0

  ${If} $TestId == ""
    !insertmacro Log "Removing registry '$0'"
    DeleteRegKey SHCTX "$0"
  ${Else}
    Push $1
    StrCpy $1 $TestId
    !insertmacro Log "Removing registry '$0\$1'"
    DeleteRegKey SHCTX "$0\$1"
    Pop $1
  ${EndIf}
FunctionEnd

Function AddToRegistry
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
      SetShellVarContext all
  ${Else}
      SetShellVarContext current
  ${EndIf}
  Pop $0
  Pop $1
  Pop $2
  ${If} $TestId != ""
    Push $3
    StrCpy $3 $TestId
    StrCpy $0 "$0\$3"
    Pop $3
  ${EndIf}

  WriteRegStr SHCTX "$0" "$2" "$1"
  !insertmacro Log "Set install registry entry: '$0' -> '$2' to '$1'"
FunctionEnd

!macro _ServiceScExec ARGS OUT_RC
    !insertmacro Log `Executing: $SYSDIR\sc.exe ${ARGS}`
    ClearErrors

    Push $0
    nsExec::ExecToStack `"$SYSDIR\sc.exe" ${ARGS}`
    Pop ${OUT_RC}
    Pop $0
    !insertmacro Log `Output: $0`
    Pop $0

!macroend

!macro Service_Create SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `create "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"` \
    ${OUT_RC}
!macroend

!macro Service_Query SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `query "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Update SERVICE_NAME BIN_PATH DISPLAY_NAME START_TYPE DEPENDENCIES OUT_RC
  !insertmacro _ServiceScExec \
    `config "${SERVICE_NAME}" binPath= "${BIN_PATH}" DisplayName= "${DISPLAY_NAME}" start= ${START_TYPE} depend= "${DEPENDENCIES}"`  \
    ${OUT_RC}
!macroend

!macro Service_Start SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `start "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Stop SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `stop "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_Delete SERVICE_NAME OUT_RC
  !insertmacro _ServiceScExec \
    `delete "${SERVICE_NAME}"` \
    ${OUT_RC}
!macroend

!macro Service_SetDescription SERVICE_NAME DESCRIPTION OUT_RC
    !insertmacro _ServiceScExec \
        `description "${SERVICE_NAME}" "${DESCRIPTION}"` ${OUT_RC}
!macroend

; ---------------------
; Installer
; ---------------------
{{- range (ds "in").InstallTypes }}
InstType "{{.}}"
{{- end }}

{{define "sectionGroupDelete"}}
{{- range .ComponentGroups }}
    {{ template "sectionGroupDelete" . }}
{{- end}}
{{- range .Components }}
    {{ template "sectionDelete" . }}
{{- end }}
{{ end }}

{{define "sectionGroup"}}
SectionGroup {{if .Expanded}}"/e"{{end}}"{{if .Bold}}!{{end}}{{.DisplayName}}" "{{.Name}}"
{{- range .Components }}
    {{ template "section" . }}
{{- end }}
{{- range .ComponentGroups }}
    {{ template "sectionGroup" . }}
{{- end}}
SectionGroupEnd
{{ end }}

#Var RootPath

{{ define "sectionDelete" }}
!insertmacro Log "Removing section {{.Name}}-{{.DisplayName}}"
{{- if .Service }}
!insertmacro Service_Stop "{{ .Name }}" $0
Sleep 2000
!insertmacro Service_Delete "{{ .Name }}" $0
Sleep 2000
{{- end }}

{{- if .Directory }}
{{- $d := .Directory }}
{{- range .Files }}
SetFileAttributes "$INSTDIR\{{$d}}\{{ .Name }}" NORMAL
Delete "$INSTDIR\{{$d}}\{{ .Name }}"
{{- end}}
{{- range $.Directories }}
RMDir /r "$INSTDIR\{{$d}}\{{.}}"
{{- end}}

RMDir "$INSTDIR\{{$d}}"
{{- else}}
{{- range .Files }}
SetFileAttributes "$INSTDIR\{{ .Name }}" NORMAL
Delete "$INSTDIR\{{ .Name }}"
{{- end}}
{{- range .Directories }}
RMDir /r "$INSTDIR\{{ . }}"
{{- end}}
{{- end}}
{{ end }}

; ------------------------
; SECTIONS
{{ define "section" }}
Section {{if .DisabledByDefault}}/o{{end}} "{{if .IsHidden}}-{{end}}{{.DisplayName}}" "{{.Name}}"
    !insertmacro Log "Entering Section {{.Name}}-{{.DisplayName}}"
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}

    {{- if or .InstallCategories .Required}}
    SectionIn {{if .Required}}RO {{end}}{{ .InstallCategories}}
    {{- end}}
    SetOutPath "$INSTDIR\{{.Directory}}"

    {{- if .Service }}
    !insertmacro Service_Stop "{{ .Name }}" $0
    Sleep 2000
    {{- end }}

    {{- range .Files }}
    File /oname={{.Name}} "{{.Source}}"
    {{- end }}

    {{- range .Directories }}
    File /r "{{ . }}\*.*"
    {{- end }}

    {{- if .Service }}
    !insertmacro Service_Query "{{.Name}}" $0
    ${If} $0 = 0
        !insertmacro Service_Update "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${PACKAGE_VENDOR} ${PACKAGE_NAME} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
        !insertmacro Service_SetDescription "{{ .Name }}" "{{.Description}}" $0
    ${Else}
        !insertmacro Service_Create "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${PACKAGE_VENDOR} ${PACKAGE_NAME} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
        !insertmacro Service_SetDescription "{{ .Name }}" "{{.Description}}" $0
    ${EndIf}
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
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}

    SetOutPath "$INSTDIR"

    Push "${REG_KEY_INSTLOC}"
    Push "$INSTDIR"
    Push "${REG_KEY}"
    Call AddToRegistry

    Push "Version"
    Push "${PACKAGE_VERSION}"
    Push "${REG_KEY}"
    Call AddToRegistry

    WriteUninstaller "$INSTDIR\${UNINSTALLER_NAME}"

    Push "DisplayName"
    Push "${PACKAGE_NAME}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "DisplayVersion"
    Push "${PACKAGE_VERSION}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "Publisher"
    Push "${PACKAGE_VENDOR}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "UninstallString"
    Push "$INSTDIR\${UNINSTALLER_NAME}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "NoRepair"
    Push "1"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "NoModify"
    Push "1"
    Push "${UN_REG_KEY}"
    Call AddToRegistry

    ${If} "${ICON_FILE}" != ""
        Push "DisplayIcon"
        Push "$INSTDIR\${ICON_FILE}"
        Push "${UN_REG_KEY}"
        Call AddToRegistry
    ${Else}
        Push "DisplayIcon"
        Push ""
        Push "${UN_REG_KEY}"
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

Function .onInit
    Push $0
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/TESTID=" $TestId
    ClearErrors

    !insertmacro SetVarCtx
    !insertmacro SetRegView
    !insertmacro ValidateMutex

    {{- range (ds "in").Components }}
    {{- template "sectionVarInit" .}}
    {{- end}}

    {{- range (ds "in").ComponentGroups }}
    {{- template "sectionGroupVarInit" .}}
    {{- end}}
    Pop $0

FunctionEnd


Function un.onInit
    Push $0
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/TESTID=" $TestId
    ClearErrors

    !insertmacro SetVarCtx
    !insertmacro SetRegView
    !insertmacro ValidateMutex

    ${If} $TestId == ""
        ReadRegStr $0 SHCTX "${REG_KEY}" "${REG_KEY_INSTLOC}"
    ${Else}
        StrCpy $0 $TestId
        ReadRegStr $0 SHCTX "${REG_KEY}/$0" "${REG_KEY_INSTLOC}"
    ${EndIf}

    ${If} ${Errors}
    ${OrIf} $0 == ""
        !insertmacro Log "No previous install exists."
        MessageBox MB_ICONSTOP "No previous install exists." /SD IDOK
        Abort
    ${EndIf}

    StrCpy $INSTDIR "$0"

    Pop $0
FunctionEnd

Function .onSelChange
    Push $0

    {{- range (ds "in").ComponentDependencies }}
    # Check for selection of "{{.Component}}"
    SectionGetFlags {{printf "${%v}" .Component}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    # If the component state is not equal to the current saved state,
    #   this is the component that triggered onSelChange
    # Else, skip
    ${If} $0 <> $SectionSelected_{{.Component}}
        # If the component is seleceted, select all dependencies
        ${If} $0 = 1
            # Set current component's fields
            IntOp $SectionSelected_{{.Component}} 0 + 1
            IntOp $SelectedExplicit_{{.Component}} 0 + 1

            # Select all dependencies
            {{- range .Dependencies }}
            # Select "{{.}}"
            IntOp $SelectRefCnt_{{.}} $SelectRefCnt_{{.}} + 1
            IntOp $SectionSelected_{{.}} 1 + 0
            !insertmacro SelectSection {{printf "${%v}" .}}
            {{- end}}
        # If the component is unselected, process unselect logic
        #   (a) unselect all dependencies that were not explicitly selected
        #   (b) unselect all dependants
        ${Else}
            # Set deselect states
            IntOp $SectionSelected_{{.Component}} 0 + 0
            IntOp $SelectedExplicit_{{.Component}} 0 + 0

            # Deselect dependencies
            {{- range .Dependencies }}
            # Process deselect for "{{.}}"

            # Reduce ref count for dependencies
            ${If} $SelectRefCnt_{{.}} > 0
                IntOp $SelectRefCnt_{{.}} $SelectRefCnt_{{.}} - 1
            ${EndIf}

            # If there are no more references and it isn't explicitly selected
            #   deselect dependency
            ${If} $SelectRefCnt_{{.}} <= 0
            ${AndIF} $SelectedExplicit_{{.}} = 0
                IntOp $SectionSelected_{{.}} 0 + 0
                IntOp $SelectRefCnt_{{.}} 0 + 0
                !insertmacro UnselectSection {{printf "${%v}" .}}
            ${EndIf}
            {{- end}}

            {{- range .RemoveRefs }}
            ${If} $SelectRefCnt_{{.}} > 0
                IntOp $SelectRefCnt_{{.}} $SelectRefCnt_{{.}} - 1
            ${EndIf}
            ${If} $SelectRefCnt_{{.}} <= 0
            ${AndIF} $SelectedExplicit_{{.}} = 0
                IntOp $SectionSelected_{{.}} 0 + 0
                IntOp $SelectRefCnt_{{.}} 0 + 0
                !insertmacro UnselectSection {{printf "${%v}" .}}
            ${EndIf}
            {{- end}}

            # Deselect all Dependants
            {{- range .Dependants }}
            # Deselect "{{.}}"
            IntOp $SelectedExplicit_{{.}} 0 + 0
            IntOp $SelectRefCnt_{{.}} 0 + 0
            IntOp $SectionSelected_{{.}} 0 + 0
            !insertmacro UnselectSection {{printf "${%v}" .}}
            {{- end}}
        ${EndIf}
    ${EndIf}
    {{- end}}
    Pop $0
FunctionEnd

Section "Uninstall"
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
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
  SetFileAttributes "$INSTDIR\${UNINSTALLER_NAME}" NORMAL
  Delete "$INSTDIR\${UNINSTALLER_NAME}"
  ; Remove if empty
  RMDir "$INSTDIR"

  Push "${UN_REG_KEY}"
  Call un.RemoveRegistry
  Push "${REG_KEY}"
  Call un.RemoveRegistry
SectionEnd
