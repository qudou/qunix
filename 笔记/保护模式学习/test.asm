; test.asm
; 实模式 => 保护模式 => ring3 [retf] => ring0 [调用门] => 实模式

%include	"pm.inc"	; 常量, 宏, 以及一些说明

org	0100h
	jmp	BEGIN

[SECTION .gdt]
;                           段基址       段界限  属性
DESC_GDT:        Descriptor 0,                0, 0         				; 空描述符
DESC_NORMAL:     Descriptor 0,           0ffffh, DA_DRW    				; Normal 描述符
DESC_CODE32:     Descriptor 0,   SegCode32Len-1, DA_C+DA_32				; 非一致代码段,32, SEG_CODE32
DESC_STACK:      Descriptor 0,       TopOfStack, DA_DRWA+DA_32			; Stack, 32 位, STACK
DESC_CODE_RING3: Descriptor 0,SegCodeRing3Len-1, DA_C+DA_32+DA_DPL3 	; CODE_RING3
DESC_STACK3:     Descriptor 0,      TopOfStack3, DA_DRWA+DA_32+DA_DPL3	; STACK3
DESC_CODE16:     Descriptor 0,           0ffffh, DA_C      				; 非一致代码段,16, SEG_CODE16
DESC_TSS:        Descriptor 0,         TSSLen-1, DA_386TSS				; TSS
DESC_VIDEO:      Descriptor 0B8000h,     0ffffh, DA_DRW+DA_DPL3			; 视频段描述符
; 门                  目标选择子       偏移   DCount 属性
CALL_GATE: 	   	 Gate SelectorCode32,  0,     0,     DA_386CGate+DA_DPL3
; GDT 结束
GdtLen		equ	$ - DESC_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1		; GDT界限
			dd	0				; GDT基地址
; GDT 选择子
SelectorNormal		equ	DESC_NORMAL		- DESC_GDT
SelectorCode32		equ	DESC_CODE32		- DESC_GDT
SelectorStack		equ	DESC_STACK		- DESC_GDT
SelectorCodeRing3	equ	DESC_CODE_RING3	- DESC_GDT + SA_RPL3
SelectorStack3		equ	DESC_STACK3		- DESC_GDT + SA_RPL3
SelectorCode16		equ	DESC_CODE16		- DESC_GDT
SelectorTSS			equ	DESC_TSS		- DESC_GDT
SelectorVideo		equ	DESC_VIDEO		- DESC_GDT
SelectorCallGate	equ	CALL_GATE - DESC_GDT + SA_RPL3
; END of [SECTION .gdt]
; -------------------------------------------------------------------------------------
[SECTION .data]
ALIGN	32
[BITS	32]
SPValueInRealMode	dw	0
STACK:
	times 512 db 0
TopOfStack	equ	$ - STACK - 1
STACK3:
	times 512 db 0
TopOfStack3	equ	$ - STACK3 - 1
TSS:
		DD	0			; Back
		DD	TopOfStack		; 0 级堆栈
		DD	SelectorStack		; 
		DD	0			; 1 级堆栈
		DD	0			; 
		DD	0			; 2 级堆栈
		DD	0			; 
		DD	0			; CR3
		DD	0			; EIP
		DD	0			; EFLAGS
		DD	0			; EAX
		DD	0			; ECX
		DD	0			; EDX
		DD	0			; EBX
		DD	0			; ESP
		DD	0			; EBP
		DD	0			; ESI
		DD	0			; EDI
		DD	0			; ES
		DD	0			; CS
		DD	0			; SS
		DD	0			; DS
		DD	0			; FS
		DD	0			; GS
		DD	0			; LDT
		DW	0			; 调试陷阱标志
		DW	$ - TSS + 2	; I/O位图基址
		DB	0ffh			; I/O位图结束标志
