/**
 * @file
 * @ingroup kernel_code
 * @author Erwin Meza <emezav@gmail.com>
 * @copyright GNU Public License.
 * @brief Punto de entrada del kernel
 * @details
 * Este código pasa a modo protegido de 32 bits, y luego imprime un
 * caracter y una cadena en la pantalla.
 *aja como vas

 * Luego, el kernel imprime un byte que se encuentra en su seccion de datos.
 * Si la carga del kernel fue correcta, debera imprimir kernel_byte luego del
 * string impreso.
*/

/** @verbatim */

.intel_syntax noprefix /* Usar sintaxis Intel, sin prefijo para los registros */
.code16		# 16 bits - Modo real
.text		#Segmento de texto

/* En este archivo se define la dirección en la cual se carga el kernel */
#include <constants.h>

/* Define el símbolo de entrada necesario para el linker */
.global kernel_start
/* Punto en el cual empieza la ejecucion del kernel */
kernel_start:

jmp kernel_main /* Saltar el encabezado del kernel */

/* Encabezado del kernel: el byte 4 contiene un word con la longitud
  del kernel en sectores.
  El valor de kernel_sectors es calculado e insertado en este archivo
  por el linker. (Ver archivo link_kernel.ld) */
.align 4
kernel_header:
.word kernel_sectors

/* La ejecución continúa en esta etiqueta. */
kernel_main:

    /* ax = cs */
    mov ax, cs

    /* ds = ax */
    mov ds, ax

    /* PASO A MODO PROTEGIDO DE 32 BITS */

    /* Paso 1 : Deshabilitar las interrupciones */

    cli

   /* Paso 1.1: Habilitar la linea de direcciones A20 */

   /* Existe una gran cantidad de alternativas para habilitar la
   línea de direcciones A20.
   Ver los siguientes enlaces para una descripción detallada de este proceso:
   http://www.win.tue.nl/~aeb/linux/kbd/A20.html
   http://wiki.osdev.org/A20_Line
   */

   /* En este kernel se hace uso de la alternativa más 'compatible' : Programar
   directamente el controlador de teclado.
   */

check_buffer_1:

	/* Leer un byte del puerto 0x64 y almacenarlo en al */
    in al, 0x64  /* Leer el registro de estado del 8042 */

    /* Verificar el segundo bit de al */
    test al, 2 /*Segundo bit: input register ( 0x60/0x64 ) has data for 8042*/

    jnz check_buffer_1 /* Esperar hasta que el buffer este vacio */

    mov al, 0xd1 /*0xd1 = Write output port: el siguiente byte escrito en
		    0x60 se coloca en el puerto de salida del 8042. El segundo
		    bit permite habilitar A20 en un teclado IBM AT compatible */
    out 0x64, al   /*Escribir el bit en el registro de comando del  8042 */

check_buffer_2:
    in al, 0x64 /* De nuevo leer el registro de estado del 8042 */
    test al, 2 /* input register ( 0x60 / 0x64 ) has data for 8042? */
    jnz check_buffer_2  /*Esperar hasta que el buffer este vacio*/

    mov al, 0xdf /* 0xdf = 1101111 = habilita el segundo bit (A20 Gate) */
    out 0x60, al /*Escribir el siguiente byte en 0x60 para habilitar A20 */

check_buffer_3: /* Esperar de nuevo hasta que el buffer este vacio*/
    in al, 0x64
    test al, 2
    jnz check_buffer_3

    /* Paso 2:  Ejecutar LGDT para cargar un GDT válido */

    lgdt [tmp_gdt_pointer]

    /* Paso 3: Ejecutar una operacion MOV para activar el primer bit (PE) en
    			cr0. */

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    /* Paso 4: Ejecutar ljmp o call.
    El ljmp o call debe pasar a un codigo de 32 bits, que debe tener
    la directiva .code32 (prefijo de 32 bits)

    El descriptor del segmento de código a saltar se encuentra en la segunda
    posicion del GDT, es decir a un desplazamiento de 8 bytes (0x8) desde el
    inicio del GDT. */

    ljmp 0x8 :  OFFSET in_pmode

    /*  En el segmento de código de base 0,  saltar a la dirección lineal
       in_pmode */

/* Prefijo para codigo de 32 bits. De este punto en adelante las instrucciones
son de 32 bits. */

.code32	/* En este punto sigue la ejecución, en modo protegido de 32 bits */

in_pmode:
    /*El ljmp  serializa el procesador. Esto asegura que todas las
    instrucciones que se ejecutaron en modo real se completan antes de
    pasar a modo protegido.

    Ya estamos en modo protegido!

    */

/* Paso 5: Cargar un LDT valido con la instruccion LLDT
	(EN ESTE CASO NO APLICA) */

/* Paso 6: Ejecutar una instruccion LTR para cargar el Task Register
	con un selector de segmento de la tarea inicial, o un area de memoria
	escribible que pueda ser utilizada para almacenar informacion del TSS
	en un task switch (EN ESTE CASO NO APLICA)
	*/

