	org	0100h
Message:    db	"Hello, OS world!",0dh,0ah,24h
    mov ax, cs
    mov ds, ax
    mov dx, Message
    mov ah, 9
    int 21h
    mov ah,4ch
    int 21h
