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
!include EnvPath.nsh
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

!define PRODUCT_DESCRIPTION "{{ template "nsq" (ds "in").Description }}"
!define PRODUCT_COPYRIGHT "{{ (ds "in").Copyright }}"

{{- if (ds "in").Version }}
!define PRODUCT_VERSION "{{ (ds "in").Version }}"
{{- else }}
!define PRODUCT_VERSION "0.0.0.0"
{{- end }}

{{- if (ds "in").InstallRoot }}
!define INSTALL_ROOT "{{(ds "in").InstallRoot}}"
{{- else if eq (ds "in").ExecutionLevel "user" }}
!define INSTALL_ROOT "$LOCALAPPDATA\Programs"
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

!define UNINSTALLER_NAME "{{ (ds "in").UninstallerName }}"
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

; $INSTDIR when .onInit starts, if it is still the InstallDir default (no /D=).
Var __instdir_default

{{- if (ds "in").HasOptions }}
{{ template "optVars" }}

!macro __Options_ForEachPersisted CALLBACK
{{- range (ds "in").Options }}
{{- if .Persist }}
    !insertmacro ${CALLBACK} {{.Page}} {{.Key}} {{.Type}}
{{- end }}
{{- end }}
!macroend
{{- end }}
!include Ini.nsh
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
; Every control kind is one branch in each of the opt* templates (defined in
; options.template.nsi): the
; handle variables, the create code, the raw read into $__opt_chk_val, the
; validation (which also canonicalizes $__opt_chk_val) and the enable list.
; ----------------------------------------------------


{{- range (ds "in").Components }}
{{template "sectionSelChangeVar" .}}
{{- end}}
{{- range (ds "in").ComponentGroups }}
{{template "sectionGroupSelChangeVar" .}}
{{- end }}


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

    ${UpdateProductRegistry} "${ProdInstallDir}" "$INSTDIR"
    ${UpdateProductRegistry} "${ProdVersion}" "${PRODUCT_VERSION}"

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
        ${Ini_ReadStr} "$2" "setup" "components" $0
        ${Ini_ReadStr} "$2" "setup" "insttype" $1
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
{{- else if .MultiSelect }}
    Push $0
    ${Array_Join} "${{.Var}}" "," $0
    !insertmacro __HelpW "$0"
    Pop $0
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
{{- if .MultiSelect }}
    Push $0
    ${Ini_FormatList} "${{.Var}}" "{{.Key}}" $0
    !insertmacro __HelpW "$0"
    Pop $0
{{- else }}
    !insertmacro __HelpW "{{.Key}}="
{{- if not .Secret }}
    !insertmacro __HelpW "${{.Var}}"
{{- end }}
    !insertmacro __HelpNL
{{- end }}
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

    !insertmacro _Option_PersistOne shortcuts enabled single
    !insertmacro _Option_PersistOne shortcuts start_menu single
    !insertmacro _Option_PersistOne shortcuts start_menu_folder single
    !insertmacro _Option_PersistOne shortcuts desktop single
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

Function .onInit
    {{- /* NSIS strips /D= from $CMDLINE; an unchanged default means it was not given. */}}
    StrCpy $__instdir_default ""
    ${If} $INSTDIR == "${INSTALL_ROOT}\${SUB_PATH}"
        StrCpy $__instdir_default $INSTDIR
    ${EndIf}
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

    {{- /* Reuse the previous install's directory unless /D= or PreInit chose one.
           Before UninstallExisting, which removes the key it lives in. */}}
    ${If} $__instdir_default != ""
    ${AndIf} $INSTDIR == $__instdir_default
        Push $0
        ${GetProductRegistry} "${ProdInstallDir}" $0
        ${If} $0 != ""
            StrCpy $INSTDIR $0
        ${EndIf}
        Pop $0
    ${EndIf}

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
  ${un.RemoveProductRegistry} "Options"
  {{- end }}
  ${un.RemoveProductRegistry} ""

  ;Remove the uninstaller itself.
  SetFileAttributes "$INSTDIR\${UNINSTALLER_NAME}" NORMAL
  Delete "$INSTDIR\${UNINSTALLER_NAME}"
  ; Remove if empty
  RMDir "$INSTDIR"

SectionEnd
