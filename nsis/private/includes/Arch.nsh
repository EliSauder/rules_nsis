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

; Sets OUT to 1 when the detected architecture may run an EXPECTED installer
; under allow_32bit_on_64bit, else 0: EXPECTED itself, or the 64bit host of the
; same instruction set (x86_32 on x86_64, arm32 on arm64). Cross-ISA hosts are
; rejected. A 64bit EXPECTED only accepts itself.
!macro __ArchAllows32On64 PREFIX
Function ${PREFIX}_ArchAllows32On64
    Exch $0 ; expected
    Push $1 ; 64bit host of the same instruction set
    ${If} $current_arch == ""
        Call ${PREFIX}DetectArch
    ${EndIf}
    ${If} $0 == "x86_32"
        StrCpy $1 "x86_64"
    ${ElseIf} $0 == "arm32"
        StrCpy $1 "arm64"
    ${Else}
        StrCpy $1 $0
    ${EndIf}
    ${If} $current_arch == $0
    ${OrIf} $current_arch == $1
        StrCpy $0 "1"
    ${Else}
        StrCpy $0 "0"
    ${EndIf}
    Pop $1
    Exch $0
FunctionEnd
!macroend
!insertmacro __ArchAllows32On64 ""
!insertmacro __ArchAllows32On64 "un."

!macro _ArchAllows32On64 PREFIX EXPECTED OUT
    Push "${EXPECTED}"
    Call ${PREFIX}_ArchAllows32On64
    Pop ${OUT}
!macroend

!macro ArchAllows32On64 EXPECTED OUT
    !insertmacro _ArchAllows32On64 "" "${EXPECTED}" ${OUT}
!macroend
!define ArchAllows32On64 `!insertmacro ArchAllows32On64`

!macro un.ArchAllows32On64 EXPECTED OUT
    !insertmacro _ArchAllows32On64 "un." "${EXPECTED}" ${OUT}
!macroend
!define un.ArchAllows32On64 `!insertmacro un.ArchAllows32On64`

; Aborts unless ArchAllows32On64 accepts the detected architecture.
!macro _ValidateArch32On64 PREFIX EXPECTED
    Push $0
    !insertmacro _ArchAllows32On64 "${PREFIX}" "${EXPECTED}" $0
    ${If} $0 != "1"
        StrCpy $0 $current_arch
        !insertmacro LogError "Current architecture '$0' cannot run a ${EXPECTED} installer."
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} compatible version of windows. You are running with $0." /SD IDOK
        Pop $0
        SetErrorLevel 3
        Abort
    ${EndIf}
    Pop $0
!macroend

!macro ValidateArch32On64 EXPECTED
    !insertmacro _ValidateArch32On64 "" "${EXPECTED}"
!macroend
!define ValidateArch32On64 `!insertmacro ValidateArch32On64`

!macro un.ValidateArch32On64 EXPECTED
    !insertmacro _ValidateArch32On64 "un." "${EXPECTED}"
!macroend
!define un.ValidateArch32On64 `!insertmacro un.ValidateArch32On64`

!macro ValidateBitwidth EXPECTED
    ${If} $current_arch == ""
        Call DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64bit == "0"
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
!define ValidateBitwidth `!insertmacro ValidateBitwidth`

!macro un.ValidateBitwidth EXPECTED
    ${If} $current_arch == ""
        Call un.DetectArch
    ${EndIf}
    ${If} ${EXPECTED} = 64
    ${AndIf} $is64bit == "0"
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
!define un.ValidateBitwidth `!insertmacro un.ValidateBitwidth`

!macro _ValidateISA PREFIX EXPECTED
    ${If} $current_arch == ""
        Call ${PREFIX}DetectArch
    ${EndIf}
    Push $0
    ; EXPECTED may be an ISA ("x86", "arm") or a full arch ("x86_32", "arm64").
    StrCpy $0 "${EXPECTED}" 3
    ${If} $0 == "arm"
        StrCpy $0 $isArm
    ${ElseIf} $0 == "x86"
        StrCpy $0 $isx86
    ${Else}
        StrCpy $0 "0"
    ${EndIf}
    ${If} $0 != "1"
        StrCpy $0 $current_arch
        !insertmacro LogError "Current architecture '$0' does not match the ${EXPECTED} instruction set."
        MessageBox MB_ICONSTOP "This installer requires a ${EXPECTED} compatible version of windows. You are running with $0." /SD IDOK
        Pop $0
        SetErrorLevel 3
        Abort
    ${EndIf}
    Pop $0
!macroend

!macro ValidateISA EXPECTED
    !insertmacro _ValidateISA "" "${EXPECTED}"
!macroend
!define ValidateISA `!insertmacro ValidateISA`

!macro un.ValidateISA EXPECTED
    !insertmacro _ValidateISA "un." "${EXPECTED}"
!macroend
!define un.ValidateISA `!insertmacro un.ValidateISA`

!endif
