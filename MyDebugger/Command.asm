.386
.model flat, stdcall
option casemap:none

include ollycrdebugger.inc


.data
    g_szCmdBuf db MAXBYTE dup(0)
    g_szErrCmd db "���������", 0dh, 0ah, 0
    g_szTestCmd db "����ִ��", 0dh, 0ah, 0
    
    g_aryCode db 32 dup(0)
    g_dwCodeLen dd $-offset g_aryCode
    g_aryDisAsm db 256 dup(0)
    g_aryHex db 256 dup(0)
    g_dwDisCodeLen dd 0
    g_dwEip dd 0
    g_szShowDisasmFmt db "%08X %-30s %s", 0dh, 0ah, 0
    
    g_rShowFmt1 db "EAX=%08x EBX=%08x ECX=%08x EDX=%08x ESI=%08x EDI=%08x ", 0
    g_rShowFmt2 db "EIP=%08x ESP=%08x EBP=%08x ", 0dh, 0ah, 0
    g_rShowFmt3 db "CS=%04x SS=%04x DS=%04x ES=%04x FS=%04x GS=%04x           ", 0
    g_rShowFmt4 db "CF:%01x PF:%01x AF:%01x ZF:%01x SF:%01x TF:%01x IF:%01x DF:%01x OF:%01x", 0dh, 0ah, 0
    g_rShowFmt5 db "%08x %-16s %s", 0dh, 0ah, 0

    g_uShowFmt1 db "%08x %-16s %s", 0dh, 0ah, 0
    
    g_ddShowFmt1 db "%08x %02x %02x %02x %02x %02x %02x %02x %02x-", 0
    g_ddShowFmt2 db "%02x %02x %02x %02x %02x %02x %02x %02x  ", 0
    g_ddShowFmt3 db "%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c", 0dh, 0ah, 0
    
    ;g_dwEndAddr dd 010124e1 
    g_bIsAutoStep dd FALSE
    
    g_dCommandCode dd 0
    
    ;T
    g_nAutoStep dd 0
    
    ;Ӳ���ϵ�Ĵ���
    g_szDrErrCmd1 db "�ϵ��ظ�����", 0dh, 0ah, 0
    g_szDrErrCmd2 db "Ӳ���Ĵ�������", 0dh, 0ah, 0
    g_szDrShow1 db "�Ĵ���%d",09,"e",09,"%08x", 0dh, 0ah, 0
    g_szDrShow2 db "�Ĵ���%d",09,"w",09,"%d",09,"%08x", 0dh, 0ah, 0
    g_szDrShow3 db "�Ĵ���%d",09,"r",09,"%d",09,"%08x", 0dh, 0ah, 0
    
    ;�ڴ�ϵ��ӡ
    g_szMemoryShow1 db "��ӡ�ڴ�ϵ�: ��� ��ַ ����", 0dh, 0ah, 0
    g_szMemoryShow2 db "%d",09,"%08x",09,"%d", 0dh, 0ah, 0
    
    ;�����ű�
    g_strEsExportBuffer db 1000 dup(0)
    g_strEsFileName db "Mycode.txt",0
    
    ;����ű�
    g_bIsImport dd FALSE
    g_nImportNumber dd 0
    g_strLsImportBuffer db 1000 dup(0)
    g_strLsImportBufferbf db 1000 dup(0)
    g_strLsImportLength dd 0
    g_strLsFileName db "Mycode.txt",0
    
    ;��¼ָ��
    g_strRecordBuffer db 10000 dup(0)
    g_strRecordFileName db "MyRecord.txt",0
    g_strRecordOneLine db 100 dup(0)
    
    ;�������
    
	g_sPrintfHex db "%x",0
    g_pImageBuffer  dd 0	;ImageBuffer
    g_ImageBase		dd 0
    g_szNewShowDisasmFmt db "%08X %-30s %s   %s %s", 0dh, 0ah, 0
    g_bIsFirstDump dd TRUE
    g_myImageBase dd 0
    g_myImageBuffer dd 0
    
.code




;***********************************
;��������
;�����ո��tab��
;***********************************
SkipWhiteChar proc uses edi pCommand:dword  ;�����հ��ַ�
     mov edi,pCommand
     .while byte ptr[edi] == ' ' || byte ptr [edi] == 9 ;9��tab��
         add edi,1
     .endw
     mov eax,edi
     ret
SkipWhiteChar endp


;***********************************
;ִ�н����������� �в�  
;��ӡ��������  
;***********************************
DisOneAsm proc TheAddr:DWORD,StrAPI:ptr CHAR,StrDll:ptr CHAR
	LOCAL @Import:DWORD
	LOCAL @Order:DWORD
		
 	invoke GetApiOrder,addr @Import,addr @Order,TheAddr;
        .if eax == TRUE
        
       	    invoke GetApiName,@Import,@Order,StrAPI,StrDll
       	mov eax,TRUE
      	ret
     .endif
     invoke RtlZeroMemory, StrAPI, 100
     invoke RtlZeroMemory, StrDll, 100
     xor eax,eax
     ret
DisOneAsm endp


;***********************************
;��ʾ�ҵ�ASM��Ϣ
;ShowMyAsm
;***********************************
ShowMyAsm proc MyEip:DWORD,MyAryHex:DWORD,MyAryDisAsm:DWORD
    LOCAL @needDisasmAddr:DWORD
    LOCAL @strApiName[100]:CHAR
    LOCAL @strDllName[100]:CHAR
    
    invoke RtlZeroMemory, addr @strApiName, 100
    invoke RtlZeroMemory,addr @strDllName,100

	;���ж���ʲôָ�call��jmpָ����Ҫapi��ʾ
     ;�ж��Ƿ���callָ��
   	 mov esi, offset g_aryDisAsm
   	 .if byte ptr [esi] == 'j' && byte ptr [esi+1] == 'm' && byte ptr [esi+2] == 'p'
    	;jmpָ���Ҫ������ַΪAPI����
        ;�Ȼ�ȡ��ַ����
        invoke crt_strlen,MyAryDisAsm
        sub eax,7
        add esi,eax
        invoke crt_strtoul, esi, 0, 16 ;ת16������ֵ
        
        mov @needDisasmAddr,eax
        
        invoke DisOneAsm,@needDisasmAddr,addr @strApiName,addr @strDllName
        invoke crt_printf, offset g_szNewShowDisasmFmt, MyEip ,MyAryHex ,MyAryDisAsm,addr @strDllName,addr @strApiName
        ret
    .endif
    
    .if byte ptr [esi] == 'c' && byte ptr [esi+1] == 'a' && byte ptr [esi+2] == 'l' && byte ptr [esi+3] == 'l'
        .if byte ptr [esi+5]!='e'
    	    ;jmpָ���Ҫ������ַΪAPI����
            ;�Ȼ�ȡ��ַ����
            invoke crt_strlen,offset g_aryDisAsm
   	        mov esi, offset g_aryDisAsm
            add esi,eax
            dec esi
   	        .if byte ptr [esi] == ']'
                sub esi,7
   	        .else
                sub esi,6
   	        .endif
            invoke crt_strtoul, esi, 0, 16 ;ת16������ֵ
        
            sub eax,g_myImageBase
            add eax,g_myImageBuffer
            mov eax,[eax]
            mov @needDisasmAddr,eax
        
            invoke DisOneAsm,@needDisasmAddr,addr @strApiName,addr @strDllName
        
            invoke crt_printf, offset g_szNewShowDisasmFmt, MyEip ,MyAryHex ,MyAryDisAsm,addr @strDllName,addr @strApiName
            ret
        .endif
    .endif
    
    
    invoke crt_printf, offset g_szShowDisasmFmt, MyEip ,MyAryHex ,MyAryDisAsm
	ret
