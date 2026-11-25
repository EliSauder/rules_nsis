!ifndef __INCLUDE_MOVEFILEFOLDER
!define __INCLUDE_MOVEFILEFOLDER

!include LogicLib.nsh
!include FileFunc.nsh

; Set to 1 to overwrite existing destination files without an 'ifnewer' check.
Var /GLOBAL switch_overwrite

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; MoveFile and MoveFolder macros
;
; Based On: MoveFileFolder by theblazingangel@aol.com (for the AutoPatcher project - www.autopatcher.com)
; Created: June 2007
; Source: https://nsis.sourceforge.io/MoveFileFolder
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; Return the volume/file identity and resolved path, preserving all registers.
!macro _MovePathInfoFunction PREFIX
Function ${PREFIX}_MovePathInfo
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9
    ClearErrors
    StrCpy $1 ""
    StrCpy $2 -1
    StrCpy $3 0
    ; Metadata access only, sharing read/write/delete, also follows junctions.
    System::Call 'kernel32::CreateFileW(w r0, i 0, i 7, p 0, i 3, i 0x02000000, p 0) p.r2'
    StrCmp $2 -1 move_path_info_failed
    System::Alloc 24
    Pop $3
    StrCmp $3 0 move_path_info_failed
    ; FILE_ID_INFO includes a 64-bit volume serial and 128-bit file identity.
    System::Call 'kernel32::GetFileInformationByHandleEx(p r2, i 18, p r3, i 24) i.r4'
    StrCmp $4 0 move_path_info_failed
    System::Call 'kernel32::GetFinalPathNameByHandleW(p r2, w .r1, i ${NSIS_MAX_STRLEN}, i 0) i.r4'
    IntCmp $4 0 move_path_info_failed
    IntCmp $4 ${NSIS_MAX_STRLEN} move_path_info_failed 0 move_path_info_failed
    ; Keep DOS/UNC spelling usable by FileFunc's parent/root helpers.
    StrCpy $4 "$1" 8
    StrCmpS $4 "\\?\UNC\" move_path_info_unc
    StrCpy $4 "$1" 4
    StrCmpS $4 "\\?\" 0 move_path_info_identity
    StrCpy $1 "$1" "" 4
    Goto move_path_info_identity
move_path_info_unc:
    StrCpy $1 "$1" "" 8
    StrCpy $1 "\\$1"
move_path_info_identity:
    System::Call '*$3(i.r5, i.r6, i.r7, i.r8, i.r9, i.r0)'
    IntFmt $5 "%08X" $5
    IntFmt $6 "%08X" $6
    IntFmt $7 "%08X" $7
    IntFmt $8 "%08X" $8
    IntFmt $9 "%08X" $9
    IntFmt $0 "%08X" $0
    StrCpy $0 "$5$6$7$8$9$0"
    StrCpy $4 1
    Goto move_path_info_cleanup
move_path_info_failed:
    DetailPrint "Cannot query move path identity/resolved name: $0"
    StrCpy $4 0
move_path_info_cleanup:
    StrCmp $3 0 +2
    System::Free $3
    StrCmp $2 -1 move_path_info_closed
    System::Call 'kernel32::CloseHandle(p r2) i.r5'
    StrCmp $5 0 0 move_path_info_closed
    DetailPrint "Cannot close move metadata handle: $1"
    StrCpy $4 0
move_path_info_closed:
    StrCmp $4 1 move_path_info_done
    StrCpy $0 ""
    StrCpy $1 ""
    SetErrors
move_path_info_done:
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Exch $1
    Exch
    Exch $0
FunctionEnd
!macroend

!insertmacro _MovePathInfoFunction ""
!insertmacro _MovePathInfoFunction "un."

