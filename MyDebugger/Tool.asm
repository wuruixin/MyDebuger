.386
.model flat, stdcall
option casemap:none

include ollycrdebugger.inc

public g_pImageBuffer
public g_ImageBase

.data
	rb db "rb",0
	wb db "wb+",0
	OpenFileFaile db "Faile to open this  file...",0
	MallocFaile db "Faile to malloc...",0
	FaileReadFile db "Faile to stroe the FileBuffer...",0
	SaveFileFaile db "Save Faile Is Faile...",0
	g_sPrintfHex db "%x",0
	g_AddKnoterr db "�ý�β������һ���ڱ��Ŀռ��޷�����һ���ڱ�...",0
	g_NewKnotName db "emt486",0
	
	g_hDumpProcess	    dd 0
	g_pNewDumpFile	dd 0
	g_NewDumpFileSize	dd 0
    g_pImageBuffer  dd 0	;ImageBuffer
    g_ImageBase		dd 0
    g_szCol0Title   db "PID", 0
    g_szCol1Title   db "Process Name", 0
    g_szCol2Title   db "Parent PID", 0
    g_szCol3Title   db "Thread Cnt", 0
    g_szCol4Title   db "Process Path", 0
    g_szFmt         db "%d", 0
    g_aryOpcodeBuf  db 1000h dup(0)  
    g_dwOpcodeSize  dd 0
    g_szErr         db "����﷨����", 0 
    g_errOpenPro    db "OpenProcess is error...",0
    
    g_NewFileName db "MyDump.exe",0
    g_NumberIMPORT_DESCRIPTOR dd 0		;���������¼dll�ĸýṹ�����
    g_NumberIMAGE_THUNK_DATA dd 0		;������¼�ú���������λ�ã��ڼ�����
    
    g_pFileHeader dd 0
   	g_pSectionHeader dd 0
   	g_pDirectory	dd 0
   	g_pImportTable dd 0	;ָ������Ŀ¼�е������Ϣ
   	g_pImport	   dd 0		;ָ�����
   	
.code

;***********************************
;д�ڴ�
;***********************************
ReadMemory proc  dwAddr:DWORD, pBuf:LPVOID, dwSize:DWORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @dwBytesReaded:DWORD
    
    invoke ReadProcessMemory,g_hProcess, dwAddr, pBuf,dwSize, addr @dwBytesReaded

    ret
ReadMemory endp


;***********************************
;��ȡ�ڴ�
;***********************************
WriteMemory proc dwAddr:DWORD, pBuf:LPVOID, dwSize:DWORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @dwBytesWrited:DWORD
    
    
    invoke VirtualProtectEx,g_hProcess,dwAddr,dwSize, PAGE_EXECUTE_READWRITE, addr @dwOldProtect
    invoke WriteProcessMemory,g_hProcess, dwAddr, pBuf,dwSize, addr @dwBytesWrited
    invoke VirtualProtectEx,g_hProcess,dwAddr,dwSize, @dwOldProtect, addr @dwOldProtect
    
    ret
WriteMemory endp


;***********************************
;DUMP  ��ȡ�ļ���ŵ�����
;***********************************
ReadFileToHeap proc lpszFile:LPSTR,FileBuffer:ptr LPVOID
	LOCAL @pFile:ptr FILE
	LOCAL @fileSize:dword
	LOCAL @pFileBuffer:LPVOID
	LOCAL @n:DWORD
	
	mov eax,0
	mov @pFile,eax
	mov @fileSize,eax
	mov @pFileBuffer,eax
	
	invoke crt_fopen,lpszFile,offset rb
	mov @pFile,eax
	.if eax == NULL		;�жϴ��ļ��Ƿ�ɹ�
		invoke crt_printf,offset OpenFileFaile
		mov eax,NULL
		ret
	.endif

	invoke crt_fseek,@pFile,0,SEEK_END
	invoke crt_ftell,@pFile
	mov @fileSize,eax
	invoke crt_fseek,@pFile,0,SEEK_SET
	;���仺����
	invoke crt_malloc,@fileSize
	mov @pFileBuffer,eax
	.if @pFileBuffer == NULL
		invoke crt_printf,offset MallocFaile
		mov eax,0
		ret
	.endif
	;	���ļ����ݶ�ȡ��������
	invoke crt_fread,@pFileBuffer,@fileSize,1,@pFile
	mov @n,eax
	.if @n == 0
		invoke crt_printf,offset FaileReadFile
		invoke crt_free, @pFileBuffer
		invoke crt_fclose,@pFile
		mov eax,0
		ret
	.endif
	;�ر��ļ�
	invoke crt_fclose,@pFile
	mov ebx,FileBuffer
	push @pFileBuffer
	pop [ebx]
	mov eax,@fileSize
	
	ret