ShowMyAsm endp



;***********************************
;��¼�����ָ��
;***********************************
RecordDisAsm proc uses edi RecordEip:dword,RecordHex:dword,RecordAry:dword 
    LOCAL @myhandle:dword
    
    ;invoke crt_printf, offset g_szShowDisasmFmt, RecordEip , RecordHex , RecordAry
    invoke wsprintf,offset g_strRecordOneLine ,offset g_szShowDisasmFmt ,RecordEip , RecordHex , RecordAry
    ;invoke crt_printf, offset g_strRecordOneLine
    invoke crt_strcat,offset g_strRecordBuffer,offset g_strRecordOneLine
    invoke crt_memset,offset g_strRecordOneLine,0,100
    
    ; ɾ��֮ǰ�ļ�¼�ļ��������
    invoke DeleteFile, offset g_strRecordFileName
    ; �����µļ�¼�ļ�
    invoke CreateFile, offset g_strRecordFileName, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL
    mov @myhandle, eax
    ;���㳤�ȣ���д��
    invoke crt_strlen,offset g_strRecordBuffer
    invoke WriteFile, @myhandle,offset g_strRecordBuffer, eax, NULL, NULL
        
    ;�رվ��
    invoke CloseHandle, @myhandle
    
    ret
RecordDisAsm endp


;***********************************
;��ʾ���������
;***********************************
ShowDisAsm proc
    LOCAL @ctx:CONTEXT
    
    ;��ȡEIP
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    push @ctx.regEip
    pop g_dwEip
    
    ;��ȡeipλ�õĻ�����
    invoke ReadMemory,g_dwEip,offset g_aryCode, g_dwCodeLen
    
    ;�����
    invoke DisAsm, offset g_aryCode, g_dwCodeLen, g_dwEip, offset g_aryDisAsm, offset g_aryHex, offset g_dwDisCodeLen
    
    ;��ʾ
    ;invoke crt_printf, offset g_szShowDisasmFmt, g_dwEip, offset g_aryHex, offset g_aryDisAsm
    invoke ShowMyAsm, g_dwEip, offset g_aryHex, offset g_aryDisAsm
    ;��¼ָ��
    invoke RecordDisAsm, g_dwEip, offset g_aryHex, offset g_aryDisAsm

    ret
ShowDisAsm endp



;***********************************
;ִ��R���� �޲�
;��ʾ�Ĵ����ͷ����
;***********************************
ExcuteRCmd proc
    LOCAL @ctx:CONTEXT
    LOCAL @nflag1:DWORD
    LOCAL @nflag2:DWORD
    LOCAL @nflag3:DWORD
    LOCAL @nflag4:DWORD
    LOCAL @nflag5:DWORD
    LOCAL @nflag6:DWORD
    LOCAL @nflag7:DWORD
    LOCAL @nflag8:DWORD
    LOCAL @nflag9:DWORD
    
    ;��ȡCONTEXT�ṹ��
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    
    invoke crt_printf,offset g_rShowFmt1,@ctx.regEax,@ctx.regEbx,@ctx.regEcx,@ctx.regEdx,@ctx.regEsi,@ctx.regEdi
    
    invoke crt_printf,offset g_rShowFmt2,@ctx.regEip,@ctx.regEsp,@ctx.regEbp
    
    ;�μĴ���
    invoke crt_printf,offset g_rShowFmt3,@ctx.regCs,@ctx.regSs,@ctx.regDs,@ctx.regEs,@ctx.regFs,@ctx.regGs
    
    ;��־�Ĵ���
    mov ebx, @ctx.regFlag
    
    ;CF �ڵ�0λ
    .if ebx&1h
        mov @nflag1,1
    .else
        mov @nflag1,0
    .endif
     ;PF �ڵ�2λ
    .if ebx&4h
        mov @nflag2,1
    .else
        mov @nflag2,0
    .endif
     ;AF �ڵ�4λ
    .if ebx&10h
        mov @nflag3,1
    .else
        mov @nflag3,0
    .endif
     ;ZF �ڵ�6λ
    .if ebx&40h
        mov @nflag4,1
    .else
        mov @nflag4,0
    .endif
     ;SF �ڵ�7λ
    .if ebx&80h
        mov @nflag5,1
    .else
        mov @nflag5,0
    .endif
     ;TF ��8λ
    .if ebx&100h
        mov @nflag6,1
    .else
        mov @nflag6,0
    .endif
     ;IF �ڵ�9λ
    .if ebx&200h
        mov @nflag7,1
    .else
        mov @nflag7,0
    .endif
    ;DF �ڵ�10λ
    .if ebx&400h
        mov @nflag8,1
    .else
        mov @nflag8,0
    .endif
    ;OF �ڵ�11λ
    .if ebx&800h
        mov @nflag9,1
    .else
        mov @nflag9,0
    .endif
    
    invoke crt_printf,offset g_rShowFmt4,@nflag1,@nflag2,@nflag3,@nflag4,@nflag5,@nflag6,@nflag7,@nflag8,@nflag9
    
    
    ;��ȡeipλ�õĻ�����
    invoke ReadMemory,g_dwEip,offset g_aryCode, g_dwCodeLen
    
    ;�����
    invoke DisAsm, offset g_aryCode, g_dwCodeLen, @ctx.regEip, offset g_aryDisAsm, offset g_aryHex, offset g_dwDisCodeLen
    
    ;��ʾ
    ;invoke crt_printf,offset g_rShowFmt5,@ctx.regEip,offset g_aryHex, offset g_aryDisAsm
    invoke ShowMyAsm, g_dwEip, offset g_aryHex, offset g_aryDisAsm
    
    ret
ExcuteRCmd endp



