{{- /* Escaping helpers for strings placed in NSIS string literals. */}}

{{- /* Escapes a string for use inside an NSIS "..." literal, variables included. */}}
{{define "nsq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\r\n" "$\\r$\\n" | strings.ReplaceAll "\r" "$\\r$\\n" | strings.ReplaceAll "\n" "$\\r$\\n" }}{{end}}

{{- /* Same, but keeps $variables usable (defaults such as $DOCUMENTS). */}}
{{define "nsd"}}{{ . | strings.ReplaceAll "\"" "$\\\"" | strings.ReplaceAll "\r\n" "$\\r$\\n" | strings.ReplaceAll "\r" "$\\r$\\n" | strings.ReplaceAll "\n" "$\\r$\\n" }}{{end}}

{{- /* Escapes a string for use inside an NSIS `...` literal. */}}
{{define "scq"}}{{ . | strings.ReplaceAll "$" "$$" | strings.ReplaceAll "`" "$\\`" | strings.ReplaceAll "\r\n" "$\\r$\\n" | strings.ReplaceAll "\r" "$\\r$\\n" | strings.ReplaceAll "\n" "$\\r$\\n" }}{{end}}