TSSLen		equ	$ - TSS
; END of [SECTION .data]
; -------------------------------------------------------------------------------------
[SECTION .s16]
[BITS	16]
BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	mov	[GO_BACK_TO_REAL+3], ax
	mov	[SPValueInRealMode], sp

	mov cx, cs					; 初始化 16 位代码段描述符
	mov ebx, SEG_CODE16
	mov si, DESC_CODE16
	call INIT_DESC

	mov ebx, SEG_CODE32 		; 初始化 32 位代码段描述符
	mov si, DESC_CODE32
	call INIT_DESC

	mov cx, ds					; 初始化堆栈段描述符
	mov ebx, STACK
	mov si, DESC_STACK
	call INIT_DESC
	
	mov ebx, CODE_RING3 		; 初始化Ring3描述符
	mov si, DESC_CODE_RING3
	call INIT_DESC

	mov ebx, STACK3				; 初始化堆栈段描述符(Ring3)
	mov si, DESC_STACK3
	call INIT_DESC

	mov ebx, TSS			; 初始化 TSS 描述符
	mov si, DESC_TSS
	call INIT_DESC

	mov	eax, SegCode32DestOffset; 初始化测试调用门描述符
	mov	word [CALL_GATE], ax

	xor	eax, eax				; 为加载 GDTR 作准备
	mov	ax, ds
	shl	eax, 4
	add	eax, DESC_GDT			; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	lgdt	[GdtPtr] 			; 加载 GDTR
	cli				 			; 关中断

	in	al, 92h					; 打开地址线A20
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax
	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0 处

INIT_DESC:
	; ebx: 段偏移, cx: 段地址，si: 描述符标号
	movzx eax, cx
	shl	eax, 4
	add	eax, ebx
	mov	word [si + 2], ax
	shr	eax, 16
	mov	byte [si + 4], al
	mov	byte [si + 7], ah
ret

REAL_ENTRY:			; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, [SPValueInRealMode]

	in	al, 92h		; 关闭 A20 地址线
	and	al, 11111101b
	out	92h, al
	
	sti				; 开中断, 回到 DOS
	mov	ax, 4c00h
	int	21h
; END of [SECTION .s16]
; -------------------------------------------------------------------------------------
[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]
SEG_CODE32:
	mov	ax, SelectorStack
	mov	ss, ax
	mov	esp, TopOfStack

	mov	ax, SelectorVideo
	mov	gs, ax
	mov	edi, (80 * 10 + 0) * 2	; 屏幕第 10 行, 第 0 列。
	mov	ax, 0C50h				; 0000: 黑底 1100: 红字, 'P'
	mov	[gs:edi], ax

	mov	ax, SelectorTSS
	ltr	ax
	push	SelectorStack3
	push	TopOfStack3
	push	SelectorCodeRing3
	push	0
	retf
	; 调用门的目标段
SegCode32DestOffset: equ	$ - SEG_CODE32
	mov	ax, SelectorVideo
	mov	gs, ax
	mov	edi, (80 * 10 + 2) * 2	; 屏幕第 10 行, 第 2 列。
	mov	ax, 0C43h				; 0000: 黑底 1100: 红字 'C'
	mov	[gs:edi], ax
	jmp	SelectorCode16:0		; 准备经由16位代码段跳回实模式
SegCode32Len	equ	$ - SEG_CODE32
; END of [SECTION .s32]
; -------------------------------------------------------------------------------------
[SECTION .ring3]
ALIGN	32
[BITS	32]
CODE_RING3:
	mov	ax, SelectorVideo
	mov	gs, ax
	mov	edi, (80 * 10 + 1) * 2	; 屏幕第 10 行, 第 1 列。
	mov	ax, 0C33h				; 0000: 黑底 1100: 红字 '3'
	mov	[gs:edi], ax
	call	SelectorCallGate:0
SegCodeRing3Len	equ	$ - CODE_RING3
; END of [SECTION .ring3]
; -------------------------------------------------------------------------------------
; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
SEG_CODE16:
	; 跳回实模式:
	mov	ax, SelectorNormal
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and	al, 11111110b
	mov	cr0, eax
GO_BACK_TO_REAL:
	jmp	0:REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值
Code16Len	equ	$ - SEG_CODE16
; END of [SECTION .s16code]