;***********************************
;ִ��R���� �޲�
;��ʾ�Ĵ����ͷ����
;***********************************
ExcuteRChangeCmd proc uses esi edi ecx pAddress:dword
    LOCAL @ctx:CONTEXT
    LOCAL @pEnd:DWORD
    LOCAL @pCmd:DWORD
    
    ;��ȡCONTEXT�ṹ��
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    
    mov esi,pAddress
    mov edi,esi
    add edi,3
    invoke SkipWhiteChar,edi
    mov @pCmd,eax
    invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
    mov @pEnd,eax
    .if byte ptr [esi]=='e' && byte ptr [esi+1]=='a' && byte ptr [esi+2]=='x'
        mov eax,@pEnd
        mov @ctx.regEax,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='b' && byte ptr [esi+2]=='x'
        mov eax,@pEnd
        mov @ctx.regEbx,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='c' && byte ptr [esi+2]=='x'
        mov eax,@pEnd
        mov @ctx.regEcx,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='d' && byte ptr [esi+2]=='x'
        mov eax,@pEnd
        mov @ctx.regEdx,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='s' && byte ptr [esi+2]=='i'
        mov eax,@pEnd
        mov @ctx.regEsi,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='d' && byte ptr [esi+2]=='i'
        mov eax,@pEnd
        mov @ctx.regEdi,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='i' && byte ptr [esi+2]=='p'
        mov eax,@pEnd
        mov @ctx.regEip,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='s' && byte ptr [esi+2]=='p'
        mov eax,@pEnd
        mov @ctx.regEsp,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='b' && byte ptr [esi+2]=='p'
        mov eax,@pEnd
        mov @ctx.regEbp,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='c' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regCs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='s' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regSs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='d' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regDs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regEs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='f' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regFs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .elseif byte ptr [esi]=='f' && byte ptr [esi+1]=='s'
        mov eax,@pEnd
        mov @ctx.regFs,eax
        invoke SetThreadContext,g_hThread, addr @ctx
    .endif
    

    ret
ExcuteRChangeCmd endp

;***********************************
;ִ��E����
;�޸��ڴ�����
;***********************************
ExcuteECmd proc uses esi edi ecx pAddress:dword
    LOCAL @tAddress:DWORD
    LOCAL @tNumber:DWORD
    LOCAL @tNum:DWORD
    
    
    ;�μĴ���
    mov esi,pAddress
    mov eax,esi
    
    ;��ǰ���ַ���н�������ŵ�@tAddress
    .while TRUE
    	.if byte ptr [eax] == ' '
    		mov byte ptr [eax],0
    		inc eax
    		.break
    	.else
    		inc eax
    	.endif
    .endw
    
    mov edi,eax
    invoke crt_strtoul,pAddress, addr @tAddress, 16 ;ת16������ֵ
    mov @tAddress,eax
    
    ;��������ǰ��Ŀհ��ַ�
    invoke SkipWhiteChar,edi
    
    ;��ǰ���ַ���н�������ŵ�@tAddress
    .while TRUE
    	.if byte ptr [eax] == ' ' || byte ptr [eax] == 0
    		.break
    	.else
    		inc eax
    		inc ecx
    	.endif
    .endw
    
    shr ecx,1
    mov @tNum,ecx
    
    invoke crt_strtoul, edi, addr @tNumber, 16 ;ת16������ֵ
    mov @tNumber,eax
    
    invoke WriteMemory,@tAddress,addr @tNumber, @tNum
    
    ret
ExcuteECmd endp

;***********************************
;ִ��ES����
;�����ű�
;***********************************
ExcuteEsCmd proc
    LOCAL @myhandle:DWORD
    
    .if g_bIsImport==TRUE
        ret
    .endif
    
    ; ɾ��֮ǰ�ļ�¼�ļ��������
    invoke DeleteFile, offset g_strEsFileName
    ; �����µļ�¼�ļ�
    invoke CreateFile, offset g_strEsFileName, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL
    mov @myhandle, eax
    ;���㳤�ȣ���д��
    invoke crt_strlen,offset g_strEsExportBuffer
    invoke WriteFile, @myhandle,offset g_strEsExportBuffer, eax, NULL, NULL
        
    ;�رվ��
    invoke CloseHandle, @myhandle
    
    ret
ExcuteEsCmd endp

;***********************************
;ִ��LS����
;����ű�
;***********************************
ExcuteLsCmd proc
    LOCAL @myhandle:DWORD
    
    .if g_bIsImport==TRUE
        ret
    .endif
    
    ;����ƫ��
    mov g_nImportNumber,0
    
    ; �����µļ�¼�ļ�
    invoke CreateFile, offset g_strLsFileName, GENERIC_READ, 0, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov @myhandle, eax
    
    
    ; ��ȡ��������
    invoke ReadFile, @myhandle, offset g_strLsImportBuffer, sizeof g_strLsImportBuffer, offset g_strLsImportLength, NULL
    mov g_bIsImport,TRUE
    
    
    ;�رվ��
    invoke CloseHandle, @myhandle
    
    ret
ExcuteLsCmd endp


;***********************************
;ִ��U���� 
;�вβ��� ���8�����
;***********************************
ExcuteUCmdParam proc uses ebx ecx pAddress:dword
    LOCAL @temp:DWORD
    
    push pAddress
    pop @temp
    
    xor ecx,ecx
    ;�μĴ���
    .while ecx!=8
    	pushad
    	pushfd
    	
    	;��ȡ��λ�õĻ�����
    	invoke ReadMemory,@temp,offset g_aryCode, g_dwCodeLen
    	
    	.if [g_aryCode]==0cch
            invoke FindNode,g_pBpListHead,offset CheckCC, @temp
            mov esi,eax
            assume esi:ptr Node
            mov edi,[esi].m_pUserData
            
    		.if eax!=0	;��cc
    			invoke crt_printf,offset g_szErrCmd
    			assume edi:ptr BpData
    			
    			xor eax,eax
                mov al, [edi].m_btOldCode
                mov [g_aryCode], al   ;�ָ�ԭָ��
                
                assume edi:nothing
    		.else
    		.endif
    		assume esi:nothing
    	.endif
    	
    	;�����
    	invoke DisAsm, offset g_aryCode, g_dwCodeLen, @temp, offset g_aryDisAsm, offset g_aryHex, offset g_dwDisCodeLen
    	;invoke crt_printf,offset g_uShowFmt1,@temp,offset g_aryHex,offset g_aryDisAsm
        invoke ShowMyAsm, @temp, offset g_aryHex, offset g_aryDisAsm
    	
        ;��¼ָ��
        invoke RecordDisAsm, @temp,offset g_aryHex,offset g_aryDisAsm
        
    	mov ebx,g_dwDisCodeLen
    	add ebx,@temp
    	mov @temp,ebx
    	popfd
    	popad
    	inc ecx
    .endw
    ret
ExcuteUCmdParam endp


;***********************************
;ִ��U���� 
;�޲β��� ���8�����
;***********************************
ExcuteUCmd proc uses ebx ecx
    LOCAL @ctx:CONTEXT
    
    ;��ȡCONTEXT�ṹ��
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    
    invoke ExcuteUCmdParam,@ctx.regEip
    
    ret
ExcuteUCmd endp


