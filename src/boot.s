.section .text.boot
.global _start

_start:
    // Set up stack pointer
    ldr x0, =_stack_top
    mov sp, x0

    // Initialize UART
    bl uart_init

    // Print "Hello World"
    ldr x0, =hello_msg
    bl uart_puts

    // Halt: infinite loop
halt:
    wfe
    b halt

.section .rodata
hello_msg:
    .asciz "Hello World\n"