ReadFileToHeap endp


;***********************************
;DUMP  �������ļ�д���ļ���
;***********************************
WriteFileForHeap proc Pnewbuffer:PVOID,f:ptr char,sizes:DWORD
	LOCAL @Fp:ptr FILE
	
	invoke crt_fopen,f,offset wb
	mov @Fp,eax
	.if @Fp != NULL
		invoke crt_fwrite,Pnewbuffer,sizes,1,@Fp
	.else
		invoke crt_printf,offset SaveFileFaile
	.endif
	
	ret
WriteFileForHeap endp


;***********************************
;DUMP  ��FOAת��RVA
;***********************************
FOAtoRVA proc pFileBuffer:LPVOID,FOA_path:DWORD
	LOCAL @RVA_path:DWORD
	LOCAL @NumberOfSections:word
	LOCAL @pSection:ptr DWORD
	LOCAL @pFileHeader:ptr DWORD
	local @rank_section:WORD
	LOCAL @i:WORD
	LOCAL @Test[16]:CHAR
	invoke RtlZeroMemory, addr @Test, 16
	
	mov @i,1
	mov @rank_section,0
	
	
	;��@pFileHeaderָ���׼PEͷ
	mov eax,pFileBuffer
	mov @pFileHeader,eax
	mov ebx,pFileBuffer
	assume ebx:ptr IMAGE_DOS_HEADER
	mov eax,[ebx].e_lfanew
	add @pFileHeader,eax
	assume ebx:nothing
	add @pFileHeader,4h
	mov ebx,@pFileHeader
	assume ebx:ptr IMAGE_FILE_HEADER
	mov cx,[ebx].NumberOfSections
	mov @NumberOfSections,cx
	assume ebx:nothing
	xor eax,eax
	;��@pSectionָ���һ���ڱ�
	mov eax,@pFileHeader
	add eax,14h
	add eax,type IMAGE_OPTIONAL_HEADER
	mov @pSection,eax
	
	;��ȷ������ļ�ƫ�Ƶ�ַ�����ĸ�����
	mov esi,@pSection
	assume esi:ptr IMAGE_SECTION_HEADER
	mov cx,@NumberOfSections
	mov edx,FOA_path
	.while @i < cx  ;�����������-1�α����ȷ�����ĸ�����
		;Ĭ��Ϊ�˽ڱ��У�����һ���ڱ���ļ�ƫ�ƱȽϣ�ȷ���Ƿ����ڴ˱��У�����ֱ�������������������
		add esi,type IMAGE_SECTION_HEADER
		.if edx < [esi].PointerToRawData
			jmp FOAtoRVAEMT
		.endif
		inc @rank_section
		;=====
		inc @i
	.endw
	FOAtoRVAEMT:
	;ȷ�������ĸ�����֮��ֻ��Ҫ��FOA��ȥ�������е��ļ�ƫ��(PointerToRawData),
	;Ȼ������ڴ�ƫ��(VirtualAddress)���õ�RVA
	mov eax,FOA_path
	mov esi,@pSection
	mov cx,@rank_section
	.while @rank_section > 0
		add esi,type IMAGE_SECTION_HEADER
		dec @rank_section
	.endw
	xor eax,eax
	mov eax,FOA_path
	sub eax,[esi].PointerToRawData
	add eax,[esi].VirtualAddress
	ret
