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
DESC_CODE16:     Descriptor 0,           0ffffh, DA_C      				; 非一致代码段,16, SEG_CODE16
DESC_VIDEO:      Descriptor 0B8000h,     0ffffh, DA_DRW+DA_DPL3			; 视频段描述符
; GDT 结束
GdtLen		equ	$ - DESC_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1		; GDT界限
			dd	0				; GDT基地址
; GDT 选择子
SelectorNormal		equ	DESC_NORMAL		- DESC_GDT
SelectorCode32		equ	DESC_CODE32		- DESC_GDT
SelectorStack		equ	DESC_STACK		- DESC_GDT
SelectorCode16		equ	DESC_CODE16		- DESC_GDT
SelectorVideo		equ	DESC_VIDEO		- DESC_GDT
; END of [SECTION .gdt]
; -------------------------------------------------------------------------------------
[SECTION .data]
ALIGN	32
[BITS	32]
SPValueInRealMode	dw	0
STACK:
	times 512 db 0
TopOfStack	equ	$ - STACK - 1
LABEL_IDT:
; 门                        目标选择子,            偏移, DCount, 属性
%rep 32
		Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.020h:	Gate	SelectorCode32,    ClockHandler,      0, DA_386IGate
%rep 95
		Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
IdtLen		equ	$ - LABEL_IDT
IdtPtr		dw	IdtLen - 1	; 段界限
			dd	0		; 基地址
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

	xor	eax, eax				; 为加载 GDTR 作准备
	mov	ax, ds
	shl	eax, 4
	add	eax, DESC_GDT			; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址
	lgdt	[GdtPtr] 			; 加载 GDTR
	;cli				 		; 关中断

	xor	eax, eax				; 为加载 IDTR 作准备
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_IDT			; eax <- idt 基地址
	mov	dword [IdtPtr + 2], eax	; [IdtPtr + 2] <- idt 基地址
	lidt	[IdtPtr]			; 加载 IDTR

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
	mov	edi, (80 * 10 + 2) * 2	; 屏幕第 10 行, 第 0 列。
	mov	ax, 0C41h				; 0000: 黑底 1100: 红字, 'A'
	mov	[gs:edi], ax

	call	Init8259A
	sti
	jmp	$
Init8259A:
	mov	al, 011h
	out	020h, al	; 主8259, ICW1.
	call	io_delay
	out	0A0h, al	; 从8259, ICW1.
	call	io_delay
	mov	al, 020h	; IRQ0 对应中断向量 0x20
	out	021h, al	; 主8259, ICW2.
	call	io_delay
	mov	al, 028h	; IRQ8 对应中断向量 0x28
	out	0A1h, al	; 从8259, ICW2.
	call	io_delay
	mov	al, 004h	; IR2 对应从8259
	out	021h, al	; 主8259, ICW3.
	call	io_delay
	mov	al, 002h	; 对应主8259的 IR2
	out	0A1h, al	; 从8259, ICW3.
	call	io_delay
	mov	al, 001h
	out	021h, al	; 主8259, ICW4.
	call	io_delay
	out	0A1h, al	; 从8259, ICW4.
	call	io_delay
	;mov	al, 11111111b	; 屏蔽主8259所有中断
	mov	al, 11111110b	; 仅仅开启定时器中断
	out	021h, al	; 主8259, OCW1.
	call	io_delay
	mov	al, 11111111b	; 屏蔽从8259所有中断
	out	0A1h, al	; 从8259, OCW1.
	call	io_delay
	ret
io_delay:
	nop
	nop
	nop
	nop
	ret
_ClockHandler:
ClockHandler	equ	_ClockHandler - $$
	inc	byte [gs:((80 * 10 + 2) * 2)]	; 屏幕第 10 行, 第 2 列。
	mov	al, 20h
	out	20h, al							; 发送 EOI
	iretd
_SpuriousHandler:
SpuriousHandler	equ	_SpuriousHandler - $$
	mov	ah, 0Ch							; 0000: 黑底    1100: 红字
	mov	al, '!'
	mov	[gs:((80 * 10 + 4) * 2)], ax	; 屏幕第 10 行, 第 4 列。
	jmp	$
	iretd
SegCode32Len	equ	$ - SEG_CODE32
; END of [SECTION .s32]
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