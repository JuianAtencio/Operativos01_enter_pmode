/** 
   @file
   @author Erwin Meza <emezav@gmail.com> 
   @brief Archivo  para realizar el enlace (linking) del kernel.
   Este archivo toma los archivos de objeto y organiza el archivo
   final. 
*/
/** @verbatim */
/* 
   Se supone que el kernel se carga en la dirección de memoria 0x1000.
*/

ENTRY(kernel_start);
OUTPUT_FORMAT(binary);
phys = 0x1000;
virt = 0x1000;
SECTIONS {
   . = phys;
   .text phys : AT(virt) {
     code_start = .;
     *(.text)
     . = ALIGN(4096);
     code_end = .;
   } = 0x90909090
   .data  : AT (virt + (data_start - code_start)) {
       data_start = .;
       *(.data)
     . = ALIGN(4096);
       data_end = .;
   } = 0x00000000
   
   /* Sectores efectivos desde el fin del segmento de datos hasta el inicio del 
      segmento  de codigo */

   kernel_sectors = ( (data_end - code_start) / 512); 
   /* El simbolo kernel_sectors almacena el numero de sectores
      que ocupa el kernel. 
      El valor de este simbolo se copia en el byte 4 del archivo binario del
      kernel (ver start.S)
   */
    
   /* Ignorar estas secciones de todos los archivos .o, ya que el codigo
      del kernel se encuentra en la seccion .text y los datos en la 
      seccion .data */
   /DISCARD/ : { 
       *(.rodata)
       *(.bss)
   }
}

/** @endverbatim */