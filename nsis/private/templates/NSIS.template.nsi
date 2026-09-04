!pragma warning disable 6010 ; Because we are using templates, some installers
                             ; don't use everything defined.
Unicode True

!include LogicLib.nsh
!include MUI2.nsh
!include x64.nsh
!include Sections.nsh

!include FileFunc.nsh

{{- range (ds "in").IncludeFiles }}
!include "{{.}}"
{{- end }}

!define IsNativeARM32 '${IsNativeMachineArchitecture} 448'

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

!define UN_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_ID}"
!define REG_KEY "Software\${PRODUCT_KEY_PATH}"

!define REG_KEY_INSTLOC "InstallDir"

!define ROOT_EVENTLOG_KEY "SYSTEM\CurrentControlSet\Services\EventLog"

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
        StrCpy $StdOutAttempted "Y"
        Push $0
        Push $1
        System::Call 'kernel32::AttachConsole(i -1)i.r1'
        ${If} $1 != 0
            System::Call 'kernel32::GetStdHandle(i -11)i.r0'
            StrCpy $StdOutHandle $0
        ${EndIf}
        Pop $1
        Pop $0
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

!macro _SetRegView
{{- if eq (ds "in").Architecture "x86_64" }}
    ${IfNot} ${IsNativeAMD64}
        !insertmacro Log "Not AMD64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit x86 version of Windows." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "x86_32" }}
    {{- if not (ds "in").ArchitectureAllow32On64 }}
    ${IfNot} ${IsNativeIA32}
        !insertmacro Log "Not IA32, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 32-bit x86 version of Windows." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
    {{- end }}

    SetRegView 32
    StrCpy $Is64BitInstall "0"
    StrCpy $IsArmInstall "0"
{{- else if eq (ds "in").Architecture "arm64" }}
    ${IfNot} ${IsNativeARM64}
        !insertmacro Log "Not ARM64, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 64-bit ARM version of Windows." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}

    SetRegView 64
    StrCpy $Is64BitInstall "1"
    StrCpy $IsArmInstall "1"
{{- else if eq (ds "in").Architecture "arm32" }}
    {{- if not (ds "in").ArchitectureAllow32On64 }}
    ${IfNot} ${IsNativeARM32}
        !insertmacro Log "Not ARM32, Aborting"
        MessageBox MB_ICONSTOP "This installer requires a 32-bit ARM version of Windows." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
    {{- end}}

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

!macro ValidateMutex Act
    Push $R0
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "${PUBLISHER}${PRODUCT}${Act}Mutex") i .r1 ?e'
    Pop $R0
    ${If} $R0 != 0
        !insertmacro Log "Another instance is already running, aborting"
        MessageBox MB_ICONEXCLAMATION "Another instance of this installer is already running." /SD IDOK
        Abort
    ${EndIf}
    Pop $R0
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
#        "A previous version of ${PRODUCT} was found. Do you want to uninstall it first?" \
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
  Exch $0 # Pop Param 1

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

  Pop $0
FunctionEnd

Function AddToRegistry
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
    Exch $0
    Exch 1
    Exch $1
    Exch 2
    Exch $2

    ${If} $TestId != ""
      Push $3
      StrCpy $3 $TestId
      StrCpy $0 "$0\$3"
      Pop $3
    ${EndIf}

    WriteRegStr SHCTX "$0" "$2" "$1"
    !insertmacro Log "Set install registry entry: '$0' -> '$2' to '$1'"

    Pop $2
    Pop $0
    Pop $1
FunctionEnd

Function un.GetFromRegistry
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
    Exch $0
    Exch
    Exch $1

    ${If} $TestId != ""
        Push $3
        StrCpy $3 $TestId
        StrCpy $0 "$0\$3"
        Pop $3
    ${EndIf}

    ReadRegStr $0 SHCTX "$0" "$1"
    Pop $1
    Exch $0
FunctionEnd

Function GetFromRegistry
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
        SetShellVarContext all
    ${Else}
        SetShellVarContext current
    ${EndIf}
    Exch $0
    Exch
    Exch $1

    ${If} $TestId != ""
        Push $3
        StrCpy $3 $TestId
        StrCpy $0 "$0\$3"
        Pop $3
    ${EndIf}

    ReadRegStr $0 SHCTX "$0" "$1"
    Pop $1
    Exch $0
