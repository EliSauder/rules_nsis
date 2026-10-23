!pragma warning disable 6010 ; Because we are using templates, some installers
                             ; don't use everything defined.
Unicode True
{{- if (ds "in").TestableInstaller }}
!define TESTABLE_INSTALLER
{{- end }}
{{- if (ds "in").ArchitectureIs64 }}
!define REGISTRY_VIEW 64
{{- else }}
!define REGISTRY_VIEW 32
{{- end }}
{{- with (ds "in").LogLevelDefine }}
!define LOGGING_ENABLE
!define {{ . }}
{{- end }}
{{- /* Defined before the includes so their compiled shell-context defaults match. */}}
{{- if eq (ds "in").ExecutionLevel "admin" }}
!define IS_ADMIN_EXECUTION_LEVEL 1
{{- else }}
!define IS_ADMIN_EXECUTION_LEVEL 0
{{- end }}
SetCompressor {{ (ds "in").Compressor }}
SetCompressorDictSize {{ (ds "in").CompressorDictSize }}

!include LogicLib.nsh
!include MUI2.nsh
!include Sections.nsh
!include Logging.nsh
!include Utility.nsh
!include Sc.nsh
!include EventLog.nsh
!include Mutex.nsh
!include iCacls.nsh
!include Uninstall.nsh

!include FileFunc.nsh
!include nsDialogs.nsh
!include Formatting.nsh
!include Cli.nsh


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
!ifdef SIGN_CMD
!uninstfinalize "${SIGN_CMD}" = 0
!finalize "${SIGN_CMD}" = 0
!endif

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

{{- if (ds "in").Vendor}}
!define SERVICE_DISPLAY_PREFIX "${PUBLISHER} ${PRODUCT}"
{{- else}}
!define SERVICE_DISPLAY_PREFIX "${PRODUCT}"
{{- end}}

!define REG_KEY "Software\${PRODUCT_KEY_PATH}"

!define REG_KEY_INSTLOC "InstallDir"

{{- if (ds "in").HasOptions }}
{{ template "optVars" }}

!macro __Options_ForEachPersisted CALLBACK
{{- range (ds "in").Options }}
{{- if .Persist }}
    !insertmacro ${CALLBACK} {{.Page}} {{.Key}}
{{- end }}
{{- end }}
!macroend
{{- end }}
!include Options.nsh

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
{{- else }}
InstallDirRegKey HKCU "${REG_KEY}" "${REG_KEY_INSTLOC}"
{{- end}}

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
{{ template "optionPagesAt" "after_welcome" }}

{{- if (ds "in").LicenseFile }}
!insertmacro MUI_PAGE_LICENSE "{{ (ds "in").LicenseFile }}"
{{- end }}
{{ template "optionPagesAt" "after_license" }}

!insertmacro MUI_PAGE_DIRECTORY
{{ template "optionPagesAt" "after_directory" }}

!insertmacro MUI_PAGE_COMPONENTS
{{ template "optionPagesAt" "after_components" }}

!insertmacro MUI_PAGE_INSTFILES
{{ template "optionPagesAt" "after_instfiles" }}

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
; Options pages
;
; Every control kind is one branch in each of the opt* templates below: the
; handle variables, the create code, the raw read into $__opt_chk_val, the
; validation (which also canonicalizes $__opt_chk_val) and the enable list.
; ----------------------------------------------------