FOAtoRVA endp



;***********************************
;DUMP  ��RVAת��FOA
;***********************************
RVAtoFOA proc pFileBuffer:LPVOID,RVA_path:DWORD
	LOCAL @ROA_path:DWORD
	LOCAL @NumberOfSections:word
	LOCAL @pSection:ptr DWORD
	LOCAL @pFileHeader:ptr DWORD
	local @rank_section:WORD
	LOCAL @i:WORD
	LOCAL @Test[16]:CHAR
	invoke RtlZeroMemory, addr @Test, 16
	
	mov @i,1
	mov @rank_section,0
	
	
	;��@pFileHeaderָ���׼PEͷ
	mov eax,pFileBuffer
	mov @pFileHeader,eax
	mov ebx,pFileBuffer
	assume ebx:ptr IMAGE_DOS_HEADER
	mov eax,[ebx].e_lfanew
	add @pFileHeader,eax
	assume ebx:nothing
	add @pFileHeader,4h
	mov ebx,@pFileHeader
	assume ebx:ptr IMAGE_FILE_HEADER
	mov cx,[ebx].NumberOfSections
	mov @NumberOfSections,cx
	assume ebx:nothing
	xor eax,eax
	
	;��@pSectionָ���һ���ڱ�
	mov eax,@pFileHeader
	add eax,14h
	add eax,type IMAGE_OPTIONAL_HEADER
	mov @pSection,eax
	
	;��ȷ���������ĸ��ڱ���
	mov esi,@pSection
	assume esi:ptr IMAGE_SECTION_HEADER
	mov cx,@NumberOfSections
	mov edx,RVA_path
	
	;�Ⱥ͵�һ���ڱ�ƫ�ƱȽϣ�ȷ���Ƿ��ڽڱ���
	.if edx < [esi].VirtualAddress
		mov eax,edx
		ret 
	.endif
	
	.while @i < cx  ;�����������-1�α����ȷ�����ĸ�����
		;Ĭ��Ϊ�˽ڱ��У�����һ���ڱ���ļ�ƫ�ƱȽϣ�ȷ���Ƿ����ڴ˱��У�����ֱ�������������������
		add esi,type IMAGE_SECTION_HEADER
		.if edx < [esi].VirtualAddress
			jmp RVAtoFOAEMT
		.endif
		inc @rank_section
		;=====
		inc @i
	.endw
	RVAtoFOAEMT:
	;ȷ�����ĸ���֮��ֻ��Ҫ��RVA-�ý��ڴ��е�ƫ���ڼ��ϸý����ļ��е�ƫ�Ƽ���
	mov eax,RVA_path
	mov esi,@pSection
	mov cx,@rank_section
	.while @rank_section > 0
		add esi,type IMAGE_SECTION_HEADER
		dec @rank_section
	.endw
	xor eax,eax
	mov eax,RVA_path
	sub eax,[esi].VirtualAddress
	add eax,[esi].PointerToRawData
	ret 
RVAtoFOA endp


