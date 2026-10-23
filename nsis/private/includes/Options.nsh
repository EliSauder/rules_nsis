!ifndef __INCLUDE_OPTIONS
!define __INCLUDE_OPTIONS

; Runtime side of options pages (nsis_options_page).
;
; Every option lives in a compile-time named variable `$__opt_<page>_<key>`
; that the generated installer code declares. The accessors below take the
; page and the key as plain words, not as strings or variables:
;
;   ${Option_Get} install_page path $0
;   ${If} install_page ${Option_IsSet} desktop_icon
;
; The generated code also defines `__Options_ForEachPersisted CALLBACK`, which
; invokes `!insertmacro ${CALLBACK} "<page>" "<key>"` for every persisted
; option. It is what Option_Persist and Option_LoadPersisted iterate. It
; defaults to nothing so this file compiles on its own.
;
; Persisted values are stored as REG_SZ values named `<page>.<key>` under
; `<product key>\Options`, in the view and shell context the installer uses.
; The product key must be set with ${SetProductKey} (Product.nsh) before
; persisting or loading values.

!include LogicLib.nsh
!include Logging.nsh
!include Product.nsh
!include Registry.nsh
!include ShellContext.nsh
!include Testing.nsh
!include WinMessages.nsh
!ifndef DTM_SETRANGE
  !define /math DTM_SETRANGE ${DTM_FIRST} + 4
!endif


!ifmacrondef __Options_ForEachPersisted
!macro __Options_ForEachPersisted CALLBACK
!macroend
!endif

!macro Option_Get PAGE KEY OUT
    StrCpy ${OUT} $__opt_${PAGE}_${KEY}
!macroend
!define Option_Get `!insertmacro Option_Get`

!macro Option_Set PAGE KEY VALUE
    StrCpy $__opt_${PAGE}_${KEY} `${VALUE}`
!macroend
!define Option_Set `!insertmacro Option_Set`

; True when a checkbox option is checked. `${If} page ${Option_IsSet} key`
!macro _Option_IsSet _a _b _t _f
    StrCmp $__opt_${_a}_${_b} "1" `${_t}` `${_f}`
!macroend
!define Option_IsSet `Option_IsSet`

; Sets OUT to 1 when VALUE is one of the `|` separated values of the option,
; and to 0 otherwise. Values are compared case-insensitively.
!macro Option_ListContains PAGE KEY VALUE OUT
    Push `$__opt_${PAGE}_${KEY}`
    Push `${VALUE}`
    Call Option_ListHas
    Pop ${OUT}
!macroend
!define Option_ListContains `!insertmacro Option_ListContains`

; Multi-line (richedit) values are stored on one line with `\n` for a line
; break and `\\` for a backslash. This returns the real text, with line breaks
; as CRLF.
!macro Option_GetMultiline PAGE KEY OUT
    Push `$__opt_${PAGE}_${KEY}`
    Call Option_Unescape
    Pop ${OUT}
!macroend
!define Option_GetMultiline `!insertmacro Option_GetMultiline`

!macro un.Option_GetMultiline PAGE KEY OUT
    Push `$__opt_${PAGE}_${KEY}`
    Call un.Option_Unescape
    Pop ${OUT}
!macroend
!define un.Option_GetMultiline `!insertmacro un.Option_GetMultiline`

!macro _OptionsFunctions PREFIX

; Stack: escaped text. Pushes the real text; sets the error flag (and pushes
; an empty string) when the text has an escape other than \n and \\.
Function ${PREFIX}Option_Unescape
    Exch $0 ; input
    Push $1 ; output
    Push $2 ; position
    Push $3 ; character

    ClearErrors
    StrCpy $1 ""
    StrCpy $2 0
    loop:
        StrCpy $3 $0 1 $2
        StrCmp $3 "" done
        IntOp $2 $2 + 1
        StrCmp $3 "\" escape
        StrCpy $1 "$1$3"
        Goto loop
    escape:
        StrCpy $3 $0 1 $2
        IntOp $2 $2 + 1
        StrCmp $3 "\" 0 +3
            StrCpy $1 "$1\"
            Goto loop
        StrCmp $3 "n" 0 invalid
            StrCpy $1 "$1$\r$\n"
            Goto loop
    invalid:
        StrCpy $1 ""
        SetErrors
    done:
    StrCpy $0 $1

    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: real text. Pushes the single-line escaped form; CRLF, CR and LF all
