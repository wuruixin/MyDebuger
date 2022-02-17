.586
.model flat,stdcall
option casemap:none

include Linker.inc

.code

;***********************************
;解析命令
;返回值：新的头结点 头节点数据 数据大小
;***********************************
PushBack proc  pHead:ptr Node, pUserData:LPVOID, dwDataSize:DWORD
    LOCAL @pNewNode:ptr Node
    
    ;创建新节点
    invoke crt_malloc, sizeof Node
    mov @pNewNode, eax

    ;为用户数据申请内存
    invoke crt_malloc, dwDataSize
    mov esi, @pNewNode
    assume esi:ptr Node
    mov [esi].m_pUserData, eax
    
    ;存储用户数据
    invoke crt_memcpy, [esi].m_pUserData, pUserData, dwDataSize
    
    ;链接新节点
    push pHead
    pop [esi].m_pNext
    
    assume esi:nothing

    mov eax, @pNewNode
    ret
PushBack endp



;***********************************
;寻找结点
;***********************************
FindNode proc uses esi  pHead:ptr Node, pfnCompare:DWORD, pData:DWORD
    mov esi, pHead
    assume esi:ptr Node
    .while esi != NULL
        
        push pData
        push [esi].m_pUserData
        call pfnCompare
        .if eax == TRUE
            mov eax, esi
            ret
        .endif
        
        mov esi, [esi].m_pNext
    .endw
    assume esi:nothing
    
    xor eax, eax
    ret
FindNode endp


;***********************************
;删除结点
;***********************************
DeleteNode proc uses esi pHead:ptr Node, pNodeToDel :ptr Node
    LOCAL @pNewHead:ptr Node
   
    mov esi, pHead
    assume esi:ptr Node
    
    ;存储新的头结点
    mov eax, [esi].m_pNext
    mov @pNewHead, eax
   
    mov eax, pNodeToDel
    assume eax:ptr Node
    
    ;交换数据
    push [eax].m_pUserData
    push [esi].m_pUserData
    pop [eax].m_pUserData
    pop [esi].m_pUserData
    

    ;删除内存
    mov eax, pHead
    invoke crt_free, [eax].m_pUserData
    invoke crt_free, pHead
    assume eax:nothing
    assume esi:nothing

    mov eax, @pNewHead
    ret
DeleteNode endp

;***********************************
;删除结点
;***********************************
FreeList proc uses esi pHead:ptr Node
    
    mov esi, pHead
    assume esi:ptr Node
    
    .while esi != NULL
        invoke DeleteNode, esi, esi
        mov esi, eax
    .endw
    
    assume esi:nothing
    
    xor eax, eax
    ret
FreeList endp

end