FunctionEnd

!macro _iCaclsExec ARGS RECURSIVE OUT_RC
    ${If} RECURSIVE > 0
        !insertmacro Log `Executing: $SYSDIR\icacls.exe ${ARGS} /C /Q /T`
    ${Else}
        !insertmacro Log `Executing: $SYSDIR\icacls.exe ${ARGS} /C /Q`
    ${EndIf}
    ClearErrors
    Push $0
    Push $1
    ${If} RECURSIVE > 0
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /C /Q /T`
    ${Else}
        nsExec::ExecToStack `"$SYSDIR\icacls.exe" ${ARGS} /C /Q`
    ${EndIf}
    Pop $0
    Pop $1
    !insertmacro Log `Code: $0, Output: $1`
    Pop $1
    Push $0
    Exch
    Pop $0
    Pop ${OUT_RC}
!macroend

!macro iCacls_Grant PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /grant ${SID}:${PERM}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_Deny PATH SID PERM RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /deny ${SID}:${PERM}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_RemoveGrant PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /remove:g ${SID}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_RemoveDeny PATH SID RECURSIVE OUT_RC
    !insertmacro _iCaclsExec `${PATH} /remove:d ${SID}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro iCacls_IntegrityLevel PATH LVL INHERTOPTS RECURSIVE
    ${IF} INHERTOPTS == ""
        !insertmacro _iCaclsExec `${PATH} /setintegritylevel ${LVL}` ${RECURSIVE} ${OUT_RC}
    ${Else}
        !insertmacro _iCaclsExec `${PATH} /setintegritylevel ${INHERTOPTS}${LVL}` ${RECURSIVE} ${OUT_RC}
    ${EndIf}
!macroend

!macro iCacls_Substitute PATH SIDOLD SIDNEW RECURSIVE
    !insertmacro _iCaclsExec`${PATH} /substitute ${SIDOLD} ${SIDNEW}` ${RECURSIVE} ${OUT_RC}
!macroend

!macro _ServiceScExec ARGS OUT_RC
    !insertmacro Log `Executing: $SYSDIR\sc.exe ${ARGS}`
    ClearErrors

    Push $0
    Push $1

    nsExec::ExecToStack `"$SYSDIR\sc.exe" ${ARGS}`
    Pop $0
    Pop $1
    !insertmacro Log `Code: $0, Output: $1`
    Pop $1

    Push $0
    Exch
    Pop $0

    Pop ${OUT_RC}

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

; ------------------------
; SECTIONS
{{ define "section" }}
Section {{if .DisabledByDefault}}/o{{end}} "{{if .IsHidden}}-{{end}}{{.DisplayName}}" "{{.Name}}"
    {{ if .HasPreInstall }}
    !insertmacro PreInstall_{{.Name}} "$INSTDIR\{{.Directory}}"
    {{ end }}

    Push $0
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
    ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1

        Push "TypesSupported"
        Push "{{.SupportedTypes}}"
        Push "${ROOT_EVENTLOG_KEY}\{{.Key}}\{{.Source}}"
        Call AddToRegistry

        Push "EventMessageFile"
        Push "{{.EventMessageFile}}"
        Push "${ROOT_EVENTLOG_KEY}\{{.Key}}\{{.Source}}"
        Call AddToRegistry

        {{- if .CategoryMessageFile}}
        Push "CategoryMessageFile"
        Push "{{.CategoryMessageFile}}"
        Push "${ROOT_EVENTLOG_KEY}\{{.Key}}\{{.Source}}"
        Call AddToRegistry
        {{- end}}
        {{- if .ParameterMessageFile}}
        Push "ParameterMessageFile"
        Push "{{.ParameterMessageFile}}"
        Push "${ROOT_EVENTLOG_KEY}\{{.Key}}\{{.Source}}"
        Call AddToRegistry
        {{- end}}
    ${EndIf}
    {{- end}}
    {{- end}}

    Pop $0

    {{ if .HasPostInstall }}
    !insertmacro PostInstall_{{.Name}} "$OUTDIR"
    {{ end }}
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
    Push "${PRODUCT_VERSION}"
    Push "${REG_KEY}"
    Call AddToRegistry

    WriteUninstaller "$INSTDIR\${UNINSTALLER_NAME}"

    Push "InstallLocation"
    Push "$INSTDIR"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "DisplayName"
    Push "${PRODUCT}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "DisplayVersion"
    Push "${PRODUCT_VERSION}"
    Push "${UN_REG_KEY}"
    Call AddToRegistry
    Push "Publisher"
    Push "${PUBLISHER}"
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
#  !insertmacro MUI_HEADER_TEXT "Install Options" "Choose options for installing ${PRODUCT}"
#  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "NSIS(ds "in").InstallOptions.ini"
#FunctionEnd

