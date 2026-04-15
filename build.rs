fn main() {
    println!("cargo:rerun-if-changed=src/os.s");
    cc::Build::new()
        .compiler("riscv64-unknown-elf-gcc")
        .flag("-march=rv32im_zicsr")
        .flag("-mabi=ilp32")
        .flag("-nostdlib")
        .flag("-mno-relax") // ← stops R_RISCV_RELAX being emitted
        .file("src/os.s")
        .compile("os");
}
