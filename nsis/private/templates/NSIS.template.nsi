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

{{- /* BEGIN shortcuts: state */}}
{{- if (ds "in").HasShortcuts }}
!include Shortcut.nsh
Var __shortcuts_done
Var __shortcuts_any
Var __shortcuts_has_sm
Var __shortcuts_has_dt
Var __shortcuts_do_sm
Var __shortcuts_do_dt
Var __shortcuts_do_path
Var __shortcuts_comp
; <product key>\Shortcuts\<component>: where the component's links are recorded.
Var __shortcuts_key
Var __shortcuts_link
Var __shortcuts_n
Var __shortcuts_d
{{- end }}
{{- /* END shortcuts: state */}}

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
!insertmacro MUI_PAGE_FINISH

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
{{- if or (eq .Control "file_request") (eq .Control "dir_request") }}
Var __hnd_{{.Page}}_{{.Key}}_b
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
{{- if and (eq .Opt.Control "date") (eq .Opt.Default "") }}
    Push "{{.Opt.Min}}"
    Push "{{.Opt.Max}}"
    Call {{.Prefix}}Option_Today
    Pop ${{.Opt.Var}}
{{- else }}
    StrCpy ${{.Opt.Var}} "{{ template "nsd" .Opt.Default }}"
{{- end }}
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
{{- else if eq .Control "combobox" }}
    ${NSD_CreateComboBox} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    {{- range .Choices }}
    ${NSD_CB_AddString} {{$h}} "{{ template "nsq" . }}"
    {{- end }}
    {{- if .MaxLength }}
    SendMessage {{$h}} ${CB_LIMITTEXT} {{.MaxLength}} 0
    {{- end }}
    ${NSD_SetText} {{$h}} "${{ .Var }}"
{{- else if eq .Control "richedit" }}
    ${NSD_CreateRichEdit} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    Push "${{ .Var }}"
    Call Option_Unescape
    Pop $0
    ${NSD_SetText} {{$h}} "$0"
{{- else if or (eq .Control "file_request") (eq .Control "dir_request") }}
    ${NSD_CreateText} {{.X}} {{.ControlY}}u {{.TextWidth}} {{.ControlHeight}}u "${{ .Var }}"
    Pop {{$h}}
    ${NSD_CreateButton} {{.BrowseX}} {{.ControlY}}u {{.BrowseWidth}} {{.ControlHeight}}u "Browse..."
    Pop {{$h}}_b
    ${NSD_OnClick} {{$h}}_b __Page_{{.Page}}_Browse_{{.Key}}
{{- else if or (eq .Control "listbox") (eq .Control "sorted_listbox") }}
    {{- $cls := "ListBox" }}
    {{- if eq .Control "sorted_listbox" }}{{ $cls = "SortedListBox" }}{{ end }}
    {{- if .MultiSelect }}
    nsDialogs::CreateControl ${__NSD_{{$cls}}_CLASS} "${__NSD_{{$cls}}_STYLE}|${LBS_EXTENDEDSEL}" ${__NSD_{{$cls}}_EXSTYLE} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    {{- else }}
    ${NSD_Create{{$cls}}} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    {{- end }}
    Pop {{$h}}
    {{- range .Choices }}
    ${NSD_LB_AddString} {{$h}} "{{ template "nsq" . }}"
    {{- end }}
    {{- if .MultiSelect }}
    {{- $o := . }}
    {{- range .Choices }}
    Push "${{ $o.Var }}"
    Push "{{ template "nsq" . }}"
    Call Option_ListHas
    Pop $0
    ${If} $0 == 1
        ${NSD_LB_FindStringExact} {{$h}} "{{ template "nsq" . }}" $0
        SendMessage {{$h}} ${LB_SETSEL} 1 $0
    ${EndIf}
    {{- end }}
    {{- else }}
    ${NSD_LB_FindStringExact} {{$h}} "${{ .Var }}" $0
    SendMessage {{$h}} ${LB_SETCURSEL} $0 0
    {{- end }}
{{- else if eq .Control "date" }}
    ${NSD_InitCommonControlsEx} ${ICC_DATE_CLASSES}
    ${NSD_CreateDatePicker} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    {{- if or .Min .Max }}
    Push {{$h}}
    Push "{{.Min}}"
    Push "{{.Max}}"
    Call Option_UiSetDateRange
    {{- end }}
    Push {{$h}}
    Push "${{ .Var }}"
    Call Option_UiSetDate
{{- else if eq .Control "ip_address" }}
    ${NSD_InitCommonControl_IPAddress}
    ${NSD_CreateIPAddress} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    Push {{$h}}
    Push "${{ .Var }}"
    Call Option_UiSetIp
{{- else if eq .Control "net_address" }}
    ${NSD_InitCommonControl_NetAddress}
    ${NSD_CreateNetAddress} {{.X}} {{.ControlY}}u {{.Width}} {{.ControlHeight}}u ""
    Pop {{$h}}
    SendMessage {{$h}} ${NCM_SETALLOWTYPE} {{.NetStringFlags}} 0
    ${NSD_SetText} {{$h}} "${{ .Var }}"
{{- end }}
{{- if .Description }}
    ${NSD_CreateLabel} {{.X}} {{.DescriptionY}}u {{.Width}} {{.DescriptionHeight}}u "{{ template "nsq" .Description }}"
    Pop $0
{{- end }}
{{end}}