;***********************************
;ִ��dd���� ��ʾ����������
;�вβ��� ���8�����
;***********************************
ExcuteDdCmdParam proc uses ebx ecx esi pAddress:dword
    LOCAL @temp:DWORD
    LOCAL @tempAddress:DWORD
    LOCAL @tecx:DWORD
    
    
    push pAddress
    pop @temp
    
    xor ecx,ecx
    ;�μĴ���
    .while ecx!=8
    	pushad
    	pushfd
    	
    	;��ȡeipλ�õĻ�����
    	invoke ReadMemory,@temp,offset g_aryCode, g_dwCodeLen
    	mov esi,offset g_aryCode
    	dec esi
    	
    	mov ecx,8
    	    .while ecx!=0
        	.if byte ptr [esi+ecx]==0cch
        	    push @temp
        	    pop @tempAddress
        	    add @tempAddress,ecx
        	    dec @tempAddress
                invoke FindNode,g_pBpListHead,offset CheckCC, @tempAddress
                mov ebx,eax
                assume ebx:ptr Node
                mov edi,[ebx].m_pUserData
                
    		    .if eax!=0	;��cc
    			    ;invoke crt_printf,offset g_szErrCmd
        			assume edi:ptr BpData
        			
    	    		xor eax,eax
                    mov al, [edi].m_btOldCode
                    mov byte ptr [esi+ecx], al   ;�ָ�ԭָ��
                
                    assume edi:nothing
        		.else
        		.endif
    	    	assume ebx:nothing
    	    .endif
    		dec ecx
    	.endw
    	
    	mov esi,offset g_aryCode
    	dec esi
    	mov ecx,8
    	.while ecx!=0
    		movzx eax,byte ptr [esi+ecx]
    		push eax
    		dec ecx
    	.endw
    	push @temp
    	push offset g_ddShowFmt1
    	
    	call crt_printf
    	add esp,40
    	
    	mov ecx,10h
    	.while ecx!=8
    		movzx eax,byte ptr [esi+ecx]
    		push eax
    		dec ecx
    	.endw
    	push offset g_ddShowFmt2
    	
    	call crt_printf
    	add esp,36
    	
    	mov ecx,10h
    	.while ecx!=0
    		movzx eax,byte ptr [esi+ecx]
    		.if eax<127
    			.if eax>32
    				push eax
    				dec ecx
    			.else
    				mov eax,46
    				push eax
    				dec ecx	
    			.endif
    		.else
    			mov eax,46
    			push eax
    			dec ecx		
    		.endif
    	.endw
    	push offset g_ddShowFmt3
    	call crt_printf
    	add esp,68
    	
    	mov ebx,10h
    	add ebx,@temp
    	mov @temp,ebx
    	
    	popfd
    	popad
    	inc ecx
    .endw
    ret
ExcuteDdCmdParam endp


;***********************************
;ִ��dd���� ��ʾ����������
;�޲β��� ���8�����
;***********************************
ExcuteDdCmd proc uses ebx ecx
    LOCAL @ctx:CONTEXT
    
    ;��ȡCONTEXT�ṹ��
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    
    invoke ExcuteDdCmdParam,@ctx.regEip
    
    ret
ExcuteDdCmd endp


;***********************************
;ִ��t���� ��������
;***********************************
ExcuteTCmd proc
    LOCAL @ctx:CONTEXT
    
    ;TF��λ
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    or @ctx.regFlag, 100h
    invoke SetThreadContext,g_hThread, addr @ctx
    
    ;���ñ�־
    mov g_bIsStepCommand, TRUE

    ret
ExcuteTCmd endp


;***********************************
;ִ��p���� ��������
;***********************************
ExcutePCmd proc
    LOCAL @ctx:CONTEXT
    
    ;�ж��Ƿ���callָ��
    mov esi, offset g_aryDisAsm
    .if byte ptr [esi] == 'c' && byte ptr [esi+1] == 'a' && byte ptr [esi+2] == 'l' && byte ptr [esi+3] == 'l'
    
        ;callָ�����һ��������ʱ�ϵ�
        mov ebx, g_dwEip
        add ebx, g_dwDisCodeLen ;call��һ��ָ��ĵ�ַ
        
        invoke SetBreakPoint,ebx,TRUE
        
    .elseif
        ;��callָ���t������ͬ
        invoke ExcuteTCmd
    .endif

    ret
ExcutePCmd endp

;***********************************
;�ж�ĳ��ַ�Ƿ���Ӳ���ϵ�
;***********************************
FindHardwareBp proc pAddress:DWORD
    xor eax,eax
    mov esi,pAddress
    .if g_dr0 == esi
        mov eax,1
    .elseif g_dr1 == esi
        mov eax,2
    .elseif g_dr2 == esi
        mov eax,3
    .elseif g_dr3 == esi
        mov eax,4
    .endif
    ret
FindHardwareBp endp

;***********************************
;����Ӳ���ϵ�
;�в��� ��ַ
;������ bh address r 4
;***********************************
SetHardwareBp proc uses ebx pAddress:DWORD
    LOCAL @ctx:CONTEXT
    LOCAL @startAddress1:DWORD
    LOCAL @startAddress2:DWORD
    LOCAL @tAddress:DWORD
    LOCAL @tFlag1:DWORD
    LOCAL @tFlag2:DWORD
    
    ;�μĴ���
    mov esi,pAddress
    mov @startAddress1,esi
    mov eax,esi
    
    .while TRUE
    	.if byte ptr [eax] == ' '
    		mov byte ptr [eax],0
    		inc eax
    		.break
    	.else
    		inc eax
    	.endif
    .endw
    
    ;������ַ����ŵ�@tAddress
    mov @startAddress2,eax
    ;invoke crt_printf, @startAddress1
    ;invoke crt_printf, @startAddress2
    invoke crt_strtoul,pAddress, addr @tAddress, 16 ;ת16������ֵ
    mov @tAddress,eax
    
    ;�������ͣ���ŵ�@tFlag1
    invoke SkipWhiteChar,@startAddress2
    mov @startAddress2, eax
    
    xor ebx,ebx
    mov bl,byte ptr [eax]
    mov @tFlag1,ebx
    
    add @startAddress2,1
    
    invoke SkipWhiteChar,@startAddress2
    mov @startAddress2, eax
    
    ;�������ȣ���ŵ�@tFlag2
    mov bl,byte ptr [eax]
    mov @tFlag2,ebx
    
    ;�ж��Ƿ���ڿ�λ����ͬλ�öϵ�
    invoke FindHardwareBp,@tAddress
    .if eax!=0
        invoke crt_printf,offset g_szDrErrCmd1
        ret
    .endif
    
    
    ;�����ͽ��н�������ŵ�@nKind ��
    ;w 01д�����ݶϵ�
    ;e 00 ִ��
    ;r 11 ����д���ݶϵ�
    .if @tFlag1=='w'
        mov @tFlag1,00000001b
    .elseif @tFlag1=='r'
        mov @tFlag1,00000011b
    .elseif @tFlag1=='e'
        mov @tFlag1,00000000b
    .endif
    
    ;�����Ƚ��н�������ŵ�@nKind ��
    .if @tFlag2=='1'
        mov @tFlag2,00000000b
    .elseif @tFlag2=='2'
        mov @tFlag2,00000001b
    .elseif @tFlag2=='4'
        mov @tFlag2,00000011b
    .endif
    
    ;��ȡCtxֵ
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL or CONTEXT_DEBUG_REGISTERS
    invoke GetThreadContext,g_hThread, addr @ctx
    
    .if @tFlag1==0
        mov @tFlag2,00000000b
    .endif
    
    ;���ñ�־�ϵ�
    .if g_dr0 == 0
        mov ebx,@tAddress
        mov @ctx.iDr0,ebx
        mov g_dr0,ebx
        
        mov ebx,@tFlag1
        shl ebx,10h
        or @ctx.iDr7,ebx
        
        mov ebx,@tFlag2
        shl ebx,12h
        or @ctx.iDr7,ebx
        
        or @ctx.iDr7,011b
        mov ebx,@ctx.iDr7
        mov g_dr7,ebx
    .elseif g_dr1 == 0
        mov ebx,@tAddress
        mov @ctx.iDr1,ebx
        mov g_dr1,ebx
        
        mov ebx,@tFlag1
        shl ebx,14h
        or @ctx.iDr7,ebx
        
        mov ebx,@tFlag2
        shl ebx,16h
        or @ctx.iDr7,ebx
        
        or @ctx.iDr7,1100b
        mov ebx,@ctx.iDr7
        mov g_dr7,ebx
    .elseif g_dr2 == 0
        mov ebx,@tAddress
        mov @ctx.iDr2,ebx
        mov g_dr2,ebx
        
        mov ebx,@tFlag1
        shl ebx,18h
        or @ctx.iDr7,ebx
        
        mov ebx,@tFlag2
        shl ebx,1ah
        or @ctx.iDr7,ebx
        
        or @ctx.iDr7,110000b
        mov ebx,@ctx.iDr7
        mov g_dr7,ebx
    .elseif g_dr3 == 0
        mov ebx,@tAddress
        mov @ctx.iDr3,ebx
        mov g_dr3,ebx
        
        mov ebx,@tFlag1
        shl ebx,1ch
        or @ctx.iDr7,ebx
        
        mov ebx,@tFlag2
        shl ebx,1eh
        or @ctx.iDr7,ebx
        
        or @ctx.iDr7,11000000b
        mov ebx,@ctx.iDr7
        mov g_dr7,ebx
    .else
        invoke crt_printf,offset g_szDrErrCmd2
        ret
    .endif
    
    invoke SetThreadContext,g_hThread, addr @ctx
    ret
