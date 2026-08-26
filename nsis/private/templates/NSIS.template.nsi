!pragma warning disable 6010 ; Because we are using templates, some installers
                             ; don't use everything defined.
Unicode True

!include LogicLib.nsh
!include MUI2.nsh
!include Sections.nsh
!include Logging.nsh
!include Utility.nsh
!include Sc.nsh
!include Uninstall.nsh

!include FileFunc.nsh

{{- range (ds "in").IncludeFiles }}
!include "{{.}}"
{{- end }}

!define PRODUCT_ID "{{ (ds "in").Id }}"

!define PRODUCT "{{ (ds "in").Product }}"
!define PRODUCT_PATH "{{ (ds "in").ProductPath }}"
!define PUBLISHER "{{ (ds "in").Vendor }}"
!define PUBLISHER_PATH "{{ (ds "in").VendorPath }}"

!define PRODUCT_DESCRIPTION "{{ (ds "in").Description }}"
!define PRODUCT_COPYRIGHT "{{ (ds "in").Copyright }}"

{{- if (ds "in").Version }}
!define PRODUCT_VERSION "{{ (ds "in").Version }}"
{{- else }}
!define PRODUCT_VERSION "0.0.0.0"
{{- end }}

{{- if eq (ds "in").ExecutionLevel "current" }}
!define INSTALL_ROOT "$LOCALAPPDATA\Programs"
{{- else if (ds "in").InstallRoot }}
!define INSTALL_ROOT "{{(ds "in").InstallRoot}}"
{{- else if (ds "in").ArchitectureIs64}}
!define INSTALL_ROOT "$PROGRAMFILES64"
{{- else}}
!define INSTALL_ROOT "$PROGRAMFILES"
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
!define SUB_PATH "{{(ds "in").InstallPath}}"
{{- else if (ds "in").VendorPath}}
!define SUB_PATH "${PUBLISHER_PATH}\${PRODUCT_PATH}"
{{- else}}
!define SUB_PATH "${PRODUCT_PATH}"
{{- end}}

{{- if (ds "in").VendorPath}}
!define PRODUCT_KEY_PATH "${PUBLISHER}\${PRODUCT}"
{{- else}}
!define PRODUCT_KEY_PATH "${PRODUCT}"
{{- end}}

Name "${PRODUCT}"
OutFile "${OUTFILE_NAME}"
InstallDir "${INSTALL_ROOT}\${SUB_PATH}"

{{- if (ds "in").ExecutionLevel }}
RequestExecutionLevel {{ (ds "in").ExecutionLevel }}
{{- else }}
RequestExecutionLevel admin
{{- end }}

{{- if eq (ds "in").ExecutionLevel "admin"}}
InstallDirRegKey HKLM "${REG_KEY}" "${REG_KEY_INSTLOC}"
!define IS_ADMIN_EXECUTION_LEVEL 1
{{- else }}
InstallDirRegKey HKCU "${REG_KEY}" "${REG_KEY_INSTLOC}"
!define IS_ADMIN_EXECUTION_LEVEL 0
{{- end}}

SetCompressor {{ (ds "in").Compressor }}
SetCompressorDictSize {{ (ds "in").CompressorDictSize }}

VIProductVersion "${PRODUCT_VERSION}"
VIAddVersionKey "ProductName" "${PRODUCT}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_DESCRIPTION}"
VIAddVersionKey "LegalCopyright" "${PRODUCT_COPYRIGHT}"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"

!define MUI_ABORTWARNING

; ---------------------
; Handle Images
; ---------------------
{{- if (ds "in").Icon }}
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
{{ end }}

{{- if (ds "in").HeaderImage }}
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "{{ (ds "in").HeaderImage }}"
{{ end }}

{{- if (ds "in").MenuImage }}
!define MUI_WELCOMEFINISHPAGE_BITMAP "{{ (ds "in").MenuImage }}"
{{- end }}

; ---------------------
; Define Install Types
; ---------------------
{{- range (ds "in").InstallTypes }}
InstType "{{.}}"
{{- end }}

; ---------------------
; Define pages
; ---------------------
!insertmacro MUI_PAGE_WELCOME

{{- if (ds "in").LicenseFile }}
!insertmacro MUI_PAGE_LICENSE "{{ (ds "in").LicenseFile }}"
{{- end }}

!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_COMPONENTS

!insertmacro MUI_PAGE_INSTFILES

!insertmacro MUI_UNPAGE_CONFIRM

!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Languages
;--------------------------------

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

; ----------------------------------------------------
; Define templates for setting up component variables
; ----------------------------------------------------

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

; ----------------------------------------------------
; Define templates for uninstalling components
; ----------------------------------------------------

{{define "sectionGroupDelete"}}
{{- range .ComponentGroups }}
    {{ template "sectionGroupDelete" . }}
{{- end}}
{{- range .Components }}
    {{ template "sectionDelete" . }}
{{- end }}
{{ end }}

{{ define "sectionDelete" }}
{{ if .HasPreUninstall }}
!insertmacro PreUninstall_{{.Name}} "$INSTDIR\{{.Directory}}"
{{ end }}

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