;***********************************
;DUMP  ����PID��ȡ��ģ���ַ
;***********************************
ImageBufferToFileBuffer proc pImageBuffer:LPVOID,pFileBuffer:ptr LPVOID
	    LOCAL @pFileBuf:LPVOID
	    LOCAL @FileSize:DWORD
	    LOCAL @pFileHeader:ptr IMAGE_FILE_HEADER
    	LOCAL @pSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    	LOCAL @pKnotTable:ptr IMAGE_SECTION_HEADER
    	LOCAL @pLastKnot:ptr IMAGE_SECTION_HEADER
    	LOCAL @SizeOfImage:DWORD
    	LOCAL @pTemKnot:DWORD
    	LOCAL @NumberOfSections:WORD			;����Ŀ
    	
    	mov edx,pImageBuffer
    	add edx,3ch		  ;ָ��e_lfanew
    	mov eax,[edx]
    	
    	;��ʼ��PEһЩ��Ҫ������ָ��
    	mov edx,pImageBuffer
    	add edx,eax			;ָ��NTͷ��ͷ
    	add edx,4h			;ָ��FILEͷ
   	mov @pFileHeader,edx
    	add edx,14h			;ָ��ѡ��ͷ
    	mov @pSectionHeader,edx	
    	add edx,type IMAGE_OPTIONAL_HEADER
    	
    	mov ecx,@pSectionHeader
    	;--add 
    	assume ecx:ptr IMAGE_OPTIONAL_HEADER
    	mov eax,[ecx].SizeOfImage
    	mov @SizeOfImage,eax
    	;--add 
    	mov @pKnotTable,edx
    	
    	;��ʼ�����ļ���С
    	mov edx,@pFileHeader
    	assume edx:ptr IMAGE_FILE_HEADER
    	mov ax,[edx].NumberOfSections
    	mov @NumberOfSections,ax
    	
    	xor ecx,ecx
    	mov cx,@NumberOfSections
    	dec cx
    	mov eax,@pKnotTable
    	sub @pLastKnot,type IMAGE_SECTION_HEADER
    	mov @pLastKnot,eax
    	xor eax,eax
     LoopS:	;��ѭ���õ�һ��ָ�����һ�������ݵ�ָ��
    		add @pLastKnot,type IMAGE_SECTION_HEADER
    		loop LoopS
    	mov edx,@pLastKnot
    	assume edx:ptr IMAGE_SECTION_HEADER
    	;--add 
    	mov ebx,@SizeOfImage
    	sub ebx,[edx].VirtualAddress
    	;--add 
    	mov eax,[edx].PointerToRawData
    	add eax,ebx
    	mov @FileSize,eax
    	
    	;��ʼ�����ڴ�
    	invoke crt_malloc,@FileSize
    	mov  @pFileBuf,eax
    	invoke RtlZeroMemory, eax, @FileSize
    	
    	;�ȿ���PEͷ���ڴ�
    	mov edx,@pSectionHeader
    	assume edx:ptr IMAGE_OPTIONAL_HEADER
    	mov eax,[edx].SizeOfHeaders
    	invoke crt_memcpy,@pFileBuf,pImageBuffer,eax
    	
    	;�ٿ����ڱ����ݽ���
    	assume edx:ptr IMAGE_SECTION_HEADER
    	mov edx,@pKnotTable
    	mov @pTemKnot,edx
    	.while @NumberOfSections > 0
    		mov edx,@pTemKnot
    		
    		mov ecx,[edx].VirtualAddress
    		add ecx,pImageBuffer
    		
    		mov eax,[edx].PointerToRawData
    		mov ebx,eax
    		add ebx,@pFileBuf
    		
    		invoke crt_memcpy,ebx,ecx,[edx].SizeOfRawData
    		
    		add @pTemKnot,type IMAGE_SECTION_HEADER
    		dec @NumberOfSections
    	.endw
    	assume edx:nothing
    	mov ebx,pFileBuffer
    	push @pFileBuf
    	pop [ebx]
    	mov eax,@FileSize
	ret

ImageBufferToFileBuffer endp


