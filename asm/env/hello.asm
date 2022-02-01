dseg    segment
message db  'How do you do.',0dh,0ah,24h
dseg    ends
;代码段
cseg    segment
        assume  cs:cseg,ds:dseg
begin:
        mov ax,dseg
        mov ds,ax
        mov dx,offset message
        mov ah,9
        mov ebx, eax
        int 21h
        mov ah,4ch
        int 21h
cseg    ends
        end begin