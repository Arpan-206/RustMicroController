MEMORY {
    SYSRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS {
    . = 0x00000000;

    .text : {
        KEEP(*(.text.start))   /* boot entry first */
        *(.text*)
    } > SYSRAM

    .rodata : { *(.rodata*) } > SYSRAM
    .data   : { *(.data*)   } > SYSRAM

    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss*)
        _bss_end = .;
    } > SYSRAM

    _stack_top = ORIGIN(SYSRAM) + LENGTH(SYSRAM);
}
