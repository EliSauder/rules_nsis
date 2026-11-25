!ifndef __INCLUDE_MOVEFILEFOLDER
!define __INCLUDE_MOVEFILEFOLDER

!include LogicLib.nsh
!include FileFunc.nsh

; Set to 1 to overwrite existing destination files without an 'ifnewer' check.
Var /GLOBAL switch_overwrite
Var /GLOBAL _MoveFolderSources
Var /GLOBAL _MoveFolderSeen
!define /math _MOVE_FOLDER_SEARCH_BYTES ${NSIS_MAX_STRLEN} * 4
!define /math _MOVE_PATH_BUFFER_CHARS ${NSIS_MAX_STRLEN} + 8
!define /math _MOVE_PATH_BUFFER_BYTES ${_MOVE_PATH_BUFFER_CHARS} * 2
!define /redef /math _MOVE_PATH_BUFFER_BYTES ${_MOVE_PATH_BUFFER_BYTES} + 24

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; MoveFile and MoveFolder macros
;
; Based On: MoveFileFolder by theblazingangel@aol.com (for the AutoPatcher project - www.autopatcher.com)
; Created: June 2007
; Source: https://nsis.sourceforge.io/MoveFileFolder
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!ifmacrondef _MoveFileFolderRename
!macro _MoveFileFolderRename SOURCE DESTINATION FLAGS RESULT LAST_ERROR
    System::Call 'kernel32::MoveFileExW(w ${SOURCE}, w ${DESTINATION}, i ${FLAGS}) i.${RESULT} ?e'
    Pop ${LAST_ERROR}
!macroend
!endif

!macro _MovePathInfoFunction PREFIX
Function ${PREFIX}_MoveCheckLiteralPath
    Exch $0
    Push $1
    Push $2
    StrCpy $2 0
    StrCpy $1 "$0" 4
    StrCmpS $1 "\\?\" 0 move_literal_next
    StrCpy $2 4
move_literal_next:
    StrCpy $1 "$0" 1 $2
    StrCmp $1 "" move_literal_done
    StrCmp $1 "*" move_literal_invalid
    StrCmp $1 "?" move_literal_invalid
    IntOp $2 $2 + 1
    Goto move_literal_next
move_literal_invalid:
    DetailPrint "Wildcard in literal move/backup path: $0"
    SetErrors
move_literal_done:
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

; Return the volume/file identity and resolved path, preserving all registers.
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
    ; Reserve prefix headroom outside NSIS strings, after FILE_ID_INFO.
    System::Alloc ${_MOVE_PATH_BUFFER_BYTES}
    Pop $3
    StrCmp $3 0 move_path_info_failed
    IntOp $4 $3 + 24
    StrCpy $5 "$0" 4
    StrCmpS $5 "\\?\" move_path_info_extended
    StrCpy $5 "$0" 2
    StrCmpS $5 "\\" move_path_info_network
    System::Call 'kernel32::lstrcpyW(p r4, w "\\?\")'
    System::Call 'kernel32::lstrcatW(p r4, w r0)'
    Goto move_path_info_open
move_path_info_network:
    StrCpy $5 "$0" "" 2
    System::Call 'kernel32::lstrcpyW(p r4, w "\\?\UNC\")'
    System::Call 'kernel32::lstrcatW(p r4, w r5)'
    Goto move_path_info_open
move_path_info_extended:
    System::Call 'kernel32::lstrcpyW(p r4, w r0)'
move_path_info_open:
    ; Metadata access only, sharing read/write/delete, also follows junctions.
    System::Call 'kernel32::CreateFileW(p r4, i 0, i 7, p 0, i 3, i 0x02000000, p 0) p.r2'
    StrCmp $2 -1 move_path_info_failed
    ; FILE_ID_INFO includes a 64-bit volume serial and 128-bit file identity.
    System::Call 'kernel32::GetFileInformationByHandleEx(p r2, i 18, p r3, i 24) i.r4'
    StrCmp $4 0 move_path_info_failed
    IntOp $5 $3 + 24
    System::Call 'kernel32::GetFinalPathNameByHandleW(p r2, p r5, i ${_MOVE_PATH_BUFFER_CHARS}, i 0) i.r4'
    IntCmp $4 0 move_path_info_failed
    IntCmp $4 ${_MOVE_PATH_BUFFER_CHARS} move_path_info_failed 0 move_path_info_failed
    ; Keep DOS/UNC spelling usable by FileFunc's parent/root helpers.
    System::Call '*$5(&w9.r1)'
    StrCpy $6 ""
    StrCpy $7 "$1" 8
    StrCmpS $7 "\\?\UNC\" move_path_info_unc
    StrCpy $7 "$1" 4
    StrCmpS $7 "\\?\" 0 move_path_info_length
    IntOp $5 $5 + 8
    IntOp $4 $4 - 4
    Goto move_path_info_length