{{- /* Reads the control into $__opt_chk_val (raw); checkboxes are handled apart. */}}
{{define "optRead"}}
{{- $h := printf "$__hnd_%s_%s" .Page .Key }}
{{- if or (eq .Control "number") (eq .Control "text") (eq .Control "password") (eq .Control "droplist") (eq .Control "combobox") (eq .Control "file_request") (eq .Control "dir_request") (eq .Control "net_address") }}
    ${NSD_GetText} {{$h}} $__opt_chk_val
{{- else if eq .Control "richedit" }}
    ${NSD_GetText} {{$h}} $__opt_chk_val
    Push $__opt_chk_val
    Call Option_Escape
    Pop $__opt_chk_val
{{- else if eq .Control "date" }}
    Push {{$h}}
    Call Option_UiGetDate
    Pop $__opt_chk_val
{{- else if eq .Control "ip_address" }}
    Push {{$h}}
    Call Option_UiGetIp
    Pop $__opt_chk_val
{{- else if or (eq .Control "listbox") (eq .Control "sorted_listbox") }}
    {{- if .MultiSelect }}
    StrCpy $__opt_chk_val ""
    {{- range .Choices }}
    ${NSD_LB_FindStringExact} {{$h}} "{{ template "nsq" . }}" $0
    ${If} $0 <> -1
        SendMessage {{$h}} ${LB_GETSEL} $0 0 $1
        ${If} $1 > 0
            ${If} $__opt_chk_val == ""
                StrCpy $__opt_chk_val "{{ template "nsq" . }}"
            ${Else}
                StrCpy $__opt_chk_val "$__opt_chk_val|{{ template "nsq" . }}"
            ${EndIf}
        ${EndIf}
    ${EndIf}
    {{- end }}
    {{- else }}
    ${NSD_LB_GetSelection} {{$h}} $__opt_chk_val
    {{- end }}
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
{{- else if eq .Control "combobox" }}
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
{{- else if eq .Control "richedit" }}
    ${If} $__opt_chk_val != ""
        Push $__opt_chk_val
        Call Option_Unescape
        Pop $0
        ${If} ${Errors}
            StrCpy $__opt_chk_err "must be on one line; use \n for line breaks and \\ for a backslash"
        {{- if .MaxLength }}
        ${Else}
            StrLen $0 $__opt_chk_val
            ${If} $0 > {{.MaxLength}}
                StrCpy $__opt_chk_err "must be at most {{.MaxLength}} characters"
            ${EndIf}
        {{- end }}
        ${EndIf}
    {{- if .Required }}
    ${ElseIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    {{- end }}
    ${EndIf}
{{- else if or (eq .Control "file_request") (eq .Control "dir_request") }}
    ${If} $__opt_chk_val != ""
        StrCpy $0 $__opt_chk_val 2
        StrCpy $1 $__opt_chk_val 1 1
        StrCpy $2 $__opt_chk_val 1 2
        StrCpy $3 0
        ${If} $0 == "\\"
            StrCpy $3 1
        ${ElseIf} $1 == ":"
            ${If} $2 == "\"
            ${OrIf} $2 == "/"
                StrCpy $3 1
            ${EndIf}
        ${EndIf}
        ${If} $3 == 0
            StrCpy $__opt_chk_err "must be an absolute path"
        {{- if .MustExist }}
        {{- if eq .Control "dir_request" }}
        ${ElseIfNot} ${FileExists} "$__opt_chk_val\*.*"
            StrCpy $__opt_chk_err "must be an existing folder"
        {{- else }}
        ${ElseIfNot} ${FileExists} "$__opt_chk_val"
            StrCpy $__opt_chk_err "must be an existing file"
        ${ElseIf} ${FileExists} "$__opt_chk_val\*.*"
            StrCpy $__opt_chk_err "must be an existing file"
        {{- end }}
        {{- end }}
        ${EndIf}
    {{- if .Required }}
    ${ElseIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    {{- end }}
    ${EndIf}
{{- else if or (eq .Control "listbox") (eq .Control "sorted_listbox") }}
    {{- if .MultiSelect }}
    ${If} $__opt_chk_val != ""
        Push $__opt_chk_val
        Call Option_ListCount
        Pop $1
        StrCpy $0 ""
        StrCpy $2 0
        {{- range .Choices }}
        Push $__opt_chk_val
        Push "{{ template "nsq" . }}"
        Call Option_ListHas
        Pop $3
        ${If} $3 == 1
            IntOp $2 $2 + 1
            ${If} $0 == ""
                StrCpy $0 "{{ template "nsq" . }}"
            ${Else}
                StrCpy $0 "$0|{{ template "nsq" . }}"
            ${EndIf}
        ${EndIf}
        {{- end }}
        ${If} $1 <> $2
            StrCpy $__opt_chk_err "must be a '|' separated list of distinct values from: {{ range $i, $c := .Choices }}{{ if $i }}, {{ end }}{{ template "nsq" $c }}{{ end }}"
        ${Else}
            StrCpy $__opt_chk_val $0
        ${EndIf}
    {{- if .Required }}
    ${ElseIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    {{- end }}
    ${EndIf}
    {{- else }}
    StrCpy $__opt_chk_err "must be one of: {{ range $i, $c := .Choices }}{{ if $i }}, {{ end }}{{ template "nsq" $c }}{{ end }}"
    {{- range .Choices }}
    ${If} $__opt_chk_val == "{{ template "nsq" . }}"
        StrCpy $__opt_chk_val "{{ template "nsq" . }}"
        StrCpy $__opt_chk_err ""
    ${EndIf}
    {{- end }}
    {{- end }}
{{- else if eq .Control "date" }}
    ClearErrors
    ${ParseDate} $__opt_chk_val $0
    ${If} ${Errors}
        StrCpy $__opt_chk_err "must be a date (YYYY-MM-DD)"
    ${Else}
        StrCpy $__opt_chk_val $0
        {{- if or .Min .Max }}
        StrCpy $1 $0 4
        StrCpy $2 $0 2 5
        StrCpy $3 $0 2 8
        StrCpy $1 "$1$2$3"
        {{- end }}
        {{- if .Min }}
        ${If} $1 < {{ .Min | strings.ReplaceAll "-" "" }}
            StrCpy $__opt_chk_err "must not be before {{.Min}}"
        ${EndIf}
        {{- end }}
        {{- if .Max }}
        ${If} $1 > {{ .Max | strings.ReplaceAll "-" "" }}
            StrCpy $__opt_chk_err "must not be after {{.Max}}"
        ${EndIf}
        {{- end }}
    ${EndIf}
{{- else if eq .Control "ip_address" }}
    ${If} $__opt_chk_val != ""
        ClearErrors
        ${ParseIPv4} $__opt_chk_val $0
        ${If} ${Errors}
            StrCpy $__opt_chk_err "must be a complete IPv4 address (a.b.c.d)"
        ${Else}
            StrCpy $__opt_chk_val $0
        ${EndIf}
    {{- if .Required }}
    ${ElseIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    {{- end }}
    ${EndIf}
{{- else if eq .Control "net_address" }}
    ${If} $__opt_chk_val != ""
        ClearErrors
        ${ParseNetAddress} $__opt_chk_val {{.NetStringFlags}} $0
        ${If} ${Errors}
            StrCpy $__opt_chk_err "must be a valid network address ({{ if .AddressTypes }}{{ range $i, $t := .AddressTypes }}{{ if $i }}, {{ end }}{{$t}}{{ end }}{{ else }}ipv4, ipv6, dns{{ end }})"
        ${EndIf}
    {{- if .Required }}
    ${ElseIf} $__opt_chk_enabled == "1"
        StrCpy $__opt_chk_err "is required"
    {{- end }}
    ${EndIf}
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
{{- if or (eq .Control "file_request") (eq .Control "dir_request") }}
    EnableWindow {{$h}}_b $0
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
{{- $prefix := . }}
{{- range (ds "in").Options }}
{{- template "optDefault" (coll.Dict "Opt" . "Prefix" $prefix) }}
{{- end }}
{{end}}

{{- /* The Browse button callback of file and directory options. */}}
{{define "optBrowse"}}
{{- if or (eq .Control "file_request") (eq .Control "dir_request") }}
Function __Page_{{.Page}}_Browse_{{.Key}}
    Exch $0
    Pop $0
    Push $0
    Push $1
    ${NSD_GetText} $__hnd_{{.Page}}_{{.Key}} $0
    {{- if eq .Control "file_request" }}
    nsDialogs::SelectFileDialog {{ if .Save }}save{{ else }}open{{ end }} "$0" "{{ template "nsq" .Filter }}"
    Pop $1
    ${If} $1 != ""
    {{- else }}
    nsDialogs::SelectFolderDialog "{{ template "nsq" .Label }}" "$0"
    Pop $1
    ${If} $1 != "error"
    ${AndIf} $1 != ""
    {{- end }}
        ${NSD_SetText} $__hnd_{{.Page}}_{{.Key}} "$1"
    ${EndIf}
    Pop $1
    Pop $0
FunctionEnd
{{- end }}
{{end}}

{{define "optPageFunctions"}}
{{- $page := . }}
{{- range .Options }}
{{- template "optBrowse" . }}
Function __Opt_Check_{{.Page}}_{{.Key}}
    Push $0
    Push $1
    Push $2
    Push $3
    StrCpy $__opt_chk_err ""
{{- template "optCheckBody" . }}
    Pop $3
    Pop $2
    Pop $1
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
        ${If} $1 == ""
        ${OrIf} $1 == "components"
        ${OrIf} $1 == "insttype"
            StrCpy $__opt_chk_enabled 1
        ${EndIf}
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
{{- if .Secret }}
    {{- /* An answer file written by /HELP leaves secrets empty. */}}
    ${AndIf} $__opt_chk_val != ""
{{- end }}
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

{{- if .HasShortcuts }}
Push "{{.Name}}"
Call un.__Shortcuts_Remove
{{- end }}

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
{{- template "optInitDefaults" "" }}
FunctionEnd

Function un.__Options_InitDefaults
{{- template "optInitDefaults" "un." }}
FunctionEnd

{{ template "optCli" }}
{{- end }}

; ----------------------------------------------------
; BEGIN command line: /COMPONENTS, /INSTTYPE and /HELP
; ----------------------------------------------------
{{- $cli := (ds "in").Cli }}

Var __cmp_name
Var __cmp_val
Var __cmp_rest
Var __cmp_tok
Var __cmp_more
{{- range $cli.Components }}
Var __cmp_w_{{.Name}}
{{- end }}

{{- /* Desired state per component: 0 unselected, 1 selected, 2 explicitly deselected. */}}
Function __Components_Mark
{{- range $cli.Components }}
    ${If} $__cmp_name == "{{.Name}}"
{{- if .Required }}
        ${If} $__cmp_val = 2
            ${Cli_Fail} "Component {{.Name}} is required and cannot be deselected."
        ${EndIf}
{{- end }}
        StrCpy $__cmp_w_{{.Name}} $__cmp_val
        Return
    ${EndIf}
{{- end }}
{{- range $cli.Groups }}
    ${If} $__cmp_name == "{{.Name}}"
{{- range .Members }}
{{- if .Required }}
        ${If} $__cmp_val = 2
            ${Cli_Fail} "Component {{.Name}} is required and cannot be deselected."
        ${EndIf}
{{- end }}
        StrCpy $__cmp_w_{{.Name}} $__cmp_val
{{- end }}
        Return
    ${EndIf}
{{- end }}
    ${Cli_Fail} "Unknown component: $__cmp_name"
FunctionEnd

{{- /* Splits the next entry off $__cmp_rest into $__cmp_tok; $__cmp_more is 1 when more follow. */}}
Function __Components_Next
    Push $0
    Push $1
    StrCpy $0 0
    ${Do}
        StrCpy $1 $__cmp_rest 1 $0
        ${If} $1 == ""
        ${OrIf} $1 == ","
            ${Break}
        ${EndIf}
        IntOp $0 $0 + 1
    ${Loop}
    StrCpy $__cmp_tok $__cmp_rest $0
    ${If} $1 == ","
        IntOp $0 $0 + 1
        StrCpy $__cmp_rest $__cmp_rest "" $0
        StrCpy $__cmp_more 1
    ${Else}
        StrCpy $__cmp_rest ""
        StrCpy $__cmp_more 0
    ${EndIf}
    StrCpy $1 $__cmp_tok 1
    ${While} $1 == " "
        StrCpy $__cmp_tok $__cmp_tok "" 1
        StrCpy $1 $__cmp_tok 1
    ${EndWhile}
    StrCpy $1 $__cmp_tok 1 -1
    ${While} $1 == " "
        StrCpy $__cmp_tok $__cmp_tok -1
        StrCpy $1 $__cmp_tok 1 -1
    ${EndWhile}
    Pop $1
    Pop $0
FunctionEnd

{{- /* /COMPONENTS= and /INSTTYPE= (the command line wins over [setup] of /OPTIONS=). */}}
Function __Components_ApplyCli
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    StrCpy $0 ""
    StrCpy $1 ""
    ClearErrors
    ${Cli_GetArgValue} "/OPTIONS" $2
    ${IfNot} ${Errors}
        ${IfNot} ${FileExists} "$2"
            ${Cli_Fail} "The options file given with /OPTIONS= does not exist."
        ${EndIf}
        ReadINIStr $0 "$2" "setup" "components"
        ReadINIStr $1 "$2" "setup" "insttype"
    ${EndIf}
    ${If} ${Cli_HasArg} "/COMPONENTS"
        ClearErrors
        ${Cli_GetArgValue} "/COMPONENTS" $2
        ${If} ${Errors}
        ${OrIf} $2 == ""
            ${Cli_Fail} "/COMPONENTS= needs a list of component names."
        ${EndIf}
        StrCpy $0 $2
    ${EndIf}
    ${If} ${Cli_HasArg} "/INSTTYPE"
        ClearErrors
        ${Cli_GetArgValue} "/INSTTYPE" $2
        ${If} ${Errors}
        ${OrIf} $2 == ""
            ${Cli_Fail} "/INSTTYPE= needs an install type name."
        ${EndIf}
        StrCpy $1 $2
    ${EndIf}
    ${If} $0 == ""
    ${AndIf} $1 == ""
        Goto __cmp_done
    ${EndIf}

    StrCpy $4 ""
    ${If} $1 != ""
{{- range $cli.InstTypes }}
        ${If} $1 == "{{ template "nsq" .Name }}"
            StrCpy $4 {{.Index}}
        ${EndIf}
{{- end }}
        ${If} $4 == ""
            ${Cli_Fail} "Unknown install type: $1"
        ${EndIf}
    ${EndIf}

    StrCpy $5 0
    StrCpy $6 0
    StrCpy $__cmp_rest $0
    ${Do}
        Call __Components_Next
        ${If} $__cmp_tok != ""
            StrCpy $2 $__cmp_tok 1
            ${If} $2 == "+"
            ${OrIf} $2 == "-"
                IntOp $5 $5 + 1
            ${Else}
                IntOp $6 $6 + 1
            ${EndIf}
        ${EndIf}
        ${If} $__cmp_more = 0
            ${Break}
        ${EndIf}
    ${Loop}
    ${If} $5 > 0
    ${AndIf} $6 > 0
        ${Cli_Fail} "/COMPONENTS cannot mix entries with and without a + or - prefix."
    ${EndIf}
    ${If} $6 > 0
    ${AndIf} $4 != ""
        ${Cli_Fail} "/INSTTYPE cannot be combined with an absolute /COMPONENTS list; prefix the entries with + or -."
    ${EndIf}
    {{- /* $3: 1 when the list is absolute. */}}
    StrCpy $3 0
    ${If} $6 > 0
        StrCpy $3 1
    ${EndIf}

    ${If} $4 != ""
        IntOp $2 $4 - 1
        SetCurInstType $2
    ${EndIf}

{{- range $cli.Components }}
{{- $n := .Name }}
    ${If} $3 = 1
        StrCpy $__cmp_w_{{.Name}} 0
    ${ElseIf} $4 != ""
{{- if .Required }}
        StrCpy $__cmp_w_{{.Name}} 1
{{- else }}
        StrCpy $__cmp_w_{{.Name}} 0
{{- range .InstTypeIdx }}
        ${If} $4 = {{.}}
            StrCpy $__cmp_w_{{$n}} 1
        ${EndIf}
{{- end }}
{{- end }}
    ${Else}
        SectionGetFlags {{printf "${%v}" .Name}} $2
        IntOp $2 $2 & ${SF_SELECTED}
        StrCpy $__cmp_w_{{.Name}} $2
    ${EndIf}
{{- end }}

    StrCpy $__cmp_rest $0
    ${Do}
        Call __Components_Next
        ${If} $__cmp_tok != ""
            StrCpy $__cmp_val 1
            ${If} $3 = 0
                StrCpy $2 $__cmp_tok 1
                ${If} $2 == "-"
                    StrCpy $__cmp_val 2
                ${EndIf}
                StrCpy $__cmp_tok $__cmp_tok "" 1
            ${EndIf}
            StrCpy $__cmp_name $__cmp_tok
            Call __Components_Mark
        ${EndIf}
        ${If} $__cmp_more = 0
            ${Break}
        ${EndIf}
    ${Loop}

{{- range $cli.Components }}
{{- if .Required }}
    StrCpy $__cmp_w_{{.Name}} 1
{{- end }}
{{- end }}
{{- /* The closure is precomputed, so a single pass is enough. */}}
{{- range $cli.Components }}
{{- if .AllDeps }}
{{- $n := .Name }}
    ${If} $__cmp_w_{{.Name}} = 1
{{- range .AllDeps }}
        ${If} $__cmp_w_{{.}} = 2
            ${Cli_Fail} "Cannot deselect component {{.}}: component {{$n}} depends on it."
        ${EndIf}
        StrCpy $__cmp_w_{{.}} 1
{{- end }}
    ${EndIf}
{{- end }}
{{- end }}

{{- range $cli.Components }}
    StrCpy $SelectRefCnt_{{.Name}} 0
{{- end }}
{{- range $cli.Components }}
    ${If} $__cmp_w_{{.Name}} = 1
        !insertmacro SelectSection {{printf "${%v}" .Name}}
        StrCpy $SectionSelected_{{.Name}} 1
        StrCpy $SelectedExplicit_{{.Name}} 1
{{- range .AllDeps }}
        IntOp $SelectRefCnt_{{.}} $SelectRefCnt_{{.}} + 1
{{- end }}
    ${Else}
        !insertmacro UnselectSection {{printf "${%v}" .Name}}
        StrCpy $SectionSelected_{{.Name}} 0
        StrCpy $SelectedExplicit_{{.Name}} 0
    ${EndIf}
{{- end }}
    __cmp_done:
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; ---- /HELP ----

Var __help_fh
Var __help_buf

!macro __HelpW TEXT
    Push `${TEXT}`
    Call __Help_W
!macroend
!macro __HelpNL
    Push "$\r$\n"
    Call __Help_W
!macroend

{{- /* Output goes to the file, else the console, else a buffer shown in a message box. */}}
Function __Help_W
    Exch $0
    ${If} $__help_fh != ""
        FileWriteUTF16LE $__help_fh $0
    ${ElseIf} $__help_buf != ""
        System::Call 'kernel32::lstrcatW(p $__help_buf, w r0)'
    ${Else}
        ${Console_Write} "$0"
    ${EndIf}
    Pop $0
FunctionEnd

Function __Help_TextUsage
    !insertmacro __HelpW "Usage:"
    !insertmacro __HelpNL
{{- range $cli.Usage }}
    !insertmacro __HelpW "{{ template "nsq" .Text }}"
    !insertmacro __HelpNL
{{- end }}
    !insertmacro __HelpNL
FunctionEnd

Function __Help_TextOptions
    !insertmacro __HelpW "Options:"
    !insertmacro __HelpNL
{{- range $cli.Pages }}
{{- range .Options }}
    !insertmacro __HelpW "{{ template "nsq" .TextPrefix }}"
{{- if .Secret }}
    !insertmacro __HelpW "<secret>"
{{- else }}
    !insertmacro __HelpW "${{.Var}}"
{{- end }}
    !insertmacro __HelpNL
    !insertmacro __HelpW "{{ template "nsq" .TextDetail }}"
    !insertmacro __HelpNL
{{- if .TextDescription }}
    !insertmacro __HelpW "{{ template "nsq" .TextDescription }}"
    !insertmacro __HelpNL
{{- end }}
{{- end }}
{{- end }}
{{- if not $cli.HasOptions }}
    !insertmacro __HelpW "  (none)"
    !insertmacro __HelpNL
{{- end }}
    !insertmacro __HelpNL
FunctionEnd

Function __Help_TextComponents
    Push $0
    !insertmacro __HelpW "Components:"
    !insertmacro __HelpNL
{{- range $cli.Components }}
    !insertmacro __HelpW "{{ template "nsq" .TextPrefix }}"
    SectionGetFlags {{printf "${%v}" .Name}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    ${If} $0 = 1
        !insertmacro __HelpW "yes"
    ${Else}
        !insertmacro __HelpW "no"
    ${EndIf}
    !insertmacro __HelpW "{{ template "nsq" .TextSuffix }}"
    !insertmacro __HelpNL
{{- end }}
    !insertmacro __HelpNL
    Pop $0
FunctionEnd

Function __Help_TextInstTypes
    !insertmacro __HelpW "Install types:"
    !insertmacro __HelpNL
{{- range $cli.InstTypes }}
    !insertmacro __HelpW "{{ template "nsq" .Text }}"
    !insertmacro __HelpNL
{{- end }}
    !insertmacro __HelpNL
FunctionEnd

Function __Help_IniUsage
    !insertmacro __HelpW "; usage:"
    !insertmacro __HelpNL
{{- range $cli.Usage }}
    !insertmacro __HelpW "{{ template "nsq" .Ini }}"
    !insertmacro __HelpNL
{{- end }}
FunctionEnd

Function __Help_IniOptions
{{- range $cli.Pages }}
{{- if .Options }}
    !insertmacro __HelpW "[{{.Name}}]"
    !insertmacro __HelpNL
{{- range .Options }}
    !insertmacro __HelpW "{{ template "nsq" .IniComment }}"
    !insertmacro __HelpNL
    !insertmacro __HelpW "{{.Key}}="
{{- if not .Secret }}
    !insertmacro __HelpW "${{.Var}}"
{{- end }}
    !insertmacro __HelpNL
{{- end }}
{{- end }}
{{- end }}
FunctionEnd

Function __Help_IniInstTypes
    !insertmacro __HelpW "; insttypes: {{ range $i, $t := $cli.InstTypes }}{{ if $i }}, {{ end }}{{ template "nsq" $t.Name }}{{ end }}"
    !insertmacro __HelpNL
    !insertmacro __HelpW "insttype="
    !insertmacro __HelpNL
FunctionEnd

Function __Help_IniComponents
    Push $0
    Push $1
    !insertmacro __HelpW "; components: "
{{- range $i, $c := $cli.Components }}
{{- if $i }}
    !insertmacro __HelpW " | "
{{- end }}
    !insertmacro __HelpW "{{ template "nsq" $c.IniPiece }}"
{{- end }}
    !insertmacro __HelpNL
    !insertmacro __HelpW "components="
    StrCpy $1 ""
{{- range $cli.Components }}
    SectionGetFlags {{printf "${%v}" .Name}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    ${If} $0 = 1
        ${If} $1 != ""
            !insertmacro __HelpW ","
        ${EndIf}
        StrCpy $1 1
        !insertmacro __HelpW "{{.Name}}"
    ${EndIf}
{{- end }}
    !insertmacro __HelpNL
    Pop $1
    Pop $0
FunctionEnd

{{- /* Topic in $0, format in $1; the output sink is already open. */}}
Function __Help_Emit
    ${If} $1 == "ini"
        !insertmacro __HelpW "; {{ template "nsq" $cli.Heading }} - generated by /HELP /FORMAT=ini"
        !insertmacro __HelpNL
        ${If} $0 == "all"
        ${OrIf} $0 == "usage"
            Call __Help_IniUsage
        ${EndIf}
        ${If} $0 == "all"
        ${OrIf} $0 == "components"
        ${OrIf} $0 == "insttypes"
            !insertmacro __HelpW "[setup]"
            !insertmacro __HelpNL
            ${If} $0 == "all"
            ${OrIf} $0 == "insttypes"
                Call __Help_IniInstTypes
            ${EndIf}
            ${If} $0 == "all"
            ${OrIf} $0 == "components"
                Call __Help_IniComponents
            ${EndIf}
        ${EndIf}
        ${If} $0 == "all"
        ${OrIf} $0 == "options"
            Call __Help_IniOptions
        ${EndIf}
    ${Else}
        !insertmacro __HelpW "{{ template "nsq" $cli.Heading }}"
        !insertmacro __HelpNL
        !insertmacro __HelpNL
        ${If} $0 == "all"
        ${OrIf} $0 == "usage"
            Call __Help_TextUsage
        ${EndIf}
        ${If} $0 == "all"
        ${OrIf} $0 == "options"
            Call __Help_TextOptions
        ${EndIf}
        ${If} $0 == "all"
        ${OrIf} $0 == "components"
            Call __Help_TextComponents
        ${EndIf}
        ${If} $0 == "all"
        ${OrIf} $0 == "insttypes"
            Call __Help_TextInstTypes
        ${EndIf}
    ${EndIf}
FunctionEnd

{{- /* Never returns. */}}
Function __Help_Run
    StrCpy $0 "all"
    ${If} ${Cli_HasArg} "/HELP"
        ClearErrors
        ${Cli_GetArgValue} "/HELP" $1
        ${IfNot} ${Errors}
        ${AndIf} $1 != ""
            StrCpy $0 $1
        ${EndIf}
    ${EndIf}
    ${If} $0 != "all"
    ${AndIf} $0 != "usage"
    ${AndIf} $0 != "options"
    ${AndIf} $0 != "components"
    ${AndIf} $0 != "insttypes"
        ${Cli_Fail} "Unknown help topic: $0. Use usage, options, components, insttypes or all."
    ${EndIf}
    StrCpy $2 "text"
    ${If} ${Cli_HasArg} "/FORMAT"
        ClearErrors
        ${Cli_GetArgValue} "/FORMAT" $2
        ${If} ${Errors}
            ${Cli_Fail} "/FORMAT= needs a value. Use text or ini."
        ${EndIf}
        ${If} $2 != "text"
        ${AndIf} $2 != "ini"
            ${Cli_Fail} "Unknown /FORMAT value. Use text or ini."
        ${EndIf}
    ${EndIf}
    StrCpy $3 ""
    ${If} ${Cli_HasArg} "/HELP-OUT"
        ClearErrors
        ${Cli_GetArgValue} "/HELP-OUT" $3
        ${If} ${Errors}
        ${OrIf} $3 == ""
            ${Cli_Fail} "/HELP-OUT= needs a file name."
        ${EndIf}
        ClearErrors
        FileOpen $__help_fh "$3" w
        ${If} ${Errors}
            ${Cli_Fail} "Could not write the help output to $3."
        ${EndIf}
        FileWriteWord $__help_fh 65279
    ${Else}
        ${IfNot} ${Console_IsAvailable}
            System::Alloc 2097152
            Pop $__help_buf
        ${EndIf}
    ${EndIf}
    StrCpy $1 $2
    Call __Help_Emit
    ${If} $__help_fh != ""
        FileClose $__help_fh
    ${ElseIf} $__help_buf != ""
        IfSilent +2
        System::Call 'user32::MessageBoxW(p 0, p $__help_buf, w "${PRODUCT}", i 0x40)'
        System::Free $__help_buf
    ${EndIf}
    SetErrorLevel 0
    Quit
FunctionEnd

{{- /* Runs early in .onInit: reports the effective state, so /COMPONENTS and the options apply first. */}}
Function __Help_Request
    ${If} ${Cli_HasArg} "/HELP"
    ${OrIf} ${Cli_HasArg} "/?"
        Push $0
        Push $1
        Push $2
        Push $3
        {{- range (ds "in").Components }}
        {{- template "sectionVarInit" .}}
        {{- end}}
        {{- range (ds "in").ComponentGroups }}
        {{- template "sectionGroupVarInit" .}}
        {{- end}}
        Call __Components_ApplyCli
        {{- if (ds "in").HasOptions }}
        Call __Options_ApplyCli
        {{- end }}
        Call __Help_Run
    ${EndIf}
FunctionEnd
; ----------------------------------------------------
; END command line
; ----------------------------------------------------


{{- /* BEGIN shortcuts: functions */}}
{{- /* Escapes a string for use inside an NSIS `...` literal. */}}
{{define "scq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "`" "$\\`" | strings.ReplaceAll "\n" "$\\n" }}{{end}}

{{define "shortcutCreate"}}
            Call __Shortcuts_Prepare
            ${Shortcut_Create} "$__shortcuts_link" `$INSTDIR\{{ template "scq" .TargetRelative }}` `{{ template "scq" .Arguments }}` `{{ if .IconRelative }}$INSTDIR\{{ template "scq" .IconRelative }}{{ end }}` {{ .IconIndex }} `{{ template "scq" .Description }}`
            Call __Shortcuts_Record
{{end}}

{{- if (ds "in").HasShortcuts }}
; ----------------------------------------------------
; Shortcuts
; ----------------------------------------------------

; Sets $__shortcuts_any, _has_sm and _has_dt from the installed components.
Function __Shortcuts_Scan
    Push $0
    StrCpy $__shortcuts_any 0
    StrCpy $__shortcuts_has_sm 0
    StrCpy $__shortcuts_has_dt 0
    {{- range (ds "in").ShortcutComponents }}
    SectionGetFlags {{printf "${%v}" .Name}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    ${If} $0 <> 0
        StrCpy $__shortcuts_any 1
        {{- if .HasStartMenu }}
        StrCpy $__shortcuts_has_sm 1
        {{- end }}
        {{- if .HasDesktop }}
        StrCpy $__shortcuts_has_dt 1
        {{- end }}
    ${EndIf}
    {{- end }}
    Pop $0
FunctionEnd

; Stack: folder. Pushes 1 for a relative folder without empty, "." or ".." parts.
Function __Shortcuts_FolderValid
    Exch $0
    Push $1
    Push $2
    Push $3
    StrCpy $3 ""
    StrCpy $1 0
    ${Do}
        StrCpy $2 $0 1 $1
        ${If} $2 == ""
        ${OrIf} $2 == "\"
            ${If} $3 == ""
            ${OrIf} $3 == "."
            ${OrIf} $3 == ".."
                StrCpy $0 0
                ${Break}
            ${EndIf}
            StrCpy $3 ""
            ${If} $2 == ""
                StrCpy $0 1
                ${Break}
            ${EndIf}
        ${ElseIf} $2 == ":"
        ${OrIf} $2 == "/"
        ${OrIf} $2 == "*"
        ${OrIf} $2 == "?"
        ${OrIf} $2 == "<"
        ${OrIf} $2 == ">"
        ${OrIf} $2 == "|"
        ${OrIf} $2 == "$\""
            StrCpy $0 0
            ${Break}
        ${Else}
            StrCpy $3 "$3$2"
        ${EndIf}
        IntOp $1 $1 + 1
    ${Loop}
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Leaves $__opt_chk_err empty when the chosen shortcuts can be created.
Function __Shortcuts_Validate
    Push $0
    StrCpy $__opt_chk_err ""
    ${If} shortcuts ${Option_IsSet} enabled
    ${AndIf} shortcuts ${Option_IsSet} start_menu
    ${AndIf} $__shortcuts_has_sm == 1
        Push $__opt_shortcuts_start_menu_folder
        Call __Shortcuts_FolderValid
        Pop $0
        ${If} $0 != 1
            StrCpy $__opt_chk_err "must be a relative folder name without empty, . or .. parts"
        ${EndIf}
    ${EndIf}
    Pop $0
FunctionEnd

Function __Shortcuts_PostCreate
    Push $0
    GetDlgItem $0 $HWNDPARENT 2
    EnableWindow $0 0
    ${If} $__shortcuts_has_sm != 1
        ShowWindow $__hnd_shortcuts_start_menu 0
        ShowWindow $__hnd_shortcuts_start_menu_folder 0
        ShowWindow $__hnd_shortcuts_start_menu_folder_l 0
    ${EndIf}
    ${IfNot} ${FileExists} "$DESKTOP\*.*"
        ${NSD_Uncheck} $__hnd_shortcuts_desktop
        ShowWindow $__hnd_shortcuts_desktop 0
    ${ElseIf} $__shortcuts_has_dt != 1
        ShowWindow $__hnd_shortcuts_desktop 0
    ${EndIf}
    Pop $0
FunctionEnd

; Stack: the link's path in $__shortcuts_link. Records the folders that do not
; exist yet and that creating the link will create.
Function __Shortcuts_Prepare
    Push $0
    Push $1
    Push $2
    Push $__shortcuts_link
    Call _Shortcut_ParentDir
    Pop $1
    StrCpy $0 $1
    StrCpy $2 ""
    ${DoWhile} $0 != ""
        ${If} ${FileExists} "$0\*.*"
            ${Break}
        ${EndIf}
        StrCpy $2 $0
        Push $0
        Call _Shortcut_ParentDir
        Pop $0
    ${Loop}
    ${If} $2 != ""
    ${AndIf} $0 != ""
        !insertmacro SetRegistrySubKeyStr "$__shortcuts_key" "d$__shortcuts_d" "$1"
        !insertmacro SetRegistrySubKeyStr "$__shortcuts_key" "s$__shortcuts_d" "$0"
        IntOp $__shortcuts_d $__shortcuts_d + 1
    ${EndIf}
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

Function __Shortcuts_Record
    ${If} ${FileExists} "$__shortcuts_link"
        !insertmacro SetRegistrySubKeyStr "$__shortcuts_key" "$__shortcuts_n" "$__shortcuts_link"
        IntOp $__shortcuts_n $__shortcuts_n + 1
        !insertmacro LogInfo "Created shortcut $__shortcuts_link"
    ${Else}
        !insertmacro LogWarn "Unable to create shortcut $__shortcuts_link"
    ${EndIf}
FunctionEnd

Function __Shortcuts_CreateAll
    ${If} $__shortcuts_done == "1"
        Return
    ${EndIf}
    StrCpy $__shortcuts_done 1
    Push $0
    !insertmacro SetShellContext
    !insertmacro DefineRegView
    Call __Shortcuts_Scan
    Call __Shortcuts_Validate
    ${If} $__opt_chk_err != ""
        ${Cli_Fail} "Invalid value for option shortcuts.start_menu_folder: $__opt_chk_err"
    ${EndIf}

    StrCpy $__shortcuts_do_sm 0
    StrCpy $__shortcuts_do_dt 0
    StrCpy $__shortcuts_do_path 0
    ${If} shortcuts ${Option_IsSet} enabled
        StrCpy $__shortcuts_do_path 1
        ${If} shortcuts ${Option_IsSet} start_menu
            StrCpy $__shortcuts_do_sm 1
        ${EndIf}
        ${If} shortcuts ${Option_IsSet} desktop
            StrCpy $__shortcuts_do_dt 1
        ${EndIf}
    ${EndIf}
    {{- /* Server Core, service accounts and the like have no desktop. */}}
    ${If} $__shortcuts_do_dt == 1
    ${AndIf} $__shortcuts_has_dt == 1
    ${AndIfNot} ${FileExists} "$DESKTOP\*.*"
        !insertmacro LogWarn "There is no desktop, so no desktop shortcuts are created."
        StrCpy $__shortcuts_do_dt 0
    ${EndIf}

    {{- range (ds "in").ShortcutComponents }}
    SectionGetFlags {{printf "${%v}" .Name}} $0
    IntOp $0 $0 & ${SF_SELECTED}
    ${If} $0 <> 0
        StrCpy $__shortcuts_comp "{{.Name}}"
        !insertmacro GetProductKey $__shortcuts_key
        StrCpy $__shortcuts_key "$__shortcuts_key\Shortcuts\$__shortcuts_comp"
        StrCpy $__shortcuts_n 0
        StrCpy $__shortcuts_d 0
        {{- range .Shortcuts }}
        {{- if .StartMenu }}
        ${If} $__shortcuts_do_sm == 1
            StrCpy $__shortcuts_link `$SMPROGRAMS\$__opt_shortcuts_start_menu_folder{{ if .StartMenuSubfolder }}\{{ template "scq" .StartMenuSubfolder }}{{ end }}\{{ template "scq" .LinkName }}.lnk`
            {{- template "shortcutCreate" . }}
        ${EndIf}
        {{- end }}
        {{- if .Desktop }}
        ${If} $__shortcuts_do_dt == 1
            StrCpy $__shortcuts_link `$DESKTOP\{{ template "scq" .LinkName }}.lnk`
            {{- template "shortcutCreate" . }}
        ${EndIf}
        {{- end }}
        {{- if .Path }}
        ${If} $__shortcuts_do_path == 1
            StrCpy $__shortcuts_link `{{ .LocationPath }}\{{ template "scq" .LinkName }}.lnk`
            {{- template "shortcutCreate" . }}
        ${EndIf}
        {{- end }}
        {{- end }}
    ${EndIf}
    {{- end }}

    !insertmacro _Option_PersistOne shortcuts enabled
    !insertmacro _Option_PersistOne shortcuts start_menu
    !insertmacro _Option_PersistOne shortcuts start_menu_folder
    !insertmacro _Option_PersistOne shortcuts desktop
    Pop $0
FunctionEnd

; Stack: component name. Removes the links recorded for the component that
; still point into $INSTDIR, then the folders that creating them created.
Function un.__Shortcuts_Remove
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    !insertmacro un.GetProductKey $4
    StrCpy $4 "$4\Shortcuts\$0"
    StrCpy $1 0
    ${Do}
        !insertmacro un.GetRegistrySubKey "$4" "$1" $2
        ${If} $2 == ""
            ${Break}
        ${EndIf}
        ${un.Shortcut_RemoveIfOwned} "$2" "$INSTDIR"
        IntOp $1 $1 + 1
    ${Loop}
    StrCpy $1 0
    ${Do}
        !insertmacro un.GetRegistrySubKey "$4" "d$1" $2
        ${If} $2 == ""
            ${Break}
        ${EndIf}
        IntOp $1 $1 + 1
    ${Loop}
    ${While} $1 > 0
        IntOp $1 $1 - 1
        !insertmacro un.GetRegistrySubKey "$4" "d$1" $2
        !insertmacro un.GetRegistrySubKey "$4" "s$1" $3
        ${un.Shortcut_RemoveEmptyDirs} "$2" "$3"
    ${EndWhile}
    !insertmacro un.RemoveRegistryKey "$4"
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; Silent installs never show the Shortcuts page.
Function .onInstSuccess
    ${If} ${Silent}
        Call __Shortcuts_CreateAll
    ${EndIf}
FunctionEnd
{{- end }}
{{- /* END shortcuts: functions */}}

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

    ${Cli_Init}
    Call __Help_Request

    {{ if and (ds "in").ArchitectureAllow32On64 (not (ds "in").ArchitectureIs64) }}
    !insertmacro ValidateArch32On64 "{{ (ds "in").Architecture }}"
    {{ else }}
    !insertmacro ValidateArch "{{ (ds "in").Architecture }}"
    {{ end }}

    !insertmacro ValidateMutex "${PRODUCT_ID}Install"

    !insertmacro SetProductCode "${PRODUCT_ID}"

    Push $0
    {{- range (ds "in").Components }}
    {{- template "sectionVarInit" .}}
    {{- end}}

    {{- range (ds "in").ComponentGroups }}
    {{- template "sectionGroupVarInit" .}}
    {{- end}}

    {{- /* Invalid arguments must fail before the existing install is removed. */}}
    Call __Components_ApplyCli

    {{- if (ds "in").HasOptions }}
    ${Cli_Init}
    Call __Options_ApplyCli
    {{- end }}

    !insertmacro UninstallExisting "${PRODUCT_ID}" $0
    ${If} $0 <> 0
        MessageBox MB_YESNO|MB_ICONSTOP "Failed to uninstall previous, continue anyway?" /SD IDYES IDYES +2
        Abort
    ${EndIf}
    Pop $0

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
