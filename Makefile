#Archivo de configuracion de la utilidad make.
#Author: Erwin Meza <emezav@gmail.com>
#/** @verbatim */


BOOTSECTOR_OBJS= src/bootsect.o
KERNEL_OBJS= src/start.o

GCC=gcc
LD=ld
JAVA=java


#Detectar si se requiere usar un compilador cruzado
arch := $(shell uname -s)
machine := $(shell uname -m)
x86found := false
os := $(shell uname -o)

ARCH :=
ifeq "$(arch)" "Linux"
	ifeq "$(machine)" "i386"
		x86found := true
	endif	
	ifeq "$(machine)" "i486"
		x86found := true
	endif	
	ifeq "$(machine)" "i586"
		x86found := true
	endif	
	ifeq "$(machine)" "i686"
		x86found := true
	endif	
else
	ARCH := i386-elf-
endif

ifeq "$(x86found)" "false"
	ARCH := i386-elf-
endif

BOCHSDBG := bochsdbg
ifeq "$(arch)" "Linux"
    BOCHSDBG := bochs
endif

DISPLAY := x
ifeq "$(os)" "Msys"
	DISPLAY := win32
endif

ifeq "$(os)" "Cygwin"
	DISPLAY := win32
endif

all: bootsector	kernel
	@sh util/check_kernel_parameters.sh kernel
	cat bootsect kernel > floppy.img

bootsector: $(BOOTSECTOR_OBJS)
	$(ARCH)$(LD) -T link_bootsector.ld -o bootsect $(BOOTSECTOR_OBJS)
	
kernel: $(KERNEL_OBJS)
	$(ARCH)$(LD) -T link_kernel.ld -o kernel $(KERNEL_OBJS)

.S.o:
	$(ARCH)$(GCC) -nostdinc -nostdlib -fno-builtin -c -Iinclude -o $@ $<

bochs: all
	-bochs -q 'boot:a' \
	'floppya: 1_44=floppy.img, status=inserted' 'megs:32'
	
bochsdbg: all
	-$(BOCHSDBG) -q 'boot:a' \
	'floppya: 1_44=floppy.img, status=inserted' 'megs:32' \
	'display_library:$(DISPLAY), options="gui_debug"'
	
qemu: all
	qemu -fda floppy.img -boot a

jpc: all
	$(JAVA) -jar ../jpc/JPCApplication.jar -boot fda -fda floppy.img

jpcdbg: all
	$(JAVA) -jar ../jpc/JPCDebugger.jar -boot fda -fda floppy.img

clean:
	rm -f bootsect kernel $(BOOTSECTOR_OBJS) $(KERNEL_OBJS) floppy.img
	-if test -d docs; then \
	   rm -r -f docs; \
	   else true; fi

#/** @endverbatim */