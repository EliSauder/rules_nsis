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

;==================
; MoveFile macro
;==================

!macro MoveFile sourceFile destinationFile

!define _MOVEFILE_JUMP ${__LINE__}

; Check source actually exists

    IfFileExists "${sourceFile}" +3 0
    SetErrors
    goto done_${_MOVEFILE_JUMP}

; Add message to details-view/install-log

    DetailPrint "Moving/renaming file: ${sourceFile} to ${destinationFile}"

; If destination does not already exists simply move file

    IfFileExists "${destinationFile}" +3 0
    rename "${sourceFile}" "${destinationFile}"
    goto done_${_MOVEFILE_JUMP}

; If overwriting without 'ifnewer' check

    ${If} $switch_overwrite == 1
	delete "${destinationFile}"
	rename "${sourceFile}" "${destinationFile}"
	delete "${sourceFile}"
	goto done_${_MOVEFILE_JUMP}
    ${EndIf}

; If destination already exists

    Push $R0
    Push $R1
    Push $R2
    push $R3

    GetFileTime "${sourceFile}" $R0 $R1
    GetFileTime "${destinationFile}" $R2 $R3

    IntCmp $R0 $R2 0 older_${_MOVEFILE_JUMP} newer_${_MOVEFILE_JUMP}
    IntCmp $R1 $R3 older_${_MOVEFILE_JUMP} older_${_MOVEFILE_JUMP} newer_${_MOVEFILE_JUMP}

older_${_MOVEFILE_JUMP}:
    delete "${sourceFile}"
    goto time_check_done_${_MOVEFILE_JUMP}

newer_${_MOVEFILE_JUMP}:
    delete "${destinationFile}"
    rename "${sourceFile}" "${destinationFile}"
    delete "${sourceFile}" ;in case above failed!

time_check_done_${_MOVEFILE_JUMP}:

    Pop $R3
    Pop $R2
    Pop $R1
    Pop $R0

done_${_MOVEFILE_JUMP}:

!undef _MOVEFILE_JUMP

!macroend
!define MoveFile `!insertmacro MoveFile`

!macro un.MoveFile sourceFile destinationFile
    !insertmacro MoveFile `${sourceFile}` `${destinationFile}`
!macroend
!define un.MoveFile `!insertmacro un.MoveFile`

;==================
; MoveFolder macro
;==================

!macro _MoveFolder PREFIX source destination mask

    !define _MOVEFOLDER_JUMP ${__LINE__}

    Push $R0
    Push $R1

; Move path parameters into registers so they can be altered if necessary

    StrCpy $R0 "${source}"
    StrCpy $R1 "${destination}"

; Sort out paths - remove final backslash if supplied

    Push $0

    ; Source
    StrCpy $0 "$R0" 1 -1
    StrCmp $0 '\' 0 +2
    StrCpy $R0 "$R0" -1

    ; Destination
    StrCpy $0 "$R1" 1 -1
    StrCmp $0 '\' 0 +2
    StrCpy $R1 "$R1" -1

    Pop $0

; Create destination dir

    CreateDirectory "$R1\"

; Add message to details-view/install-log

    DetailPrint "Moving files: $R0\${mask} to $R1\"

; Push registers used by ${Locate} onto stack

    Push $R6
    Push $R7
    Push $R8
    Push $R9

; Duplicate dir structure (to preserve empty folders and such)

    ${${PREFIX}Locate} "$R0" "/L=D" "${PREFIX}_MoveFolder_Locate_createDir"

; Locate files and move (via callback function)

    ${${PREFIX}Locate} "$R0" "/L=F /M=${mask} /S= /G=1" "${PREFIX}_MoveFolder_Locate_moveFile"

; Delete subfolders left over after move

    Push $R2
deldir_loop_${_MOVEFOLDER_JUMP}:
    StrCpy $R2 0
    ${${PREFIX}Locate} "$R0" "/L=DE" "${PREFIX}_MoveFolder_Locate_deleteDir"
    StrCmp $R2 0 0 deldir_loop_${_MOVEFOLDER_JUMP}
    Pop $R2

; Delete empty subfolders moved - say the user just wanted to move *.apm files, they now also have a load of empty dir's from dir structure duplication!

    Push $R2
delnewdir_loop_${_MOVEFOLDER_JUMP}:
    StrCpy $R2 0
    ${${PREFIX}Locate} "$R1" "/L=DE" "${PREFIX}_MoveFolder_Locate_deleteDir"
    StrCmp $R2 0 0 delnewdir_loop_${_MOVEFOLDER_JUMP}
    Pop $R2

; Pop registers used by ${Locate} off the stack again

    Pop $R9
    Pop $R8
    Pop $R7
    Pop $R6

; Delete source folder if empty

    rmdir "$R0"

Pop $R1
Pop $R0

!undef _MOVEFOLDER_JUMP

!macroend

!macro MoveFolder source destination mask
    !insertmacro _MoveFolder "" `${source}` `${destination}` `${mask}`
!macroend
!define MoveFolder `!insertmacro MoveFolder`

!macro un.MoveFolder source destination mask
    !insertmacro _MoveFolder "un." `${source}` `${destination}` `${mask}`
!macroend
!define un.MoveFolder `!insertmacro un.MoveFolder`

;==================
; MoveFolder macro's ${Locate} callback functions
;==================

!macro _MoveFolderCallbacks PREFIX
Function ${PREFIX}_MoveFolder_Locate_createDir

    ${If} $R6 == ""
	Push $R2
	StrLen $R2 "$R0"
	StrCpy $R2 $R9 '' $R2
	CreateDirectory "$R1$R2"
	Pop $R2
    ${EndIf}

    Push $R1

FunctionEnd

Function ${PREFIX}_MoveFolder_Locate_moveFile

    Push $R2

    ; Get path to file

	StrLen $R2 "$R0"
	StrCpy $R2 $R9 '' $R2
	StrCpy $R2 "$R1$R2"

    ; If destination does not already exists simply move file

	IfFileExists "$R2" +3 0
	rename "$R9" "$R2"
	goto done

    ; If overwriting without 'ifnewer' check

	${If} $switch_overwrite == 1
	    delete "$R2"
	    rename "$R9" "$R2"
	    delete "$R9"
	    goto done
	${EndIf}

    ; If destination already exists

	Push $0
	Push $1
	Push $2
	push $3

	GetFileTime "$R9" $0 $1
	GetFileTime "$R2" $2 $3

	IntCmp $0 $2 0 older newer
	IntCmp $1 $3 older older newer

	older:
	delete "$R9"
	goto time_check_done

	newer:
	delete "$R2"
	rename "$R9" "$R2"
	delete "$R9" ;in case above failed!

	time_check_done:

	Pop $3
	Pop $2
	Pop $1
	Pop $0

    done:

    Pop $R2

    Push $R1

FunctionEnd

Function ${PREFIX}_MoveFolder_Locate_deleteDir

    ${If} $R6 == ""
	RMDir $R9
	IntOp $R2 $R2 + 1
    ${EndIf}

    Push $R1

FunctionEnd
!macroend

!insertmacro _MoveFolderCallbacks ""
!insertmacro _MoveFolderCallbacks "un."

!endif
