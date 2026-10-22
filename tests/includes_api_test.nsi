Unicode True
!pragma warning disable 6010
!pragma warning disable 6001
RequestExecutionLevel user
SilentInstall silent
InstallDir "$TEMP\RulesNsisIncludeApiTests"
OutFile "${OUTFILE}"

!define TESTABLE_INSTALLER
!include "Arch.nsh"
!include "EventLog.nsh"
!include "Formatting.nsh"
!include "Guid.nsh"
!include "Logging.nsh"
!include "MoveFileFolder.nsh"
!include "Mutex.nsh"
!include "Product.nsh"
!include "Registry.nsh"
!include "Sc.nsh"
!include "ShellContext.nsh"
!include "Testing.nsh"
!include "Uninstall.nsh"
!include "Utility.nsh"
!include "Version.nsh"
!include "iCacls.nsh"

!macro _AssertEqual EXPECTED ACTUAL ERROR_CODE
    ${If} "${ACTUAL}" != "${EXPECTED}"
        SetErrorLevel ${ERROR_CODE}
        Abort
    ${EndIf}
!macroend

!macro _AssertNotEmpty ACTUAL ERROR_CODE
    ${If} "${ACTUAL}" == ""
        SetErrorLevel ${ERROR_CODE}
        Abort
    ${EndIf}
!macroend

!macro _AssertNotEqual EXPECTED ACTUAL ERROR_CODE
    ${If} "${ACTUAL}" == "${EXPECTED}"
        SetErrorLevel ${ERROR_CODE}
        Abort
    ${EndIf}
!macroend

!macro _SetTestProductCode
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
!macroend

!macro TestInstall_arch_get
    ${GetArch} $0
    !insertmacro _AssertNotEmpty "$0" 101
!macroend
!macro TestUninstall_arch_get
    ${un.GetArch} $0
    !insertmacro _AssertNotEmpty "$0" 103
!macroend

!macro TestInstall_arch_detect
    ${DetectArch}
    !insertmacro _AssertNotEmpty "$current_arch" 102
!macroend
!macro TestUninstall_arch_detect
    ${un.DetectArch}
    !insertmacro _AssertNotEmpty "$current_arch" 103
!macroend

!macro TestInstall_arch_is_64_bit
    ${Is64Bit} $0
    ${If} $0 != "0"
    ${AndIf} $0 != "1"
        SetErrorLevel 104
        Abort
    ${EndIf}
!macroend
!macro TestUninstall_arch_is_64_bit
    ${un.Is64Bit} $0
    ${If} $0 != "0"
    ${AndIf} $0 != "1"
        SetErrorLevel 105
        Abort
    ${EndIf}
!macroend

!macro TestInstall_arch_is_32_bit
    ${Is32Bit} $0
    ${If} $0 != "0"
    ${AndIf} $0 != "1"
        SetErrorLevel 106
        Abort
    ${EndIf}
!macroend
!macro TestUninstall_arch_is_32_bit
    ${un.Is32Bit} $0
    ${If} $0 != "0"
    ${AndIf} $0 != "1"
        SetErrorLevel 107
        Abort
    ${EndIf}
!macroend

!macro TestInstall_arch_validate
    ${GetArch} $0
    ${ValidateArch} "$0"
!macroend
!macro TestUninstall_arch_validate
    ${un.GetArch} $0
    ${un.ValidateArch} "$0"
!macroend

!macro TestInstall_arch_validate_bitwidth
    ${GetArch} $0
    ${If} $is64bit == "1"
        ${ValidateBitwdth} 64
    ${Else}
        ${ValidateBitwdth} 32
    ${EndIf}
!macroend
!macro TestUninstall_arch_validate_bitwidth
    ${un.GetArch} $0
    ${If} $is64bit == "1"
        ${un.ValidateBitwdth} 64
    ${Else}
        ${un.ValidateBitwdth} 32
    ${EndIf}
!macroend

!macro TestInstall_arch_validate_isa
    ${GetArch} $0
    ${If} $isArm == "1"
        ${ValidateISA} "arm"
    ${Else}
        ${ValidateISA} "x86"
    ${EndIf}