SetHardwareBp endp

;***********************************
;��ʾӲ���ϵ�
;***********************************
ShowHardwareBp proc uses ebx
    LOCAL @ctx:CONTEXT
    LOCAL @nTemp:DWORD
    LOCAL @nLen:DWORD
    ;��ȡ��Ϣ
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL or CONTEXT_DEBUG_REGISTERS
    invoke GetThreadContext,g_hThread, addr @ctx
    
    mov eax,@ctx.iDr7
    shr eax,10h
    mov @nTemp,eax
    
    .if g_dr0 != 0
        mov eax,@nTemp
        and eax,1100b
        shr eax,2
        
        .if eax==0
            mov @nLen,1
        .elseif eax==1
            mov @nLen,2
        .elseif eax==3
            mov @nLen,4
        .endif
        
        mov eax,@nTemp
        and eax,11b
        .if eax == 00b
            invoke crt_printf,offset g_szDrShow1,1,g_dr0
        .elseif eax == 01b
            invoke crt_printf,offset g_szDrShow2,1,@nLen,g_dr0
        .elseif eax == 11b
            invoke crt_printf,offset g_szDrShow3,1,@nLen,g_dr0
        .endif
    .endif
    .if g_dr1 != 0
        mov eax,@nTemp
        shr eax,4
        and eax,1100b
        shr eax,2
        
        .if eax==0
            mov @nLen,1
        .elseif eax==1
            mov @nLen,2
        .elseif eax==3
            mov @nLen,4
        .endif
        
        mov eax,@nTemp
        shr eax,4
        and eax,11b
        .if eax == 00b
            invoke crt_printf,offset g_szDrShow1,2,g_dr1
        .elseif eax == 01b
            invoke crt_printf,offset g_szDrShow2,2,@nLen,g_dr1
        .elseif eax == 11b
            invoke crt_printf,offset g_szDrShow3,2,@nLen,g_dr1
        .endif
    .endif
    .if g_dr2 != 0
        mov eax,@nTemp
        shr eax,8
        and eax,1100b
        shr eax,2
        
        .if eax==0
            mov @nLen,1
        .elseif eax==1
            mov @nLen,2
        .elseif eax==3
            mov @nLen,4
        .endif
        
        mov eax,@nTemp
        shr eax,8
        and eax,11b
        .if eax == 00b
            invoke crt_printf,offset g_szDrShow1,3,g_dr2
        .elseif eax == 01b
            invoke crt_printf,offset g_szDrShow2,3,@nLen,g_dr2
        .elseif eax == 11b
            invoke crt_printf,offset g_szDrShow3,3,@nLen,g_dr2
        .endif
    .endif
    .if g_dr3 != 0
        mov eax,@nTemp
        shr eax,0ch
        and eax,1100b
        shr eax,2
        
        .if eax==0
            mov @nLen,1
        .elseif eax==1
            mov @nLen,2
        .elseif eax==3
            mov @nLen,4
        .endif
        
        mov eax,@nTemp
        shr eax,0ch
        and eax,11b
        .if eax == 00b
            invoke crt_printf,offset g_szDrShow1,4,g_dr3
        .elseif eax == 01b
            invoke crt_printf,offset g_szDrShow2,4,@nLen,g_dr3
        .elseif eax == 11b
            invoke crt_printf,offset g_szDrShow3,4,@nLen,g_dr3
        .endif
    .endif
    ret
ShowHardwareBp endp

;***********************************
;ɾ��Ӳ���ϵ�
;���� ���
;***********************************
DelHardwareBp proc uses ebx nFlag:DWORD
    LOCAL @ctx:CONTEXT
    
    ;��ȡ��Ϣ
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL or CONTEXT_DEBUG_REGISTERS
    invoke GetThreadContext,g_hThread, addr @ctx
    
    .if nFlag == 1
        mov g_dr0,0
        mov @ctx.iDr0,0
        xor @ctx.iDr7,11b
    .elseif nFlag == 2
        mov g_dr1,0
        mov @ctx.iDr1,0
        xor @ctx.iDr7,1100b
    .elseif nFlag == 3
        mov g_dr2,0
        mov @ctx.iDr2,0
        xor @ctx.iDr7,110000b
    .elseif nFlag == 4
        mov g_dr3,0
        mov @ctx.iDr3,0
        xor @ctx.iDr7,11000000b
    .endif
    
    invoke SetThreadContext,g_hThread, addr @ctx
    ret
DelHardwareBp endp


