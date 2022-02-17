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
	g_AddKnoterr db "该节尾处至第一个节表处的空间无法容下一个节表...",0
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
    g_szErr         db "汇编语法错误", 0 
    g_errOpenPro    db "OpenProcess is error...",0
    
    g_NewFileName db "MyDump.exe",0
    g_NumberIMPORT_DESCRIPTOR dd 0		;导入表所记录dll的该结构体序号
    g_NumberIMAGE_THUNK_DATA dd 0		;导入表记录该函数的所在位置（第几个）
    
    g_pFileHeader dd 0
   	g_pSectionHeader dd 0
   	g_pDirectory	dd 0
   	g_pImportTable dd 0	;指向数据目录中导入表信息
   	g_pImport	   dd 0		;指向导入表
   	
.code

;***********************************
;写内存
;***********************************
ReadMemory proc  dwAddr:DWORD, pBuf:LPVOID, dwSize:DWORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @dwBytesReaded:DWORD
    
    invoke ReadProcessMemory,g_hProcess, dwAddr, pBuf,dwSize, addr @dwBytesReaded

    ret
ReadMemory endp


;***********************************
;读取内存
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
;DUMP  读取文件存放到堆中
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
	.if eax == NULL		;判断打开文件是否成功
		invoke crt_printf,offset OpenFileFaile
		mov eax,NULL
		ret
	.endif

	invoke crt_fseek,@pFile,0,SEEK_END
	invoke crt_ftell,@pFile
	mov @fileSize,eax
	invoke crt_fseek,@pFile,0,SEEK_SET
	;分配缓冲区
	invoke crt_malloc,@fileSize
	mov @pFileBuffer,eax
	.if @pFileBuffer == NULL
		invoke crt_printf,offset MallocFaile
		mov eax,0
		ret
	.endif
	;	将文件数据读取到缓冲区
	invoke crt_fread,@pFileBuffer,@fileSize,1,@pFile
	mov @n,eax
	.if @n == 0
		invoke crt_printf,offset FaileReadFile
		invoke crt_free, @pFileBuffer
		invoke crt_fclose,@pFile
		mov eax,0
		ret
	.endif
	;关闭文件
	invoke crt_fclose,@pFile
	mov ebx,FileBuffer
	push @pFileBuffer
	pop [ebx]
	mov eax,@fileSize
	
	ret
ReadFileToHeap endp


