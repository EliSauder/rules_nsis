!macro PostInit
    Push $0
    nsArray::Set smoke /key=a one
    nsArray::Length smoke
    Pop $0
    nsArray2::Set smoke2 /key=a one
    nsArray2::Length smoke2
    Pop $0
    Pop $0
!macroend