;***********************************
;�����ڴ�ϵ�
;�в��� δ�����ĵ�ַ
;bm address length
;***********************************
SetMemoryBp proc uses ebx pAddress:DWORD
    LOCAL @startAddress:DWORD
    LOCAL @tAddress:DWORD
    LOCAL @tLength:DWORD
    LOCAL @tProtect:DWORD
    
    mov @tProtect,0
    
    ;����
    mov esi,pAddress
    mov @startAddress,esi
    mov eax,esi
    
    .while TRUE
    	.if byte ptr [eax] == ' '
    		mov byte ptr [eax],0
    		inc eax
    		.break
    	.else
    		inc eax
    	.endif
    .endw
    
    ;������ַ����ŵ�@tAddress
    mov @startAddress,eax
    invoke crt_strtoul,pAddress, addr @tAddress, 16 ;ת16������ֵ
    mov @tAddress,eax
    
    ;�������ȣ���ŵ�@tLength
    invoke SkipWhiteChar,@startAddress
    mov @startAddress, eax
    
    invoke crt_strtoul,@startAddress, addr @tLength, 16 ;ת16������ֵ
    mov @tLength,eax
    
    
    ;��ʼ�����ڴ�ϵ�
    ;��ӵ��ڴ��б���
    mov esi,offset g_bmMemory
    .while TRUE
        mov eax,[esi]
        .if eax==0
            mov eax,@tAddress
            mov [esi],eax
            mov eax,@tLength
            mov [esi+4],eax
            .break
        .else
            mov ebx,@tAddress
            shr eax,0ch
            shr ebx,0ch
            .if eax==ebx
                mov eax,[esi+8]
                mov @tProtect,eax
            .endif
            add esi,0ch
        .endif
    .endw
    
    push esi
    
    ;�޸��ڴ�����
    invoke VirtualProtectEx,g_hProcess, @tAddress, @tLength, PAGE_NOACCESS, offset g_dwOldProtect
    
    pop esi
    mov eax,g_dwOldProtect
    mov [esi+8],eax
    
    .if @tProtect!=0
        mov eax,@tProtect
        mov [esi+8],eax
    .endif

    ret
SetMemoryBp endp
    
    
;***********************************
;��ʾӲ���ϵ�
;***********************************  
ShowMemoryBp proc uses ebx
    LOCAL @tAddress:DWORD
    LOCAL @tLength:DWORD
    LOCAL @nNumber
    
    ;��ʼ�����ڴ�ϵ�
    ;��ӵ��ڴ��б���
    invoke crt_printf,offset g_szMemoryShow1
    mov esi,offset g_bmMemory
    mov @nNumber,0
    .while TRUE
        add @nNumber,1
        mov eax,[esi]
        .if eax==0
            .break
        .else
            mov eax,[esi]
            mov @tAddress,eax
            mov eax,[esi+4]
            mov @tLength,eax
            pushad
            invoke crt_printf,offset g_szMemoryShow2,@nNumber,@tAddress,@tLength
            popad
            add esi,0ch
        .endif
    .endw

    ret
ShowMemoryBp endp


;***********************************
;ɾ��Ӳ���ϵ�
;���� ���
;***********************************
DelMemoryBp proc uses ebx nFlag:DWORD
    LOCAL @tAddress:DWORD
    LOCAL @tLength:DWORD
    LOCAL @tStatue:DWORD
    LOCAL @nNumber
    

    ;esi���棬ediǰ��
    ;�𲽸���
    mov esi,offset g_bmMemory
    mov edi,esi
    add esi,0ch
    mov @nNumber,0
    .while TRUE
        add @nNumber,1
        mov eax,[edi]
        .if eax==0
            .break
        .else
            mov ecx,@nNumber
            .if ecx<nFlag
                add esi,0ch
                add edi,0ch
            .elseif ecx==nFlag
                mov eax,[edi]
                mov @tAddress,eax
                mov eax,[edi+4]
                mov @tLength,eax
                mov eax,[edi+8]
                mov @tStatue,eax
                
                ;�޸��ڴ�����
                invoke VirtualProtectEx,g_hProcess, @tAddress, @tLength, @tStatue, addr g_dwOldProtect
                
                mov eax,[esi]
                mov [edi],eax
                mov eax,[esi+4]
                mov [edi+4],eax
                mov eax,[esi+8]
                mov [edi+8],eax
                
                add esi,0ch
                add edi,0ch
            .else
                mov eax,[esi]
                mov [edi],eax
                mov eax,[esi+4]
                mov [edi+4],eax
                mov eax,[esi+8]
                mov [edi+8],eax
            
                add esi,0ch
                add edi,0ch
            .endif
        .endif
    .endw
    
    
   mov edi,offset g_bmMemory
   .while TRUE
        mov eax,[edi]
        .if eax!=0
            invoke VirtualProtectEx,g_hProcess, [edi], [edi+4], PAGE_NOACCESS, offset g_dwOldProtect
            add edi,0ch
        .else
            .break
        .endif
    .endw
    ret
DelMemoryBp endp


;***********************************
;ML �鿴ģ���б��� 
;���� ���
;***********************************
ExcuteMlCmd proc
    LOCAL @me32:MODULEENTRY32
    LOCAL @hModuleSnap:HANDLE
    LOCAL @dwPid:DWORD
    LOCAL @dwNum:DWORD
    
    xor eax, eax
    mov @dwNum, eax

    invoke CreateToolhelp32Snapshot,TH32CS_SNAPMODULE, g_nProcessId
    mov @hModuleSnap, eax
    .if @hModuleSnap == INVALID_HANDLE_VALUE
        ret
    .endif
    
    mov @me32.dwSize, sizeof MODULEENTRY32
    
    invoke Module32First, @hModuleSnap, addr @me32
    .if eax == FALSE
        invoke CloseHandle,@hModuleSnap
    .endif
    
    .while TRUE
        
        invoke crt_printf, SADD("Number:%03d   NAME:%-18s BASE:%08X   PATH:%s", 0dh,0ah, 0), @dwNum, addr @me32.szModule, @me32.modBaseAddr, addr @me32.szExePath
        
        invoke Module32Next, @hModuleSnap, addr @me32
        .if eax == FALSE
            .break
        .endif
        inc @dwNum
    .endw
    
    invoke CloseHandle,@hModuleSnap
    
    ret
ExcuteMlCmd endp


;***********************************
;���ص�ǰEip
;***********************************
GetCurrentEip proc
    LOCAL @ctx:CONTEXT
    ;��ȡ��ǰeip
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL
    invoke GetThreadContext,g_hThread, addr @ctx
    mov eax, @ctx.regEip

    ret
GetCurrentEip endp