;***********************************
;DUMP  ����PID��ȡ��ģ���ַ
;***********************************
GetProcessImageBase proc dwProcessId:DWORD
	LOCAL @pProcessImageBase:DWORD
	LOCAL @hProcess:HANDLE
	LOCAL @hModule[100]:HMODULE
	LOCAL @dwRet:DWORD
	LOCAL @bRet:BOOL
	xor eax,eax
	mov @pProcessImageBase,eax
	mov @dwRet,eax
	; �򿪽��̾��
    	invoke OpenProcess, PROCESS_ALL_ACCESS, FALSE, dwProcessId
    	mov @hProcess,eax
    	mov g_hDumpProcess,eax	;�浽ȫ�ֱ���ȥ g_hDumpProcess
    	.if eax == NULL
    		invoke crt_printf,offset g_errOpenPro ;"OpenProcess is error...",0
    		ret
    	.endif
    	;��������ģ��
    	invoke EnumProcessModules,@hProcess,addr @hModule,type @hModule,addr @dwRet
    	mov @bRet,eax
    	.if eax == FALSE
    		invoke CloseHandle,@hProcess
    		ret
    	.endif
    	;��ȡ��һ��ģ����ػ�ַ
    	mov eax,@hModule[0]
    	mov g_ImageBase,eax
    	mov g_myImageBase,eax
	ret
GetProcessImageBase endp



;***********************************
;DUMP  ��ȡ��ģ�鵽��������
;***********************************
ReadModuleBuffer proc proc dwPid:DWORD
    LOCAL @hProc:HWND
    LOCAL @lpAddr:LPVOID
    LOCAL @ProcessImageBass:DWORD
    LOCAL @Dos_e_lfanew:DWORD
    LOCAL @pPrcFileHeader:ptr IMAGE_FILE_HEADER
    LOCAL @SectionHeader:IMAGE_OPTIONAL_HEADER
    LOCAL @pPrcSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @SizeofImage:DWORD ;// PE�ļ��ڽ����ڴ��е��ܴ�С����SectionAlignment����
    
    ;
    LOCAL @pSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @pFileBuffer:LPVOID
    LOCAL @FileSize:DWORD
    
    ;��pid��ȡ��ģ���ַ
    invoke GetProcessImageBase,dwPid
    mov @ProcessImageBass,eax
    ;��ȡPE�����ͷ�ļ���ƫ��
    mov edx,@ProcessImageBass
    add edx,3ch
    invoke ReadMemory,edx,addr @Dos_e_lfanew,type DWORD
    mov eax,@Dos_e_lfanew
    add eax,@ProcessImageBass ;ָ��NTͷ��ͷ
    add eax,4h			;ָ��FILEͷ
    mov @pPrcFileHeader,eax
    add eax,14h			;ָ��ѡ��ͷ
    mov @pPrcSectionHeader,eax	
    ;��ʼ����ѡpeͷ�ṹ���С
    invoke ReadMemory,@pPrcSectionHeader,addr @SectionHeader,type IMAGE_OPTIONAL_HEADER
    mov eax,@SectionHeader.SizeOfImage
    mov @SizeofImage,eax
    ;���仺����
    invoke crt_malloc,@SizeofImage
    .if eax == NULL
    	invoke MessageBox,NULL,offset MallocFaile,NULL,MB_OK
    .endif
    mov g_pImageBuffer,eax	;����������ַ�ռ��׵�ַ
    
    ;��Ŀ������ڴ���dump����ģ������
    invoke ReadMemory,@ProcessImageBass,g_pImageBuffer,@SizeofImage
    mov eax,g_pImageBuffer
    
    invoke ImageBufferToFileBuffer,g_pImageBuffer,addr @pFileBuffer
    mov @FileSize,eax
    
	mov eax,@FileSize
	mov g_NewDumpFileSize,eax
	mov eax,@pFileBuffer
	mov g_pNewDumpFile,eax
	
    ret
ReadModuleBuffer endp


