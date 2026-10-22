!include "Version.nsh"

!macro PreInit
    ${VersionCompare} "1.2.3" "1.2.4" $0
    ${If} $0 != "-1"
        SetErrorlevel 101
        Abort
    ${EndIf}

    ${NormalizeGuid} "aabbccdd-eeff-0011-2233-445566778899" $0
    ${If} $0 != "{AABBCCDD-EEFF-0011-2233-445566778899}"
        SetErrorlevel 102
        Abort
    ${EndIf}

    ${CharToASCII} "A" $0
    ${If} $0 != "65"
        SetErrorlevel 103
        Abort
    ${EndIf}

    ${Hex2Bin} "41" $0
    ${If} $0 != "01000001"
        SetErrorlevel 104
        Abort
    ${EndIf}

    ${FormatStrToBin} "A" 0 $0
    ${If} $0 != "01000001"
        SetErrorlevel 105
        Abort
    ${EndIf}

    ${GetArch} $0
    ${If} $0 == ""
        SetErrorlevel 106
        Abort
    ${EndIf}
!macroend

!macro PreUnInit
    ${un.NormalizeGuid} "aabbccdd-eeff-0011-2233-445566778899" $0
    ${If} $0 != "{AABBCCDD-EEFF-0011-2233-445566778899}"
        SetErrorlevel 111
        Abort
    ${EndIf}

    ${un.CharToASCII} "A" $0
    ${If} $0 != "65"
        SetErrorlevel 112
        Abort
    ${EndIf}

    ${un.Hex2Bin} "41" $0
    ${If} $0 != "01000001"
        SetErrorlevel 113
        Abort
    ${EndIf}

    ${un.FormatStrToBin} "A" 0 $0
    ${If} $0 != "01000001"
        SetErrorlevel 114
        Abort
    ${EndIf}

    ${un.GetArch} $0
    ${If} $0 == ""
        SetErrorlevel 115
        Abort
    ${EndIf}
!macroend