;***********************************
;�����ĵ�
;***********************************
ExcuteHCmd proc
    invoke crt_printf,SADD(" ",0ah)
    invoke crt_printf,SADD("************************�����ĵ�****************************",0ah)
    invoke crt_printf,SADD("1���������ϵ�	bp+addr",0ah)
    invoke crt_printf,SADD("2����ʾ����ϵ��б�	bpl",0ah)
    invoke crt_printf,SADD("3���������ϵ�	bpc+number	number �������ϵ����",0ah)
    invoke crt_printf,SADD("4�����Ӳ���ϵ�	bh addr ���� ����	����ewr  ����124",0ah)
    invoke crt_printf,SADD("5����ʾӲ���ϵ��б�	bhl",0ah)
    invoke crt_printf,SADD("6�����Ӳ���ϵ�	bhc+number",0ah)
    invoke crt_printf,SADD("7������ڴ�ϵ�	bm+address",0ah)
    invoke crt_printf,SADD("8����ʾ�ڴ�ϵ��б�	bml",0ah)
    invoke crt_printf,SADD("9������ڴ�ϵ�	bmc+number",0ah)
    invoke crt_printf,SADD("10����ʾ������8��������	u",0ah)
    invoke crt_printf,SADD("11����ʾָ����ַ�Ļ�����	u+address",0ah)
    invoke crt_printf,SADD("12����ʾ�Ĵ���״̬	r",0ah)
    invoke crt_printf,SADD("13���޸ļĴ���״̬	r+eax+666",0ah)
    invoke crt_printf,SADD("14�������ű�	es",0ah)
    invoke crt_printf,SADD("15������ű�	ls",0ah)
    invoke crt_printf,SADD("16��DUMP	du",0ah)
    invoke crt_printf,SADD("17���޸��ڴ�	e ",0ah)
    invoke crt_printf,SADD("18������ִ��	g",0ah)
    invoke crt_printf,SADD("19����������	t",0ah)
    invoke crt_printf,SADD("20����������	p",0ah)
    invoke crt_printf,SADD("21��һֱִ�е�ĳ����ַ	T+address",0ah)
    invoke crt_printf,SADD("22����ʾ����ģ��	ml",0ah)
    invoke crt_printf,SADD("23����ʾ�ڴ�	dd",0ah)
    invoke crt_printf,SADD("24����ʾָ����ַ�ڴ�	dd+address",0ah)
    invoke crt_printf,SADD("25��ִ�е�����	G",0ah)
    invoke crt_printf,SADD("26��API��ʾ	�Զ�	�Զ���ʾAPI",0ah)
    invoke crt_printf,SADD("27����¼ִ��Code	�Զ�	�Զ���¼���뵽MyRecord��",0ah)
    invoke crt_printf,SADD("28������H	h	",0ah)
    invoke crt_printf,SADD("************************************************************",0ah)


    ret
ExcuteHCmd endp


;***********************************
;ִ��g����
;***********************************
ExcuteGCmd proc
    LOCAL @aryCode[MAXBYTE]:CHAR
    LOCAL @aryDisAsm[MAXBYTE]:CHAR
    LOCAL @aryHex[MAXBYTE]:CHAR
    LOCAL @dwLen:DWORD
    LOCAL @dwCnt:DWORD
    LOCAL @dwSize:DWORD
    LOCAL @dwTmpEip:DWORD
    
    ;�ֲ�������ʼ��
    invoke RtlZeroMemory, addr @aryCode, sizeof @aryCode
    invoke RtlZeroMemory, addr @aryDisAsm, sizeof @aryDisAsm
    invoke RtlZeroMemory, addr @aryHex, sizeof @aryHex
    
    ; ��ȡ��ǰeip
    invoke GetCurrentEip
    mov @dwTmpEip, eax
   
    .while TRUE
        ;��ȡeipλ�õĻ�����
        invoke ReadMemory, @dwTmpEip, addr @aryCode, 10h
        lea ebx, @aryCode
        .if byte ptr [ebx] == 0c3h
            ;Ŀ���ַ������ʱ�ϵ�
             invoke SetBreakPoint, @dwTmpEip, TRUE
            .break
        .endif
        
        ; ���ǣ��ж���һ��EIP��, ��ȡ��ǰeipָ��ĳ���
        invoke DisAsm, addr @aryCode, 10h, @dwTmpEip, addr @aryDisAsm, addr @aryHex, addr @dwLen
        
        mov eax, @dwLen
        add eax, @dwTmpEip
        mov @dwTmpEip, eax
    .endw 
    
    mov eax, DBG_CONTINUE
    ret

ExcuteGCmd endp


;***********************************
;��������
;***********************************
ParseCommand proc uses esi
    LOCAL @dwStatus:DWORD
    LOCAL @pCmd:DWORD
    LOCAL @pEnd:DWORD
    LOCAL @nAutoStep:DWORD
    LOCAL @nParam1:DWORD
    LOCAL @nParam2:DWORD
    
    invoke ShowDisAsm
    mov @dwStatus, DBG_CONTINUE
    
    .if g_bIsFirstDump==TRUE
        invoke DumpFunction
        mov g_bIsFirstDump,FALSE
    .endif
    
    ;T�Զ�׷��ִ��
    .if g_bIsAutoStep ==TRUE
        mov eax,g_nAutoStep
        .if g_dwEip != eax
            mov g_bIsAutoStep, TRUE
            invoke crt_printf,SADD(" ",0ah)
            invoke ExcutePCmd
            invoke ExcuteRCmd
            mov eax, DBG_CONTINUE
            ret
        .else
            mov g_bIsAutoStep, FALSE
        .endif
    .endif

    ;����
    .while TRUE
    	invoke RtlZeroMemory,addr g_szCmdBuf, MAXBYTE
    	
        ;����ű�����ִ��
        .if g_bIsImport==TRUE
            mov ecx,g_nImportNumber
            lea esi,g_strLsImportBuffer
            add esi,ecx
            .if g_strLsImportLength == ecx
                mov g_bIsImport,FALSE
            .else
                invoke crt_strcpy,offset g_szCmdBuf,esi
                lea esi,g_szCmdBuf
                mov ecx,0
                .while TRUE
                    .if byte ptr [esi]==0Ah
                        mov byte ptr [esi],0
                        inc ecx
                        add g_nImportNumber,ecx
                        invoke crt_printf,SADD("import:  %s",0ah), offset g_szCmdBuf
                        jmp LS_IMPORT1
                    .else
                        inc ecx
                        inc esi
                    .endif
                .endw
            .endif
        .endif
        
        ;��ȡһ��
        invoke crt_gets, offset g_szCmdBuf
        
