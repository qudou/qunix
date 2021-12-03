#########################
# Makefile for qunix #
#########################

# Entry point of qunix
# It must have the same value with 'KernelEntryPointPhyAddr' in load.inc!
ENTRYPOINT	= 0x30400

# Offset of entry point in kernel file
# It depends on ENTRYPOINT
ENTRYOFFSET	=   0x400

# Programs, flags, etc.
ASM		= nasm
DASM		= ndisasm
CC		= gcc
LD		= ld
ASMBFLAGS	= -I boot/include/
ASMKFLAGS	= -I include/ -f elf
CFLAGS		= -I include/ -c -fno-builtin -fno-stack-protector -minline-all-stringops -m32
LDFLAGS		= -s -Ttext $(ENTRYPOINT) -melf_i386
DASMFLAGS	= -u -o $(ENTRYPOINT) -e $(ENTRYOFFSET)

# This Program
ORANGESBOOT	= boot/boot.bin

# All Phony Targets
.PHONY : everything final image clean realclean all buildimg

# Default starting position
everything : $(ORANGESBOOT)

all : realclean everything

final : all clean

image : final buildimg

realclean :
	rm -f $(ORANGESBOOT)

# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo umount /mnt/floppy

boot/boot.bin : boot/boot.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<