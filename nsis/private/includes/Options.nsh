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
; invokes `!insertmacro ${CALLBACK} "<page>" "<key>" "<kind>"` for every persisted
; option, where KIND is the option type (`list`, `multiline` or any other).
; It is what Option_Persist and Option_LoadPersisted iterate. It defaults to
; nothing so this file compiles on its own.
;
; Values named `<page>.<key>` live under `<product key>\Options`, in the
; installer's view and shell context. bool uses a one-byte REG_BINARY, int
; (or int32) uses REG_DWORD, int64 uses REG_QWORD, list uses REG_MULTI_SZ,
; and other kinds use REG_SZ. Resolved file/dir paths are not expanded.
; Multiline REG_SZ keeps the legacy escaped form so old values are unambiguous.
; Legacy REG_MULTI_SZ scalars and REG_SZ lists/numbers are read without
; rewriting. Option_Persist writes the new types after the old uninstall.
;
; The variable of a `list` option (multi_select) holds the name of an nsArray
; array with its items instead of a value; see Option_ListContains.
; The product key must be set with ${SetProductKey} (Product.nsh) before
; persisting or loading values.

!include LogicLib.nsh
!include Logging.nsh
!include Product.nsh
!include Array.nsh
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

; A `list` option (a listbox with multi_select) holds the name of an nsArray
; array with one string per selected choice; Option_Get returns that name.
; Sets OUT to 1 when VALUE is one of the items of the option, and to 0
; otherwise. Values are compared case-insensitively.
!macro Option_ListContains PAGE KEY VALUE OUT
    Push `$__opt_${PAGE}_${KEY}`
    Push `${VALUE}`
    Call Option_ListHas
    Pop ${OUT}
!macroend
!define Option_ListContains `!insertmacro Option_ListContains`

; Sets OUT to the number of items of a list option.
!macro Option_ListCount PAGE KEY OUT
    Push `$__opt_${PAGE}_${KEY}`
    Call Option_ListCount
    Pop ${OUT}
!macroend
!define Option_ListCount `!insertmacro Option_ListCount`

; Sets OUT to the item of a list option at INDEX (from 0, in the order of the
; choices), or to an empty string when there is none.
!macro Option_ListGet PAGE KEY INDEX OUT
    Push `$__opt_${PAGE}_${KEY}`
    Push `${INDEX}`
    Call Option_ListGet
    Pop ${OUT}
!macroend
!define Option_ListGet `!insertmacro Option_ListGet`

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

; Stack: array name. Pushes the number of items in a list option's array (0
; when the array does not exist).
Function ${PREFIX}Option_ListCount
    Exch $0 ; array
    ${Array_Length} $0 $0
    Exch $0
FunctionEnd

; Stack: array name, index (top). Pushes the item, or "" past the end.
Function ${PREFIX}Option_ListGet
    Exch $1 ; index
    Exch
    Exch $0 ; array
    Push $2

    ${Array_Length} $0 $2
    IntCmp $1 $2 none read none
    read:
    ${Array_GetAt} $0 $1 $0
    Goto done
    none:
    StrCpy $0 ""
    done:
    ClearErrors

    Pop $2
    Exch $0
    Exch
    Pop $1
FunctionEnd

; Stack: array name, value (top). Pushes 1 when the array holds the value
; (compared case-insensitively), otherwise 0.
Function ${PREFIX}Option_ListHas
    Exch $1 ; value
    Exch
    Exch $0 ; array
    Push $2
    Push $3
    Push $4
    Push $5

    StrCpy $5 0
    ${Array_Length} $0 $2
    StrCpy $3 0
    loop:
        IntCmp $3 $2 done 0 done
        ${Array_GetAt} $0 $3 $4
        StrCmp $4 $1 0 +3
            StrCpy $5 1
            Goto done
        IntOp $3 $3 + 1
        Goto loop
    done:
    ClearErrors
    StrCpy $1 $5

    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Exch $1
FunctionEnd

; Stack: source array name, destination array name (top). Replaces the
; destination's items with the source's.
Function ${PREFIX}Option_ArrayCopy
    Exch $1 ; destination
    Exch
    Exch $0 ; source
    Push $2
    Push $3
    Push $4

    ${Array_Reset} $1
    ${Array_Length} $0 $2
    StrCpy $3 0
    loop:
        IntCmp $3 $2 done 0 done
        ${Array_GetAt} $0 $3 $4
        ${Array_Set} $1 $3 "$4"
        IntOp $3 $3 + 1
        Goto loop
    done:
    ClearErrors

    Pop $4
    Pop $3
    Pop $2
    Pop $0
    Pop $1
FunctionEnd

