.section .text
.global run_tcp_tests

// External symbols from tcp.s
.extern tcp_listen_port
.extern tcp_state
.extern tcp_rx_buffer
.extern tcp_rx_buffer_len
.extern tcp_buffer_append
.extern tcp_buffer_reset

.equ HTTP_PORT, 80
.equ STATE_LISTEN, 1

run_tcp_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_tcp_listen_port
    bl test_tcp_initial_seq
    bl test_tcp_buffer_reset
    bl test_tcp_buffer_append
    bl test_tcp_buffer_append_accumulates

    ldp x29, x30, [sp], #16
    ret

// Test: Listen port is configured to 80
test_tcp_listen_port:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Simple test: HTTP_PORT should be 80
    mov x0, #HTTP_PORT
    mov x1, #80
    ldr x2, =name_listen_port
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: STATE_LISTEN constant is 1
test_tcp_initial_seq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #STATE_LISTEN
    mov x1, #1
    ldr x2, =name_state_listen
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: tcp_buffer_reset clears buffer length
test_tcp_buffer_reset:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // First set buffer length to something non-zero
    ldr x0, =tcp_rx_buffer_len
    mov w1, #100
    str w1, [x0]

    // Reset buffer
    bl tcp_buffer_reset

    // Check length is now 0
    ldr x0, =tcp_rx_buffer_len
    ldr w0, [x0]
    mov x1, #0
    ldr x2, =name_buffer_reset
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: tcp_buffer_append adds data and returns count
test_tcp_buffer_append:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Reset buffer first
    bl tcp_buffer_reset

    // Append test data
    ldr x0, =test_data
    mov w1, #5                  // 5 bytes: "hello"
    bl tcp_buffer_append

    // Check returned byte count
    mov x1, #5
    ldr x2, =name_buffer_append_ret
    bl test_assert_eq

    // Check buffer length
    ldr x0, =tcp_rx_buffer_len
    ldr w0, [x0]
    mov x1, #5
    ldr x2, =name_buffer_append_len
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Multiple appends accumulate
test_tcp_buffer_append_accumulates:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Reset buffer first
    bl tcp_buffer_reset

    // Append first chunk
    ldr x0, =test_data
    mov w1, #5
    bl tcp_buffer_append

    // Append second chunk
    ldr x0, =test_data2
    mov w1, #6
    bl tcp_buffer_append

    // Check total buffer length is 11
    ldr x0, =tcp_rx_buffer_len
    ldr w0, [x0]
    mov x1, #11
    ldr x2, =name_buffer_accumulates
    bl test_assert_eq

    // Clean up
    bl tcp_buffer_reset

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "tcp"
name_listen_port:
    .asciz "tcp listen port is 80"
name_state_listen:
    .asciz "tcp state can be set to LISTEN"
name_buffer_reset:
    .asciz "tcp_buffer_reset clears length"
name_buffer_append_ret:
    .asciz "tcp_buffer_append returns count"
name_buffer_append_len:
    .asciz "tcp_buffer_append updates length"
name_buffer_accumulates:
    .asciz "tcp_buffer appends accumulate"

test_data:
    .ascii "hello"
test_data2:
    .ascii "world!"
