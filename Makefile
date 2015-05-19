#########################
# Makefile #
#########################

# Entry point
# It must have the same value with 'KernelEntryPointPhyAddr' in load.inc!
ENTRYPOINT = 0x30400

# Offset of entry point in kernel file
# It depends on ENTRYPOINT
ENTRYOFFSET = 0x400

# Programs, flags, etc.
ASM       = nasm
DASM      = ndisasm
CC        = gcc
LD        = ld
ASMBFLAGS = -I boot/include/
ASMKFLAGS = -I include/ -f elf
# compile 32bit code with 64bit gcc
CFLAGS    = -I include/ -c -fno-builtin -m32 -fno-stack-protector
LDFLAGS   = -s -Ttext $(ENTRYPOINT) -m elf_i386
DASMFLAGS = -u -o $(ENTRYPOINT) -e $(ENTRYOFFSET)

# This Program
ORANGESBOOT   = boot/boot.bin boot/loader.bin
ORANGESKERNEL = kernel.bin
OBJS          = kernel/kernel.o kernel/start.o kernel/global.o kernel/i8259.o \
	kernel/protect.o kernel/main.o kernel/clock.o kernel/syscall.o kernel/proc.o \
	kernel/keyboard.o kernel/tty.o kernel/console.o kernel/io.o \
	lib/klib.o lib/kliba.o lib/string.o
DASMOUTPUT    = kernel.bin.asm

# All Phony Targets
.PHONY : everything final image clean realclean disasm all buildimg

# Default starting position
everything : $(ORANGESBOOT) $(ORANGESKERNEL)

all : realclean everything

final : all clean

image : final buildimg

clean :
	rm -f $(OBJS)

realclean :
	rm -f $(OBJS) $(ORANGESBOOT) $(ORANGESKERNEL)

disasm :
	$(DASM) $(DASMFLAGS) $(ORANGESKERNEL) > $(DASMOUTPUT)

# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo cp -fv boot/loader.bin /mnt/floppy/
	sudo cp -fv kernel.bin /mnt/floppy
	sudo umount /mnt/floppy

boot/boot.bin : boot/boot.asm boot/include/load.inc boot/include/fat12hdr.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

boot/loader.bin : boot/loader.asm boot/include/load.inc \
			boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(ORANGESKERNEL) $(OBJS)

kernel/kernel.o : kernel/kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/start.o : kernel/start.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/i8259.o :  kernel/i8259.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o : kernel/global.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/protect.o : kernel/protect.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/main.o : kernel/main.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/clock.o : kernel/clock.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/syscall.o : kernel/syscall.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/proc.o : kernel/proc.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/keyboard.o : kernel/keyboard.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/tty.o : kernel/tty.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/console.o : kernel/console.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/io.o : kernel/io.c
	$(CC) $(CFLAGS) -o $@ $<

lib/klib.o : lib/klib.c
	$(CC) $(CFLAGS) -o $@ $<

lib/kliba.o : lib/kliba.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

lib/string.o : lib/string.c
	$(CC) $(CFLAGS) -o $@ $<