; Stack: option kind, default, name (top). Pushes the stored value, or the
; default when no value is stored. The value and the default of a `list`
; option are the name of its array, which is filled with the stored items.
Function ${PREFIX}Option_ReadReg
    Exch $0 ; name
    Exch
    Exch $1 ; default
    Exch 2
    Exch $4 ; kind
    Push $2
    Push $3

    !insertmacro ${PREFIX}GetProductKey $2
    StrCpy $2 "$2\Options"
    ${Array_Clear} __options_reg
    ClearErrors
    !insertmacro ${PREFIX}GetRegistrySubKeyMultiStr "$2" "$0" __options_reg
    IfErrors legacy
        StrCmp $4 "list" 0 single
            Push "__options_reg"
            Push $1
            Call ${PREFIX}Option_ArrayCopy
            Goto done
        single:
        Push $4
        Call ${PREFIX}Option_FromArray
        Pop $1
        Goto done
    legacy:
    ClearErrors
    StrCmp $4 "list" legacylist
        Push $4
        Push $0
        Call ${PREFIX}Option_ReadScalar
        Pop $3
        IfErrors done
        StrCpy $1 $3
        Goto done
    legacylist:
    !insertmacro ${PREFIX}GetRegistrySubKey "$2" "$0" $3
    IfErrors done
        ${Array_Reset} $1
        StrCmp $3 "" done
            ${Array_Split} $1 "$3" "|"
    done:
    ClearErrors

    Pop $3
    Pop $2
    Pop $4
    Pop $0
    Exch $1
FunctionEnd

; Stack: kind, name (top). Returns a scalar as its NSIS string value.
; Missing values set errors; malformed or unexpected types are also logged.
Function ${PREFIX}Option_ReadScalar
    Exch $0 ; name
    Exch
    Exch $1 ; kind
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9
    Push $R0
    Push $R1

    StrCpy $R1 ""
    !insertmacro ${PREFIX}SetShellContext
    !insertmacro ${PREFIX}GetProductKey $2
    StrCpy $2 "$2\Options"
    !insertmacro _ApplyRegTestId $2 $3
    !insertmacro ${PREFIX}GetRegView $3
    !insertmacro _RegMultiSzAccess "${PREFIX}" $3 1 $4 $5
    System::Call 'advapi32::RegOpenKeyExW(i r4, w r2, i 0, i r5, *p .r6) i .r7'
    StrCmp $7 2 missing
    StrCmp $7 0 0 failed
    System::Call 'advapi32::RegQueryValueExW(p r6, w r0, p 0, *i .r7, p 0, *i .r8) i .r5'
    StrCmp $5 2 closemissing
    StrCmp $5 0 0 closefailed
    IntOp $9 $8 + 4
    System::Alloc $9
    Pop $9
    StrCmp $9 0 closefailed
    System::Call '*(i r8) p .r10'
    System::Call 'advapi32::RegQueryValueExW(p r6, w r0, p 0, p 0, p r9, p r10) i .r5'
    System::Free $R0
    StrCmp $5 0 0 freefailed
    ; REG_SZ also accepts legacy strings for numeric/boolean options.
    StrCmp $7 1 string
    StrCmp $1 "bool" boolean
    StrCmp $1 "int" integer
    StrCmp $1 "int32" integer
    StrCmp $1 "int64" integer64 freefailed
    boolean:
        StrCmp $7 3 0 freefailed
        StrCmp $8 1 0 freefailed
        System::Call '*$9(&i1 .r11)'
        StrCmp $R1 0 success
        StrCmp $R1 1 success freefailed
    integer:
        StrCmp $7 4 0 freefailed
        StrCmp $8 4 0 freefailed
        System::Call '*$9(i .r11)'
        Goto success
    integer64:
        StrCmp $7 11 0 freefailed
        StrCmp $8 8 0 freefailed
        ; System's signed formatter negates negatives and overflows at INT64_MIN.
        System::Call '*$9(i .r5, i .r7)'
        StrCmp $5 0 0 readinteger64
        StrCmp $7 -2147483648 0 readinteger64
        StrCpy $R1 "-9223372036854775808"
        Goto success
    readinteger64:
        System::Call '*$9(l .r11)'
        Goto success
    string:
        IntOp $5 ${NSIS_MAX_STRLEN} * 2
        IntCmp $8 $5 0 0 freefailed
        System::Call 'kernel32::lstrcpynW(w .r11, p r9, i ${NSIS_MAX_STRLEN})'
    success:
        System::Free $9
        System::Call 'advapi32::RegCloseKey(p r6)'
        ClearErrors
        Goto finish
    freefailed:
        System::Free $9
    closefailed:
        System::Call 'advapi32::RegCloseKey(p r6)'
    failed:
        !insertmacro LogWarn "Unable to read option '$0' as $1 (type $7, size $8)."
        Goto missing
    closemissing:
        System::Call 'advapi32::RegCloseKey(p r6)'
    missing:
        SetErrors
    finish:
    StrCpy $0 $R1
    Pop $R1
    Pop $R0
    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