{{- range .CreateDirectories }}
RMDir "{{.Path}}"
{{- end}}

{{- if .EventLog }}
{{- with .EventLog}}
${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
    Push "${ROOT_EVENTLOG_KEY}\{{.Key}}\{{.Source}}"
    Call un.RemoveRegistry
${EndIf}
{{- end}}
{{- end}}

{{ if .HasPostUninstall }}
!insertmacro PostUninstall_{{.Name}} "$INSTDIR\{{.Directory}}"
{{ end }}
{{ end }}

; ----------------------------------------------------
; Define templates for installing components
; ----------------------------------------------------

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

{{ define "section" }}
Section {{if .DisabledByDefault}}/o{{end}} "{{if .IsHidden}}-{{end}}{{.DisplayName}}" "{{.Name}}"
    {{ if .HasPreInstall }}
    !insertmacro PreInstall_{{.Name}} "$INSTDIR\{{.Directory}}"
    {{ end }}

    Push $0
    !insertmacro Log "Entering Section {{.Name}}-{{.DisplayName}}"

    !insertmacro SetShellContext
    !insertmacro DefineRegView

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
        !insertmacro Service_Update "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${PUBLISHER} ${PRODUCT} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
        !insertmacro Service_SetDescription "{{ .Name }}" "{{.Description}}" $0
    ${Else}
        !insertmacro Service_Create "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${PUBLISHER} ${PRODUCT} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
        !insertmacro Service_SetDescription "{{ .Name }}" "{{.Description}}" $0
    ${EndIf}
    {{- end }}

    {{- range .CreateDirectories }}
    {{ $r := conv.ToInt64 .Recursive }}
    {{ $p := .Path }}
    CreateDirectory "{{ $p }}"
    {{- range $old, $new := .Substitutions}}
    !insertmacro iCacls_Substitute "{{$p}}" "{{$old}}" "{{$new}}" {{ $r }} $0
    {{- end}}
    {{- range .GrantsRemove}}
    !insertmacro iCacls_RemoveGrant "{{$p}}" "{{.}}" {{$r}} $0
    {{- end}}
    {{- range .DenialsRemove}}
    !insertmacro iCacls_RemoveDeny "{{$p}}" "{{.}}" {{$r}} $0
    {{- end}}
    {{- range $sid, $perm := .Grants}}
    !insertmacro iCacls_Grant "{{$p}}" "{{$sid}}" "{{$perm}}" {{$r}} $0
    {{- end}}
    {{- range $sid, $perm := .Denials}}
    !insertmacro iCacls_Deny "{{$p}}" "{{$sid}}" "{{$perm}}" {{$r}} $0
    {{- end}}
    {{- if .IntegrityLevel}}
    !insertmacro iCacls_IntegrityLevel "{{$p}}" "{{.IntegrityLevel}}" "{{.IntegrityLevelInheritanceRights}}" {{$r}} $0
    {{- end}}
    {{- end }}

    {{- if .EventLog }}
    {{- with .EventLog}}
    !insertmacro EventLog_AddSource "{{.Key}}" "{{.Source}}" "{{.SupportedTypes}}" "{{.EventMessageFile}}" "{{.CategoryMessageFile}}" "{{.ParameterMessageFile}}"
    {{- end}}
    {{- end}}

    Pop $0

    {{ if .HasPostInstall }}
    !insertmacro PostInstall_{{.Name}} "$OUTDIR"
    {{ end }}
SectionEnd
{{ end }}

; ----------------------------------------------------
; Define component install sections
; ----------------------------------------------------

{{- range (ds "in").Components }}
{{template "section" .}}
{{- end}}

{{- range (ds "in").ComponentGroups }}
{{template "sectionGroup" .}}
{{- end }}

; ----------------------------------------------------
; Define uninstall macro
; ----------------------------------------------------

!macro RemoveComponents
{{- range (ds "in").Components }}
{{template "sectionDelete" .}}
{{- end}}
{{- range (ds "in").ComponentGroups }}
{{template "sectionGroupDelete" .}}
{{- end }}
!macroend

Section "-Core Installation"
    !insertmacro SetShellContext
    !insertmacro DefineRegView

    SetOutPath "$INSTDIR"

    Push "${REG_KEY_INSTLOC}"
    Push "$INSTDIR"
    Push "${REG_KEY}"
    Call AddToRegistry

    Push "Version"
    Push "${PRODUCT_VERSION}"
    Push "${REG_KEY}"
    Call AddToRegistry

    WriteUninstaller "$INSTDIR\${UNINSTALLER_NAME}"

    Push $0
    !insertmacro NormalizeGuid "${PRODUCT_ID}" $0

    !insertmacro UpdateUninstallRegistry "${UnInstallLocation}" "$INSTDIR"
    !insertmacro UpdateUninstallRegistry "${UnDisplayName}" "${PRODUCT}"
    !insertmacro UpdateUninstallRegistry "${UnDisplayVersion}" "${PRODUCT_VERSION}"
    !insertmacro UpdateUninstallRegistry "${UnPublisher}" "${PUBLISHER}"
    !insertmacro UpdateUninstallRegistry "${UnUninstallString}" "$INSTDIR\${UNINSTALLER_NAME}"
    !insertmacro UpdateUninstallRegistry "${UnQuietUninstallString}" "$INSTDIR\${UNINSTALLER_NAME} /S"
    !insertmacro UpdateUninstallRegistry "${UnNoRepair}" "1"
    !insertmacro UpdateUninstallRegistry "${UnNoModify}" "1"
    !insertmacro UpdateUninstallRegistry "${UnNoRemove}" "0"
    !insertmacro UpdateUninstallRegistry "${UnProductID}" "$0"
    !insertmacro UpdateUninstallRegistry "${UnComments}" "${PRODUCT_DESCRIPTION}"
    !insertmacro UpdateUninstallRegistry "${UnInstallSource}" "$EXEPATH"

    ${If} "${ICON_FILE}" != ""
        !insertmacro UpdateUninstallRegistry "${UnDisplayIcon}" "$INSTDIR\${ICON_FILE}"
    ${EndIf}

    SetOutPath "$TEMP"
    File "8ffe12fa-a0cf-4319-913a-9da6efa60efc.txt"
    SetOutPath "$INSTDIR"

    Push $R0
    Push $R1
    Push $R2
    Push $R3
    Push $R4
    Push $R5
    Push $R6

    ${GetTime} "$TEMP\8ffe12fa-a0cf-4319-913a-9da6efa60efc.txt" "CS" $R0 $R1 $R2 $R3 $R4 $R5 $R6
    Delete "$TEMP\8ffe12fa-a0cf-4319-913a-9da6efa60efc.txt"
    !insertmacro UpdateUninstallRegistry "${UnInstallDate}" "$R2-$R1-$R0T$3:$4:$5Z"

    Pop $R6
    Pop $R5
    Pop $R4
    Pop $R3

    ${GetSize} "$INSTDIR" "/S=0K" $R0 $R1 $R2
    IntFmt $0 "0x%08X" $0
    IntOp $R0 $R0 * 1024
    !insertmacro UpdateUninstallRegistry "${UnEstimatedSize}" $R0

    Pop $R2
    Pop $R1
    Pop $R0
SectionEnd

Function .onInit
    {{ if (ds "in").HasPreInit }}
    !insertmacro PreInit
    {{ end }}

    !insertmacro SetShellContext
    !insertmacro DefineRegView

    {{ if not (ds "in").ArchitectureAllow32On64 }}
    !insertmacro ValidateArch "{{ (ds "in").Architecture }}"
    {{ else }}
    !insertmacro ValidateISA "{{ (ds "in").Architecture }}"
    {{ end }}

    !insertmacro ValidateMutex "${PRODUCT_ID}Install"

    !insertmacro SetProductCode "${PRODUCT_ID}"

    Push $0
    !insertmacro UninstallExisting "${PRODUCT_ID}" $0
    ${If} $0 <> 0
        MessageBox MB_YESNO|MB_ICONSTOP "Failed to uninstall previous, continue anyway?" /SD IDYES IDYES +2
        Abort
    ${EndIf}

    {{- range (ds "in").Components }}
    {{- template "sectionVarInit" .}}
    {{- end}}

    {{- range (ds "in").ComponentGroups }}
    {{- template "sectionGroupVarInit" .}}
    {{- end}}
    Pop $0

    {{ if (ds "in").HasPostInit }}
    !insertmacro PostInit
    {{ end }}
FunctionEnd

Function un.onInit
    {{ if (ds "in").HasPreUninit }}
    !insertmacro PreUnInit
    {{ end }}

    !insertmacro un.SetShellContext
    !insertmacro un.DefineRegView

    !insertmacro un.SetProductCode "${PRODUCT_ID}"

    {{ if not (ds "in").ArchitectureAllow32On64 }}
    !insertmacro un.ValidateArch "{{ (ds "in").Architecture }}"
    {{ else }}
    !insertmacro un.ValidateISA "{{ (ds "in").Architecture }}"
    {{ end }}

    !insertmacro un.ValidateMutex "${PRODUCT_ID}Uninstall"

    Push "InstallLocation"
    Push "${UN_REG_KEY}"
    Call un.GetFromRegistry
    Pop $0

    ${If} "$0" == ""
        !insertmacro Log "No install exists."
        MessageBox MB_ICONSTOP "No install exists." /SD IDOK
        Abort
    ${EndIf}

    StrCpy $INSTDIR "$0"

    Pop $0

    {{ if (ds "in").HasPostUninit }}
    !insertmacro PostUnInit
    {{ end }}
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
  !insertmacro SetShellContext
  !insertmacro DefineRegView

  !insertmacro RemoveComponents

  Push "${UN_REG_KEY}"
  Call un.RemoveRegistry
  Push "${REG_KEY}"
  Call un.RemoveRegistry

  ;Remove the uninstaller itself.
  SetFileAttributes "$INSTDIR\${UNINSTALLER_NAME}" NORMAL
  Delete "$INSTDIR\${UNINSTALLER_NAME}"
  ; Remove if empty
  RMDir "$INSTDIR"

SectionEnd