!macroend
!macro TestUninstall_arch_validate_isa
    ${un.GetArch} $0
    ${If} $isArm == "1"
        ${un.ValidateISA} "arm"
    ${Else}
        ${un.ValidateISA} "x86"
    ${EndIf}
!macroend

!macro TestInstall_arch_if_bitwidth_match
    ${GetArch} $1
    ${IfBitWdithMatch} $is64bit == "1"
        StrCpy $0 "matched"
    ${Else}
        StrCpy $0 ""
    ${EndIf}
    !insertmacro _AssertEqual "matched" "$0" 108
!macroend
!macro TestUninstall_arch_if_bitwidth_match
!macroend

!macro TestInstall_arch_reg_view
    ${DefineRegView}
!macroend
!macro TestUninstall_arch_reg_view
    ${un.DefineRegView}
!macroend

!macro TestInstall_char_to_ascii
    ${CharToASCII} "A" $0
    !insertmacro _AssertEqual "65" "$0" 111
    ${CharToASCII} "z" $0
    !insertmacro _AssertEqual "122" "$0" 112
    ${CharToASCII} "not-one-character" $0
    !insertmacro _AssertEqual "0" "$0" 113
!macroend
!macro TestUninstall_char_to_ascii
    ${un.CharToASCII} "A" $0
    !insertmacro _AssertEqual "65" "$0" 114
    ${un.CharToASCII} "not-one-character" $0
    !insertmacro _AssertEqual "0" "$0" 115
!macroend

!macro TestInstall_hex_to_bin
    ${Hex2Bin} "0123456789ABCDEF" $0
    !insertmacro _AssertEqual "0000000100100011010001010110011110001001101010111100110111101111" "$0" 116
    ${Hex2Bin} "f" $0
    !insertmacro _AssertEqual "00001111" "$0" 117
    ${Hex2Bin} "" $0
    !insertmacro _AssertEqual "" "$0" 118
    ${Hex2Bin} "xz" $0
    !insertmacro _AssertEqual "" "$0" 119
!macroend
!macro TestUninstall_hex_to_bin
    ${un.Hex2Bin} "a1" $0
    !insertmacro _AssertEqual "10100001" "$0" 120
    ${un.Hex2Bin} "g" $0
    !insertmacro _AssertEqual "" "$0" 121
!macroend

!macro TestInstall_format_str_to_bin
    ${FormatStrToBin} "A" 0 $0
    !insertmacro _AssertEqual "01000001" "$0" 122
    ${FormatStrToBin} "255" 1 $0
    !insertmacro _AssertEqual "11111111" "$0" 123
    ${FormatStrToBin} "not-one-character" 0 $0
    !insertmacro _AssertEqual "0000" "$0" 124
!macroend
!macro TestUninstall_format_str_to_bin
    ${un.FormatStrToBin} "A" 0 $0
    !insertmacro _AssertEqual "01000001" "$0" 125
    ${un.FormatStrToBin} "15" 1 $0
    !insertmacro _AssertEqual "1111" "$0" 126
!macroend

!macro TestInstall_format_str_to_dword
    ${FormatStrToDWORD} "A" $0
    !insertmacro _AssertEqual "0x41" "$0" 127
    ${FormatStrToDWORD} "not-one-character" $0
    !insertmacro _AssertEqual "0x0" "$0" 128
!macroend
!macro TestUninstall_format_str_to_dword
    ${un.FormatStrToDWORD} "z" $0
    !insertmacro _AssertEqual "0x7A" "$0" 129
!macroend

!macro TestInstall_normalize_guid
    ${NormalizeGuid} "aabbccdd-eeff-0011-2233-445566778899" $0
    !insertmacro _AssertEqual "{AABBCCDD-EEFF-0011-2233-445566778899}" "$0" 130
    ${NormalizeGuid} "{aabbccdd-eeff-0011-2233-445566778899}" $0
    !insertmacro _AssertEqual "{AABBCCDD-EEFF-0011-2233-445566778899}" "$0" 131
    ${NormalizeGuid} "aabbccdd-eeff-0011-2233-44556677889z" $0
    !insertmacro _AssertEqual "" "$0" 132
    ${NormalizeGuid} "not-a-guid" $0
    !insertmacro _AssertEqual "" "$0" 133
