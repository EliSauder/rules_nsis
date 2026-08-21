!ifndef __INCLUDE_UTILITY
!define __INCLUDE_UTILITY

!macro _TrimQuotes PREFIX
Function ${PREFIX}TrimQuotes
    Exch $R0
    Push $R1

    StrCpy $R1 $R0 1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 `` 1

    StrCpy $R1 $R0 1 -1
    StrCmp $R1 `"` 0 +2
        StrCpy $R0 $R0 -1

    Pop $R1
    Exch $R0
FunctionEnd
!macroend

!insertmacro _TrimQuotes ""
!insertmacro _TrimQuotes "un."

!macro TrimQuotes Input Output
    Push "${Input}"
    Call TrimQuotes
    Pop ${Output}
!macroend

!macro un.TrimQuotes Input Output
    Push "${Input}"
    Call un.TrimQuotes
    Pop ${Output}
!macroend

!endif
