ENTRY(init)

MEMORY {
    MMODE (rwx) : ORIGIN = 0x00000000, LENGTH = 256K
    UMODE (rwx) : ORIGIN = 0x00040000, LENGTH = 256K
}

SECTIONS {
    . = 0x00000000;
    .text.start : { KEEP(*(.text.start)) } > MMODE
    .text       : { KEEP(*(.text*))      } > MMODE
    .rodata     : { *(.rodata*)           } > MMODE
    .bss        : { *(.bss*) *(COMMON)    } > MMODE
    _bss_end = .;

    . = 0x00040000;
    .utext   : { KEEP(*(.utext.start)) KEEP(*(.utext*))  } > UMODE
    .urodata : { *(.urodata*)      } > UMODE
}
