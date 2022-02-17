.386
.model flat, stdcall
option casemap:none

include ollycrdebugger.inc

public g_hProcess
public g_hThread
public g_nProcessId
public g_bIsStepCommand
public g_bIsHardwareBpStep
public g_dr0
public g_dr1
public g_dr2
public g_dr3
public g_dr7
public g_bmMemory
public g_dwOldProtect

.data 
    g_hProcess dd 0
    g_hThread  dd 0
    g_nProcessId    dd 0

.data
    g_szExePath db "calc11.exe", 0
    g_szErrCreateProcess db "创建进程失败",0dh, 0ah, 0
    g_szEXCEPTION_DEBUG_EVENT      db "EXCEPTION_DEBUG_EVENT      ",0dh,0ah,0
    g_szCREATE_THREAD_DEBUG_EVENT  db "CREATE_THREAD_DEBUG_EVENT  ",0dh,0ah,0
    g_szCREATE_PROCESS_DEBUG_EVENT db "CREATE_PROCESS_DEBUG_EVENT ",0dh,0ah,0
    g_szEXIT_THREAD_DEBUG_EVENT    db "EXIT_THREAD_DEBUG_EVENT    ",0dh,0ah,0
    g_szEXIT_PROCESS_DEBUG_EVENT   db "EXIT_PROCESS_DEBUG_EVENT   ",0dh,0ah,0
    g_szLOAD_DLL_DEBUG_EVENT       db "LOAD_DLL_DEBUG_EVENT       ",0dh,0ah,0
    g_szUNLOAD_DLL_DEBUG_EVENT     db "UNLOAD_DLL_DEBUG_EVENT     ",0dh,0ah,0
    g_szOUTPUT_DEBUG_STRING_EVENT  db "OUTPUT_DEBUG_STRING_EVENT  ",0dh,0ah,0
    g_szLodDllFmt                  db "[event] LodDll Base:%08X ImageName:%s", 0dh, 0ah, 0
    g_dwLoadDllFmtLen              dd $ - offset g_szLodDllFmt
    
    
    g_bIsSystemCC                  dd FALSE;系统断点标志位
    g_pBpDataToReset               dd NULL ;断步配合，重设断点
    g_bIsStepCommand               dd FALSE;是否有单步命令
    g_bIsHardwareBpStep            dd FALSE;是否是硬件断点的单步
    b_bIsMemBpStep                 dd FALSE;是否是内存断点的单步
    g_dr0                          dd 0
    g_dr1                          dd 0
    g_dr2                          dd 0
    g_dr3                          dd 0
    g_dr7                          dd 0
    g_bmMemory                     dd 1000 dup(0)
    g_dwOldProtect                 dd 0
    
.code

;***********************************
;触发断点响应事件
;***********************************
OnBreakPoint proc uses esi edi ebx pER:ptr EXCEPTION_RECORD
    LOCAL @dwStatus:DWORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @btCodeCC:BYTE
    LOCAL @dwBytesWrited:DWORD
    LOCAL @dwBytesReaded:DWORD
    LOCAL @ctx:CONTEXT
    
    mov @dwStatus, DBG_CONTINUE
    
    mov esi, pER
    assume esi: ptr EXCEPTION_RECORD
    
    ;系统断点，忽略
    .if g_bIsSystemCC == FALSE
        mov g_bIsSystemCC, TRUE
        
        invoke ParseCommand
        ret
    .endif
    
    ;判断是否是自己的断点，遍历链表
    mov edi, g_pBpListHead
    assume edi:ptr Node
    .while edi != NULL
        mov ebx, [edi].m_pUserData
        assume ebx:ptr BpData
        mov eax, [esi].ExceptionAddress
        .if [ebx].m_dwAddr == eax
            ;是自己的断点,恢复原来的指令
            mov g_pBpDataToReset, ebx
            invoke ResCode, ebx
            
            .if [ebx].m_bIsTmp == TRUE
                ;临时断点，不设单步
                invoke SetTFAndDecEip, FALSE, 1
                invoke DelBreakPoint,[ebx].m_dwNumber
            .else
                ;永久断点，设置单步，用于重设断点
                invoke SetTFAndDecEip, TRUE, 1
            .endif

            ;输入新命令
            invoke ParseCommand
            mov @dwStatus, eax

            .break
        .endif
        assume ebx:nothing
        
        mov edi, [edi].m_pNext
    .endw
    
    assume edi:nothing

    mov eax, @dwStatus
    ret
