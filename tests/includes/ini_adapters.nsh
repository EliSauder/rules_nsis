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
    nsArray::Length harness_list
    Pop ${COUNT}
    StrCpy ${FIRST} ""
    StrCpy ${SECOND} ""
    ${If} ${COUNT} > 0
        nsArray::Get harness_list /at=0
        Pop ${FIRST}
        Pop ${FIRST}
    ${EndIf}
    ${If} ${COUNT} > 1
        nsArray::Get harness_list /at=1
        Pop ${SECOND}
        Pop ${SECOND}
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
    nsArray::Join harness_sections ","
    Pop ${SECTIONS}
    ${Ini_Keys} `${FILE}` `${SECTION}` harness_keys
    nsArray::Join harness_keys ","
    Pop ${KEYS}
!macroend

; Formats the items that are not empty and writes the text to OUT_FILE, since
; harness outputs cannot hold line breaks.
!macro HarnessIniFormatList A B KEY OUT_FILE
    Push $R8
    Push $R9
    nsArray::Set harness_items /key=0 ""
    nsArray::Clear harness_items
    ${If} `${A}` != ""
        nsArray::Set harness_items /key=0 `${A}`
    ${EndIf}
    ${If} `${B}` != ""
        nsArray::Length harness_items
        Pop $R9
        nsArray::Set harness_items /key=$R9 `${B}`
    ${EndIf}
    ${Ini_FormatList} harness_items `${KEY}` $R9
    FileOpen $R8 `${OUT_FILE}` w
    FileWrite $R8 $R9
    FileClose $R8
    Pop $R9
    Pop $R8
!macroend
