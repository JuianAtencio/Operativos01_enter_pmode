/**
* @file
* @ingroup kernel_code
* @author Erwin Meza <emezav@gmail.com>
* @copyright GNU Public License.
* @brief Sector de Arranque en Imagen de Floppy
* @details
* Este bootsector se copia a si mismo a la posicion de memoria 0x500
* (la primera dirección de memoria disponible en modo real), y le cede el
*  control al código copiado en esta dirección (el mismo código del sector
* de arranque).
*
* A su vez, esta copia del bootsector se encarga de 'leer' un kernel en formato
* binario que se encuentra almacenado a partir del segundo sector de la imagen
* de disco. Este kernel se carga en la dirección de memoria 0x1000 (4 KB).
*
* El kernel almacena su tamaño en sectores en una variable que se encuentra
* definida exactamente en un desplazamiento de 4 bytes a partir su inicio.
*
* El bootsector lee el primer sector del kernel (el segundo sector de la
* imagen de disco), y de este primer sector obtiene el numero de sectores (-1)
* que debe leer para cargar el kernel completamente. Luego, carga los demas
* sectores del kernel.
*
* Con el fin de simplificar el proceso de lectura, se implementa una rutina
* que recibe como parametro el numero lineal de sector a leer, y la dirección de
* memoria (segmento:offset) en el cual se debe leer.
*
* Para cargar el kernel, se implementa la rutina 'read_lba_from_floppy',
* que oculta los detalles de la geometria de un  disco floppy.
*
* Finalmente, el bootsector le transfiere el control al kernel por medio
* de una instruccion ljmp.
*/

/** @verbatim */

.intel_syntax noprefix /* Usar sintaxis Intel, si prefijo para los registros */
.code16     /* 16 bits- Modo Real */

.section .text  /* Seccion de texto */

.globl start

/* Simbolo de entrada del bootsector. En este punto comienza su ejecucion. */
start:

    ljmp 0x7C0 : entry_point /* Asegurarse que cs tome el valor de 0x7C0
                                 ip toma el valor del desplazamiento
                                 de la etiqueta 'entry_point' */

/* La ejecucion continúa en este punto, pero se garantiza que el valor de cs
es 0x7C0 */
entry_point:

	/* ax = cs = 0x7C0*/
    mov ax, cs

    /* ds = ax */
    mov ds, ax

    /* Copiarse a sí mismo a la dirección de memoria 0x500.*/
	/* cx = 0x100 = 256*/
    mov cx, 0x100 /*   El bootsector ocupa 512 bytes, pero
                        se van a copiar dos bytes (1 word) cada vez.
                        Por lo tanto se deben copiar  256 words = 512 bytes. */

    /* si = 0. Equivalente a mov si, 0x0000 */
    xor si, si

    /* ds:si ahora apunta a 0x7C00*/

	/* ax = 0x50 */
    mov ax, 0x50

    /* es = ax */
    mov es, ax

    /* di = 0 */
    xor di, di

    /* es:di ahora apunta a 0x500 */
    rep movsw       /* Decrementar cx. mientras cx > 0, copiar un word de
                    ds:si a es:di e incrementar si en 2 y di en 2, ya que
                    se copio un word (2 bytes) */

    /* Ver documentación de la instrucción movs y del prefijo 'rep' */

   /* Pasar el control a la copia del bootsector, que se encuentra
     en la posicion de memoria 0x500. */

     /* La ejecución no puede empezar en 0x50: 0x0000 = 0x500, debido a que
    el código del sector de arranque se ejecutaría desde el inicio
    (es decir se repetiría la copia,y saltaría de nuevo .. ciclo infinito) */


     ljmp 0x50 : OFFSET continuar /* continuar la ejecucion con cs = 0x50,
                              con un desplazamiento de la etiqueta 'continuar'*/


    /* Este código es ejecutado por la copia en la nueva posicion de
    memoria (0x500) */
continuar:

    /* ax = cs */
    mov ax, cs  /* Se debe actualizar ds a partir de cs, para que el */

    /* ds = ax */
    mov ds, ax  /* segmento de datos apunte a la nueva posicion de memoria.*/

    /* Ahora la copia debe configurar la pila en una región de memoria
     que no esté siendo utilizada. */

    cli     /* Deshabilitar las interrupciones */

	/* ax = 0x50 */
    mov ax, 0x50

    /* ss = ax */
    mov ss, ax     /* No se puede establecer directamente ss, usar ax*/

    /* sp = 0xB00 */
    mov sp, 0xB00  /* Configurar el tope de la pila a =0x500 + 0xB00 = 0x5B00*/

    sti     /* Habilitar de nuevo las interrupciones */

    /* Leer el primer sector del kernel */

   /* El kernel se encuentra contiguo al sector de arranque, es decir
   en el sector 2 del floppy. */

   push 0x0000
   push 0x100
   push 0x1
   /* read_lba_from_floppy(i, segmento, offset) */
   call read_lba_from_floppy
   add sp, 6

   /* El primer sector del kernel ha sido leído en 0x1000.
   Dentro del primer sector del kernel, a un desplazamiento de 4
   bytes, se encuentra el numero de sectores. Leer ese valor
   para leer los n-1 sectores faltantes del kernel.
   Ver el archivo link_bootsector.ld para más detalles.
   */

   /* configurar ES para que apunte al segmento que comienza en 0x1000,
   la dirección de memoria  en la cual se va a leer el kernel desde disco */

   /*  ax = 0x100 */
   mov ax, 0x100

   /* es = ax */
   mov es, ax

   /* es = 0x100.  es:[4] = (0x100 * 0x10) + 4 = 0x1004, la posición
     de la variable que almacena el tamano del kernel en sectores.

     cx = [1004]

     */

   mov cx, es:[4]
   /* CX ya contiene el número de sectores que ocupa el kernel.
   Recordar que este número de sectores fué calculado por el linker */

   /* cx = cx - 1 */
   decw cx /* Ya se leyó el primer sector, restar 1 al numero de sectores */

   /* Los sectores 2.. n del kernel se deben leer a partir de 0x1200, ya
   que el primer sector de 512 bytes (0x200), fue leido en 0x1000 */

   /* segment = 0x120. */
   /* equivalente a mov WORD PTR [segment], (0x100 + 0x20) */
   movw [segment], (0x100 + 0x20)

   /* El siguiente sector a leer: 0 = bootsector, 1 = primer sector del kernel
      Empezar en el sector LBA 2
   */

   /* lba_sector = 2 */
   /* equivalente a mov WORD PTR [lba_sector], 0x02*/
   movw [lba_sector], 0x02

read_kernel_sectors:    /* Ciclo para leer los sectores 2..n del kernel*/
   push 0x0000 /* Desplazamiento: Siempre cero */
   push [segment] /* Segmento: comienza en 0x120, dirección lineal 0x1200 */

   /* En cada interación se lee el sector de disco a la posición
   referenciada por segment : 0x00000 es decir 0x1200, 0x1400 .. etc.
   Al manejar siempre un desplazamiento de cero, y modificar el
   segmento, se evita el problema de modo real de sólo poder acceder
   segmentos de 64 KB. */

   push [lba_sector] /* Sector LBA a leer, comienza en 2*/

   /* Llamar a la rutina read_lba_from_floppy(i, segmento, offset=0)*/
   call read_lba_from_floppy

   /* Se introdujeron 3 parámetros en la pila, en modo real cada parámetro
   ocupa un word. Luego de ejecutar la función se deben sacar los
   parámetros enviados a ella.*/
   add sp, 6

   /* lba_sector = lba_sector + 1 */
   incw [lba_sector] /* Incrementar el sector lba a leer */

   /* segment = segment + 0x20 */
   addw [segment], 0x20 /* Incrementar el segmento en el cual se va a leer
                          el sector */
   /* Al aumentar segment en 0x20, en realidad se está desplazando
   512 bytes en la memoria.

   segment toma los valores de 0x100, 0x120, 0x140, 0x180, .. etc. Debido a que
   este valor se almacena en un registro de segmento, es multiplicado
   automáticamente por 16 en modo real. Así la dirección lineal
   apuntada es 0x1000, 0x1200, 0x1400, .. etc.

   */

    /* Imprimir un '+' por cada sector leido. Debido a que con este ciclo
    se leen n-1 sectores del kernel, deberia imprimir n-1 '+'*/

    mov al, '+'
    mov ah, 0x0E
    int 0x10

   loop read_kernel_sectors /* Decrementar cx, e iterar si cx > 0*/

   /* Cuando CX = 0, termina el ciclo y la ejecución continúa en este
   punto. */

   /* Saltar a cs = 0x000, offset=0x1000 = 0x1000

	En otras palabras, pasar el control al código del kernel que se leyó
	a partir de la dirección 0x1000
   */

   ljmp 0x0000 :  0x1000

   /* El kernel no debería retornar la ejecución a este punto. Sin embargo,
   para asegurarse, saltar a la etiqueta 'finished' para entrar en un
   ciclo infinito.*/

  jmp finished /* Saltar al símbolo (la etiqueta) 'finished'

/* Simbolo (etiqueta) finished. */
finished:
   jmp finished   /* Salta de nuevo a la etiqueta 'finished' (ciclo infinito) */