move_path_info_unc:
    IntOp $5 $5 + 16
    IntOp $4 $4 - 7
    StrCpy $6 "\\"
move_path_info_length:
    IntCmp $4 ${NSIS_MAX_STRLEN} move_path_info_failed 0 move_path_info_failed
    System::Call '*$5(&w${NSIS_MAX_STRLEN}.r1)'
    StrCpy $1 "$6$1"
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
    Push "$0"
    Call ${PREFIX}_MoveCheckLiteralPath
    IfErrors move_file_failed
    Push "$1"
    Call ${PREFIX}_MoveCheckLiteralPath
    IfErrors move_file_failed
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
    !insertmacro _MoveFileFolderRename r0 r1 r6 r2 $7
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

!macro _MoveFolderSupport PREFIX
Function ${PREFIX}_MoveFolderFreeList
    Exch $0
    Push $1
move_list_free:
    StrCmp $0 0 move_list_freed
    System::Call '*$0(p.r1)'
    System::Free $0
    StrCpy $0 $1
    Goto move_list_free
move_list_freed:
    Pop $1
    Pop $0
FunctionEnd

Function ${PREFIX}_MoveFolderRemember
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push "$0"
    Call ${PREFIX}_MovePathInfo
    Pop $1
    Pop $2
    IfErrors move_remember_failed
    StrCpy $2 $_MoveFolderSeen
move_remember_find:
    StrCmp $2 0 move_remember_add
    System::Call '*$2(p.r3, &w49.r4)'
    StrCmpS $1 $4 move_remember_failed
    StrCpy $2 $3
    Goto move_remember_find
move_remember_add:
    StrCpy $2 $_MoveFolderSeen
    System::Call '*(p r2, &w49 r1) p.r3'
    StrCmp $3 0 move_remember_failed
    StrCpy $_MoveFolderSeen $3
    Goto move_remember_done
move_remember_failed:
    DetailPrint "Cannot traverse move directory (identity query, cycle, or repeated alias): $0"
    SetErrors
move_remember_done:
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

Function ${PREFIX}_MoveFolderDestination
    Exch $0
    Push $1
    Push $2
    StrLen $1 "$R0"
    StrCpy $0 "$0" "" $1
    StrCpy $1 "$R1" 1 -1
    StrCmp $1 "\" 0 +2
    StrCpy $0 "$0" "" 1
    StrLen $1 "$R1"
    StrLen $2 "$0"
    IntOp $1 $1 + $2
    IntCmp $1 ${NSIS_MAX_STRLEN} move_destination_long 0 move_destination_long
    StrCpy $0 "$R1$0"
    Goto move_destination_done
move_destination_long:
    DetailPrint "Mapped move destination exceeds the NSIS string limit"
    StrCpy $0 ""
    SetErrors
move_destination_done:
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

Function ${PREFIX}_MoveFolderCheckDestination
    Exch $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
move_destination_parent:
    ${${PREFIX}GetRoot} "$0" $1
    StrCmpS $0 $1 0 +2
    StrCpy $0 "$0\"
    System::Call 'kernel32::GetFileAttributesW(w r0) i.r1 ?e'
    Pop $2
    IntCmp $1 -1 0 move_destination_found move_destination_found
    StrCmp $2 2 move_destination_missing
    StrCmp $2 3 0 move_destination_unsafe
move_destination_missing:
    ${${PREFIX}GetRoot} "$0" $1
    StrCmpS $0 "$1\" move_destination_unsafe
    ${${PREFIX}GetParent} "$0" $0
    Goto move_destination_parent
move_destination_found:
    IntOp $1 $1 & 0x10
    StrCmp $1 0 move_destination_unsafe
    StrCpy $7 0
move_destination_identity:
    Push "$0"
    Call ${PREFIX}_MovePathInfo
    Pop $1
    Pop $2
    IfErrors move_destination_unsafe
    StrCmp $7 0 0 +2
    StrCpy $6 "$2"
    StrCpy $3 $_MoveFolderSources
move_destination_source:
    StrCmp $3 0 move_destination_ancestor
    System::Call '*$3(p.r4, &w49.r5)'
    StrCmpS $1 $5 move_destination_unsafe
    StrCpy $3 $4
    Goto move_destination_source
move_destination_ancestor:
    ; Check both logical parents and canonical parents: a junction can leave
    ; the source tree, or enter it through a destination child.
    ${${PREFIX}GetRoot} "$0" $1
    StrCmpS $0 "$1\" move_destination_chain_done
    StrCmpS $0 $1 move_destination_chain_done
    ${${PREFIX}GetParent} "$0" $0
    ${${PREFIX}GetRoot} "$0" $1
    StrCmpS $0 $1 0 +2
    StrCpy $0 "$0\"
    StrCmp $7 2 +2
    StrCpy $7 1
    Goto move_destination_identity
