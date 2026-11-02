{{- /* Escaping helpers for strings placed in NSIS string literals. */}}

{{- /* Escapes a string for use inside an NSIS "..." literal, variables included. */}}
{{define "nsq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\n" "$\\n" }}{{end}}

{{- /* Same, but keeps $variables usable (defaults such as $DOCUMENTS). */}}
{{define "nsd"}}{{ . | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\n" "$\\n" }}{{end}}

{{- /* Escapes a string for use inside an NSIS `...` literal. */}}
{{define "scq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "`" "$\\`" | strings.ReplaceAll "\n" "$\\n" }}{{end}}