!macro TrimQuotes Input Output
    Push "${Input}"
    Call TrimQuotes
    Pop ${Output}
!macroend

Function TrimQuotes
    Exch $R0
    Push $R1

    StrCpy $R1 $R0 1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 `` 1

    StrCpy $R1 $R0 1 -1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 -1

    Pop $R1
    Exch $R0
FunctionEnd

!macro UninstallExisting appkey exitcode
    Push "${appkey}"
    Call UninstallExisting
    Pop ${exitcode}
!macroend

Function UninstallExisting #(appkey: str) -> int:
    Exch $0

    Push $1

    Push "UninstallString"
    Push "Software\Microsoft\Windows\CurrentVersion\Uninstall\$0"
    Call GetFromRegistry
    Pop $1

    !insertmacro TrimQuotes $1 $1
    ${If} "$1" == ""
        !insertmacro Log "No uninstall path for id: $0"
        Pop $1
        Pop $0
        Push 0
        Return
    ${EndIf}
    !insertmacro Log "$0 has uninstall path: $1"

    IfFileExists "$1" exists notexist
notexist:
    !insertmacro Log "Uninstall file $1 does not exist"
    # If not exist
    Pop $1
    Pop $0
    Push 0
    Return

exists:
    Push $2
    Push $3

    Push "InstallLocation"
    Push "Software\Microsoft\Windows\CurrentVersion\Uninstall\$0"
    Call GetFromRegistry
    Pop $3
    !insertmacro TrimQuotes $3 $3
    ${If} "$3" == ""
        !insertmacro Log "App $0 has no ${REG_KEY_INSTLOC} path. Please uninstall manually first."
        MessageBox MB_ICONSTOP "App $0 has no ${REG_KEY_INSTLOC} path defined. Please uninstall manually first." /SD IDOK
        Pop $3
        Pop $2
        Pop $1
        Pop $0
        Push 1
        Return
    ${EndIf}

    Push $4
    Push $5

    ${If} $TestId == ""
        nsExec::ExecToStack `"$1" /S _?=$3`
        Pop $4
        Pop $5
    ${Else}
        StrCpy $2 "$TestId"
        nsExec::ExecToStack `"$1" /S /TESTID=$2 _?=$3`
        Pop $4
        Pop $5
    ${EndIf}
    !insertmacro Log `Result of uninstall existing: Code: $4, Output: $5`
    IntOp $2 $4 + 0
    Pop $5
    Pop $4


    ${If} $2 = 0
        !insertmacro Log `Successful uninstall: Deleting '$1', Removind '$3'`
        Delete "$1"
        RMDir "$3"
        Pop $3
        Pop $2
        Pop $1
        Pop $0
        Push 0
        Return
    ${EndIf}

    Pop $3
    Exch $2
    Exch
    Pop $1
    Exch
    Pop $0
FunctionEnd

Function .onInit
    {{ if (ds "in").HasPreInit }}
    !insertmacro PreInit
    {{ end }}

    Push $0
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/TESTID=" $TestId
    ClearErrors

    !insertmacro SetVarCtx
    !insertmacro _SetRegView
    !insertmacro ValidateMutex "Install"

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

    Push $0
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/TESTID=" $TestId
    ClearErrors

    !insertmacro SetVarCtx
    !insertmacro _SetRegView
    !insertmacro ValidateMutex "Uninstall"

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
  ${If} ${IS_ADMIN_EXECUTION_LEVEL} = 1
      SetShellVarContext all
  ${Else}
      SetShellVarContext current
  ${EndIf}

  !insertmacro _SetRegView

  #ReadRegStr $StartMenuFolder SHCTX "${UN_REG_KEY}" "StartMenu"
  #${Unless} ${Errors}
  #  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  #  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
  #  RMDir $SMPROGRAMS\$StartMenuFolder
  #${EndUnless}
  #ClearErrors

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
