; Compiles only if the default nsArray plugin and its header are on the search path.
!include "nsArray.nsh"

Function PluginsSmoke
    Push $0
    nsArray::Set smoke /key=a one
    nsArray::Length smoke
    Pop $0
    Pop $0
FunctionEnd