; become \n.
Function ${PREFIX}Option_Escape
    Exch $0 ; input
    Push $1 ; output
    Push $2 ; position
    Push $3 ; character

    StrCpy $1 ""
    StrCpy $2 0
    loop:
        StrCpy $3 $0 1 $2
        StrCmp $3 "" done
        IntOp $2 $2 + 1
        StrCmp $3 "\" backslash
        StrCmp $3 "$\r" carriage
        StrCmp $3 "$\n" newline
        StrCpy $1 "$1$3"
        Goto loop
    backslash:
        StrCpy $1 "$1\\"
        Goto loop
    carriage:
        StrCpy $3 $0 1 $2
        StrCmp $3 "$\n" 0 newline
        IntOp $2 $2 + 1
    newline:
        StrCpy $1 "$1\n"
        Goto loop
    done:
    StrCpy $0 $1

    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: list. Pushes the number of `|` separated items (0 for an empty list).
Function ${PREFIX}Option_ListCount
    Exch $0 ; list
    Push $1 ; count
    Push $2 ; position
    Push $3

    StrCpy $1 0
    StrCmp $0 "" done
    StrCpy $1 1
    StrCpy $2 0
    loop:
        StrCpy $3 $0 1 $2
        StrCmp $3 "" done
        StrCmp $3 "|" 0 +2
            IntOp $1 $1 + 1
        IntOp $2 $2 + 1
        Goto loop
    done:
    StrCpy $0 $1

    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: list, value (top). Pushes 1 or 0.
Function ${PREFIX}Option_ListHas
    Exch $1 ; value
    Exch
    Exch $0 ; list
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6

    StrCpy $5 0
    StrCmp $1 "" done
    StrCpy $2 0 ; token start
    StrCpy $3 0 ; scan position
    loop:
        StrCpy $4 $0 1 $3
        StrCmp $4 "|" token
        StrCmp $4 "" token
        IntOp $3 $3 + 1
        Goto loop
    token:
        IntOp $6 $3 - $2
        StrCpy $6 $0 $6 $2
        StrCmp $6 $1 0 +3
            StrCpy $5 1
            Goto done
        StrCmp $4 "" done
        IntOp $3 $3 + 1
        StrCpy $2 $3
        Goto loop
    done:
    StrCpy $1 $5

    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Exch $1
FunctionEnd

; Stack: default, name (top). Pushes the stored value, or the default when
; no value is stored.
Function ${PREFIX}Option_ReadReg
    Exch $0 ; name
    Exch
    Exch $1 ; default
    Push $2
    Push $3

    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}GetProductKey $2
    StrCpy $2 "$2\Options"
    !insertmacro _ApplyRegTestId $2 $3
    !insertmacro ${PREFIX}DefineRegView
    ClearErrors
    ReadRegStr $3 SHCTX "$2" "$0"
    IfErrors +2 0
        StrCpy $1 $3

    Pop $3
    Pop $2
    Pop $0
    Exch $1
FunctionEnd

!macroend

!insertmacro _OptionsFunctions ""
!insertmacro _OptionsFunctions "un."

; Helpers of the generated pages (date and IP address controls).

; Day or month part of a YYYY-MM-DD date without its leading zero.
!macro _Option_DatePart OUT DATE OFFSET TMP
    StrCpy ${OUT} ${DATE} 2 ${OFFSET}
    StrCpy ${TMP} ${OUT} 1
    StrCmp ${TMP} "0" 0 +2
        StrCpy ${OUT} ${OUT} "" 1
!macroend