LS_IMPORT1:
        
        ;��¼ָ��
        invoke crt_strcat,offset g_strEsExportBuffer,offset g_szCmdBuf
        invoke crt_strcat,offset g_strEsExportBuffer,SADD(0Ah)
        
        ;��������ǰ��Ŀհ��ַ�
        invoke SkipWhiteChar,offset g_szCmdBuf
        mov @pCmd, eax
        
        ;�ж�����
        mov esi, @pCmd
        .if byte ptr [esi]=='b' && byte ptr [esi+1]=='p'
        
            add @pCmd, 2;����bp�ַ�
            mov esi, @pCmd
            
            .if byte ptr [esi] == 'l' ;��ʾ�ϵ��б�
                invoke ListBreakPoint
            
            .elseif byte ptr [esi] == 'c' ;����ϵ�
                inc @pCmd
                invoke SkipWhiteChar, @pCmd
                mov @pCmd, eax
                
                ;����bpc�������
                invoke crt_strtoul, @pCmd, addr @pEnd, 10 ;ת16������ֵ
                
                invoke DelBreakPoint,eax

            .else     ;���öϵ�        
                invoke SkipWhiteChar, @pCmd
                mov @pCmd, eax
                
                ;����bp�����ַ
                invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
                mov edx, @pEnd
                .if eax == 0 || @pCmd == edx
                    invoke crt_printf, offset g_szErrCmd
                    .continue
                .endif
                
                ;���öϵ�
                invoke SetBreakPoint, eax, FALSE
            
            .endif
        
        ;Ӳ���ϵ� Ӳ���ϵ� Ӳ���ϵ� Ӳ���ϵ� Ӳ���ϵ� Ӳ���ϵ� Ӳ���ϵ� 
        .elseif byte ptr [esi]=='b' && byte ptr [esi+1]=='h'
            add @pCmd, 2;����bh�ַ�
            mov esi, @pCmd
            
            .if byte ptr [esi] == 'l' ;��ʾ�ϵ��б�
                invoke ShowHardwareBp
            .elseif byte ptr[esi] == 'c' ;���Ӳ���ϵ�
                add @pCmd, 1;����bhc�ַ�
                mov esi, @pCmd
                invoke SkipWhiteChar, @pCmd
                mov @pCmd, eax
                ;invoke crt_printf,@pCmd
                invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
                mov edx, @pEnd
                .if eax == 0 || @pCmd == edx
                    invoke crt_printf, offset g_szErrCmd
                    .continue
                .endif
                
                ;ɾ���ϵ�
                invoke DelHardwareBp, eax
            .else     
                ;���öϵ�  
                invoke SkipWhiteChar, @pCmd
            
                invoke SetHardwareBp, eax
            .endif
            
        ;�ڴ�ϵ� �ڴ�ϵ� �ڴ�ϵ� �ڴ�ϵ� �ڴ�ϵ� �ڴ�ϵ� �ڴ�ϵ� 
        .elseif byte ptr [esi]=='b' && byte ptr [esi+1]=='m'
            add @pCmd, 2;����bm�ַ�
            mov esi, @pCmd
            
            .if byte ptr [esi] == 'l' ;��ʾ�ϵ��б�
                invoke ShowMemoryBp
            .elseif byte ptr[esi] == 'c' ;���Ӳ���ϵ�
                add @pCmd, 1;����bmc�ַ�
                mov esi, @pCmd
                invoke SkipWhiteChar, @pCmd
                mov @pCmd, eax
                ;invoke crt_printf,@pCmd
                invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
                mov edx, @pEnd
                .if eax == 0 || @pCmd == edx
                    invoke crt_printf, offset g_szErrCmd
                    .continue
                .endif
                
                ;ɾ���ϵ�
                invoke DelMemoryBp, eax
            .else     
                ;���öϵ�  
                invoke SkipWhiteChar, @pCmd
            
                invoke SetMemoryBp, eax
            .endif
            
        ;UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU
        .elseif byte ptr [esi]=='u'
            add @pCmd, 1;����bp�ַ�
            
            ;��������ǰ��Ŀհ��ַ�
            invoke SkipWhiteChar,@pCmd
            mov @pCmd, eax
            mov esi, @pCmd
            movzx eax,byte ptr [esi]
        
            .if eax==0h
            	invoke ExcuteUCmd
            .else
            	invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
                mov edx, @pEnd
                .if @pCmd == edx
                    invoke crt_printf, offset g_szErrCmd
                    .continue
                .endif
                
            	invoke ExcuteUCmdParam,eax
            .endif
            .continue
            
        .elseif byte ptr [esi]=='r'
            add @pCmd, 1;����r�ַ�
            
            ;��������ǰ��Ŀհ��ַ�
            invoke SkipWhiteChar,@pCmd
            mov @pCmd, eax
            
            .if byte ptr [eax]==0
                invoke ExcuteRCmd
            .else
                invoke ExcuteRChangeCmd,@pCmd
            .endif
            .continue
        
        ;�����ű�
        .elseif byte ptr [esi]=='e' && byte ptr [esi+1]=='s'
            invoke ExcuteEsCmd
            .continue
            
        ;����ű�
        .elseif byte ptr [esi]=='l' && byte ptr [esi+1]=='s'
            invoke ExcuteLsCmd
            .continue
            
        ;DUMP
        .elseif byte ptr [esi]=='d' && byte ptr [esi+1]=='u'
            invoke DumpFunction
            .continue
            
        ;���� h
        .elseif byte ptr [esi]=='h'
            invoke ExcuteHCmd
            .continue
            
        ;�޸��ڴ�
        .elseif byte ptr [esi]=='e'
            add @pCmd, 1;����bp�ַ�
            
            ;��������ǰ��Ŀհ��ַ�
            invoke SkipWhiteChar,@pCmd
            mov @pCmd, eax
            
            invoke ExcuteECmd, @pCmd
            .continue
            
        .elseif byte ptr [esi]=='g'
            mov eax, DBG_CONTINUE
            ret
        .elseif byte ptr [esi]=='t'
            invoke ExcuteTCmd
            mov eax, DBG_CONTINUE
            ret
        .elseif byte ptr [esi]=='p'
            invoke ExcutePCmd
            mov eax, DBG_CONTINUE
            ret
        .elseif byte ptr [esi] == 'T'
            add @pCmd, 1;����T�ַ�
            mov esi, @pCmd
            invoke SkipWhiteChar, @pCmd
            mov @pCmd, eax
            ;invoke crt_printf,@pCmd
            invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
            mov g_nAutoStep,eax
        
            mov g_bIsAutoStep, TRUE
            invoke ExcutePCmd
            mov eax, DBG_CONTINUE
            ret
            
        .elseif byte ptr [esi] == 'm' && byte ptr [esi+1] == 'l'
            invoke ExcuteMlCmd
            .continue
            
        .elseif byte ptr [esi] == 'G'
            invoke ExcuteGCmd
            mov eax, DBG_CONTINUE
            ret
            
        .elseif byte ptr [esi] == 'd'
            add @pCmd, 1;����d�ַ�
            mov esi, @pCmd
            
            .if byte ptr [esi] == 'd'
            	add @pCmd, 1;����dd�ַ�
            
            	;��������ǰ��Ŀհ��ַ�
            	invoke SkipWhiteChar,@pCmd
            	mov @pCmd, eax
            	mov esi, @pCmd
            	mov eax,[esi]
        	
            	.if eax==0h
            	     	invoke ExcuteDdCmd
            	.else
            	     	invoke crt_strtoul, @pCmd, addr @pEnd, 16 ;ת16������ֵ
                	mov edx, @pEnd
                	.if @pCmd == edx
                    		invoke crt_printf, offset g_szErrCmd
                    	.continue
                	.endif
                	
            		invoke ExcuteDdCmdParam,eax
            	.endif
            .endif
            .continue
        .else
            invoke crt_printf, offset g_szErrCmd;
        .endif
        
    .endw
    
    mov eax, @dwStatus
    ret

ParseCommand endp

end