OnBreakPoint endp

;***********************************
;触发单步断点触发
;***********************************
OnSingleStep proc pER:ptr EXCEPTION_RECORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @btCodeCC:BYTE
    LOCAL @dwBytesWrited:DWORD
    LOCAL @dwBytesReaded:DWORD
    LOCAL @dwStatus:DWORD
    LOCAL @ctx:CONTEXT
    
    mov @dwStatus, DBG_CONTINUE
    
    ;重设断点
    .if g_pBpDataToReset != NULL
    
        mov esi, g_pBpDataToReset
        assume esi:ptr BpData
        
        mov @btCodeCC, 0cch
        invoke WriteMemory,[esi].m_dwAddr, addr @btCodeCC, type @btCodeCC
        
        assume esi:nothing
        
        mov g_pBpDataToReset, NULL
    .endif
    
    ;有单步命令
    .if g_bIsStepCommand == TRUE
         mov g_bIsStepCommand, FALSE
         
         ;获取命令
         invoke ParseCommand
         mov @dwStatus, eax
    .endif
    
    ;有内存断点
    .if b_bIsMemBpStep == TRUE
        
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
        mov b_bIsMemBpStep, FALSE
    .endif
    
    ;判断是否有硬件断点命令
    invoke RtlZeroMemory, addr @ctx, type @ctx
    mov @ctx.ContextFlags, CONTEXT_FULL or CONTEXT_DEBUG_REGISTERS
    invoke GetThreadContext,g_hThread, addr @ctx
    
    ;bp 1012475
    ;bh 1014efc e 1
    ; 重设硬件断点
    .if g_bIsHardwareBpStep == TRUE
        ;xor @ctx.iDr7, 11b
        mov eax, g_dr7
        mov @ctx.iDr7, eax
        and @ctx.iDr6, 0
        
        invoke SetThreadContext,g_hThread, addr @ctx
        mov g_bIsHardwareBpStep, FALSE
        mov eax, DBG_CONTINUE
        ret
    .endif
    
    mov eax, @ctx.iDr6
    .if eax & 1b
        ; L0断点
        mov eax, @ctx.regFlag
        or eax, 100h
        mov @ctx.regFlag, eax
        mov g_bIsHardwareBpStep, TRUE
        
        ; 取消硬件断点，L0 = 0
        xor @ctx.iDr7, 11b
        
        mov @ctx.iDr6, 0
        invoke SetThreadContext, g_hThread, addr @ctx
        
        invoke ParseCommand
        mov @dwStatus, eax     
    .elseif eax & 10b
        ; L0断点
        mov eax, @ctx.regFlag
        or eax, 100h
        mov @ctx.regFlag, eax
        mov g_bIsHardwareBpStep, TRUE
        
        ; 取消硬件断点，L0 = 0
        xor @ctx.iDr7, 1100b
        
        mov @ctx.iDr6, 0
        invoke SetThreadContext, g_hThread, addr @ctx
        
        invoke ParseCommand
        mov @dwStatus, eax     
    .elseif eax & 100b
        ; L0断点
        mov eax, @ctx.regFlag
        or eax, 100h
        mov @ctx.regFlag, eax
        mov g_bIsHardwareBpStep, TRUE
        
        ; 取消硬件断点，L0 = 0
        xor @ctx.iDr7, 110000b
        
        mov @ctx.iDr6, 0
        invoke SetThreadContext, g_hThread, addr @ctx
        
        invoke ParseCommand
        mov @dwStatus, eax     
    .elseif eax & 1000b
        ; L0断点
        mov eax, @ctx.regFlag
        or eax, 100h
        mov @ctx.regFlag, eax
        mov g_bIsHardwareBpStep, TRUE
        
        ; 取消硬件断点，L0 = 0
        xor @ctx.iDr7, 11000000b
        
        mov @ctx.iDr6, 0
        invoke SetThreadContext, g_hThread, addr @ctx
        
        invoke ParseCommand
        mov @dwStatus, eax     
    .endif
    mov eax, @dwStatus
    ret