;***********************************
;DUMP  将堆中文件写入文件中
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
;DUMP  将FOA转成RVA
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
	
	
	;将@pFileHeader指向标准PE头
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
	;将@pSection指向第一个节表
	mov eax,@pFileHeader
	add eax,14h
	add eax,type IMAGE_OPTIONAL_HEADER
	mov @pSection,eax
	
	;先确定这个文件偏移地址处于哪个节中
	mov esi,@pSection
	assume esi:ptr IMAGE_SECTION_HEADER
	mov cx,@NumberOfSections
	mov edx,FOA_path
	.while @i < cx  ;仅需遍历节数-1次便可以确定是哪个节中
		;默认为此节表中，与下一个节表的文件偏移比较，确认是否是在此表中，是则直接跳出，否则继续查找
		add esi,type IMAGE_SECTION_HEADER
		.if edx < [esi].PointerToRawData
			jmp FOAtoRVAEMT
		.endif
		inc @rank_section
		;=====
		inc @i
	.endw
	FOAtoRVAEMT:
	;确定了在哪个节中之后，只需要将FOA减去在它节中的文件偏移(PointerToRawData),
	;然后加上内存偏移(VirtualAddress)即得到RVA
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
;DUMP  将RVA转成FOA
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
	
	
	;将@pFileHeader指向标准PE头
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
	
	;将@pSection指向第一个节表
	mov eax,@pFileHeader
	add eax,14h
	add eax,type IMAGE_OPTIONAL_HEADER
	mov @pSection,eax
	
	;先确定数据在哪个节表中
	mov esi,@pSection
	assume esi:ptr IMAGE_SECTION_HEADER
	mov cx,@NumberOfSections
	mov edx,RVA_path
	
	;先和第一个节表偏移比较，确定是否在节表中
	.if edx < [esi].VirtualAddress
		mov eax,edx
		ret 
	.endif
	
	.while @i < cx  ;仅需遍历节数-1次便可以确定是哪个节中
		;默认为此节表中，与下一个节表的文件偏移比较，确认是否是在此表中，是则直接跳出，否则继续查找
		add esi,type IMAGE_SECTION_HEADER
		.if edx < [esi].VirtualAddress
			jmp RVAtoFOAEMT
		.endif
		inc @rank_section
		;=====
		inc @i
	.endw
	RVAtoFOAEMT:
	;确定在哪个节之后，只需要将RVA-该节内存中的偏移在加上该节在文件中的偏移即可
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
;DUMP  利用PID获取主模块基址
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
    	LOCAL @NumberOfSections:WORD			;节数目
    	
    	mov edx,pImageBuffer
    	add edx,3ch		  ;指向e_lfanew
    	mov eax,[edx]
    	
    	;初始化PE一些重要的数据指针
    	mov edx,pImageBuffer
    	add edx,eax			;指向NT头开头
    	add edx,4h			;指向FILE头
   	mov @pFileHeader,edx
    	add edx,14h			;指向选项头
    	mov @pSectionHeader,edx	
    	add edx,type IMAGE_OPTIONAL_HEADER
    	
    	mov ecx,@pSectionHeader
    	;--add 
    	assume ecx:ptr IMAGE_OPTIONAL_HEADER
    	mov eax,[ecx].SizeOfImage
    	mov @SizeOfImage,eax
    	;--add 
    	mov @pKnotTable,edx
    	
    	;开始计算文件大小
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
     LoopS:	;该循环得到一个指向最后一个节数据的指针
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
    	
    	;开始分配内存
    	invoke crt_malloc,@FileSize
    	mov  @pFileBuf,eax
    	invoke RtlZeroMemory, eax, @FileSize
    	
    	;先拷贝PE头进内存
    	mov edx,@pSectionHeader
    	assume edx:ptr IMAGE_OPTIONAL_HEADER
    	mov eax,[edx].SizeOfHeaders
    	invoke crt_memcpy,@pFileBuf,pImageBuffer,eax
    	
    	;再拷贝节表数据进入
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
;DUMP  利用PID获取主模块基址
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
	; 打开进程句柄
    	invoke OpenProcess, PROCESS_ALL_ACCESS, FALSE, dwProcessId
    	mov @hProcess,eax
    	mov g_hDumpProcess,eax	;存到全局变量去 g_hDumpProcess
    	.if eax == NULL
    		invoke crt_printf,offset g_errOpenPro ;"OpenProcess is error...",0
    		ret
    	.endif
    	;遍历进程模块
    	invoke EnumProcessModules,@hProcess,addr @hModule,type @hModule,addr @dwRet
    	mov @bRet,eax
    	.if eax == FALSE
    		invoke CloseHandle,@hProcess
    		ret
    	.endif
    	;获取第一个模块加载基址
    	mov eax,@hModule[0]
    	mov g_ImageBase,eax
    	mov g_myImageBase,eax
	ret
GetProcessImageBase endp



