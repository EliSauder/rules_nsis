{{- /* Shortcuts: the code that creates one shortcut. */}}

{{define "shortcutCreate"}}
            Call __Shortcuts_Prepare
            ${Shortcut_Create} "$__shortcuts_link" `$INSTDIR\{{ template "scq" .TargetRelative }}` `{{ template "scq" .Arguments }}` `{{ if .IconRelative }}$INSTDIR\{{ template "scq" .IconRelative }}{{ end }}` {{ .IconIndex }} `{{ template "scq" .Description }}`
            Call __Shortcuts_Record
{{end}}