!macro _MoveFileFunction PREFIX
Function ${PREFIX}_MoveFile
    Exch $1
    Exch
    Exch $0
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9

    ClearErrors
    StrCmp $0 "" move_file_failed
    StrCmp $1 "" move_file_failed
    System::Call 'kernel32::GetFullPathNameW(w r0, i ${NSIS_MAX_STRLEN}, w .r0, p 0) i.r2'
    IntCmp $2 0 move_file_failed
    IntCmp $2 ${NSIS_MAX_STRLEN} move_file_failed 0 move_file_failed
    System::Call 'kernel32::GetFullPathNameW(w r1, i ${NSIS_MAX_STRLEN}, w .r1, p 0) i.r2'
    IntCmp $2 0 move_file_failed
    IntCmp $2 ${NSIS_MAX_STRLEN} move_file_failed 0 move_file_failed
    System::Call 'kernel32::GetFileAttributesW(w r0) i.r2'
    IntCmp $2 -1 move_file_failed
    IntOp $2 $2 & 0x10
    StrCmp $2 0 0 move_file_failed

    Push "$0"
    Call ${PREFIX}_MovePathInfo
    Pop $8
    Pop $9
    IfErrors move_file_failed
    DetailPrint "Moving/renaming file: $0 to $1"

move_file_destination:
    System::Call 'kernel32::GetFileAttributesW(w r1) i.r2 ?e'
    Pop $7
    IntCmp $2 -1 move_file_missing
    IntOp $2 $2 & 0x10
    StrCmp $2 0 0 move_file_failed
    ; String normalization does not resolve 8.3 names or junction aliases.
    Push "$1"
    Call ${PREFIX}_MovePathInfo
    Pop $2
    Pop $9
    IfErrors move_file_failed
    StrCmpS $8 $2 move_file_done
    StrCpy $6 3
    StrCmp $switch_overwrite 1 move_file_rename

    GetFileTime "$0" $2 $3
    IfErrors move_file_failed
    GetFileTime "$1" $4 $5
    IfErrors move_file_failed
    ; FILETIME consists of two unsigned DWORDs, high word first.
    IntCmpU $2 $4 0 move_file_discard move_file_rename
    IntCmpU $3 $5 move_file_discard move_file_discard move_file_rename

move_file_discard:
    Delete "$0"
    IfErrors move_file_failed
    Goto move_file_done

move_file_missing:
    StrCmp $7 2 move_file_new
    StrCmp $7 3 0 move_file_failed
move_file_new:
    StrCpy $6 2

move_file_rename:
    ; COPY_ALLOWED retains cross-volume file moves; REPLACE_EXISTING replaces
    ; in place without first deleting the destination. Never delete on failure.
    System::Call 'kernel32::MoveFileExW(w r0, w r1, i r6) i.r2 ?e'
    Pop $7
    StrCmp $2 0 0 move_file_verify_removed
    StrCmp $6 2 0 move_file_windows_error
    ; If a destination appeared after our check, apply the timestamp policy.
    StrCmp $7 80 move_file_destination
    StrCmp $7 183 move_file_destination
move_file_windows_error:
    DetailPrint "Windows move error: $7"
    Goto move_file_failed
move_file_verify_removed:
    ; COPY_ALLOWED can report success when copying succeeded but deletion failed.
    System::Call 'kernel32::GetFileAttributesW(w r0) i.r2 ?e'
    Pop $7
    IntCmp $2 -1 0 move_file_source_remains move_file_source_remains
    StrCmp $7 2 move_file_done
    StrCmp $7 3 move_file_done move_file_windows_error
move_file_source_remains:
    DetailPrint "Move copied/renamed a destination but the source still exists: $0"
move_file_failed:
    DetailPrint "Failed to move file: $0 to $1"
    SetErrors

move_file_done:
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Pop $1
FunctionEnd
!macroend

!insertmacro _MoveFileFunction ""
!insertmacro _MoveFileFunction "un."

!macro MoveFile sourceFile destinationFile
    Push "${sourceFile}"
    Push "${destinationFile}"
    Call _MoveFile
!macroend
!define MoveFile `!insertmacro MoveFile`

!macro un.MoveFile sourceFile destinationFile
    Push "${sourceFile}"
    Push "${destinationFile}"
    Call un._MoveFile
