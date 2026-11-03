{{- /* Components: the Section and SectionGroup blocks, their variables and their uninstall code. */}}

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

{{- if .AddToPath }}
${un.EnvPath_Remove} "$INSTDIR\{{.Directory}}"
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
{{- range .TreeFiles }}
SetFileAttributes "$INSTDIR\{{$d}}\{{.}}" NORMAL
Delete "$INSTDIR\{{$d}}\{{.}}"
{{- end}}
{{- range .TreeDirectories }}
RMDir "$INSTDIR\{{$d}}\{{.}}"
{{- end}}

RMDir "$INSTDIR\{{$d}}"
{{- else}}
{{- range .Files }}
SetFileAttributes "$INSTDIR\{{ .Name }}" NORMAL
Delete "$INSTDIR\{{ .Name }}"
{{- end}}
{{- range .TreeFiles }}
SetFileAttributes "$INSTDIR\{{.}}" NORMAL
Delete "$INSTDIR\{{.}}"
{{- end}}
{{- range .TreeDirectories }}
RMDir "$INSTDIR\{{.}}"
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

    {{- if .AddToPath }}
    ${EnvPath_Add} "$OUTDIR"
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
