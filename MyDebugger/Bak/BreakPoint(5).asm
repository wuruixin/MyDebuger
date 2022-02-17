.386
.model flat, stdcall
option casemap:none

include ollycrdebugger.inc

public g_pBpListHead 

.data
    g_pBpListHead dd NULL
    g_dwNumber  dd 0
    g_szBpList db "�ϵ��б���" , 0dh, 0ah, 0
    g_szFmt db "%d %08X", 0dh, 0ah, 0

.code


;***********************************
;���������ϵ�
;***********************************
SetBreakPoint proc uses edi dwAddr:DWORD, bIsTmp:BOOL
    LOCAL @bpdata:BpData
    LOCAL @btCodeCC:BYTE
    
    push dwAddr
    pop @bpdata.m_dwAddr
    push bIsTmp
    pop @bpdata.m_bIsTmp
    push g_dwNumber
    pop @bpdata.m_dwNumber
    
    inc g_dwNumber ;�ϵ��������

    ;����ɵ�
    lea edi, @bpdata.m_btOldCode    
    invoke ReadMemory,dwAddr, edi, type @bpdata.m_btOldCode
    
    ;д��CC
    mov @btCodeCC, 0cch
    invoke WriteMemory,dwAddr, addr @btCodeCC, type @btCodeCC
    
    ;��������
    invoke PushBack, g_pBpListHead, addr @bpdata, type @bpdata
    mov g_pBpListHead, eax
    
    
    xor eax, eax
    ret
SetBreakPoint endp


;***********************************
;ɾ�������ϵ�
;***********************************
DelBreakPoint proc uses esi edi ebx dwNumber:DWORD
    mov esi, g_pBpListHead
    assume esi:ptr Node
    .while esi != NULL
        mov edi, [esi].m_pUserData
        assume edi:ptr BpData
        
        mov eax, dwNumber
        .if [edi].m_dwNumber == eax
            
            ;��ԭָ��
            lea ebx, [edi].m_btOldCode
            invoke WriteMemory,[edi].m_dwAddr,ebx, type [edi].m_btOldCode
            
            ;ɾ���ڵ�
            invoke DeleteNode, g_pBpListHead, esi
            mov g_pBpListHead, eax
            
            ret
        .endif
     
        assume edi:nothing
        
        mov esi, [esi].m_pNext
    .endw
    assume esi:nothing
    ret
DelBreakPoint endp


;***********************************
;�о������ϵ�
;***********************************
ListBreakPoint proc uses esi edi

    invoke crt_printf, offset g_szBpList    

    mov esi, g_pBpListHead
    assume esi:ptr Node
    .while esi != NULL
    
        mov edi, [esi].m_pUserData
        assume edi:ptr BpData
        
        invoke crt_printf, offset g_szFmt, [edi].m_dwNumber, [edi].m_dwAddr
        
        assume edi:nothing
        
        mov esi, [esi].m_pNext
    .endw
    assume esi:nothing
    
    ret
ListBreakPoint endp


;***********************************
;�о������ϵ�
;***********************************
ResCode proc uses edi ebx pBpData:ptr BpData
    
    ;��ԭָ��
    mov edi, pBpData
    assume edi:ptr BpData
    lea ebx, [edi].m_btOldCode
    invoke WriteMemory,[edi].m_dwAddr,ebx, type [edi].m_btOldCode 
    assume edi:nothing

    ret
ResCode endp


;***********************************
;����TFλ��EIP��һ
;***********************************
SetTFAndDecEip proc bTF:BOOL, dwDec:DWORD
    LOCAL @ctx:CONTEXT

    ;TF��λ
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    .if bTF == TRUE
        or @ctx.regFlag, 100h
    .endif
    mov eax, dwDec
    sub @ctx.regEip, eax
    invoke SetThreadContext,g_hThread, addr @ctx
    
    ret
SetTFAndDecEip endp


CheckCC proc uses edi esi arg1:DWORD, arg2:DWORD
    mov edi, arg1
    mov esi, arg2
    assume edi:ptr BpData
   
    .if [edi].m_dwAddr == esi
        mov eax,TRUE
        ret 
    .endif
    
    mov eax,FALSE
    ret 
CheckCC endp



end