{{- /* Escapes a string for use inside an NSIS "..." literal, variables included. */}}
{{define "nsq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\n" "$\\n" }}{{end}}
{{- /* Same, but keeps $variables usable (defaults such as $DOCUMENTS). */}}
{{define "nsd"}}{{ . | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\n" "$\\n" }}{{end}}

{{define "optionPagesAt"}}
{{- $pos := . }}
{{- range (ds "in").OptionsPages }}
{{- if eq .Position $pos }}
Page custom __Page_{{.Name}}_Create __Page_{{.Name}}_Leave
{{- end }}
{{- end }}
{{end}}

{{define "optHandleVars"}}
Var __hnd_{{.Page}}_{{.Key}}
{{- if .HasLabel }}
Var __hnd_{{.Page}}_{{.Key}}_l
{{- end }}
{{- if eq .Control "radio" }}
{{- range $i, $c := .Choices }}
{{- if gt $i 0 }}
Var __hnd_{{$.Page}}_{{$.Key}}_r{{$i}}
{{- end }}
{{- end }}
{{- end }}
{{end}}

{{define "optVars"}}
Var __opt_chk_val
Var __opt_chk_err
Var __opt_chk_what
Var __opt_chk_enabled
{{- range (ds "in").Options }}
Var {{.Var}}
{{- template "optHandleVars" . }}
{{- end }}
{{- range $p := (ds "in").OptionsPages }}
{{- range .Groups }}
Var __hnd_{{$p.Name}}_grp{{.Index}}
{{- end }}
{{- end }}
{{end}}

{{define "optDefault"}}
    StrCpy ${{.Var}} "{{ template "nsd" .Default }}"
{{end}}

{{- /* Creates the controls; $0 is free, the page dialog is already created. */}}
{{define "optCreate"}}
{{- $h := printf "$__hnd_%s_%s" .Page .Key }}
{{- if .HasLabel }}
    ${NSD_CreateLabel} {{.X}} {{.LabelY}}u {{.Width}} 10u "{{ template "nsq" .Label }}"
    Pop {{$h}}_l
{{- end }}
{{- if eq .Control "checkbox" }}
    ${NSD_CreateCheckbox} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u "{{ template "nsq" .Label }}"
    Pop {{$h}}
    ${If} ${{.Var}} == "1"
        ${NSD_Check} {{$h}}
    ${EndIf}
    {{- if .HasDependents }}
    ${NSD_OnClick} {{$h}} __Page_{{.Page}}_OnToggle
    {{- end }}
{{- else if eq .Control "number" }}
    {{- if .AllowNegative }}
    ${NSD_CreateText} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u "${{ .Var }}"
    {{- else }}
    ${NSD_CreateNumber} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u "${{ .Var }}"
    {{- end }}
    Pop {{$h}}
    ${NSD_SetTextLimit} {{$h}} 11
{{- else if or (eq .Control "text") (eq .Control "password") }}
    {{- if eq .Control "password" }}
    ${NSD_CreatePassword} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u "${{ .Var }}"
    {{- else }}
    ${NSD_CreateText} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u "${{ .Var }}"
    {{- end }}
    Pop {{$h}}
    {{- if .MaxLength }}
    ${NSD_SetTextLimit} {{$h}} {{.MaxLength}}
    {{- end }}
{{- else if eq .Control "radio" }}
    {{- $o := . }}
    {{- range $i, $c := .Choices }}
    {{- $rh := $h }}
    {{- if gt $i 0 }}{{ $rh = printf "%s_r%d" $h $i }}{{ end }}
    {{- if eq $i 0 }}
    ${NSD_CreateFirstRadioButton} {{$o.X}} {{index $o.ChoiceYs $i}}u {{$o.Width}} 12u "{{ template "nsq" $c }}"
    {{- else }}
    ${NSD_CreateAdditionalRadioButton} {{$o.X}} {{index $o.ChoiceYs $i}}u {{$o.Width}} 12u "{{ template "nsq" $c }}"
    {{- end }}
    Pop {{$rh}}
    ${If} ${{$o.Var}} == "{{ template "nsq" $c }}"
        ${NSD_Check} {{$rh}}
    ${EndIf}
    {{- end }}
{{- else if eq .Control "droplist" }}
    ${NSD_CreateDropList} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    {{- range .Choices }}
    ${NSD_CB_AddString} {{$h}} "{{ template "nsq" . }}"
    {{- end }}
    ${NSD_CB_SelectStringExact} {{$h}} "${{ .Var }}"
{{- end }}
{{- if .Description }}
    ${NSD_CreateLabel} {{.X}} {{.DescriptionY}}u {{.Width}} {{.DescriptionHeight}}u "{{ template "nsq" .Description }}"
    Pop $0
{{- end }}
{{end}}

{{- /* Reads the control into $__opt_chk_val (raw); checkboxes are handled apart. */}}
{{define "optRead"}}
{{- $h := printf "$__hnd_%s_%s" .Page .Key }}
{{- if or (eq .Control "number") (eq .Control "text") (eq .Control "password") (eq .Control "droplist") }}
    ${NSD_GetText} {{$h}} $__opt_chk_val
{{- else if eq .Control "radio" }}
    {{- $o := . }}
    StrCpy $__opt_chk_val ""
    {{- range $i, $c := .Choices }}
    {{- $rh := $h }}
    {{- if gt $i 0 }}{{ $rh = printf "%s_r%d" $h $i }}{{ end }}
    ${NSD_GetState} {{$rh}} $0
    ${If} $0 = 1
        StrCpy $__opt_chk_val "{{ template "nsq" $c }}"
    ${EndIf}
    {{- end }}
{{- end }}
{{end}}

{{- /* Validates and canonicalizes $__opt_chk_val; failure sets $__opt_chk_err. */}}
{{define "optCheckBody"}}
{{- if eq .Control "checkbox" }}
    ClearErrors
    ${ParseBool} $__opt_chk_val $0
    ${If} ${Errors}
        StrCpy $__opt_chk_err "must be a boolean (1/0, true/false, yes/no, on/off)"
    ${Else}
        StrCpy $__opt_chk_val $0
    ${EndIf}
{{- else if eq .Control "number" }}
    ClearErrors
    ${ParseInt} $__opt_chk_val $0
    ${If} ${Errors}
        StrCpy $__opt_chk_err "must be a whole number"
    {{- if .Min }}
    ${ElseIf} $0 < {{.Min}}
        StrCpy $__opt_chk_err "must be at least {{.Min}}"
    {{- end }}
    {{- if .Max }}
    ${ElseIf} $0 > {{.Max}}
        StrCpy $__opt_chk_err "must be at most {{.Max}}"
    {{- end }}
    ${Else}
        StrCpy $__opt_chk_val $0
    ${EndIf}
{{- else if or (eq .Control "text") (eq .Control "password") }}
    {{- if .MaxLength }}
    StrLen $0 $__opt_chk_val
    ${If} $0 > {{.MaxLength}}
        StrCpy $__opt_chk_err "must be at most {{.MaxLength}} characters"
    ${EndIf}
    {{- end }}
    {{- if .Required }}
    ${If} $__opt_chk_val == ""
    ${AndIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    ${EndIf}
    {{- end }}
{{- else if or (eq .Control "radio") (eq .Control "droplist") }}
    StrCpy $__opt_chk_err "must be one of: {{ range $i, $c := .Choices }}{{ if $i }}, {{ end }}{{ template "nsq" $c }}{{ end }}"
    {{- range .Choices }}
    ${If} $__opt_chk_val == "{{ template "nsq" . }}"
        StrCpy $__opt_chk_val "{{ template "nsq" . }}"
        StrCpy $__opt_chk_err ""
    ${EndIf}
    {{- end }}
{{- end }}
{{end}}

{{define "optEnable"}}
{{- $h := printf "$__hnd_%s_%s" .Page .Key }}
    EnableWindow {{$h}} $0
{{- if .HasLabel }}
    EnableWindow {{$h}}_l $0
{{- end }}
{{- if eq .Control "radio" }}
    {{- range $i, $c := .Choices }}
    {{- if gt $i 0 }}
    EnableWindow {{$h}}_r{{$i}} $0
    {{- end }}
    {{- end }}
{{- end }}
{{end}}

{{- /* Sets $0 to 1 when every checkbox in the chain is checked. */}}
{{define "optChainEnabled"}}
    StrCpy $0 1
{{- range .Chain }}
    ${NSD_GetState} $__hnd_{{$.Page}}_{{.}} $1
    ${If} $1 <> 1
        StrCpy $0 0
    ${EndIf}
{{- end }}
{{end}}

{{define "optInitDefaults"}}
{{- range (ds "in").Options }}
{{- template "optDefault" . }}
{{- end }}
{{end}}

{{define "optPageFunctions"}}
{{- $page := . }}
{{- range .Options }}
Function __Opt_Check_{{.Page}}_{{.Key}}
    Push $0
    StrCpy $__opt_chk_err ""
{{- template "optCheckBody" . }}
    Pop $0
FunctionEnd
{{- end }}

Function __Page_{{.Name}}_ApplyEnabled
    Push $0
    Push $1
{{- range .Items }}
{{- if .IsGroup }}
{{- if .Group.EnabledChain }}
{{ template "optChainEnabled" (coll.Dict "Page" $page.Name "Chain" .Group.EnabledChain) }}
    EnableWindow $__hnd_{{$page.Name}}_grp{{.Group.Index}} $0
{{- end }}
{{- else if .EnabledChain }}
{{ template "optChainEnabled" (coll.Dict "Page" $page.Name "Chain" .EnabledChain) }}
{{ template "optEnable" . }}
{{- end }}
{{- end }}
{{- range .Groups }}
{{- range .Options }}
{{- if .EnabledChain }}
{{ template "optChainEnabled" (coll.Dict "Page" $page.Name "Chain" .EnabledChain) }}
{{ template "optEnable" . }}
{{- end }}
{{- end }}
{{- end }}
    Pop $1
    Pop $0
FunctionEnd

Function __Page_{{.Name}}_OnToggle
    Exch $0
    Pop $0
    Call __Page_{{.Name}}_ApplyEnabled
FunctionEnd

Function __Page_{{.Name}}_Create
    Push $0
    Push $1
{{- if not .Always }}
{{- range .OwningComponents }}
    SectionGetFlags {{printf "${%v}" .}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    StrCmp $0 0 +1 __show
{{- end }}
    Pop $1
    Pop $0
    Abort
    __show:
{{- end }}
{{- if .Internal }}
{{ .PreCreate }}
{{- end }}
    !insertmacro MUI_HEADER_TEXT "{{ template "nsq" .Title }}" "{{ template "nsq" .Subtitle }}"
    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Pop $1
        Pop $0
        Abort
    ${EndIf}
{{- if .Text }}
    ${NSD_CreateLabel} 0u {{.TextY}}u 100% {{.TextHeight}}u "{{ template "nsq" .Text }}"
    Pop $0
{{- end }}
{{- range .Items }}
{{- if .IsGroup }}
    ${NSD_CreateGroupBox} {{.Group.X}} {{.Group.Y}}u {{.Group.Width}} {{.Group.Height}}u "{{ template "nsq" .Group.Label }}"
    Pop $__hnd_{{$page.Name}}_grp{{.Group.Index}}
    {{- range .Group.Options }}
{{ template "optCreate" . }}
    {{- end }}
{{- else }}
{{ template "optCreate" . }}
{{- end }}
{{- end }}
    Call __Page_{{.Name}}_ApplyEnabled
    Pop $1
    Pop $0
    nsDialogs::Show
FunctionEnd

Function __Page_{{.Name}}_Leave
    Push $0
    Push $1
{{- /* Checkboxes first: they decide which other controls are enabled. */}}
{{- range .Options }}
{{- if eq .Control "checkbox" }}
    ${NSD_GetState} $__hnd_{{.Page}}_{{.Key}} $0
    ${If} $0 = 1
        StrCpy ${{.Var}} "1"
    ${Else}
        StrCpy ${{.Var}} "0"
    ${EndIf}
{{- end }}
{{- end }}
{{- range .Options }}
{{- if ne .Control "checkbox" }}
{{ template "optLeaveOne" . }}
{{- end }}
{{- end }}
{{- if .Internal }}
{{ .PostLeave }}
{{- end }}
    Pop $1
    Pop $0
    Return
    __fail:
    MessageBox MB_OK|MB_ICONEXCLAMATION "$__opt_chk_what: $__opt_chk_err"
    Pop $1
    Pop $0
    Abort
FunctionEnd
{{end}}

{{define "optApplyOne"}}
    StrCpy $__opt_chk_what "{{.Id}}"
    StrCpy $__opt_chk_enabled 1
    Call __Opt_Check_{{.Page}}_{{.Key}}
    ${If} $__opt_chk_err != ""
        ${Cli_Fail} "Invalid value for option {{.Id}}: $__opt_chk_err"
    ${EndIf}
    StrCpy ${{.Var}} $__opt_chk_val
{{end}}

{{define "optCli"}}
{{- /* Result of the unknown-name check is left in $__opt_chk_enabled. */}}
Function __Opt_IniIsKnown
    Push $0
    Push $1
    StrCpy $0 $__opt_chk_what
    StrCpy $1 $__opt_chk_val
    StrCpy $__opt_chk_enabled 0
    ${If} $0 == "setup"
        StrCpy $__opt_chk_enabled 1
    {{- range (ds "in").OptionsPages }}
    ${ElseIf} $0 == "{{.Name}}"
        ${If} $1 == ""
            StrCpy $__opt_chk_enabled 1
        {{- range .Options }}
        ${ElseIf} $1 == "{{.Key}}"
            StrCpy $__opt_chk_enabled 1
        {{- end }}
        ${EndIf}
    {{- end }}
    ${EndIf}
    Pop $1
    Pop $0
FunctionEnd

; Stack: ini file. Rejects unknown sections and keys, then applies known values.
Function __Options_ApplyIni
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    System::Alloc 131072
    Pop $1
    System::Alloc 131072
    Pop $2
    System::Call 'kernel32::GetPrivateProfileSectionNamesW(i r1, i 65535, w r0)'
    IntOp $3 $1 + 0
    ${Do}
        System::Call 'kernel32::lstrlenW(i r3) i .r4'
        ${If} $4 = 0
            ${Break}
        ${EndIf}
        System::Call 'kernel32::lstrcpyW(w .r5, i r3)'
        StrCpy $__opt_chk_what $5
        StrCpy $__opt_chk_val ""
        Call __Opt_IniIsKnown
        ${If} $__opt_chk_enabled != 1
            ${Cli_Fail} "Unknown section [$5] in the options file."
        ${EndIf}
        System::Call 'kernel32::GetPrivateProfileStringW(w r5, i 0, w "", i r2, i 65535, w r0)'
        IntOp $6 $2 + 0
        ${Do}
            System::Call 'kernel32::lstrlenW(i r6) i .r7'
            ${If} $7 = 0
                ${Break}
            ${EndIf}
            System::Call 'kernel32::lstrcpyW(w .r4, i r6)'
            StrCpy $__opt_chk_what $5
            StrCpy $__opt_chk_val $4
            Call __Opt_IniIsKnown
            ${If} $__opt_chk_enabled != 1
                ${Cli_Fail} "Unknown option [$5] $4 in the options file."
            ${EndIf}
            IntOp $7 $7 + 1
            IntOp $7 $7 * 2
            IntOp $6 $6 + $7
        ${Loop}
        System::Call 'kernel32::lstrlenW(i r3) i .r4'
        IntOp $4 $4 + 1
        IntOp $4 $4 * 2
        IntOp $3 $3 + $4
    ${Loop}
    System::Free $1
    System::Free $2
    {{- range (ds "in").Options }}
    ClearErrors
    ReadINIStr $__opt_chk_val $0 "{{.Page}}" "{{.Key}}"
    ${IfNot} ${Errors}
{{- template "optApplyOne" . }}
    ${EndIf}
    {{- end }}
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

{{- /* Precedence: defaults, persisted values, /OPTIONS=, then /O: arguments. */}}
Function __Options_ApplyCli
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    ClearErrors
    ${Cli_GetArgValue} "/OPTIONS" $0
    ${IfNot} ${Errors}
        ${IfNot} ${FileExists} "$0"
            ${Cli_Fail} "The options file given with /OPTIONS= does not exist."
        ${EndIf}
        Push $0
        Call __Options_ApplyIni
    ${EndIf}
    ${Cli_ArgCount} $1
    StrCpy $2 0
    ${While} $2 < $1
        ${Cli_GetArg} $2 $3
        StrCpy $4 $3 3
        ${If} $4 == "/O:"
            StrCpy $3 $3 "" 3
            StrCpy $5 0
            ${Do}
                StrCpy $4 $3 1 $5
                ${If} $4 == ""
                    ${Cli_Fail} "Option arguments must have the form /O:page.key=value."
                ${EndIf}
                ${If} $4 == "="
                    ${Break}
                ${EndIf}
                IntOp $5 $5 + 1
            ${Loop}
            StrCpy $4 $3 $5
            IntOp $5 $5 + 1
            StrCpy $3 $3 "" $5
            {{- range (ds "in").Options }}
            ${If} $4 == "{{.Id}}"
                StrCpy $__opt_chk_val $3
{{- template "optApplyOne" . }}
                Goto __cli_next
            ${EndIf}
            {{- end }}
            ${Cli_Fail} "Unknown option: $4"
        ${EndIf}
        __cli_next:
        IntOp $2 $2 + 1
    ${EndWhile}
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd
{{end}}

{{define "optLeaveOne"}}
{{- $n := printf "__skip_%s" .Key }}
    StrCpy $__opt_chk_enabled 1
{{- range .EnabledChain }}
    StrCmp $__opt_{{$.Page}}_{{.}} 1 +2 0
        StrCpy $__opt_chk_enabled 0
{{- end }}
{{- if .EnabledChain }}
    StrCmp $__opt_chk_enabled 1 +2 0
        Goto {{$n}}
{{- end }}
{{ template "optRead" . }}
    StrCpy $__opt_chk_what "{{ template "nsq" .Label }}"
    Call __Opt_Check_{{.Page}}_{{.Key}}
    StrCmp $__opt_chk_err "" +2 0
        Goto __fail
    StrCpy ${{.Var}} $__opt_chk_val
{{- if .EnabledChain }}
    {{$n}}:
{{- end }}
{{end}}


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

!insertmacro LogInfo "Removing section {{.Name}}-{{.DisplayName}}"
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
!insertmacro un.EventLog_RemoveSource "{{.Key}}" "{{.Source}}"
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
    !insertmacro LogInfo "Entering Section {{.Name}}-{{.DisplayName}}"

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
        !insertmacro Service_Update "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${SERVICE_DISPLAY_PREFIX} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
        !insertmacro Service_SetDescription "{{ .Name }}" "{{.Description}}" $0
    ${Else}
        !insertmacro Service_Create "{{ .Name }}" "$OUTDIR\{{ .ServiceExecutable.Name }} {{ .ServiceArgs }}" "${SERVICE_DISPLAY_PREFIX} {{.DisplayName}}" "{{ .ServiceStartType }}" "{{ .ServiceDependencies }}" $0
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

    !insertmacro SetRegistrySubKeyStr "${REG_KEY}" "${REG_KEY_INSTLOC}" "$INSTDIR"
    !insertmacro SetRegistrySubKeyStr "${REG_KEY}" "Version" "${PRODUCT_VERSION}"

    {{- if (ds "in").HasOptions }}
    ${Option_Persist}
    {{- end }}

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
    Pop $0

    !if "${ICON_FILE}" != ""
    ; The icon is embedded in the uninstaller via MUI_UNICON.
    !insertmacro UpdateUninstallRegistry "${UnDisplayIcon}" "$INSTDIR\${UNINSTALLER_NAME},0"
    !endif

    Push $R0
    Push $R1
    Push $R2
    Push $R3
    Push $R4
    Push $R5
    Push $R6

    ${GetTime} "" "L" $R0 $R1 $R2 $R3 $R4 $R5 $R6
    !insertmacro UpdateUninstallRegistry "${UnInstallDate}" "$R0$R1$R2"

    Pop $R6
    Pop $R5
    Pop $R4
    Pop $R3

    ; EstimatedSize is a REG_DWORD in KB.
    ${GetSize} "$INSTDIR" "/S=0K" $R0 $R1 $R2
    !insertmacro UpdateUninstallRegistryDWORD "${UnEstimatedSize}" $R0

    Pop $R2
    Pop $R1
    Pop $R0
SectionEnd

{{- if (ds "in").HasOptions }}
; ----------------------------------------------------
; Define options pages
; ----------------------------------------------------

{{- range (ds "in").OptionsPages }}
{{ template "optPageFunctions" . }}
{{- end }}

Function __Options_InitDefaults
{{- template "optInitDefaults" }}
FunctionEnd

Function un.__Options_InitDefaults
{{- template "optInitDefaults" }}
FunctionEnd

{{ template "optCli" }}
{{- end }}

Function .onInit
    {{- if (ds "in").TestableInstaller }}
    !insertmacro TestIdInit
    {{- end }}
    !insertmacro SetProductKey "${PRODUCT_KEY_PATH}"
    !insertmacro SetShellContext
    {{- if (ds "in").HasOptions }}
    Call __Options_InitDefaults
    {{- end }}

    {{ if (ds "in").HasPreInit }}
    !insertmacro PreInit
    {{ end }}
    {{- /* Re-apply in case the hook changed the shell context. */}}
    !insertmacro SetShellContext
    !insertmacro DefineRegView

    {{- if (ds "in").HasOptions }}
    {{- /* Before UninstallExisting, which removes the key the values live in. */}}
    ${Option_LoadPersisted}
    {{- end }}

    {{ if and (ds "in").ArchitectureAllow32On64 (not (ds "in").ArchitectureIs64) }}
    !insertmacro ValidateArch32On64 "{{ (ds "in").Architecture }}"
    {{ else }}
    !insertmacro ValidateArch "{{ (ds "in").Architecture }}"
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

    {{- if (ds "in").HasOptions }}
    ${Cli_Init}
    Call __Options_ApplyCli
    {{- end }}

    {{ if (ds "in").HasPostInit }}
    !insertmacro PostInit
    {{ end }}
FunctionEnd

Function un.onInit
    {{- if (ds "in").TestableInstaller }}
    !insertmacro TestIdInit
    {{- end }}
    !insertmacro un.SetProductKey "${PRODUCT_KEY_PATH}"
    !insertmacro un.SetShellContext
    {{- if (ds "in").HasOptions }}
    Call un.__Options_InitDefaults
    ${un.Option_LoadPersisted}
    {{- end }}

    {{ if (ds "in").HasPreUninit }}
    !insertmacro PreUnInit
    {{ end }}
    {{- /* Re-apply in case the hook changed the shell context. */}}
    !insertmacro un.SetShellContext
    !insertmacro un.DefineRegView

    !insertmacro un.SetProductCode "${PRODUCT_ID}"

    {{ if and (ds "in").ArchitectureAllow32On64 (not (ds "in").ArchitectureIs64) }}
    !insertmacro un.ValidateArch32On64 "{{ (ds "in").Architecture }}"
    {{ else }}
    !insertmacro un.ValidateArch "{{ (ds "in").Architecture }}"
    {{ end }}

    !insertmacro un.ValidateMutex "${PRODUCT_ID}Uninstall"

    !insertmacro un.GetRegistrySubKey "${_UNINSTALLER_BASE_KEY}\$product_code" "${UnInstallLocation}" $0

    ${If} "$0" == ""
        !insertmacro LogError "No install exists."
        MessageBox MB_ICONSTOP "No install exists." /SD IDOK
        Abort
    ${EndIf}

    StrCpy $INSTDIR "$0"

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
        # If the component is selected, select all dependencies
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
  !insertmacro un.SetShellContext
  !insertmacro un.DefineRegView

  !insertmacro RemoveComponents

  !insertmacro un.RemoveRegistryKey "${_UNINSTALLER_BASE_KEY}\$product_code"
  {{- if (ds "in").HasOptions }}
  !insertmacro un.RemoveRegistryKey "${REG_KEY}\Options"
  {{- end }}
  !insertmacro un.RemoveRegistryKey "${REG_KEY}"

  ;Remove the uninstaller itself.
  SetFileAttributes "$INSTDIR\${UNINSTALLER_NAME}" NORMAL
  Delete "$INSTDIR\${UNINSTALLER_NAME}"
  ; Remove if empty
  RMDir "$INSTDIR"

SectionEnd