move_destination_chain_done:
    StrCmp $7 2 move_destination_safe
    StrCpy $0 "$6"
    StrCpy $7 2
    Goto move_destination_identity
move_destination_unsafe:
    DetailPrint "Unsafe or inaccessible move destination ancestor: $0"
    SetErrors
move_destination_safe:
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

Function ${PREFIX}_MoveFolderWalk
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
    Push $R6
    Push $R9
    Push $R7
    StrCpy $2 0
    StrCpy $R7 0
    StrCpy $3 -1
    StrCpy $9 0
    Push "$0"
    Call ${PREFIX}_MoveFolderRemember
    IfErrors move_walk_failed
    StrCmp $1 "create" 0 move_walk_allocate
    StrCpy $R9 "$0"
    StrCpy $R6 ""
    Call ${PREFIX}_MoveFolder_Locate_createDir
    Pop $6
    IfErrors move_walk_failed
move_walk_allocate:
    System::Alloc 592
    Pop $2
    StrCmp $2 0 move_walk_failed
    System::Alloc ${_MOVE_FOLDER_SEARCH_BYTES}
    Pop $R7
    StrCmp $R7 0 move_walk_failed
    StrCpy $8 0
    StrCmp $1 "move" 0 move_walk_open
    StrCpy $8 1
move_walk_open:
    StrCpy $5 "*"
    StrCmp $8 1 0 +2
    StrCpy $5 "$R2"
    ; A search suffix must not truncate an otherwise exact-fit directory path.
    System::Call 'kernel32::lstrcpyW(p R7, w r0)'
    System::Call 'kernel32::lstrcatW(p R7, w "\")'
    System::Call 'kernel32::lstrcatW(p R7, w r5)'
    System::Call 'kernel32::FindFirstFileW(p R7, p r2) p.r3 ?e'
    Pop $7
    StrCmp $3 -1 0 move_walk_entry
    StrCmp $7 2 move_walk_empty_search move_walk_failed
move_walk_empty_search:
    System::Call 'kernel32::GetFileAttributesW(w r0) i.r4'
    IntCmp $4 -1 move_walk_failed
    IntOp $4 $4 & 0x10
    StrCmp $4 0 move_walk_failed move_walk_search_done
move_walk_entry:
    System::Call '*$2(i.r4, i, i, i, i, i, i, i, i, i, i, &w260.r5)'
    StrCmp $5 "." move_walk_next
    StrCmp $5 ".." move_walk_next
    StrLen $6 "$0"
    StrLen $7 "$5"
    IntOp $6 $6 + $7
    IntOp $6 $6 + 1
    IntCmp $6 ${NSIS_MAX_STRLEN} move_walk_failed 0 move_walk_failed
    StrCpy $R9 "$0\$5"
    IntOp $4 $4 & 0x10
    StrCmp $4 0 move_walk_file
    StrCmp $8 1 move_walk_next
    Push "$R9"
    Push "$1"
    Call ${PREFIX}_MoveFolderWalk
    IfErrors move_walk_failed
    StrCmp $1 "clean" 0 move_walk_next
    System::Call 'kernel32::GetFileAttributesW(w R9) i.r4 ?e'
    Pop $7
    IntCmp $4 -1 0 move_walk_not_empty move_walk_not_empty
    StrCmp $7 2 move_walk_next
    StrCmp $7 3 move_walk_next move_walk_failed
move_walk_file:
    StrCmp $8 1 0 move_walk_not_empty
    StrCpy $R6 0
    Call ${PREFIX}_MoveFolder_Locate_moveFile
    Pop $6
    IfErrors move_walk_failed
    Goto move_walk_next
move_walk_not_empty:
    StrCpy $9 1
move_walk_next:
    System::Call 'kernel32::FindNextFileW(p r3, p r2) i.r4 ?e'
    Pop $7
    StrCmp $4 0 0 move_walk_entry
    StrCmp $7 18 0 move_walk_failed
    System::Call 'kernel32::FindClose(p r3) i.r4'
    StrCpy $3 -1
    StrCmp $4 0 move_walk_failed
move_walk_search_done:
    StrCmp $8 1 0 move_walk_finish
    StrCpy $8 0
    Goto move_walk_open
move_walk_finish:
    StrCmp $1 "clean" 0 move_walk_done
    StrCmp $9 0 0 move_walk_done
    StrCmpS $0 $R1 move_walk_done
    StrCpy $R9 "$0"
    StrCpy $R6 ""
    Call ${PREFIX}_MoveFolder_Locate_deleteDir
    Pop $6
    IfErrors move_walk_failed
move_walk_done:
    StrCpy $6 0
    Goto move_walk_release
