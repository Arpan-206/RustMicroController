fn main() {
    println!("cargo:rerun-if-changed=src/lcd.s");
    cc::Build::new()
        .compiler("riscv64-unknown-elf-gcc") // force 32-bit, not riscv64
        .flag("-march=rv32im")
        .flag("-mabi=ilp32")
        .file("src/lcd.s")
        .compile("lcd");
}