OnSingleStep endp



;***********************************
;触发内存断点异常
;***********************************
OnAccessVoilation proc uses esi pER:ptr EXCEPTION_RECORD
    LOCAL @dwStatus:DWORD
    LOCAL @nTemp1:DWORD
    LOCAL @nTemp2:DWORD
    LOCAL @nTemp3:DWORD
    
    ;1、将所有断点恢复内存属性
    mov esi,offset g_bmMemory
    .while TRUE
        mov eax,[esi]
        .if eax!=0
            mov eax,[esi]
            mov @nTemp1,eax
            mov eax,[esi+4]
            mov @nTemp2,eax
            mov eax,[esi+8]
            mov @nTemp3,eax
            invoke VirtualProtectEx,g_hProcess, @nTemp1, @nTemp2, @nTemp3, addr @nTemp3
            add esi,0ch
        .else
            .break
        .endif
    .endw
    
    ;2、设置单步和内存断点状态
    invoke SetTFAndDecEip,TRUE, 0
    mov b_bIsMemBpStep, TRUE
    
    
    ;3、获取异常结构体里的地址是否命中了设置断点的区域
    mov @dwStatus, DBG_CONTINUE
    mov esi, pER
    assume esi:ptr EXCEPTION_RECORD
    
    ;eax是一个数组,里面有2个元素(每个元素4字节),第一个4字节存放的是读写标志0读1写,第二个4字节异常地址
    lea eax, [esi].ExceptionInformation
    mov eax, [eax+4];获取异常访问的地址
    
    
    ;4、遍历断点判断是否是内存断点出现问题
    mov edi,offset g_bmMemory
    .while TRUE
        mov edx,[edi]
        .if edx==0
            .break
        .endif
        mov ebx,[edi+4]
        add ebx,edx
        .if edx<=eax && eax<ebx
            pushad
            ;invoke crt_printf,SADD("2",0ah)
            invoke ParseCommand
            popad
            mov eax,DBG_CONTINUE
            ret
        .endif
        add edi,0ch
    .endw
    
    assume esi:nothing
    ;invoke crt_printf,offset g_szEXCEPTION_DEBUG_EVENT
    
    mov eax, @dwStatus
    ret
OnAccessVoilation endp


;***********************************
;触发异常响应事件
;***********************************
OnException proc uses esi pDe:ptr DEBUG_EVENT
    LOCAL @dwStatus:DWORD
    
    mov @dwStatus, DBG_CONTINUE
    
    mov esi, pDe
    assume esi:ptr DEBUG_EVENT
    lea esi, [esi].u.Exception
    assume esi:ptr EXCEPTION_RECORD
    
    .if [esi].ExceptionCode == EXCEPTION_BREAKPOINT
        invoke OnBreakPoint, esi
        ret
        
    .elseif [esi].ExceptionCode == EXCEPTION_SINGLE_STEP
        invoke OnSingleStep, esi
        ret
        
    .elseif [esi].ExceptionCode == EXCEPTION_ACCESS_VIOLATION
        invoke OnAccessVoilation, esi
        ret
         
    .endif
    
    assume esi:nothing
    
    mov eax, @dwStatus
    ret
OnException endp

;***********************************
;触发创建进程响应事件
;***********************************
OnCreateProcess proc uses esi pDe:ptr DEBUG_EVENT
    LOCAL @dwOldProtect:DWORD
    LOCAL @btCodeCC:BYTE
    LOCAL @dwBytesWrited:DWORD
    LOCAL @dwBytesReaded:DWORD

    ret
OnCreateProcess endp