move_walk_failed:
    DetailPrint "Cannot enumerate/process move directory: $0 (phase: $1)"
    StrCpy $6 1
move_walk_release:
    StrCmp $3 -1 move_walk_free
    System::Call 'kernel32::FindClose(p r3) i.r7'
    StrCmp $7 0 0 move_walk_free
    DetailPrint "Cannot close move directory search: $0"
    StrCpy $6 1
move_walk_free:
    StrCmp $R7 0 +2
    System::Free $R7
    StrCmp $2 0 +2
    System::Free $2
    StrCmp $6 0 0 +3
    ClearErrors
    Goto move_walk_restore
    SetErrors
move_walk_restore:
    Pop $R7
    Pop $R9
    Pop $R6
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

!insertmacro _MoveFolderSupport ""
!insertmacro _MoveFolderSupport "un."

!macro _MoveFolderRun PREFIX PATH PHASE
    Push "${PATH}"
    Push "${PHASE}"
    Call ${PREFIX}_MoveFolderWalk
    IfErrors move_folder_failed
    Push $_MoveFolderSeen
    Call ${PREFIX}_MoveFolderFreeList
    StrCpy $_MoveFolderSeen 0
!macroend

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
    Push $_MoveFolderSources
    Push $_MoveFolderSeen
    StrCpy $_MoveFolderSources 0
    StrCpy $_MoveFolderSeen 0

    ClearErrors
    StrCmp $R0 "" move_folder_failed
    StrCmp $R1 "" move_folder_failed
    Push "$R0"
    Call ${PREFIX}_MoveCheckLiteralPath
    IfErrors move_folder_failed
    Push "$R1"
    Call ${PREFIX}_MoveCheckLiteralPath
    IfErrors move_folder_failed
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
    ${${PREFIX}GetRoot} "$R1" $0
    StrCmpS $R1 $0 0 +2
    StrCpy $R1 "$R1\"
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

    System::Call 'kernel32::GetFileAttributesW(w R1) i.r0 ?e'
    Pop $1
    IntCmp $0 -1 0 move_folder_existing move_folder_existing
    StrCmp $1 2 move_folder_scan
    StrCmp $1 3 0 move_folder_failed
    Goto move_folder_scan
move_folder_existing:
    IntOp $0 $0 & 0x10
    StrCmp $0 0 move_folder_failed
    Push "$R1"
    Call ${PREFIX}_MovePathInfo
    Pop $5
    Pop $4
    IfErrors move_folder_failed
    StrCmpS $2 $5 move_folder_done
move_folder_scan:
    Push "$R0"
    Push "scan"
    Call ${PREFIX}_MoveFolderWalk
    IfErrors move_folder_failed
    StrCpy $_MoveFolderSources $_MoveFolderSeen
    StrCpy $_MoveFolderSeen 0
    !insertmacro _MoveFolderRun "${PREFIX}" "$R0" "create"
    !insertmacro _MoveFolderRun "${PREFIX}" "$R0" "move"
    StrCpy $R3 0
    !insertmacro _MoveFolderRun "${PREFIX}" "$R0" "clean"
    !insertmacro _MoveFolderRun "${PREFIX}" "$R1" "clean"
    Goto move_folder_done

move_folder_failed:
    DetailPrint "Failed to move folder: $R0 to $R1 (mask: $R2)"
    StrCpy $6 1
    Goto move_folder_release
move_folder_done:
    StrCpy $6 0
move_folder_release:
    Push $_MoveFolderSeen
    Call ${PREFIX}_MoveFolderFreeList
    Push $_MoveFolderSources
    Call ${PREFIX}_MoveFolderFreeList
    Pop $_MoveFolderSeen
    Pop $_MoveFolderSources
    ClearErrors
    StrCmp $6 0 +2
    SetErrors
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
        Push "$R9"
        Call ${PREFIX}_MoveFolderDestination
        Pop $R4
        IfErrors move_create_failed
        Push "$R4"
        Call ${PREFIX}_MoveFolderCheckDestination
        IfErrors move_create_failed
        CreateDirectory "$R4"
        Goto move_create_done
move_create_failed:
        SetErrors
move_create_done:
        Pop $R4
    ${EndIf}
    Push ""
FunctionEnd

Function ${PREFIX}_MoveFolder_Locate_moveFile
    Push $R4
    Push $0
    Push "$R9"
    Call ${PREFIX}_MoveFolderDestination
    Pop $R4
    IfErrors move_mapped_failed
    ${${PREFIX}GetParent} "$R4" $0
    Push "$0"
    Call ${PREFIX}_MoveFolderCheckDestination
    IfErrors move_mapped_failed
    ${${PREFIX}MoveFile} "$R9" "$R4"
    Goto move_mapped_done
move_mapped_failed:
    SetErrors
move_mapped_done:
    Pop $0
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