!macro _OptionToday PREFIX
; Stack: min, max (top). Pushes today as YYYY-MM-DD, moved into the optional
; (empty = unbounded) range.
Function ${PREFIX}Option_Today
    Exch $1 ; max
    Exch
    Exch $0 ; min
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9

    System::Call '*(&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0)p.r2'
    System::Call 'kernel32::GetLocalTime(p r2)'
    System::Call '*$2(&i2.r3,&i2.r4,&i2,&i2.r5)'
    System::Free $2
    IntFmt $4 "%02d" $4
    IntFmt $5 "%02d" $5
    StrCpy $2 "$3-$4-$5"
    StrCpy $6 "$3$4$5"

    StrCmp $0 "" checkmax
    StrCpy $7 $0 4
    StrCpy $8 $0 2 5
    StrCpy $9 $0 2 8
    StrCpy $7 "$7$8$9"
    IntCmp $6 $7 checkmax 0 checkmax
    StrCpy $2 $0
    StrCpy $6 $7
    checkmax:
    StrCmp $1 "" done
    StrCpy $7 $1 4
    StrCpy $8 $1 2 5
    StrCpy $9 $1 2 8
    StrCpy $7 "$7$8$9"
    IntCmp $6 $7 done done 0
    StrCpy $2 $1
    done:
    StrCpy $0 $2

    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Exch $0
    Exch
    Pop $1
FunctionEnd
!macroend
!insertmacro _OptionToday ""
!insertmacro _OptionToday "un."

; Stack: control, YYYY-MM-DD (top). Sets the date of a date picker.
Function Option_UiSetDate
    Exch $1 ; date
    Exch
    Exch $0 ; control
    Push $2
    Push $3
    Push $4
    Push $9

    StrCpy $2 $1 4
    !insertmacro _Option_DatePart $3 $1 5 $9
    !insertmacro _Option_DatePart $4 $1 8 $9
    System::Call '*(&i2 r2,&i2 r3,&i2 0,&i2 r4,&i2 0,&i2 0,&i2 0,&i2 0)p.r2'
    System::Call 'user32::SendMessageW(p r0, i ${DTM_SETSYSTEMTIME}, p 0, p r2)'
    System::Free $2

    Pop $9
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Pop $1
FunctionEnd

; Stack: control, min, max (top); either bound may be empty. Sets the range of
; a date picker.
Function Option_UiSetDateRange
    Exch $2 ; max
    Exch
    Exch $1 ; min
    Exch 2
    Exch $0 ; control
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9
    Push $R9

    StrCpy $5 0
    StrCpy $3 0
    StrCpy $4 0
    StrCpy $6 0
    StrCpy $7 0
    StrCpy $8 0
    StrCpy $9 0
    StrCmp $1 "" skipmin
    StrCpy $5 1
    StrCpy $3 $1 4
    !insertmacro _Option_DatePart $4 $1 5 $R9
    !insertmacro _Option_DatePart $6 $1 8 $R9
    skipmin:
    StrCmp $2 "" skipmax
    IntOp $5 $5 | 2
    StrCpy $7 $2 4
    !insertmacro _Option_DatePart $8 $2 5 $R9
    !insertmacro _Option_DatePart $9 $2 8 $R9
    skipmax:
    System::Call '*(&i2 r3,&i2 r4,&i2 0,&i2 r6,&i2 0,&i2 0,&i2 0,&i2 0,&i2 r7,&i2 r8,&i2 0,&i2 r9,&i2 0,&i2 0,&i2 0,&i2 0)p.r3'
    System::Call 'user32::SendMessageW(p r0, i ${DTM_SETRANGE}, i r5, p r3)'
    System::Free $3

    Pop $R9
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $0
    Pop $2
    Pop $1
FunctionEnd

; Stack: control. Pushes the date of a date picker as YYYY-MM-DD.
Function Option_UiGetDate
    Exch $0 ; control
    Push $1
    Push $2
    Push $3

    System::Call '*(&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0,&i2 0)p.r1'
    System::Call 'user32::SendMessageW(p r0, i ${DTM_GETSYSTEMTIME}, p 0, p r1)'
    System::Call '*$1(&i2.r0,&i2.r2,&i2,&i2.r3)'
    System::Free $1
    IntFmt $2 "%02d" $2
    IntFmt $3 "%02d" $3
    StrCpy $0 "$0-$2-$3"

    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: control, dotted quad (top; empty clears). Sets an IP address control.