!macroend
!macro TestUninstall_normalize_guid
    ${un.NormalizeGuid} "aabbccdd-eeff-0011-2233-445566778899" $0
    !insertmacro _AssertEqual "{AABBCCDD-EEFF-0011-2233-445566778899}" "$0" 134
    ${un.NormalizeGuid} "not-a-guid" $0
    !insertmacro _AssertEqual "" "$0" 135
!macroend

!macro TestInstall_version_compare
    ${VersionCompare} "1.2.3" "1.2.4" $0
    !insertmacro _AssertEqual "-1" "$0" 136
    ${VersionCompare} "1.2.4" "1.2.3" $0
    !insertmacro _AssertEqual "1" "$0" 137
    ${VersionCompare} "1.2.3" "1.2.3" $0
    !insertmacro _AssertEqual "0" "$0" 138
    ${VersionCompare} "01.002" "1.2" $0
    !insertmacro _AssertEqual "0" "$0" 139
!macroend
!macro TestUninstall_version_compare
!macroend

!macro TestInstall_version_compare_call
    ${VersionCompareCall} "2.0" "1.9" $0
    !insertmacro _AssertEqual "1" "$0" 140
!macroend
!macro TestUninstall_version_compare_call
!macroend

!macro TestInstall_trim_quotes
    ${TrimQuotes} "$\"quoted value$\"" $0
    !insertmacro _AssertEqual "quoted value" "$0" 141
    ${TrimQuotes} "plain value" $0
    !insertmacro _AssertEqual "plain value" "$0" 142
    ${TrimQuotes} "$\"$\"" $0
    !insertmacro _AssertEqual "" "$0" 143
    ${TrimQuotes} "$\"left only" $0
    !insertmacro _AssertEqual "left only" "$0" 144
!macroend
!macro TestUninstall_trim_quotes
    ${un.TrimQuotes} "$\"quoted$\"" $0
    !insertmacro _AssertEqual "quoted" "$0" 145
!macroend

!macro TestInstall_registry_string
    ${SetRegistrySubKeyStr} "Software\RulesNsisIncludeApi" "String" "value"
    ${GetRegistrySubKey} "Software\RulesNsisIncludeApi" "String" $0
    !insertmacro _AssertEqual "value" "$0" 146
    ${RemoveRegistryKey} "Software\RulesNsisIncludeApi"
!macroend
!macro TestUninstall_registry_string
    ${un.SetRegistrySubKeyStr} "Software\RulesNsisIncludeApiUn" "String" "un-value"
    ${un.GetRegistrySubKey} "Software\RulesNsisIncludeApiUn" "String" $0
    !insertmacro _AssertEqual "un-value" "$0" 147
    ${un.RemoveRegistryKey} "Software\RulesNsisIncludeApiUn"
!macroend

!macro TestInstall_registry_dword
    ${SetRegistrySubKeyDWORD} "Software\RulesNsisIncludeApi" "Dword" 37
    ${GetRegistrySubKey} "Software\RulesNsisIncludeApi" "Dword" $0
    !insertmacro _AssertEqual "37" "$0" 148
    ${RemoveRegistryKey} "Software\RulesNsisIncludeApi"
!macroend
!macro TestUninstall_registry_dword
    ${un.SetRegistrySubKeyDWORD} "Software\RulesNsisIncludeApiUn" "Dword" 42
    ${un.GetRegistrySubKey} "Software\RulesNsisIncludeApiUn" "Dword" $0
    !insertmacro _AssertEqual "42" "$0" 149
    ${un.RemoveRegistryKey} "Software\RulesNsisIncludeApiUn"
!macroend

!macro TestInstall_registry_binary
    StrCpy $0 "Software\RulesNsisIncludeApi\${API_TEST_CASE}-$TestId"
    ${SetRegistrySubKeyBin} "$0" "Binary" 000102FF
    DeleteRegKey HKCU "$0"
