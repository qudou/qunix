;程序名: t10-1.asm
;功能: 演示实方式和保护方式切换
;16位偏移的段间直接转移指令的宏定义
jump    macro  selector,offsetv
        db     0EAH
        dw     offsetv
        dw     selector
        endm

;字符显示宏指令的定义
echoch  macro ascii
    mov     ah, 2
    mov     dl, ascii
    int     21h
    endm

;存储段描述符结构类型的定义
descriptor  struc
limit       dw      0   ;段界限(0~15)
basel       dw      0   ;段基地址(0~15)
basem       db      0   ;段基地址(16~23)
attributes  dw      0   ;段属性
baseh       db      0   ;段基地址(24~31)
descriptor  ends

;伪描述符结构类型的定义
pdesc       struc
limit       dw      0   ;16界限
baseh       dd      0   ;基地址
pdesc       ends

;常量定义
atdw    =   92h         ;存在的可读写数据段属性值
atce    =   98h         ;存在的只执行代码段属性值

;----------------------------------

;数据段
dseg    segment use16               ;16位段
gdt         label byte              ;全局描述符表gdt
dummy       descriptor  <>          ;空描述符
code        descriptor  <0ffffh,,,atce,>
code_sel    = code - gdt            ;代码段描述的选择子
datas       descriptor  <0ffffh,0h,11h,atdw,0>
datas_sel   = datas - gdt           ;源数据段描述符的选择子
datad       descriptor  <0ffffh,,,atdw,>
datad_sel   = datad-gdt             ;目标数据段描述符的选择子
gdtlen      = $ - gdt
;
vgdtr       pdesc <gdtlen-1,>       ;伪描述符
;
bufferlen   = 256                   ;缓冲区字节长度
buffer      db  bufferlen   dup(0)  ;缓冲区
dseg        ends

;----------------------------------

;代码段
cseg    segment     use16       ;16位段
        assume      cs:cseg,    ds:dseg
start:
        mov ax,dseg
        mov ds,ax
        ;准备要加载到gdtr的伪描述符
        mov bx,16
        mul bx                  ;计算并设置 gdt 基地址
        add ax,offset gdt       ;界限已在定义时设置妥当
        adc dx,0
        mov word ptr vgdtr.base,   ax
        mov word ptr vgdtr.base+2, dx
        ;设置代码段描述符
        mov ax,cs
        mul bx
        mov code.basel,ax       ;代码段开始偏移为0
        mov code.basem,dl       ;代码段界限已在定义时设置妥当
        mov code.baseh,dh
        ;设置目标数据段描述符
        mov ax,ds
        mul bx                  ;计算并设置目标数据段基地址
        add ax,offset buffer
        adc dx,0
        mov datad.basel,ax
        mov datad.basem,dl
        mov datad.baseh,dh
        ;加载gdtr
        lgdt qword ptr vgdtr
        ;
        cli                     ;关中断
        call enablea20          ;打开地址线A20
        ;切换到保护方式
        mov eax,cr0
        or eax,1
        mov cr0,eax
        ;清指令预取队列，并真正进入保护方式
        jump <code_sel>,<offset virtual>
        ;
virtual:;现在开始在保护方式下
        mov ax,datas-sel
        mov ds,ax               ;加载源数据段描述符
        mov ax,datad-sel
        mov es,ax               ;加载目标数据段描述符
        cld
        xor si,si               ;设置指针初值
        xor di,di
        mov cx,bufferlen/4      ;设置4字节为单位的缓冲区长度
        repz movsd              ;传送
        ;切换回实方式
        mov eax,cr0
        and eax,0ffffffffh
        mov cr0,eax
        ;清指令预取队列，进入实方式
        jump <seg real>,<offset real>
real: ;现在又回到实方式
        call disablea20         ;关闭地址线A20
        sti;                    ;开中断
        ;
        mov ax,dseg             ;重置数据段寄存器
        mov ds,ax
        mov si,offset buffer
        cld                     ;显示缓冲区内容
        mov bp,bufferlen/16
nextline:
        mov cx,16
nextch:
        lodsb
        push ax
        shr  al,4
        call toascii
        echoch al
        pop ax
        call toascii
        echoch al
        echoch  ''
        loop    nextch
        echoch  0dh
        echoch  0ah
        dec bp
        jnz nextline

        mov ax,4c00h            ;结束
        int 21h
;
toascii proc
;把 al 低4位的十六进制数据转换成对应的 ASCII, 保存在 al
toascii endp
;
ea20    proc
;打开地址线A20
ea20    endp
;
da20 proc
;关闭地址线A20
da20 endp
cseg ends
     end    start
;
;打开地址线A20
ea20    proc
    push    ax
    int     al,92h
    or      al,2
    out     92h,al
    pop     ax
    ret
ea20    endp
;
;关闭地址线A20
da20    proc
    push    ax
    in      al,92h
    and     al,0fdh     ;0fdh = not 20h
    out     92h,al
    pop     ax
    ret
da20    endp