/// Indices into the M-mode shared_data array.
/// The ISR and OS write to these; user-space reads/writes via SYS_SHARED_GET/SET.
#[repr(u32)]
pub enum SharedSlot {
    Counter = 0,  // incremented by timer ISR each second
    Dirty   = 1,  // set to 1 by ISR when counter updated; cleared by foreground
    Running = 2,  // 1 = running, 0 = paused; written by foreground
}