Function Option_UiSetIp
    Exch $1 ; address
    Exch
    Exch $0 ; control
    Push $2

    StrCmp $1 "" clear
    System::Call 'ws2_32::inet_addr(m r1) i .r2'
    StrCmp $2 -1 clear
    System::Call 'ws2_32::ntohl(i r2) i .r2'
    System::Call 'user32::SendMessageW(p r0, i ${IPM_SETADDRESS}, p 0, i r2)'
    Goto done
    clear:
    System::Call 'user32::SendMessageW(p r0, i ${IPM_CLEARADDRESS}, p 0, p 0)'
    done:

    Pop $2
    Pop $0
    Pop $1
FunctionEnd

; Stack: control. Pushes the dotted quad of an IP address control: empty when
; all fields are blank, "incomplete" when only some are filled.
Function Option_UiGetIp
    Exch $0 ; control
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5

    System::Call 'user32::SendMessageW(p r0, i ${IPM_GETADDRESS}, p 0, *i .r1) i .r2'
    StrCpy $0 ""
    StrCmp $2 0 done
    StrCpy $0 "incomplete"
    StrCmp $2 4 0 done
    IntOp $2 $1 >> 24
    IntOp $2 $2 & 255
    IntOp $3 $1 >> 16
    IntOp $3 $3 & 255
    IntOp $4 $1 >> 8
    IntOp $4 $4 & 255
    IntOp $5 $1 & 255
    StrCpy $0 "$2.$3.$4.$5"
    done:

    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: value, name (top).
Function Option_WriteReg
    Exch $0 ; name
    Exch
    Exch $1 ; value
    Push $2
    Push $3

    !insertmacro SetShellContext
    !insertmacro GetProductKey $2
    StrCpy $2 "$2\Options"
    !insertmacro _ApplyRegTestId $2 $3
    !insertmacro DefineRegView
    WriteRegStr SHCTX "$2" "$0" "$1"

    Pop $3
    Pop $2
    Pop $0
    Pop $1
FunctionEnd

!macro _Option_PersistOne PAGE KEY
    Push `$__opt_${PAGE}_${KEY}`
    Push "${PAGE}.${KEY}"
    Call Option_WriteReg
!macroend

!macro _Option_LoadOne PAGE KEY
    Push `$__opt_${PAGE}_${KEY}`
    Push "${PAGE}.${KEY}"
    Call Option_ReadReg
    Pop $__opt_${PAGE}_${KEY}
!macroend

!macro _un.Option_LoadOne PAGE KEY
    Push `$__opt_${PAGE}_${KEY}`
    Push "${PAGE}.${KEY}"
    Call un.Option_ReadReg
    Pop $__opt_${PAGE}_${KEY}
!macroend

; Writes every persisted option. Call it while installing.
!macro Option_Persist
    !insertmacro __Options_ForEachPersisted _Option_PersistOne
!macroend
!define Option_Persist `!insertmacro Option_Persist`

; Replaces the options' values with the stored ones; options without a stored
; value keep their current (default) value.
!macro Option_LoadPersisted
    !insertmacro __Options_ForEachPersisted _Option_LoadOne
!macroend
!define Option_LoadPersisted `!insertmacro Option_LoadPersisted`

!macro un.Option_LoadPersisted
    !insertmacro __Options_ForEachPersisted _un.Option_LoadOne
!macroend
!define un.Option_LoadPersisted `!insertmacro un.Option_LoadPersisted`

!macro un.Option_ListContains PAGE KEY VALUE OUT
    Push `$__opt_${PAGE}_${KEY}`
    Push `${VALUE}`
    Call un.Option_ListHas
    Pop ${OUT}
!macroend
!define un.Option_ListContains `!insertmacro un.Option_ListContains`

!endif