!macroend
!macro TestUninstall_registry_binary
    StrCpy $0 "Software\RulesNsisIncludeApiUn\${API_TEST_CASE}-$TestId"
    ${un.SetRegistrySubKeyBin} "$0" "Binary" 000102FF
    DeleteRegKey HKCU "$0"
!macroend

!macro TestInstall_registry_remove
    ${SetRegistrySubKeyStr} "Software\RulesNsisIncludeApi" "String" "value"
    ${RemoveRegistryKey} "Software\RulesNsisIncludeApi"
    ${GetRegistrySubKey} "Software\RulesNsisIncludeApi" "String" $0
    !insertmacro _AssertEqual "" "$0" 150
!macroend
!macro TestUninstall_registry_remove
    ${un.SetRegistrySubKeyStr} "Software\RulesNsisIncludeApiUn" "String" "value"
    ${un.RemoveRegistryKey} "Software\RulesNsisIncludeApiUn"
    ${un.GetRegistrySubKey} "Software\RulesNsisIncludeApiUn" "String" $0
    !insertmacro _AssertEqual "" "$0" 151
!macroend

!macro TestInstall_test_id
    ${SetTestId} "set-id"
    ${GetTestId} $0
    !insertmacro _AssertEqual "set-id" "$0" 152
!macroend
!macro TestUninstall_test_id
    ${TestIdInit}
    ${GetTestId} $0
    !insertmacro _AssertNotEmpty "$0" 155
!macroend

!macro TestInstall_if_test
    ${IfTest}
        StrCpy $0 "test"
    ${Else}
        StrCpy $0 "not-test"
    ${EndIf}
    !insertmacro _AssertEqual "test" "$0" 153
!macroend
!macro TestUninstall_if_test
!macroend

!macro TestInstall_if_not_test
    ${IfNotTest}
        StrCpy $0 "not-test"
    ${Else}
        StrCpy $0 "test"
    ${EndIf}
    !insertmacro _AssertEqual "not-test" "$0" 154
!macroend
!macro TestUninstall_if_not_test
!macroend

!macro TestInstall_shell_context_current
    ${UpdateShellContextToCurrent}
    ${SetShellContext}
    ${IfNotAdmin}
        StrCpy $0 "current"
    ${Else}
        StrCpy $0 "admin"
    ${EndIf}
    !insertmacro _AssertEqual "current" "$0" 156
!macroend
!macro TestUninstall_shell_context_current
    ${UpdateShellContextToCurrent}
    ${un.SetShellContext}
!macroend

!macro TestInstall_shell_context_admin
    ${UpdateShellContextToAdmin}
    ${SetShellContext}
    ${IfAdmin}
        StrCpy $0 "admin"
    ${Else}
        StrCpy $0 "current"
    ${EndIf}
    !insertmacro _AssertEqual "admin" "$0" 157
!macroend
!macro TestUninstall_shell_context_admin
    ${UpdateShellContextToAdmin}
    ${un.SetShellContext}
!macroend

!macro TestInstall_shell_context_reset
    ${UpdateShellContextToAdmin}
    ${ResetShellContext}
    ${IfNotAdmin}
        StrCpy $0 "current"
    ${Else}
        StrCpy $0 "admin"
    ${EndIf}
    !insertmacro _AssertEqual "current" "$0" 187
!macroend
!macro TestUninstall_shell_context_reset
    ${UpdateShellContextToAdmin}
    ${ResetShellContext}
!macroend