;***********************************
;OnLoadDll 
;打印加载过的DLL
;***********************************
OnLoadDll proc uses esi pDe:ptr DEBUG_EVENT
    LOCAL @szFileName[MAX_PATH*2]:CHAR
    LOCAL @dwAddr:DWORD
    LOCAL @dwBytesReaded:DWORD
    LOCAL @szwLoadDllFmt[MAXBYTE]:WORD
    
    mov esi, pDe
    assume esi:ptr DEBUG_EVENT
    
    ;读取地址
    invoke ReadProcessMemory,g_hProcess, [esi].u.LoadDll.lpImageName, addr @dwAddr, type @dwAddr, addr @dwBytesReaded
    .if eax == FALSE || @dwAddr == NULL
        ret
    .endif
    
    ;读取字符串
    invoke ReadProcessMemory, g_hProcess, @dwAddr,addr @szFileName, MAX_PATH*2, addr @dwBytesReaded
    
    .if   [esi].u.LoadDll.fUnicode  == TRUE
        invoke crt_mbstowcs, addr @szwLoadDllFmt, offset g_szLodDllFmt, g_dwLoadDllFmtLen
        invoke crt_wprintf, addr @szwLoadDllFmt, [esi].u.LoadDll.lpBaseOfDll, addr @szFileName
    .else
        ;invoke crt_printf, offset g_szLodDllFmt, [esi].u.LoadDll.lpBaseOfDll, addr @szFileName
    .endif
    
    assume esi:nothing
    ret
OnLoadDll endp

;***********************************
;主函数
;***********************************
main proc 
    LOCAL @si:STARTUPINFO
    LOCAL @pi:PROCESS_INFORMATION
    LOCAL @de:DEBUG_EVENT 
    LOCAL @dwStatus:DWORD
    
    invoke RtlZeroMemory,addr @si, type  @si
    mov @si.cb, type @si
    invoke RtlZeroMemory,addr @pi, type @pi
    
    invoke CreateProcess,offset g_szExePath, NULL, NULL,NULL,FALSE,DEBUG_ONLY_THIS_PROCESS,NULL,NULL,addr @si, addr @pi
    .if eax == FALSE
        invoke crt_printf, offset g_szErrCreateProcess
        ret
    .endif
    
    push @pi.hProcess
    pop g_hProcess
    
    push @pi.dwProcessId
    pop g_nProcessId
    
    .while TRUE
        ;等待调试事件
        invoke RtlZeroMemory,addr @de, type @de
        invoke WaitForDebugEvent, addr @de, INFINITE
        
        ;获取线程句柄
        invoke OpenThread,THREAD_ALL_ACCESS, FALSE, @de.dwThreadId
        mov g_hThread, eax
        
        ;处理调试事件
        mov @dwStatus, DBG_CONTINUE
        .if @de.dwDebugEventCode == EXCEPTION_DEBUG_EVENT
            ;invoke crt_printf, offset g_szEXCEPTION_DEBUG_EVENT 
            invoke OnException,addr @de
            mov @dwStatus, eax
       
        .elseif @de.dwDebugEventCode == CREATE_THREAD_DEBUG_EVENT
            ;invoke crt_printf, offset g_szCREATE_THREAD_DEBUG_EVENT 
             
        .elseif @de.dwDebugEventCode == CREATE_PROCESS_DEBUG_EVENT
            ;invoke crt_printf, offset g_szCREATE_PROCESS_DEBUG_EVENT 
            ;invoke OnCreateProcess, addr @de
            
        .elseif @de.dwDebugEventCode == EXIT_THREAD_DEBUG_EVENT
            ;invoke crt_printf, offset g_szEXIT_THREAD_DEBUG_EVENT 
            
        .elseif @de.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT
            ;invoke crt_printf, offset g_szEXIT_PROCESS_DEBUG_EVENT  
            
        .elseif @de.dwDebugEventCode == LOAD_DLL_DEBUG_EVENT
            ;invoke crt_printf, offset g_szLOAD_DLL_DEBUG_EVENT 
            ;invoke OnLoadDll,addr @de 
            
        .elseif @de.dwDebugEventCode == UNLOAD_DLL_DEBUG_EVENT
            ;invoke crt_printf, offset g_szUNLOAD_DLL_DEBUG_EVENT 
            
        .elseif @de.dwDebugEventCode == OUTPUT_DEBUG_STRING_EVENT
            ;invoke crt_printf, offset g_szOUTPUT_DEBUG_STRING_EVENT  
        .endif
        
        invoke CloseHandle,g_hThread
        invoke ContinueDebugEvent,@de.dwProcessId, @de.dwThreadId, @dwStatus
    .endw
    
    ret
main endp



START:

    invoke main
    
    xor eax, eax
    invoke ExitProcess,eax
end START