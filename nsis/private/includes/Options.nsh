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

; Multi-line values are completed together with the controls that produce them.
!macro Option_GetMultiline PAGE KEY OUT
    StrCpy ${OUT} $__opt_${PAGE}_${KEY}
!macroend
!define Option_GetMultiline `!insertmacro Option_GetMultiline`

!macro _OptionsFunctions PREFIX

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
