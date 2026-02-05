// Dynamic JSON Builder
// Builds JSON responses incrementally

.section .text
.global json_init
.global json_start_obj
.global json_end_obj
.global json_start_arr
.global json_end_arr
.global json_add_key
.global json_add_string
.global json_add_int
.global json_comma
.global json_finish

// JSON context layout (passed in x0 for all functions)
.equ JSON_BUF,      0   // 8 bytes: buffer pointer
.equ JSON_CAP,      8   // 4 bytes: capacity
.equ JSON_LEN,      12  // 4 bytes: current length
.equ JSON_CTX_SIZE, 16

// json_init: Initialize JSON builder context
// Input: x0 = context pointer (16 bytes)
//        x1 = buffer pointer
//        x2 = buffer capacity
json_init:
    str x1, [x0, #JSON_BUF]
    str w2, [x0, #JSON_CAP]
    str wzr, [x0, #JSON_LEN]
    ret

// json_start_obj: Write '{'
// Input: x0 = context pointer
json_start_obj:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w1, #'{'
    bl json_write_char

    ldp x29, x30, [sp], #16
    ret

// json_end_obj: Write '}'
// Input: x0 = context pointer
json_end_obj:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w1, #'}'
    bl json_write_char

    ldp x29, x30, [sp], #16
    ret

// json_start_arr: Write '['
// Input: x0 = context pointer
json_start_arr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w1, #'['
    bl json_write_char

    ldp x29, x30, [sp], #16
    ret

// json_end_arr: Write ']'
// Input: x0 = context pointer
json_end_arr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w1, #']'
    bl json_write_char

    ldp x29, x30, [sp], #16
    ret

// json_add_key: Write "key":
// Input: x0 = context pointer
//        x1 = key string pointer
//        x2 = key string length
json_add_key:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // context
    mov x20, x1              // key
    mov w21, w2              // key length

    // Write opening quote
    mov x0, x19
    mov w1, #'"'
    bl json_write_char

    // Write key string
    mov x0, x19
    mov x1, x20
    mov w2, w21
    bl json_write_string

    // Write closing quote and colon
    mov x0, x19
    mov w1, #'"'
    bl json_write_char

    mov x0, x19
    mov w1, #':'
    bl json_write_char

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// json_add_string: Write "value"
// Input: x0 = context pointer
//        x1 = value string pointer
//        x2 = value string length
json_add_string:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // context
    mov x20, x1              // value
    mov w21, w2              // value length

    // Write opening quote
    mov x0, x19
    mov w1, #'"'
    bl json_write_char

    // Write value string
    mov x0, x19
    mov x1, x20
    mov w2, w21
    bl json_write_string

    // Write closing quote
    mov x0, x19
    mov w1, #'"'
    bl json_write_char

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// json_add_int: Write integer value
// Input: x0 = context pointer
//        x1 = integer value
json_add_int:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // context
    mov w20, w1              // integer value

    // Handle zero specially
    cbnz w20, .int_nonzero
    mov x0, x19
    mov w1, #'0'
    bl json_write_char
    b .int_done

.int_nonzero:
    // Build digits in reverse on stack
    sub sp, sp, #16
    mov x21, sp              // digit buffer
    mov w22, #0              // digit count

.int_div_loop:
    cbz w20, .int_write

    mov w0, #10
    udiv w1, w20, w0         // quotient
    msub w2, w1, w0, w20     // remainder

    add w2, w2, #'0'
    strb w2, [x21, x22]
    add w22, w22, #1

    mov w20, w1
    b .int_div_loop

.int_write:
    // Write digits in reverse order
    sub w22, w22, #1
.int_write_loop:
    cmp w22, #0
    b.lt .int_write_done

    ldrb w1, [x21, x22]
    mov x0, x19
    bl json_write_char

    sub w22, w22, #1
    b .int_write_loop

.int_write_done:
    add sp, sp, #16

.int_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// json_comma: Write ','
// Input: x0 = context pointer
json_comma:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w1, #','
    bl json_write_char

    ldp x29, x30, [sp], #16
    ret

// json_finish: Finalize and return buffer info
// Input: x0 = context pointer
// Output: x0 = buffer pointer
//         x1 = content length
json_finish:
    ldr w1, [x0, #JSON_LEN]
    ldr x0, [x0, #JSON_BUF]
    ret

//=============================================================================
// Internal helpers
//=============================================================================

// json_write_char: Write a single character
// Input: x0 = context pointer
//        w1 = character
json_write_char:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Check capacity
    ldr w2, [x0, #JSON_LEN]
    ldr w3, [x0, #JSON_CAP]
    cmp w2, w3
    b.ge .write_char_done

    // Write character
    ldr x4, [x0, #JSON_BUF]
    strb w1, [x4, x2]

    // Increment length
    add w2, w2, #1
    str w2, [x0, #JSON_LEN]

.write_char_done:
    ldp x29, x30, [sp], #16
    ret

// json_write_string: Write a string (without quotes)
// Input: x0 = context pointer
//        x1 = string pointer
//        w2 = string length
json_write_string:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // context
    mov x20, x1              // string
    mov w21, w2              // length

    mov w22, #0              // index
.write_str_loop:
    cmp w22, w21
    b.ge .write_str_done

    ldrb w1, [x20, x22]
    mov x0, x19
    bl json_write_char

    add w22, w22, #1
    b .write_str_loop

.write_str_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