; Stack: option kind (top). Pushes the value of a non-list option held by the
; `__options_reg` array: its first string, escaped on one line for multiline.
Function ${PREFIX}Option_FromArray
    Exch $1 ; kind
    Push $0
    Push $2

    StrCpy $0 ""
    ${Array_Length} __options_reg $2
    StrCmp $2 "0" done
        ${Array_GetAt} __options_reg 0 $0
        StrCmp $1 "multiline" 0 done
            Push $0
            Call ${PREFIX}Option_Escape
            Pop $0
    done:
    ClearErrors

    Pop $2
    Exch $0
    Exch
    Pop $1
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

; Stack: option kind, value, name (top). A list's value is its array name.
Function Option_WriteReg
    Exch $0 ; name
    Exch
    Exch $1 ; value
    Exch 2
    Exch $4 ; kind
    Push $2
    Push $3
    Push $5
    Push $6
    Push $7
    Push $8
    Push $9

    !insertmacro GetProductKey $2
    StrCpy $2 "$2\Options"
    StrCmp $4 "list" list
    StrCmp $4 "bool" boolean
    StrCmp $4 "int" integer
    StrCmp $4 "int32" integer
    StrCmp $4 "int64" integer64
        !insertmacro SetRegistrySubKeyStr "$2" "$0" "$1"
        IfErrors failed
        Goto done
    list:
        !insertmacro SetRegistrySubKeyMultiStr "$2" "$0" "$1"
        IfErrors failed
        Goto done
    integer:
        !insertmacro SetRegistrySubKeyDWORD "$2" "$0" "$1"
        IfErrors failed
        Goto done
    boolean:
        StrCpy $5 3 ; REG_BINARY, one byte, not the ASCII character '0'/'1'.
        StrCpy $6 1
        System::Call '*(&i1 r1) p .r3'
        Goto write
    integer64:
        StrCpy $5 11 ; REG_QWORD
        StrCpy $6 8
        System::Call '*(l r1) p .r3'
    write:
        StrCmp $3 0 failed
        !insertmacro SetShellContext
        !insertmacro _ApplyRegTestId $2 $7
        !insertmacro GetRegView $7
        !insertmacro _RegMultiSzAccess "" $7 2 $8 $9
        System::Call 'advapi32::RegCreateKeyExW(i r8, w r2, i 0, p 0, i 0, i r9, p 0, *p .r7, p 0) i .r8'
        StrCmp $8 0 0 freefailed
        System::Call 'advapi32::RegSetValueExW(p r7, w r0, i 0, i r5, p r3, i r6) i .r8'
        System::Call 'advapi32::RegCloseKey(p r7)'
        StrCmp $8 0 0 freefailed
        System::Free $3
        ClearErrors
        Goto done
    freefailed:
        System::Free $3
    failed:
        !insertmacro LogError "Unable to persist option '$0' as $4."
        SetErrors
    done:

    Pop $9
    Pop $8
    Pop $7
    Pop $6
    Pop $5
    Pop $3
    Pop $2
    Pop $4
    Pop $0
    Pop $1
FunctionEnd

; Writes one persistable option using its backing kind. Passwords must not be
; passed here; their exclusion is enforced by the generated persistence list.
!macro Option_PersistOne PAGE KEY KIND
    Push "${KIND}"
    Push `$__opt_${PAGE}_${KEY}`
    Push "${PAGE}.${KEY}"
    Call Option_WriteReg
!macroend
!define Option_PersistOne `!insertmacro Option_PersistOne`

!macro _Option_PersistOne PAGE KEY KIND
    ${Option_PersistOne} ${PAGE} ${KEY} ${KIND}
!macroend

!macro _Option_LoadOne PAGE KEY KIND
    Push "${KIND}"
    Push `$__opt_${PAGE}_${KEY}`
    Push "${PAGE}.${KEY}"
    Call Option_ReadReg
    Pop $__opt_${PAGE}_${KEY}
!macroend

!macro _un.Option_LoadOne PAGE KEY KIND
    Push "${KIND}"
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

!macro un.Option_ListCount PAGE KEY OUT
    Push `$__opt_${PAGE}_${KEY}`
    Call un.Option_ListCount
    Pop ${OUT}
!macroend
!define un.Option_ListCount `!insertmacro un.Option_ListCount`

!macro un.Option_ListGet PAGE KEY INDEX OUT
    Push `$__opt_${PAGE}_${KEY}`
    Push `${INDEX}`
    Call un.Option_ListGet
    Pop ${OUT}
!macroend
!define un.Option_ListGet `!insertmacro un.Option_ListGet`

!endif