;***********************************
;DUMP  ������
;***********************************
DumpFunction proc
    LOCAL @PeDumpFileName[100]:CHAR
    LOCAL @PeDumpWindowHandle:DWORD
    LOCAL @PeDumpPid:DWORD  ;����pid
    LOCAL @hModuleSnap:DWORD
    LOCAL @hProc:DWORD      ;���
    LOCAL @me32:MODULEENTRY32
    LOCAL @ProcessImageBass:DWORD
    LOCAL @hFile:HANDLE
    LOCAL @Dos_e_lfanew:DWORD
    LOCAL @pPrcFileHeader:ptr IMAGE_FILE_HEADER
    LOCAL @SectionHeader:IMAGE_OPTIONAL_HEADER
    LOCAL @pPrcSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @SizeofImage:DWORD 
    LOCAL @pSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @pFileBuffer:LPVOID
    LOCAL @FileSize:DWORD
    
    mov eax,g_nProcessId
    mov @PeDumpPid,eax
    
    ;��pid��ȡ��ģ���ַ
    invoke GetProcessImageBase,@PeDumpPid
    mov @ProcessImageBass,eax
    
    ;��ȡPE�����ͷ�ļ���ƫ��
    mov edx,@ProcessImageBass
    add edx,3ch
    invoke ReadMemory,edx,addr @Dos_e_lfanew,type DWORD
    mov eax,@Dos_e_lfanew
    add eax,@ProcessImageBass ;ָ��NTͷ��ͷ
    add eax,4h			;ָ��FILEͷ
    mov @pPrcFileHeader,eax
    add eax,14h			;ָ��ѡ��ͷ
    mov @pPrcSectionHeader,eax	
    
    ;��ʼ����ѡpeͷ�ṹ���С
    invoke ReadMemory,@pPrcSectionHeader,addr @SectionHeader,type IMAGE_OPTIONAL_HEADER
    mov eax,@SectionHeader.SizeOfImage
    mov @SizeofImage,eax
    
    ;���仺����
    invoke crt_malloc,@SizeofImage
    .if eax == NULL
    	invoke MessageBox,NULL,offset MallocFaile,NULL,MB_OK
    .endif
    mov g_pImageBuffer,eax	;����������ַ�ռ��׵�ַ
    mov g_myImageBuffer,eax
    
    ;��Ŀ������ڴ���dump����ģ������
    invoke ReadMemory,@ProcessImageBass,g_pImageBuffer,@SizeofImage
    mov eax,g_pImageBuffer
    
    invoke ImageBufferToFileBuffer,g_pImageBuffer,addr @pFileBuffer
    mov @FileSize,eax
    
    invoke WriteFileForHeap,@pFileBuffer,offset g_NewFileName,@FileSize
    
    invoke crt_free,@pFileBuffer
    ret
DumpFunction endp


;***********************************
;APINAME ��ȡAPI���
;***********************************
GetApiOrder proc pInport_oder:ptr DWORD,pFun_oder:ptr DWORD,VA:DWORD
		LOCAL @Va:DWORD
		LOCAL @Ioder:DWORD
		LOCAL @Foder:DWORD
		LOCAL @JudgeSearch:DWORD
		
		LOCAL @pNowTable:ptr IMAGE_IMPORT_DESCRIPTOR
		LOCAL @Name:DWORD
		LOCAL @OriginalFirstThunk:DWORD
		LOCAL @FirstThunk:DWORD
		LOCAL @pIAT:DWORD
		LOCAL @IatFunAddr:DWORD
		
		xor eax,eax
		mov @Ioder,eax
		mov @Foder,eax
		mov @JudgeSearch,eax
