{{- /* Options: variables, defaults, pages, validation and the command line. */}}

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
{{- if .Opt.MultiSelect }}
    {{- /* A list option's variable holds the name of the array with its items. */}}
    StrCpy ${{.Opt.Var}} "{{.Opt.Var}}"
    ${Array_Reset} {{.Opt.Var}}
    {{- range $i, $d := .Opt.Default }}
    ${Array_Set} {{$.Opt.Var}} {{$i}} "{{ template "nsq" $d }}"
    {{- end }}
{{- else if and (eq .Opt.Control "date") (eq .Opt.Default "") }}
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
    ${NSD_SetTextLimit} {{$h}} {{if or (eq .Type "int64") (eq .Type "uint64")}}20{{else}}11{{end}}
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
    {{- /* The selected choices go to the array __opt_chk. */}}
    ${Array_Reset} __opt_chk
    {{- range .Choices }}
    ${NSD_LB_FindStringExact} {{$h}} "{{ template "nsq" . }}" $0
    ${If} $0 <> -1
        SendMessage {{$h}} ${LB_GETSEL} $0 0 $1
        ${If} $1 > 0
            ${Array_Length} __opt_chk $1
            ${Array_Set} __opt_chk $1 "{{ template "nsq" . }}"
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
    ${ParseInteger} $__opt_chk_val "{{.Type}}" $0
    ${If} ${Errors}
        StrCpy $__opt_chk_err "must be a whole number"
    ${Else}
        StrCpy $__opt_chk_val $0
        {{- if .Min }}
        Push $0
        Push "{{.Min}}"
        Call CompareInteger
        Pop $1
        ${If} $1 == -1
            StrCpy $__opt_chk_err "must be at least {{.Min}}"
        ${EndIf}
        {{- end }}
        {{- if .Max }}
        Push $0
        Push "{{.Max}}"
        Call CompareInteger
        Pop $1
        ${If} $1 == 1
            StrCpy $__opt_chk_err "must be at most {{.Max}}"
        ${EndIf}
        {{- end }}
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
    {{- /* The items are in the array __opt_chk; the valid ones, in the order of the choices, replace them. */}}
    ${Array_Reset} __opt_chk_out
    Push "__opt_chk"
    Call Option_ListCount
    Pop $1
    ${If} $1 = 1
        Push "__opt_chk"
        Push 0
        Call Option_ListGet
        Pop $0
        ${If} $0 == ""
            ${Array_Clear} __opt_chk
            StrCpy $1 0
        ${EndIf}
    ${EndIf}
    ${If} $1 > 0
        StrCpy $2 0
        {{- range .Choices }}
        Push "__opt_chk"
        Push "{{ template "nsq" . }}"
        Call Option_ListHas
        Pop $3
        ${If} $3 == 1
            ${Array_Set} __opt_chk_out $2 "{{ template "nsq" . }}"
            IntOp $2 $2 + 1
        ${EndIf}
        {{- end }}
        ${If} $1 <> $2
            StrCpy $__opt_chk_err "must be distinct values from: {{ range $i, $c := .Choices }}{{ if $i }}, {{ end }}{{ template "nsq" $c }}{{ end }}"
        ${Else}
            Push "__opt_chk_out"
            Push "__opt_chk"
            Call Option_ArrayCopy
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

{{- /* Stores the checked value: a list option's items are copied into its array. */}}
{{define "optCommit"}}
{{- if .MultiSelect }}
    Push "__opt_chk"
    Push "{{.Var}}"
    Call Option_ArrayCopy
{{- else }}
    StrCpy ${{.Var}} $__opt_chk_val
{{- end }}
{{end}}

{{define "optApplyOne"}}
    StrCpy $__opt_chk_what "{{.Id}}"
    StrCpy $__opt_chk_enabled 1
    Call __Opt_Check_{{.Page}}_{{.Key}}
    ${If} $__opt_chk_err != ""
        ${Cli_Fail} "Invalid value for option {{.Id}}: $__opt_chk_err"
    ${EndIf}
{{- template "optCommit" . }}
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
    ${Ini_Sections} $0 __opt_ini_sections
    ${Array_Length} __opt_ini_sections $1
    StrCpy $2 0
    ${While} $2 < $1
        ${Array_GetAt} __opt_ini_sections $2 $3
        StrCpy $__opt_chk_what $3
        StrCpy $__opt_chk_val ""
        Call __Opt_IniIsKnown
        ${If} $__opt_chk_enabled != 1
            ${Cli_Fail} "Unknown section [$3] in the options file."
        ${EndIf}
        ${Ini_Keys} $0 $3 __opt_ini_keys
        ${Array_Length} __opt_ini_keys $4
        StrCpy $5 0
        ${While} $5 < $4
            ${Array_GetAt} __opt_ini_keys $5 $6
            StrCpy $__opt_chk_what $3
            StrCpy $__opt_chk_val $6
            Call __Opt_IniIsKnown
            ${If} $__opt_chk_enabled != 1
                ${Cli_Fail} "Unknown option [$3] $6 in the options file."
            ${EndIf}
            IntOp $5 $5 + 1
        ${EndWhile}
        IntOp $2 $2 + 1
    ${EndWhile}
    {{- range (ds "in").Options }}
    ClearErrors
{{- if .MultiSelect }}
    ${Ini_ReadList} $0 "{{.Page}}" "{{.Key}}" __opt_chk
{{- else }}
    ${Ini_ReadStr} $0 "{{.Page}}" "{{.Key}}" $__opt_chk_val
{{- end }}
    ${IfNot} ${Errors}
{{- if .Secret }}
    {{- /* An answer file written by /HELP leaves secrets empty. */}}
    ${AndIf} $__opt_chk_val != ""
{{- end }}
{{- template "optApplyOne" . }}
    ${EndIf}
    {{- end }}
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
    {{- /* The values of /O: arguments for list options are collected in arrays first. */}}
    {{- range (ds "in").Options }}
    {{- if .MultiSelect }}
    ${Array_Reset} __optcli_{{.Var}}
    {{- end }}
    {{- end }}
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
{{- if .MultiSelect }}
                {{- /* The option may be repeated: every value is one item. */}}
                ${Array_Length} __optcli_{{.Var}} $5
                ${Array_Set} __optcli_{{.Var}} $5 "$3"
{{- else }}
                StrCpy $__opt_chk_val $3
{{- template "optApplyOne" . }}
{{- end }}
                Goto __cli_next
            ${EndIf}
            {{- end }}
            ${Cli_Fail} "Unknown option: $4"
        ${EndIf}
        __cli_next:
        IntOp $2 $2 + 1
    ${EndWhile}
    {{- range (ds "in").Options }}
    {{- if .MultiSelect }}
    ${Array_Length} __optcli_{{.Var}} $0
    ${If} $0 > 0
        Push "__optcli_{{.Var}}"
        Push "__opt_chk"
        Call Option_ArrayCopy
{{- template "optApplyOne" . }}
    ${EndIf}
    {{- end }}
    {{- end }}
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
{{- template "optCommit" . }}
{{- if .EnabledChain }}
    {{$n}}:
{{- end }}
{{end}}