;***********************************
;DUMP  读取主模块到缓冲区中
;***********************************
ReadModuleBuffer proc proc dwPid:DWORD
    LOCAL @hProc:HWND
    LOCAL @lpAddr:LPVOID
    LOCAL @ProcessImageBass:DWORD
    LOCAL @Dos_e_lfanew:DWORD
    LOCAL @pPrcFileHeader:ptr IMAGE_FILE_HEADER
    LOCAL @SectionHeader:IMAGE_OPTIONAL_HEADER
    LOCAL @pPrcSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @SizeofImage:DWORD ;// PE文件在进程内存中的总大小，跟SectionAlignment对齐
    
    ;
    LOCAL @pSectionHeader:ptr IMAGE_OPTIONAL_HEADER
    LOCAL @pFileBuffer:LPVOID
    LOCAL @FileSize:DWORD
    
    ;由pid获取主模块基址
    invoke GetProcessImageBase,dwPid
    mov @ProcessImageBass,eax
    ;获取PE相对于头文件的偏移
    mov edx,@ProcessImageBass
    add edx,3ch
    invoke ReadMemory,edx,addr @Dos_e_lfanew,type DWORD
    mov eax,@Dos_e_lfanew
    add eax,@ProcessImageBass ;指向NT头开头
    add eax,4h			;指向FILE头
    mov @pPrcFileHeader,eax
    add eax,14h			;指向选项头
    mov @pPrcSectionHeader,eax	
    ;初始化可选pe头结构体大小
    invoke ReadMemory,@pPrcSectionHeader,addr @SectionHeader,type IMAGE_OPTIONAL_HEADER
    mov eax,@SectionHeader.SizeOfImage
    mov @SizeofImage,eax
    ;分配缓冲区
    invoke crt_malloc,@SizeofImage
    .if eax == NULL
    	invoke MessageBox,NULL,offset MallocFaile,NULL,MB_OK
    .endif
    mov g_pImageBuffer,eax	;存好所分配地址空间首地址
    
    ;从目标进程内存中dump出主模块数据
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
;DUMP  主函数
;***********************************
DumpFunction proc
    LOCAL @PeDumpFileName[100]:CHAR
    LOCAL @PeDumpWindowHandle:DWORD
    LOCAL @PeDumpPid:DWORD  ;进程pid
    LOCAL @hModuleSnap:DWORD
    LOCAL @hProc:DWORD      ;句柄
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
    
    ;由pid获取主模块基址
    invoke GetProcessImageBase,@PeDumpPid
    mov @ProcessImageBass,eax
    
    ;获取PE相对于头文件的偏移
    mov edx,@ProcessImageBass
    add edx,3ch
    invoke ReadMemory,edx,addr @Dos_e_lfanew,type DWORD
    mov eax,@Dos_e_lfanew
    add eax,@ProcessImageBass ;指向NT头开头
    add eax,4h			;指向FILE头
    mov @pPrcFileHeader,eax
    add eax,14h			;指向选项头
    mov @pPrcSectionHeader,eax	
    
    ;初始化可选pe头结构体大小
    invoke ReadMemory,@pPrcSectionHeader,addr @SectionHeader,type IMAGE_OPTIONAL_HEADER
    mov eax,@SectionHeader.SizeOfImage
    mov @SizeofImage,eax
    
    ;分配缓冲区
    invoke crt_malloc,@SizeofImage
    .if eax == NULL
    	invoke MessageBox,NULL,offset MallocFaile,NULL,MB_OK
    .endif
    mov g_pImageBuffer,eax	;存好所分配地址空间首地址
    mov g_myImageBuffer,eax
    
    ;从目标进程内存中dump出主模块数据
    invoke ReadMemory,@ProcessImageBass,g_pImageBuffer,@SizeofImage
    mov eax,g_pImageBuffer
    
    invoke ImageBufferToFileBuffer,g_pImageBuffer,addr @pFileBuffer
    mov @FileSize,eax
    
    invoke WriteFileForHeap,@pFileBuffer,offset g_NewFileName,@FileSize
    
    invoke crt_free,@pFileBuffer
    ret
DumpFunction endp


;***********************************
;APINAME 获取API序号
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
			
		;将@pFileHeader指向标准PE头
		mov eax,g_pImageBuffer
		mov g_pFileHeader,eax
		mov ebx,g_pImageBuffer
		assume ebx:ptr IMAGE_DOS_HEADER
		mov eax,[ebx].e_lfanew
		add g_pFileHeader,eax
		assume ebx:nothing
		add g_pFileHeader,4h
		mov eax,g_pFileHeader
		;赋值@pSectionHeader
		add eax,14h	
		mov g_pSectionHeader,eax
		;赋值@pDirectory
		add eax,60h
		mov g_pDirectory,eax
		
		;赋值g_pImportTable
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
		;开始遍历导入表
		.while TRUE
			mov eax,[edx].Name1
			mov @Name,eax
			mov eax,[edx].OriginalFirstThunk
			mov @OriginalFirstThunk,eax
			mov eax,[edx].FirstThunk
			mov @FirstThunk,eax
			
			;开始遍历IAT表
			add eax,g_pImageBuffer
			mov @pIAT,eax
			push dword ptr [eax]
			pop @IatFunAddr
			.while @IatFunAddr != 0
				mov ebx,VA
				.if @IatFunAddr == ebx
					;找到了
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
			;如果这个dll里面没有找到，则去下一个dll中找
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
		;没有找到
		xor eax,eax
		ret
GetApiOrder endp



;***********************************
;APINAME 获取API名字
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
		;为序号导出
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