!macro TestInstall_eventlog_add_source
    ${EventLog_AddSource} "Application" "RulesNsisApiTest" "7" "" "category.dll" "parameter.dll"
    ${GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiTest" "TypesSupported" $0
    !insertmacro _AssertEqual "7" "$0" 158
    ${GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiTest" "EventMessageFile" $0
    !insertmacro _AssertEqual "%SystemRoot%\System32\EventCreate.exe" "$0" 159
    ${GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiTest" "CategoryMessageFile" $0
    !insertmacro _AssertEqual "category.dll" "$0" 160
    ${GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiTest" "ParameterMessageFile" $0
    !insertmacro _AssertEqual "parameter.dll" "$0" 161
    ${EventLog_RemoveSource} "Application" "RulesNsisApiTest"
!macroend
!macro TestUninstall_eventlog_add_source
    ${un.EventLog_AddSource} "Application" "RulesNsisApiTestUn" "3" "events.dll" "" ""
    ${un.GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiTestUn" "TypesSupported" $0
    !insertmacro _AssertEqual "3" "$0" 162
    ${un.EventLog_RemoveSource} "Application" "RulesNsisApiTestUn"
!macroend

!macro TestInstall_eventlog_remove_source
    ${EventLog_AddSource} "Application" "RulesNsisApiRemoveTest" "1" "" "" ""
    ${EventLog_RemoveSource} "Application" "RulesNsisApiRemoveTest"
    ${GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiRemoveTest" "TypesSupported" $0
    !insertmacro _AssertEqual "" "$0" 163
!macroend
!macro TestUninstall_eventlog_remove_source
    ${un.EventLog_AddSource} "Application" "RulesNsisApiRemoveTestUn" "1" "" "" ""
    ${un.EventLog_RemoveSource} "Application" "RulesNsisApiRemoveTestUn"
    ${un.GetRegistrySubKey} "SYSTEM\CurrentControlSet\Services\EventLog\Application\RulesNsisApiRemoveTestUn" "TypesSupported" $0
    !insertmacro _AssertEqual "" "$0" 164
!macroend

!macro TestInstall_product_code
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${GetProductCode} $0
    !insertmacro _AssertEqual "{AABBCCDD-EEFF-0011-2233-445566778899}" "$0" 165
!macroend
!macro TestUninstall_product_code
    ${un.SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${un.GetProductCode} $0
    !insertmacro _AssertEqual "{AABBCCDD-EEFF-0011-2233-445566778899}" "$0" 167
!macroend

!macro TestInstall_uninstall_registry_update
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${UpdateUninstallRegistry} "${UnDisplayName}" "API Test"
    ${GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "API Test" "$0" 166
    ${RemoveUninstallRegistry}
!macroend
!macro TestUninstall_uninstall_registry_update
    ${un.SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${un.UpdateUninstallRegistry} "${UnDisplayName}" "API Test Un"
    ${un.GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "API Test Un" "$0" 168
    ${un.RemoveUninstallRegistry}
!macroend

!macro TestInstall_uninstall_registry_get
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${UpdateUninstallRegistry} "${UnDisplayName}" "API Test"
    ${GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "API Test" "$0" 214
    ${RemoveUninstallRegistry}
!macroend
!macro TestUninstall_uninstall_registry_get
    ${un.SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${un.UpdateUninstallRegistry} "${UnDisplayName}" "API Test Un"
    ${un.GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "API Test Un" "$0" 215
    ${un.RemoveUninstallRegistry}
!macroend

!macro TestInstall_uninstall_registry_remove
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${UpdateUninstallRegistry} "${UnDisplayName}" "remove me"
    ${RemoveUninstallRegistry}
    ${GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "" "$0" 216
!macroend
!macro TestUninstall_uninstall_registry_remove
    ${un.SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${un.UpdateUninstallRegistry} "${UnDisplayName}" "remove me"
    ${un.RemoveUninstallRegistry}
    ${un.GetUninstallRegistry} "${UnDisplayName}" $0
    !insertmacro _AssertEqual "" "$0" 217
!macroend

!macro TestInstall_install_detail_update
    ${UpdateInstallDetail} "RulesNsis" "ApiTest" "Install" "Name" "install-value"
    ${GetInstallDetail} "RulesNsis" "ApiTest" "Install" "Name" $0
    !insertmacro _AssertEqual "install-value" "$0" 169
    ${RemoveRegistryKey} "Software\RulesNsis\ApiTest\Components\Install"
!macroend
!macro TestUninstall_install_detail_update
    ${un.UpdateInstallDetail} "RulesNsis" "ApiTest" "Uninstall" "Name" "uninstall-value"
    ${un.GetInstallDetail} "RulesNsis" "ApiTest" "Uninstall" "Name" $0
    !insertmacro _AssertEqual "uninstall-value" "$0" 170
    ${un.RemoveRegistryKey} "Software\RulesNsis\ApiTest\Components\Uninstall"
!macroend

!macro TestInstall_install_detail_get
    ${UpdateInstallDetail} "RulesNsis" "ApiTest" "Get" "Name" "get-value"
    ${GetInstallDetail} "RulesNsis" "ApiTest" "Get" "Name" $0
    !insertmacro _AssertEqual "get-value" "$0" 185
    ${RemoveRegistryKey} "Software\RulesNsis\ApiTest\Components\Get"
!macroend
!macro TestUninstall_install_detail_get
    ${un.UpdateInstallDetail} "RulesNsis" "ApiTest" "GetUn" "Name" "get-value"
    ${un.GetInstallDetail} "RulesNsis" "ApiTest" "GetUn" "Name" $0
    !insertmacro _AssertEqual "get-value" "$0" 186
    ${un.RemoveRegistryKey} "Software\RulesNsis\ApiTest\Components\GetUn"
!macroend

!macro TestInstall_uninstall_existing
    ${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"
    ${UninstallExisting} "missing-test-product" $0
    !insertmacro _AssertEqual "0" "$0" 171
!macroend
!macro TestUninstall_uninstall_existing
!macroend

!macro TestInstall_mutex
    ${ValidateMutex} "RulesNsisApiTest-${API_TEST_CASE}"
!macroend
!macro TestUninstall_mutex
    ${un.ValidateMutex} "RulesNsisApiTestUn-${API_TEST_CASE}"
!macroend

!macro TestInstall_log_debug
    ${LogDebug} "debug"
!macroend
!macro TestUninstall_log_debug
    ${LogDebug} "debug uninstall"
!macroend

!macro TestInstall_log_info
    ${LogInfo} "info"
!macroend
!macro TestUninstall_log_info
    ${LogInfo} "info uninstall"
!macroend

!macro TestInstall_log_warn
    ${LogWarn} "warning"
!macroend
!macro TestUninstall_log_warn
    ${LogWarn} "warning uninstall"
!macroend

!macro TestInstall_log_error
    ${LogError} "error"
!macroend
!macro TestUninstall_log_error
    ${LogError} "error uninstall"
!macroend

!macro TestInstall_log
    ${Log} "plain"
!macroend
!macro TestUninstall_log
    ${Log} "plain uninstall"
!macroend

!macro TestInstall_move_file
    StrCpy $0 "$TEMP\RulesNsisApi-${API_TEST_CASE}-$TestId"
    CreateDirectory "$0"
    FileOpen $1 "$0\source.txt" w
    FileWrite $1 "move test"
    FileClose $1
    ${MoveFile} "$0\source.txt" "$0\destination.txt"
    IfFileExists "$0\destination.txt" 0 +2
        Goto move_file_passed
    SetErrorLevel 172
    Abort
move_file_passed:
    Delete "$0\destination.txt"
    RMDir "$0"
!macroend
!macro TestUninstall_move_file
!macroend

!macro TestInstall_move_folder
    StrCpy $0 "$TEMP\RulesNsisApi-${API_TEST_CASE}-$TestId"
    CreateDirectory "$0\source\child"
    FileOpen $1 "$0\source\child\source.txt" w
    FileWrite $1 "move folder test"
    FileClose $1
    ${MoveFolder} "$0\source" "$0\destination" "*.txt"
    IfFileExists "$0\destination\child\source.txt" 0 +2
        Goto move_folder_passed
    SetErrorLevel 173
    Abort
move_folder_passed:
    Delete "$0\destination\child\source.txt"
    RMDir "$0\destination\child"
    RMDir "$0\destination"
    RMDir "$0"
!macroend
!macro TestUninstall_move_folder
!macroend

!macro TestInstall_service_create
    ${Service_Create} "RulesNsis/Invalid-${API_TEST_CASE}" "$SYSDIR\cmd.exe" "Invalid" "demand" "" $0
    !insertmacro _AssertNotEmpty "$0" 218
    !insertmacro _AssertNotEqual "0" "$0" 219
!macroend
!macro TestUninstall_service_create
!macroend
!macro TestInstall_service_query
    ${Service_Query} "RulesNsisApiMissing-${API_TEST_CASE}" $0
    !insertmacro _AssertNotEmpty "$0" 220
    !insertmacro _AssertNotEqual "0" "$0" 221
!macroend
!macro TestUninstall_service_query
!macroend
!macro TestInstall_service_update
    ${Service_Update} "RulesNsis/Invalid-${API_TEST_CASE}" "$SYSDIR\cmd.exe" "Invalid" "demand" "" $0
    !insertmacro _AssertNotEmpty "$0" 222
    !insertmacro _AssertNotEqual "0" "$0" 223
!macroend
!macro TestUninstall_service_update
!macroend
!macro TestInstall_service_start
    ${Service_Start} "RulesNsisApiMissing-${API_TEST_CASE}" $0
    !insertmacro _AssertNotEmpty "$0" 224
    !insertmacro _AssertNotEqual "0" "$0" 225
!macroend
!macro TestUninstall_service_start
!macroend
!macro TestInstall_service_stop
    ${Service_Stop} "RulesNsisApiMissing-${API_TEST_CASE}" $0
    !insertmacro _AssertNotEmpty "$0" 226
    !insertmacro _AssertNotEqual "0" "$0" 227
!macroend
!macro TestUninstall_service_stop
!macroend
!macro TestInstall_service_delete
    ${Service_Delete} "RulesNsis/Invalid-${API_TEST_CASE}" $0
    !insertmacro _AssertNotEmpty "$0" 228
    !insertmacro _AssertNotEqual "0" "$0" 229
!macroend
!macro TestUninstall_service_delete
!macroend
!macro TestInstall_service_set_description
    ${Service_SetDescription} "RulesNsis/Invalid-${API_TEST_CASE}" "Invalid" $0
    !insertmacro _AssertNotEmpty "$0" 230
    !insertmacro _AssertNotEqual "0" "$0" 231
!macroend
!macro TestUninstall_service_set_description
!macroend

!macro TestInstall_icacls_grant
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_Grant} "$1" "*S-1-1-0" "R" 0 $0
    !insertmacro _AssertNotEmpty "$0" 232
    !insertmacro _AssertNotEqual "0" "$0" 233
!macroend
!macro TestUninstall_icacls_grant
!macroend
!macro TestInstall_icacls_deny
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_Deny} "$1" "*S-1-1-0" "R" 0 $0
    !insertmacro _AssertNotEmpty "$0" 234
    !insertmacro _AssertNotEqual "0" "$0" 235
!macroend
!macro TestUninstall_icacls_deny
!macroend
!macro TestInstall_icacls_remove_grant
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_RemoveGrant} "$1" "*S-1-1-0" 0 $0
    !insertmacro _AssertNotEmpty "$0" 236
    !insertmacro _AssertNotEqual "0" "$0" 237
!macroend
!macro TestUninstall_icacls_remove_grant
!macroend
!macro TestInstall_icacls_remove_deny
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_RemoveDeny} "$1" "*S-1-1-0" 0 $0
    !insertmacro _AssertNotEmpty "$0" 238
    !insertmacro _AssertNotEqual "0" "$0" 239
!macroend
!macro TestUninstall_icacls_remove_deny
!macroend
!macro TestInstall_icacls_integrity
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_IntegrityLevel} "$1" "Low" "" 0 $0
    !insertmacro _AssertNotEmpty "$0" 240
    !insertmacro _AssertNotEqual "0" "$0" 241
    ${iCacls_IntegrityLevel} "$1" "Low" "OI" 0 $0
    !insertmacro _AssertNotEmpty "$0" 242
    !insertmacro _AssertNotEqual "0" "$0" 243
!macroend
!macro TestUninstall_icacls_integrity
!macroend
!macro TestInstall_icacls_substitute
    StrCpy $1 "$TEMP\RulesNsisApiMissing-${API_TEST_CASE}-$TestId"
    ${iCacls_Substitute} "$1" "*S-1-1-0" "*S-1-5-18" 0 $0
    !insertmacro _AssertNotEmpty "$0" 244
    !insertmacro _AssertNotEqual "0" "$0" 245
!macroend
!macro TestUninstall_icacls_substitute
!macroend

!macro TestInstall_uninstall_registry_constants
    !insertmacro _SetTestProductCode
    !insertmacro _AssertEqual "DisplayName" "${UnDisplayName}" 174
    !insertmacro _AssertEqual "DisplayVersion" "${UnDisplayVersion}" 188
    !insertmacro _AssertEqual "DisplayIcon" "${UnDisplayIcon}" 189
    !insertmacro _AssertEqual "InstallLocation" "${UnInstallLocation}" 175
    !insertmacro _AssertEqual "InstallDate" "${UnInstallDate}" 176
    !insertmacro _AssertEqual "Publisher" "${UnPublisher}" 177
    !insertmacro _AssertEqual "VersionMinor" "${UnVersionMinor}" 190
    !insertmacro _AssertEqual "VersionMajor" "${UnVersionMajor}" 191
    !insertmacro _AssertEqual "HelpLink" "${UnHelpLink}" 192
    !insertmacro _AssertEqual "HelpTelephone" "${UnHelpTelephone}" 193
    !insertmacro _AssertEqual "InstallDateToday" "${UnInstallDateToday}" 194
    !insertmacro _AssertEqual "InstallSource" "${UnInstallSource}" 195
    !insertmacro _AssertEqual "UrlAboutInfo" "${UnUrlAboutInfo}" 196
    !insertmacro _AssertEqual "UrlUpdateInfo" "${UnUrlUpdateInfo}" 197
    !insertmacro _AssertEqual "AuthorizedCdfPrefix" "${UnAuthorizedCdfPrefix}" 198
    !insertmacro _AssertEqual "Comments" "${UnComments}" 199
    !insertmacro _AssertEqual "Contact" "${UnContact}" 200
    !insertmacro _AssertEqual "EstimatedSize" "${UnEstimatedSize}" 201
    !insertmacro _AssertEqual "Language" "${UnLanguage}" 202
    !insertmacro _AssertEqual "ModifyPath" "${UnModifyPath}" 203
    !insertmacro _AssertEqual "Readme" "${UnReadme}" 204
    !insertmacro _AssertEqual "UninstallString" "${UnUninstallString}" 205
    !insertmacro _AssertEqual "QuietUninstallString" "${UnQuietUninstallString}" 206
    !insertmacro _AssertEqual "SettingsIdentifier" "${UnSettingsIdentifier}" 207
    !insertmacro _AssertEqual "NoModify" "${UnNoModify}" 208
    !insertmacro _AssertEqual "NoRepair" "${UnNoRepair}" 209
    !insertmacro _AssertEqual "NoRemove" "${UnNoRemove}" 210
    !insertmacro _AssertEqual "ProductID" "${UnProductID}" 211
    !insertmacro _AssertEqual "SystemComponent" "${UnSystemComponent}" 212
    !insertmacro _AssertEqual "Installed" "${InsInstalled}" 178
    !insertmacro _AssertEqual "Directory" "${InsDirectory}" 179
    !insertmacro _AssertEqual "EventLogSource" "${InsEventLogSource}" 180
    !insertmacro _AssertEqual "InstallLocation" "${InsInstallLocation}" 213
!macroend
!macro TestUninstall_uninstall_registry_constants
!macroend

!macro TestInstall_native_arch_define
    ${If} ${IsNativeARM32}
        StrCpy $0 "arm32"
    ${Else}
        StrCpy $0 "other"
    ${EndIf}
    !insertmacro _AssertEqual "other" "$0" 181
!macroend
!macro TestUninstall_native_arch_define
!macroend

!macro TestInstall_shell_context_aliases
    ${UpdateShellContextToCurrent}
    ${IfNotAdmin}
        StrCpy $0 "current"
    ${Else}
        StrCpy $0 "admin"
    ${EndIf}
    !insertmacro _AssertEqual "current" "$0" 182
!macroend
!macro TestUninstall_shell_context_aliases
!macroend

Function .onInit
    ${TestIdInit}
    !insertmacro TestInstall_${API_TEST_CASE}
FunctionEnd

Function un.onInit
    ${TestIdInit}
    !insertmacro TestUninstall_${API_TEST_CASE}
FunctionEnd

Section
    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd
