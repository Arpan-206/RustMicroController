MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS {
    . = 0x00000000;
    .text : {
        *(.text.start)   /* _start must be first */
        *(.text*)
    } > RAM
    .rodata : { *(.rodata*) } > RAM
    .data   : { *(.data*)   } > RAM
    .bss    : { *(.bss*)    } > RAM
    _bss_end = .;
}