;		
		.if g_pImageBuffer == NULL
			xor eax,eax
			ret
		.endif
			
		;��@pFileHeaderָ���׼PEͷ
		mov eax,g_pImageBuffer
		mov g_pFileHeader,eax
		mov ebx,g_pImageBuffer
		assume ebx:ptr IMAGE_DOS_HEADER
		mov eax,[ebx].e_lfanew
		add g_pFileHeader,eax
		assume ebx:nothing
		add g_pFileHeader,4h
		mov eax,g_pFileHeader
		;��ֵ@pSectionHeader
		add eax,14h	
		mov g_pSectionHeader,eax
		;��ֵ@pDirectory
		add eax,60h
		mov g_pDirectory,eax
		
		;��ֵg_pImportTable
		mov eax,g_pDirectory
		add eax,type IMAGE_DATA_DIRECTORY
		mov g_pImportTable,eax
		
		assume eax:ptr IMAGE_DATA_DIRECTORY
		mov edx,[eax].VirtualAddress
		assume eax:nothing
		add edx,g_pImageBuffer
		mov g_pImport,edx
		
		mov @pNowTable,edx
		assume edx:ptr IMAGE_IMPORT_DESCRIPTOR
		;��ʼ���������
		.while TRUE
			mov eax,[edx].Name1
			mov @Name,eax
			mov eax,[edx].OriginalFirstThunk
			mov @OriginalFirstThunk,eax
			mov eax,[edx].FirstThunk
			mov @FirstThunk,eax
			
			;��ʼ����IAT��
			add eax,g_pImageBuffer
			mov @pIAT,eax
			push dword ptr [eax]
			pop @IatFunAddr
			.while @IatFunAddr != 0
				mov ebx,VA
				.if @IatFunAddr == ebx
					;�ҵ���
					;invoke MessageBox,0,0,0,MB_OK
					;invoke MessageBox,0,0,0,MB_OK
					mov ebx,pInport_oder
					mov eax, @Ioder
					mov [ebx],eax
					mov ebx,pFun_oder
					mov eax,@Foder
					mov [ebx],eax
					mov eax,TRUE
					
					ret
				.endif
				inc @Foder
				add @pIAT,4
				mov eax,@pIAT
				push dword ptr [eax]
				pop @IatFunAddr
			.endw
			;������dll����û���ҵ�����ȥ��һ��dll����
			xor eax,eax
			mov @Foder,eax
			inc @Ioder
			mov edx,@pNowTable
			add edx,type IMAGE_IMPORT_DESCRIPTOR
			mov @pNowTable,edx
			.if [edx].Name1 == NULL && [edx].OriginalFirstThunk == NULL && [edx].FirstThunk == NULL
				jmp ENDIMPORT
			.endif
		.endw
		ENDIMPORT:
		;û���ҵ�
		xor eax,eax
		ret
GetApiOrder endp



;***********************************
;APINAME ��ȡAPI����
;***********************************
GetApiName proc Inport_oder:DWORD,Fun_oder:DWORD,strApiName:ptr CHAR,strDllName:ptr CHAR
	LOCAL @pNowTable:ptr IMAGE_IMPORT_DESCRIPTOR
	LOCAL @pTHUNK_DATA:DWORD
	LOCAL @pFunName:DWORD
	LOCAL @pNameLen:DWORD
	LOCAL @Name:DWORD
	LOCAL @OriginalFirstThunk:DWORD
	
	;invoke MessageBox,0,0,0,MB_OK
	mov eax,g_pImport
	mov ecx,Inport_oder
	.while ecx != 0
		add eax,type IMAGE_IMPORT_DESCRIPTOR
		dec ecx
	.endw
	mov @pNowTable,eax
	assume eax:ptr IMAGE_IMPORT_DESCRIPTOR
	mov edx,[eax].OriginalFirstThunk
	mov @OriginalFirstThunk,edx
	add edx,g_pImageBuffer
	mov @pTHUNK_DATA,edx
	mov edx,[eax].Name1
	add edx,g_pImageBuffer
	mov @Name,edx
	
	invoke crt_strlen,@Name
	invoke crt_memcpy,strDllName,@Name,eax
	
	mov ecx,Fun_oder
	.while ecx != 0
		add @pTHUNK_DATA,4
		dec ecx
	.endw
	mov edx,@pTHUNK_DATA
	mov ebx,dword ptr [edx]
	.if  ebx & 80000000h
		;Ϊ��ŵ���
		xor eax,eax
		ret
	.endif
	
	mov eax,dword ptr [edx]
	add eax,g_pImageBuffer
	add eax,2
	
	mov @pFunName,eax
	invoke crt_strlen,eax
	mov @pNameLen,eax
	invoke crt_memcpy,strApiName,@pFunName,@pNameLen
	
	ret
GetApiName endp

end