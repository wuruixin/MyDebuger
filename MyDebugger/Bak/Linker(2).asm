.586
.model flat,stdcall
option casemap:none

include Linker.inc

.code

;***********************************
;��������
;����ֵ���µ�ͷ��� ͷ�ڵ����� ���ݴ�С
;***********************************
PushBack proc  pHead:ptr Node, pUserData:LPVOID, dwDataSize:DWORD
    LOCAL @pNewNode:ptr Node
    
    ;�����½ڵ�
    invoke crt_malloc, sizeof Node
    mov @pNewNode, eax

    ;Ϊ�û����������ڴ�
    invoke crt_malloc, dwDataSize
    mov esi, @pNewNode
    assume esi:ptr Node
    mov [esi].m_pUserData, eax
    
    ;�洢�û�����
    invoke crt_memcpy, [esi].m_pUserData, pUserData, dwDataSize
    
    ;�����½ڵ�
    push pHead
    pop [esi].m_pNext
    
    assume esi:nothing

    mov eax, @pNewNode
    ret
PushBack endp



;***********************************
;Ѱ�ҽ��
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
;ɾ�����
;***********************************
DeleteNode proc uses esi pHead:ptr Node, pNodeToDel :ptr Node
    LOCAL @pNewHead:ptr Node
   
    mov esi, pHead
    assume esi:ptr Node
    
    ;�洢�µ�ͷ���
    mov eax, [esi].m_pNext
    mov @pNewHead, eax
   
    mov eax, pNodeToDel
    assume eax:ptr Node
    
    ;��������
    push [eax].m_pUserData
    push [esi].m_pUserData
    pop [eax].m_pUserData
    pop [esi].m_pUserData
    

    ;ɾ���ڴ�
    mov eax, pHead
    invoke crt_free, [eax].m_pUserData
    invoke crt_free, pHead
    assume eax:nothing
    assume esi:nothing

    mov eax, @pNewHead
    ret
DeleteNode endp

;***********************************
;ɾ�����
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