/* Paso 7: Luego de entrar a modo protegido, los registros de segmento
continuan con los valores que tenian en modo real. El jmp far solo cambia
cs, por lo cual se deben actualizar los demas registros (ss, ds, es, fs y
gs).
Si alguno de estos registos no se va a utilizar, se deben cargar con el
selector nulo del GDT, es decir 0x0.
*/

    /*El descriptor del segmento de datos (y pila) se encuentra en la tercera
    posicion del GDT, es decir en un desplazamiento de 16 bits (0x10) desde el
    inicio del GDT. */

    /* ax = 0x10 */
    mov ax, 0x10

    mov ds, ax   /* Todos los registros de segmento de datos apuntan al mismo */
    mov es, ax   /* selector */
    mov fs, ax
    mov gs, ax
    mov ss, ax

    /* Importante: Configurar un segmento de pila temporal */
    mov esp, 0x9F000

    /*Probar si el paso a modo protegido se realizó correctamente. Si es así, se
    puede utilizar la dirección absoluta 0xb8000 para tener acceso a la
    memoria de video, ya que el segmento de datos se configuró para
    iniciar en 0x0.

    Tratar de escribir un caracter en la dirección lineal de la memoria de
    video (0xb8000)
    */

	/* ds: 0xB8000 = apunta al inicio de la memoria de video de modo texto */
    mov edi, 0xb8000
    movw  ds:[edi], 0x0740 /* Enviar el caracter '@' en la primera posicion de
		              la memoria de video
		               07 = atributos (blanco sobre negro), 40 = caracter '@' */

    add edi, 2  /* Incrementar en 2 el apuntador en la memoria de video */

    /* Ahora imprimir una cadena de caracteres*/

    mov eax, OFFSET pm_message /* Equivalente a lea  eax, pm_message*/

    mov esi, eax	/*  esi contiene la dirección lineal de pm_message */

    mov al, 0x1f		    /*Byte de atributos 0x1f = blanco sobre azul */

print_loop:			    /*Ciclo para imprimir la cadena */
    cmpb ds:[esi], 0x0	    /* El fin de la cadena (Caracter 0 = nulo)? */
    je end_print_loop		    /* Si es así, salir del ciclo*/

    movsb			    /* cargar byte de ds:(esi) en es:(edi)
				    	  e incrementar edi y esi */
    stosb    		    /* cargar el valor de al en es:(edi)(atributos de texto)
				    	e incrementar edi */
    jmp print_loop		    /* Siguiente caracter */


end_print_loop:			    /* Fin del ciclo */

    /* Ahora imprimir kernel_byte, que se encuentra en la seccion de datos del
    kernel. */

    mov al, [kernel_byte]
    mov ah, 0x1f /* Byte de atributos 0x1f = blanco sobre azul*/

    stosw		/* movw es:[edi], ax; inc edi */

    jmp finished	 /*Por ultimo, entrar en un ciclo infinito ya que la CPU
    			debe estar ocupada.*/

finished:			    /* Ciclo infinito */
   jmp finished


/*
TABLA GLOBAL DE DESCRIPTORES (gdt)
Esta es la tabla de descriptores que utiliza el procesador en modo protegido de
32 bits.
En este caso se va a utilizar el Modelo Flat Basico, en el cual el kernel
accede a un espacio de direcciones continuo, no segmentado. Para este modo
se requieren al menos dos descriptores de segmento, que se mapean al
espacio de direcciones que puede referenciar el computador (0-4GB).
Para ello, ambos descriptores (de codigo y datos) tienen un valor base de 0
y un límite de 1 MB. Si el bit G=1, se utilizan paginas de 4KB, por lo cual
el limite es 1 MB * 4 KB = 4 GB.
*/

.align 8
tmp_gdt:
    /* La primera entrada del gdt debe ser nula */
   .word 0x0000
   .word 0x0000
   .byte 0x00
   .byte 0x00
   .byte 0x00
   .byte 0x00

   .word 0xFFFF  /* Limite 0..15 = FFFF */
   .word 0x0000  /* Base 0..15 = 0000 */
   .byte 0x00    /* Base 16..23 = 00 */
   .byte 0x9A    /* 10011010 P=1, DPL=0, S=1, Tipo: codigo, read/execute,
		   		 	non conforming */
   .byte 0xCF	/* 11001111 G=1, D/B=1 (32 bits), L=0, AVL=0, Limite 16..19=F */
   .byte 0x00	/* Base 24..31 = 00 */

   .word 0xFFFF  /*Limite 0..15 = FFFF */
   .word 0x0000  /*Base 0..15 = 0000 */
   .byte 0x00    /*Base 16..23 = 00 */
   .byte 0x92	 /*10010010 P=1, DPL=0, S=1, Tipo: datos, read/write */
   .byte 0xCF /*11001111  G=1, D/B=1 (32 bits) , L=0, AVL=0, Limite 16..19=F  */
   .byte 0x00	 /*Base 24..31 = 00  */

/*Apuntador a la tabla global de descriptores, que se usa en la instruccion
LGDT.
 Debe contener el tamaño del gdt (numero de entradas * 8 bytes /entrada) - 1,
 y la dirección lineal (en un espacio de 32 bits) en la cual se encuentra la
tabla de descriptores globales (GDT).
*/

tmp_gdt_pointer:
   .word .-tmp_gdt-1 /* Tamaño del GDT - 1: . (dirección actual) -
				     (dirección del gdt) - 1 */
   .long  tmp_gdt  /* dirección lineal de 32 bits en la cual se
					encuentra el gdt */

.data
pm_message:
	.asciz "Hola desde Modo Protegido!"

kernel_byte:
	.byte '*'

.space 1024

/**
@endverbatim
*/
