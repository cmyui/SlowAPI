.section .text
.global uart_init
.global uart_putc
.global uart_puts

// PL011 UART base address for QEMU virt machine
.equ UART_BASE, 0x09000000
.equ UART_DR,   0x00        // Data register
.equ UART_FR,   0x18        // Flag register
.equ UART_FR_TXFF, 5        // TX FIFO full flag bit

// uart_init: Initialize UART (minimal - QEMU PL011 works without config)
uart_init:
    ret

// uart_putc: Write a single character
// Input: w0 = character to write
uart_putc:
    ldr x1, =UART_BASE
1:
    ldr w2, [x1, #UART_FR]      // Load flag register
    tbnz w2, #UART_FR_TXFF, 1b  // Loop if TX FIFO full
    strb w0, [x1, #UART_DR]     // Write character
    ret

// uart_puts: Write a null-terminated string
// Input: x0 = pointer to string
uart_puts:
    stp x29, x30, [sp, #-16]!   // Save frame pointer and return address
    mov x29, sp
    mov x19, x0                  // Save string pointer in callee-saved register

    stp x19, xzr, [sp, #-16]!   // Save x19

.puts_loop:
    ldrb w0, [x19], #1          // Load byte and increment pointer
    cbz w0, .puts_done          // If null terminator, done
    bl uart_putc                // Print character
    b .puts_loop

.puts_done:
    ldp x19, xzr, [sp], #16     // Restore x19
    ldp x29, x30, [sp], #16     // Restore frame pointer and return address
    ret