/* Variables del bootsector
Geometría por defecto del floppy: 80 cilindros, 2 cabezas, 18 sectores por
pista (SPT).
Total sectores: 2880
Se utilizan las variables cyls, heads y spt para calcular el cilindro,
la cabeza y el sector que corresponden a un sector LBA 'i' especificado.
*/

cyls: /* Variable para almacenar los cilindros que tiene un floppy */
.word 80

heads:  /* Variable para almacenar las cabezas que tiene un floppy*/
.word 2

spt:    /* Variable para almacenar los sectores por pista de un floppy */
.word 18

segment: /* Segmento en el cual se va a leer el siguiente sector del kernel */
.word 0x0000

lba_sector: /* Numero de sector LBA del kernel a leer */
.word 0x0000

/* Implementación de las rutinas */
/*
Rutina: read_lba_from_floppy

Descripcion: Esta rutina lee un sector de un disco floppy, haciendo uso
de los servicios de disco de la BIOS (int 0x13).
Entrada: Los parámetros de sector a leer, segmento y desplazamiento (dirección
		 lógica a la cual se va a leer el sector en memoria) deberán estar
		 en la pila.
		 4(bp) : sector lba a leer (i).
         6(bp) : segmento en el cual se desea leer el sector (segmento)
         8(bp) : desplazamiento en el cual se desea leer el sector (offset)

LBA = Logical Block Addressing. Es una forma de referenciar un sector en el
disco, tomando el disco como una secuencia lineal de n sectores:
+--------------------------------------------------+
| 0  |   1  |   2  |  ...  |  i    | n-2     | n-1 |
+--------------------------------------------------+
En LBA, los sectores se enumeran de 0 a n-1, donde n es el
número de sectores del disco.

Los discos generalmente utilizan una geometria basada en Cilindros, Sectores
y Cabezas (C/H/S). Esta es la geometría usada por la BIOS para leer sectores.

A partir del sector LBA 'i' especificado, esta rutina calcula el sector, el
cilindro y la cabeza en la cual se encuentra el sector en un disco floppy.

*/

read_lba_from_floppy:
   push bp    /* Crear el marco de pila */
   mov bp, sp

   pusha       /* Guardar los registros de proposito general en la pila */

   push es   /* Guardar en la pila el registro es */

   /* Primer parámetro: Sector (lba, comienza en 0) */
   mov ax, [bp + 4]

   /* dx = 0, dx:ax = sector LBA */
   xor dx, dx

   /* dx:ax / spt ax = cociente, dx = resto */
   divw [spt]

   /* Para la BIOS, los sectores empiezan en 1 */
   incw dx

   /* cl= dl, Numero del sector */
   mov cl, dl

   /* dx = 0 */
   xor dx, dx

   /* dx:ax = sector / spt */

   /* dx:ax (sector /spt) / cabezas ax = cociente, dx = resto */
   divw [heads]

   /* dh = cabeza */
   mov dh, dl

   /* Drive (0x0 = floppy) */
   xor dl, dl

   /* al = cilindro */
   mov ch, al

   /* Recuperar el segundo parametro de la pila: El segmento en el cual
   se debe leer el sector de disco */
   mov bx, [bp + 6]

   /* es = bx */
   mov es, bx

   /* Recuperar el tercer parametro de la pila: El desplazamiento dentro del
   segmento en el cual se debe leer el sector */
   mov bx, [bp + 8]

   /* es:bx apunta al segmento:desplazamiento en el cual se debe leer el
      sector */

read_sector:
   /* al = 0x01 */
   mov al, 0x1   /* Leer un (1) sector */

   /* ah = 0x02 */
   mov ah, 0x2   /* ah = 02h = read sectors from drive */

   int  0x13       /* Invocar los servicios de disco de la BIOS */

   jc read_sector /* Error? repetir lectura */

   pop es        /* Recuperar el valor de es de la pila */
   popa          /* Recuperar el valor de los registros de proposito general*/

   mov sp, bp   /* Cerrar el marco de pila */
   pop bp
   ret          /* Retornar de la rutina */

/*
Fin del bootsector
*/

/*
Una vez compilado, el código del bootsector no puede ocupar más de 510 bytes.
Al generar el codigo ejecutable del bootsector, el linker se encarga
de rellenar con ceros el espacio a partir de la ultima instruccion de codigo
compilado hasta completar 510 bytes, y luego incluye los bytes 0x55 y 0xAA
para generar un bootsector valido de 512 bytes.

Ver el archivo link_bootsector.ld para más detalles.

*/

/**
@endverbatim
*/
