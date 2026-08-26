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

!macro un.GetArch OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $current_arch
!macroend

!macro Is64Bit OUT
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    StrCpy ${OUT} $is64bit
!macroend

!macro un.Is64Bit OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $is64bit
!macroend

!macro Is32Bit OUT
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    StrCpy ${OUT} $is32bit
!macroend

!macro un.Is32Bit OUT
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    StrCpy ${OUT} $is32bit
!macroend

!macro un.GetArch OUT
    StrCpy ${OUT} $current_arch
!macroend

!macro _DetectArch PREFIX
Function ${PREFIX}DetectArch
    ${If} ${IsNativeX64}
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

!define IfBitWdithMatch `${If} `

!macro ValidateArch EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} "${EXPECTED}" != $current_arch
        Push $0
        StrCpy $0 $current_arch
        !insertmacro LogError "Current arch '$0' is not expected ${EXPECTED}"
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} version of windows. You are running with $0." /SD IDOK
        Abort 3
        Pop $0
    ${EndIf}
!macroend

!macro un.ValidateArch EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} "${EXPECTED}" != $current_arch
        Push $0
        StrCpy $0 $current_arch
        !insertmacro un.LogError "Current architecture '$0' is not expected ${EXPECTED}"
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} version of windows. You are running with $0." /SD IDOK
        Abort 3
        Pop $0
    ${EndIf}
!macroend

!macro ValidateBitwdth EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64Bit == "0"
        !insertmacro un.LogError "Installer must be run on a 64 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 64 bit computer." /SD IDOK
        Abort 3
    ${ElseIf} ${EXPECTED} = 32
    ${AndIf} $is32bit == "0"
        !insertmacro un.LogError "Installer must be run on a 32 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 32 bit computer." /SD IDOK
        Abort 3
    ${EndIf}
!macroend

!macro un.ValidateBitwdth EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64Bit == "0"
        !insertmacro un.LogError "Installer must be run on a 64 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 64 bit computer." /SD IDOK
        Abort 3
    ${ElseIf} ${EXPECTED} = 32
    ${AndIf} $is32bit == "0"
        !insertmacro un.LogError "Installer must be run on a 32 bit computer."
        MessageBox MB_ICONSTOP "Installer must be run on a 32 bit computer." /SD IDOK
        Abort 3
    ${EndIf}
!macroend

!macro ValidateISA EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} ${EXPECTED} == "arm"
    ${AndIf} $isArm == "0"
        !insertmacro un.LogError "Installer must be run on an arm computer."
        MessageBox MB_ICONSTOP "Installer must be run on an arm computer." /SD IDOK
        Abort 3
    ${ElseIf} ${EXPECTED} == "x86"
    ${AndIf} $isx86 == "0"
        !insertmacro un.LogError "Installer must be run on a x86 computer."
        MessageBox MB_ICONSTOP "Installer must be run on a x86 computer." /SD IDOK
        Abort 3
    ${EndIf}
!macroend

!macro un.ValidateISA EXPECTED
    !insertmacro
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} ${EXPECTED} == "arm"
    ${AndIf} $isArm == "0"
        !insertmacro un.LogError "Installer must be run on an arm computer."
        MessageBox MB_ICONSTOP "Installer must be run on an arm computer." /SD IDOK
        Abort 3
    ${ElseIf} ${EXPECTED} == "x86"
    ${AndIf} $isx86 == "0"
        !insertmacro un.LogError "Installer must be run on a x86 computer."
        MessageBox MB_ICONSTOP "Installer must be run on a x86 computer." /SD IDOK
        Abort 3
    ${EndIf}
!macroend

!endif