!macroend
!define un.MoveFile `!insertmacro un.MoveFile`

!macro _MoveFolderFunction PREFIX
Function ${PREFIX}_MoveFolder
    Exch $R2
    Exch
    Exch $R1
    Exch 2
    Exch $R0
    Push $R3
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6

    ClearErrors
    StrCmp $R0 "" move_folder_failed
    StrCmp $R1 "" move_folder_failed
    System::Call 'kernel32::GetFullPathNameW(w R0, i ${NSIS_MAX_STRLEN}, w .R0, p 0) i.r0'
    IntCmp $0 0 move_folder_failed
    IntCmp $0 ${NSIS_MAX_STRLEN} move_folder_failed 0 move_folder_failed
    System::Call 'kernel32::GetFullPathNameW(w R1, i ${NSIS_MAX_STRLEN}, w .R1, p 0) i.r0'
    IntCmp $0 0 move_folder_failed
    IntCmp $0 ${NSIS_MAX_STRLEN} move_folder_failed 0 move_folder_failed
    System::Call 'kernel32::GetFileAttributesW(w R0) i.r0'
    IntCmp $0 -1 move_folder_failed
    IntOp $0 $0 & 0x10
    StrCmp $0 0 move_folder_failed

    StrCpy $0 "$R0" 1 -1
    StrCmp $0 "\" 0 +2
    StrCpy $R0 "$R0" -1
    StrCpy $0 "$R1" 1 -1
    StrCmp $0 "\" 0 +2
    StrCpy $R1 "$R1" -1
    ${${PREFIX}GetRoot} "$R0" $0
    StrCmp $R0 $0 move_folder_failed
    Push "$R0"
    Call ${PREFIX}_MovePathInfo
    Pop $2
    Pop $3
    IfErrors move_folder_failed
    ${${PREFIX}GetRoot} "$3" $0
    StrCmpS $3 $0 move_folder_failed
    StrCmpS $3 "$0\" move_folder_failed

    ; Resolve the nearest existing destination ancestor before creating anything.
    StrCpy $4 "$R1"
    StrCpy $6 1
move_folder_find_parent:
    System::Call 'kernel32::GetFileAttributesW(w r4) i.r0 ?e'
    Pop $1
    IntCmp $0 -1 0 move_folder_parent_found move_folder_parent_found
    StrCmp $1 2 move_folder_parent_missing
    StrCmp $1 3 0 move_folder_failed
move_folder_parent_missing:
    StrCpy $6 0
    ${${PREFIX}GetRoot} "$4" $0
    StrCmpS $4 $0 move_folder_failed
    StrCmpS $4 "$0\" move_folder_failed
    ${${PREFIX}GetParent} "$4" $4
    ${${PREFIX}GetRoot} "$4" $0
    ; A bare drive (C:) resolves to its current directory, not its root.
    StrCmpS $4 $0 0 +2
    StrCpy $4 "$4\"
    Goto move_folder_find_parent
move_folder_parent_found:
    IntOp $0 $0 & 0x10
    StrCmp $0 0 move_folder_failed
    Push "$4"
    Call ${PREFIX}_MovePathInfo
    Pop $5
    Pop $4
    IfErrors move_folder_failed
    StrCmpS $2 $5 0 move_folder_check_ancestor
    StrCmp $6 1 move_folder_done move_folder_failed
move_folder_check_ancestor:
    StrCmpS $2 $5 move_folder_failed
    ${${PREFIX}GetRoot} "$4" $0
    StrCmpS $4 $0 move_folder_destination_safe
    StrCmpS $4 "$0\" move_folder_destination_safe
    ${${PREFIX}GetParent} "$4" $4
    ${${PREFIX}GetRoot} "$4" $0
    StrCmpS $4 $0 move_folder_destination_safe
    Push "$4"
    Call ${PREFIX}_MovePathInfo
    Pop $5
    Pop $4
    IfErrors move_folder_failed
    Goto move_folder_check_ancestor
