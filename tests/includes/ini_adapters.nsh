!include "Ini.nsh"

; Reads the list and reports how many values there are, the first two and
; whether the read reported an error (no value).
!macro HarnessIniReadList FILE SECTION KEY COUNT FIRST SECOND MISSING
    ${Ini_ReadList} `${FILE}` `${SECTION}` `${KEY}` harness_list
    ${If} ${Errors}
        StrCpy ${MISSING} 1
    ${Else}
        StrCpy ${MISSING} 0
    ${EndIf}
    ${Array_Length} harness_list ${COUNT}
    StrCpy ${FIRST} ""
    StrCpy ${SECOND} ""
    ${If} ${COUNT} > 0
        ${Array_GetAt} harness_list 0 ${FIRST}
    ${EndIf}
    ${If} ${COUNT} > 1
        ${Array_GetAt} harness_list 1 ${SECOND}
    ${EndIf}
!macroend

!macro HarnessIniReadStr FILE SECTION KEY VALUE MISSING
    ${Ini_ReadStr} `${FILE}` `${SECTION}` `${KEY}` ${VALUE}
    ${If} ${Errors}
        StrCpy ${MISSING} 1
    ${Else}
        StrCpy ${MISSING} 0
    ${EndIf}
!macroend

; Reports the section names, and the key names of SECTION, joined with commas.
!macro HarnessIniNames FILE SECTION SECTIONS KEYS
    ${Ini_Sections} `${FILE}` harness_sections
    ${Array_Join} harness_sections "," ${SECTIONS}
    ${Ini_Keys} `${FILE}` `${SECTION}` harness_keys
    ${Array_Join} harness_keys "," ${KEYS}
!macroend

; Formats the items that are not empty and writes the text to OUT_FILE, since
; harness outputs cannot hold line breaks.
!macro HarnessIniFormatList A B KEY OUT_FILE
    Push $R8
    Push $R9
    ${Array_Reset} harness_items
    ${If} `${A}` != ""
        ${Array_Append} harness_items `${A}`
    ${EndIf}
    ${If} `${B}` != ""
        ${Array_Append} harness_items `${B}`
    ${EndIf}
    ${Ini_FormatList} harness_items `${KEY}` $R9
    FileOpen $R8 `${OUT_FILE}` w
    FileWrite $R8 $R9
    FileClose $R8
    Pop $R9
    Pop $R8
!macroend
