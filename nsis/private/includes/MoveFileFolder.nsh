!ifndef __INCLUDE_MOVEFILEFOLDER
!define __INCLUDE_MOVEFILEFOLDER

!include LogicLib.nsh
!include FileFunc.nsh

; Set to 1 to overwrite existing destination files without an 'ifnewer' check.
Var /GLOBAL switch_overwrite

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; MoveFile and MoveFolder macros
;
; Author:  theblazingangel@aol.com (for the AutoPatcher project - www.autopatcher.com)
; Created: June 2007
; Source: https://nsis.sourceforge.io/MoveFileFolder
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

    ; The old timestamp branch could delete a file moved onto itself.
    StrCmp $0 $1 move_file_done
    DetailPrint "Moving/renaming file: $0 to $1"

move_file_destination:
    System::Call 'kernel32::GetFileAttributesW(w r1) i.r2 ?e'
    Pop $7
    IntCmp $2 -1 move_file_missing
    IntOp $2 $2 & 0x10
    StrCmp $2 0 0 move_file_failed
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
    StrCmp $2 0 0 move_file_done
    StrCmp $6 2 0 move_file_windows_error
    ; If a destination appeared after our check, apply the timestamp policy.
    StrCmp $7 80 move_file_destination
    StrCmp $7 183 move_file_destination
move_file_windows_error:
    DetailPrint "Windows move error: $7"
move_file_failed:
    DetailPrint "Failed to move file: $0 to $1"
    SetErrors

move_file_done:
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
    StrCmp $R0 $R1 move_folder_done

    ; A destination inside the source would be traversed and moved recursively.
    StrLen $0 "$R0"
    IntOp $0 $0 + 1
    StrCpy $1 "$R1" $0
    StrCmp $1 "$R0\" move_folder_failed

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

move_folder_delete_destination:
    StrCpy $R3 0
    ${${PREFIX}Locate} "$R1" "/L=DE" "${PREFIX}_MoveFolder_Locate_deleteDir"
    IfErrors move_folder_failed
    StrCmp $R3 0 0 move_folder_delete_destination

    ; Nonmatching files deliberately remain in the source and are not errors.
    ${${PREFIX}DirState} "$R0" $0
    StrCmp $0 -1 move_folder_failed
    ; DirState uses FindNext's error flag to signal an empty directory.
    ClearErrors
    StrCmp $0 0 0 move_folder_done
    RMDir "$R0"
    IfErrors move_folder_failed
    Goto move_folder_done

move_folder_failed:
    DetailPrint "Failed to move folder: $R0 to $R1 (mask: $R2)"
    SetErrors
move_folder_done:
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
