!ifndef __INCLUDE_ARCH
!define __INCLUDE_ARCH

!include x64.nsh
!include Logging.nsh

!define IsNativeARM32 '${IsNativeMachineArchitecture} 448'

Var current_arch
Var is64bit
Var is32bit
Var isArm
Var isx86

!macro GetArch OUT
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    StrCpy ${OUT} $current_arch
!macroend
!define GetArch `!insertmacro GetArch`

!macro un.GetArch OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $current_arch
!macroend
!define un.GetArch `!insertmacro un.GetArch`

!macro Is64Bit OUT
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    StrCpy ${OUT} $is64bit
!macroend
!define Is64Bit `!insertmacro Is64Bit`

!macro un.Is64Bit OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $is64bit
!macroend
!define un.Is64Bit `!insertmacro un.Is64Bit`

!macro Is32Bit OUT
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    StrCpy ${OUT} $is32bit
!macroend
!define Is32Bit `!insertmacro Is32Bit`

!macro un.Is32Bit OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $is32bit
!macroend
!define un.Is32Bit `!insertmacro un.Is32Bit`

!macro _DetectArch PREFIX
Function ${PREFIX}DetectArch
    ${If} ${IsNativeAMD64}
        StrCpy $is64bit "1"
        StrCpy $isArm "0"
        StrCpy $is32bit "0"
        StrCpy $isx86 "1"
        StrCpy $current_arch "x86_64"
    ${ElseIf} ${IsNativeIA32}
        StrCpy $is64bit "0"
        StrCpy $isArm "0"
        StrCpy $is32bit "1"
        StrCpy $isx86 "1"
        StrCpy $current_arch "x86_32"
    ${ElseIf} ${IsNativeARM64}
        StrCpy $is64bit "1"
        StrCpy $isArm "1"
        StrCpy $is32bit "0"
        StrCpy $isx86 "0"
        StrCpy $current_arch "arm64"
    ${ElseIf} ${IsNativeARM32}
        StrCpy $is64bit "0"
        StrCpy $isArm "1"
        StrCpy $is32bit "1"
        StrCpy $isx86 "0"
        StrCpy $current_arch "arm32"
    ${ElseIf} ${RunningX64}
        StrCpy $is64bit "1"
        StrCpy $isArm "0"
        StrCpy $is32bit "0"
        StrCpy $isx86 "1"
        StrCpy $current_arch "x86_64"
    ${Else}
        StrCpy $is64bit "0"
        StrCpy $isArm "0"
        StrCpy $is32bit "1"
        StrCpy $isx86 "1"
        StrCpy $current_arch "x86_32"
    ${EndIf}
FunctionEnd
!macroend

!insertmacro _DetectArch ""
!insertmacro _DetectArch "un."

!macro DetectArch
    Call DetectArch
!macroend
!define DetectArch `!insertmacro DetectArch`

!macro un.DetectArch
    Call un.DetectArch
!macroend
!define un.DetectArch `!insertmacro un.DetectArch`

!define IfBitWdithMatch `${If} `

!macro ValidateArch EXPECTED
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} "${EXPECTED}" != $current_arch
        Push $0
        StrCpy $0 $current_arch
        !insertmacro LogError "Current arch '$0' is not expected ${EXPECTED}"
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} version of windows. You are running with $0." /SD IDOK
        Pop $0
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define ValidateArch `!insertmacro ValidateArch`

!macro un.ValidateArch EXPECTED
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} "${EXPECTED}" != $current_arch
        Push $0
        StrCpy $0 $current_arch
        !insertmacro LogError "Current architecture '$0' is not expected ${EXPECTED}"
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} version of windows. You are running with $0." /SD IDOK
        Pop $0
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define un.ValidateArch `!insertmacro un.ValidateArch`

!macro ValidateBitwdth EXPECTED
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64Bit == "0"
        !insertmacro LogError "Installer must be run on a 64 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 64 bit computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${ElseIf} ${EXPECTED} = 32
    ${AndIf} $is32bit == "0"
        !insertmacro LogError "Installer must be run on a 32 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 32 bit computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define ValidateBitwdth `!insertmacro ValidateBitwdth`

!macro un.ValidateBitwdth EXPECTED
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64Bit == "0"
        !insertmacro LogError "Installer must be run on a 64 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 64 bit computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${ElseIf} ${EXPECTED} = 32
    ${AndIf} $is32bit == "0"
        !insertmacro LogError "Installer must be run on a 32 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 32 bit computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define un.ValidateBitwdth `!insertmacro un.ValidateBitwdth`

!macro ValidateISA EXPECTED
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} ${EXPECTED} == "arm"
    ${AndIf} $isArm == "0"
        !insertmacro LogError "Installer must be run on an arm computer."
        MessageBox MB_ICONSTOP "Installer must be run on an arm computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${ElseIf} ${EXPECTED} == "x86"
    ${AndIf} $isx86 == "0"
        !insertmacro LogError "Installer must be run on a x86 computer."
        MessageBox MB_ICONSTOP "Installer must be run on a x86 computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define ValidateISA `!insertmacro ValidateISA`

!macro un.ValidateISA EXPECTED
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} ${EXPECTED} == "arm"
    ${AndIf} $isArm == "0"
        !insertmacro LogError "Installer must be run on an arm computer."
        MessageBox MB_ICONSTOP "Installer must be run on an arm computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${ElseIf} ${EXPECTED} == "x86"
    ${AndIf} $isx86 == "0"
        !insertmacro LogError "Installer must be run on a x86 computer."
        MessageBox MB_ICONSTOP "Installer must be run on a x86 computer." /SD IDOK
        SetErrorLevel 3
        Abort
    ${EndIf}
!macroend
!define un.ValidateISA `!insertmacro un.ValidateISA`

!endif