move_folder_destination_safe:

    CreateDirectory "$R1\"
    IfErrors move_folder_failed
    DetailPrint "Moving files: $R0\$R2 to $R1\"
    ${${PREFIX}Locate} "$R0" "/L=D" "${PREFIX}_MoveFolder_Locate_createDir"
    IfErrors move_folder_failed
    ${${PREFIX}Locate} "$R0" "/L=F /M=$R2 /S= /G=1" "${PREFIX}_MoveFolder_Locate_moveFile"
    IfErrors move_folder_failed

    ; Only clean up after every matching file was handled successfully.
move_folder_delete_source:
    StrCpy $R3 0
    ${${PREFIX}Locate} "$R0" "/L=DE" "${PREFIX}_MoveFolder_Locate_deleteDir"
    IfErrors move_folder_failed
    StrCmp $R3 0 0 move_folder_delete_source

    ; Nonmatching files deliberately remain in the source and are not errors.
    ${${PREFIX}DirState} "$R0" $0
    StrCmp $0 -1 move_folder_failed
    ; DirState uses FindNext's error flag to signal an empty directory.
    ClearErrors
    StrCmp $0 0 0 move_folder_delete_destination
    RMDir "$R0"
    IfErrors move_folder_failed

    ; Remove the source first: when moving into an ancestor, destination cleanup
    ; can also visit and remove the now-empty source directory.
move_folder_delete_destination:
    StrCpy $R3 0
    ${${PREFIX}Locate} "$R1" "/L=DE" "${PREFIX}_MoveFolder_Locate_deleteDir"
    IfErrors move_folder_failed
    StrCmp $R3 0 0 move_folder_delete_destination
    Goto move_folder_done

move_folder_failed:
    DetailPrint "Failed to move folder: $R0 to $R1 (mask: $R2)"
    SetErrors
move_folder_done:
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
    Pop $R3
    Pop $R0
    Pop $R2
    Pop $R1
FunctionEnd
!macroend

!insertmacro _MoveFolderFunction ""
!insertmacro _MoveFolderFunction "un."

!macro MoveFolder source destination mask
    Push "${source}"
    Push "${destination}"
    Push "${mask}"
    Call _MoveFolder
!macroend
!define MoveFolder `!insertmacro MoveFolder`

!macro un.MoveFolder source destination mask
    Push "${source}"
    Push "${destination}"
    Push "${mask}"
    Call un._MoveFolder
!macroend
!define un.MoveFolder `!insertmacro un.MoveFolder`

!macro _MoveFolderCallbacks PREFIX
Function ${PREFIX}_MoveFolder_Locate_createDir
    ${If} $R6 == ""
        Push $R4
        StrLen $R4 "$R0"
        StrCpy $R4 "$R9" "" $R4
        CreateDirectory "$R1$R4"
        Pop $R4
    ${EndIf}
    Push ""
FunctionEnd

Function ${PREFIX}_MoveFolder_Locate_moveFile
    Push $R4
    StrLen $R4 "$R0"
    StrCpy $R4 "$R9" "" $R4
    StrCpy $R4 "$R1$R4"
    ${${PREFIX}MoveFile} "$R9" "$R4"
    Pop $R4
    Push ""
FunctionEnd

Function ${PREFIX}_MoveFolder_Locate_deleteDir
    ${If} $R6 == ""
        Push $0
        RMDir "$R9"
        IfErrors move_folder_delete_failed
        ; Deletion can remain pending on an open handle. Do not count it as
        ; progress and repeatedly rediscover the same directory forever.
        System::Call 'kernel32::GetFileAttributesW(w R9) i.r0'
        IntCmp $0 -1 0 move_folder_delete_failed move_folder_delete_failed
        Pop $0
        IntOp $R3 $R3 + 1
    ${EndIf}
    Push ""
    Return
move_folder_delete_failed:
    Pop $0
    DetailPrint "Failed to remove empty directory: $R9"
    SetErrors
    Push ""
FunctionEnd
!macroend

!insertmacro _MoveFolderCallbacks ""
!insertmacro _MoveFolderCallbacks "un."

!endif
