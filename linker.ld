ENTRY(init)

MEMORY {
    MMODE (rwx) : ORIGIN = 0x00000000, LENGTH = 256K
    UMODE (rwx) : ORIGIN = 0x00040000, LENGTH = 256K
}

SECTIONS {
    . = 0x00000000;
    .ktext.start : { KEEP(*(.ktext.start)) } > MMODE
    .ktext       : { KEEP(*(.ktext))       } > MMODE
    .krodata     : { *(.krodata*)          } > MMODE
    .data        : { *(.data*)             } > MMODE
    .bss         : { *(.bss*) *(COMMON)    } > MMODE
    _bss_end = .;

    . = 0x00040000;
    .utext.start : { KEEP(*(.utext.start)) } > UMODE
    .text        : { *(.text*)             } > UMODE
    .rodata      : { *(.rodata*)           } > UMODE
    .urodata     : { *(.urodata*)          } > UMODE
}
