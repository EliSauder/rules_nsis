!ifndef __INCLUDE_VERSION
!define __INCLUDE_VERSION

; Compare dotted version numbers.
;
; Originally based on https://nsis.sourceforge.io/VersionCompare (Afrow UK's
; VersionCheckNew2). Rewritten so each component is compared as a whole
; non-negative integer: leading zeros are ignored ("01.002" equals "1.2") and
; missing trailing components count as zero ("1.2" equals "1.2.0"). Components
; are compared digit by digit, so they are not limited to 32-bit integers.
;
; Syntax:
; ${VersionCompare} "[Version1]" "[Version2]" $var
; ${un.VersionCompare} "[Version1]" "[Version2]" $var
;
; "[Version1]"        ; First version
; "[Version2]"        ; Second version
; $var                ; Result:
;                     ;    $var=0  Versions are equal
;                     ;    $var=1  Version1 is newer
;                     ;    $var=-1  Version2 is newer
!macro _VersionCompare PREFIX
Function ${PREFIX}VersionCompare
	Exch $1 ; version 2
	Exch
	Exch $0 ; version 1
	Exch
	Push $2 ; scan index
	Push $3 ; character
	Push $4 ; version 1 component
	Push $5 ; version 2 component
	Push $6 ; component length
	Push $7 ; version 2 digit

next_component:
	StrCmp $0$1 "" equal

	; Split the next component from each version.
	StrCpy $2 0
version1_scan:
	StrCpy $3 $0 1 $2
	StrCmp $3 "" version1_split
	StrCmp $3 "." version1_split
	IntOp $2 $2 + 1
	Goto version1_scan
version1_split:
	StrCpy $4 $0 $2
	IntOp $2 $2 + 1
	StrCpy $0 $0 "" $2

	StrCpy $2 0
version2_scan:
	StrCpy $3 $1 1 $2
	StrCmp $3 "" version2_split
	StrCmp $3 "." version2_split
	IntOp $2 $2 + 1
	Goto version2_scan
version2_split:
	StrCpy $5 $1 $2
	IntOp $2 $2 + 1
	StrCpy $1 $1 "" $2

	; Strip leading zeros; an all-zero or missing component becomes "".
version1_trim:
	StrCpy $3 $4 1
	StrCmp $3 "0" 0 version2_trim
	StrCpy $4 $4 "" 1
	Goto version1_trim
version2_trim:
	StrCpy $3 $5 1
	StrCmp $3 "0" 0 compare_lengths
	StrCpy $5 $5 "" 1
	Goto version2_trim

compare_lengths:
	; Without leading zeros, the longer number is the larger one.
	StrLen $6 $4
	StrLen $2 $5
	IntCmp $6 $2 0 newer2 newer1

	StrCpy $2 0
compare_digits:
	IntCmp $2 $6 next_component
	StrCpy $3 $4 1 $2
	StrCpy $7 $5 1 $2
	IntCmp $3 $7 0 newer2 newer1
	IntOp $2 $2 + 1
	Goto compare_digits

equal:
	StrCpy $0 0
	Goto end
newer1:
	StrCpy $0 1
	Goto end
newer2:
	StrCpy $0 -1

end:
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Exch $0
FunctionEnd
!macroend

!insertmacro _VersionCompare ""
!insertmacro _VersionCompare "un."

!macro VersionCompare _VER1 _VER2 _RESULT
	Push `${_VER1}`
	Push `${_VER2}`
	Call VersionCompare
	Pop ${_RESULT}
!macroend
!define VersionCompare `!insertmacro VersionCompare`

!macro un.VersionCompare _VER1 _VER2 _RESULT
	Push `${_VER1}`
	Push `${_VER2}`
	Call un.VersionCompare
	Pop ${_RESULT}
!macroend
!define un.VersionCompare `!insertmacro un.VersionCompare`

!endif
