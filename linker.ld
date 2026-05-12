ENTRY(init)

MEMORY {
    MMODE (rwx) : ORIGIN = 0x00000000, LENGTH = 256K
    UMODE (rwx) : ORIGIN = 0x00040000, LENGTH = 256K
}

PROVIDE(__os_stack_size = 1024);
PROVIDE(__user_stack_size = 2048);

SECTIONS {
    . = 0x00000000;
    .ktext.start : { KEEP(*(.ktext.start)) } > MMODE
    .ktext       : { KEEP(*(.ktext))       } > MMODE
    .krodata     : { *(.krodata*)          } > MMODE
    .bss         : { *(.bss*) *(COMMON)    } > MMODE
    _bss_end = .;

    . = 0x00040000;
    .utext.start : { KEEP(*(.utext.start)) } > UMODE
    .text        : { *(.text*)             } > UMODE
    .rodata      : { *(.rodata*)           } > UMODE
    .urodata     : { *(.urodata*)          } > UMODE
}
