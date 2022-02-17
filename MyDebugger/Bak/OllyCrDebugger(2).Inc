ifndef OLLCREBG_H
OLLCREBG_H equ 0

include windows.inc
include kernel32.inc
include msvcrt.inc
include Linker.inc
include macros.asm

includelib kernel32.lib
includelib msvcrt.lib
includelib MyUdis86.lib

include psapi.inc
includelib Psapi.lib

;---------------------------------------------------------
;全局变量
;---------------------------------------------------------
externdef g_hProcess:dword
externdef g_hThread:dword
externdef g_nProcessId:dword
externdef g_bIsStepCommand:dword
externdef g_bIsHardwareBpStep:dword
externdef g_pBpListHead:dword
externdef g_dr0:dword
externdef g_dr1:dword
externdef g_dr2:dword
externdef g_dr3:dword
externdef g_dr7:dword
externdef g_bmMemory:dword
externdef g_dwOldProtect:dword

;---------------------------------------------------------
;工具函数
;---------------------------------------------------------

ReadMemory proto  dwAddr:DWORD, pBuf:LPVOID, dwSize:DWORD
WriteMemory proto dwAddr:DWORD, pBuf:LPVOID, dwSize:DWORD
DisAsm proto stdcall pMachineCode:LPBYTE,  dwCodeSize:DWORD, dwEip:DWORD, pDisAsm:LPSTR, pCodeHex:LPSTR, pdwCodeLen:LPDWORD
ReadFileToHeap proto lpszFile:LPSTR,FileBuffer:ptr LPVOID
WriteFileForHeap proto Pnewbuffer:PVOID,f:ptr char,sizes:DWORD
ReadModuleBuffer proto proc dwPid:DWORD
DumpFunction proto
GetApiOder proto pInport_oder:ptr DWORD,pFun_oder:ptr DWORD,VA:DWORD
GetApiName proto Inport_oder:DWORD,Fun_oder:DWORD,strApiName:ptr CHAR,strDllName:ptr CHAR

;----------------------------------------------------------
;软件断点相关
;----------------------------------------------------------
BpData struc
    m_dwAddr dd 0
    m_bIsTmp dd 0
    m_dwNumber dd 0
    m_btOldCode db 0 ;原来的指令
BpData ends


;---------------------------------------------------------
;工具函数
;---------------------------------------------------------
SetBreakPoint proto dwAddr:DWORD, bIsTmp:BOOL
DelBreakPoint proto dwNumber:DWORD
ListBreakPoint proto 
ResCode proto pBpData:ptr BpData
SetTFAndDecEip proto bTF:BOOL, dwDec:DWORD
CheckCC proto arg1:DWORD, arg2:DWORD
ParseCommand proto

endif
