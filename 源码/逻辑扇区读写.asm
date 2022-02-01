; 入口参数
; (ah)=功能号(2:读,3:写)
; (dx)=要读写的逻辑扇区号(0~2879)
; (es:bx)=指向接收从扇区读入数据的内存区|指向将写入磁盘的数据
; 返回参数
; 操作成功：(ah)=0,(al)=读入|写入的扇区数
; 操作失败：(ah)=出错代码

int7ch:
    cmp ah,1
    ja over
    
    push ax
    push bx
    push cx
    push dx

    push ax
    mov ax,dx
    mov dx,0
    mov bx,1440
    div bx       ; dxax/bx = ax 余 dx
    mov cl,al

    mov bl,18
    mov ax,dx
    div bl       ; ax/bl = al 余 ah
    
    inc ah
    mov cl,ah    ; 扇区号

    mov ch,al    ; 磁道号
    
    mov dl,0     ; 驱动器号
    mov dh,al    ; 磁头号

    pop ax
    mov al,1     ; 读写1个扇区
    add ah,2     ; 巧妙!0|1+2=2|3
    int 13h
    
    pop dx
    pop cx
    pop bx
    pop ax
over: 
    iret