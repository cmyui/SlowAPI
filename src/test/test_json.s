// JSON Builder Unit Tests

.section .text
.global run_json_tests

// JSON context size
.equ JSON_CTX_SIZE, 16

run_json_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_json_empty_object
    bl test_json_empty_array
    bl test_json_simple_object
    bl test_json_int_value
    bl test_json_finish_length

    ldp x29, x30, [sp], #16
    ret

// Test: Build empty object {}
test_json_empty_object:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #JSON_CTX_SIZE + 64

    // Initialize
    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #64
    bl json_init

    // Build {}
    mov x0, sp
    bl json_start_obj
    mov x0, sp
    bl json_end_obj

    // Get result
    mov x0, sp
    bl json_finish
    // x0 = buffer, x1 = length

    // Length should be 2
    mov x0, x1
    mov x1, #2
    ldr x2, =name_empty_obj_len
    bl test_assert_eq

    add sp, sp, #JSON_CTX_SIZE + 64
    ldp x29, x30, [sp], #16
    ret

// Test: Build empty array []
test_json_empty_array:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #JSON_CTX_SIZE + 64

    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #64
    bl json_init

    mov x0, sp
    bl json_start_arr
    mov x0, sp
    bl json_end_arr

    mov x0, sp
    bl json_finish

    mov x0, x1
    mov x1, #2
    ldr x2, =name_empty_arr_len
    bl test_assert_eq

    add sp, sp, #JSON_CTX_SIZE + 64
    ldp x29, x30, [sp], #16
    ret

// Test: Build {"key":"value"}
test_json_simple_object:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #JSON_CTX_SIZE + 128

    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #128
    bl json_init

    mov x0, sp
    bl json_start_obj

    mov x0, sp
    ldr x1, =test_key
    mov x2, #3               // "key"
    bl json_add_key

    mov x0, sp
    ldr x1, =test_value
    mov x2, #5               // "value"
    bl json_add_string

    mov x0, sp
    bl json_end_obj

    mov x0, sp
    bl json_finish
    mov x19, x0              // buffer
    mov w20, w1              // length

    // Check first char is '{'
    ldrb w0, [x19]
    mov x1, #'{'
    ldr x2, =name_obj_start
    bl test_assert_eq

    add sp, sp, #JSON_CTX_SIZE + 128
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: Integer value formatting
test_json_int_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #JSON_CTX_SIZE + 64

    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #64
    bl json_init

    // Just write an integer
    mov x0, sp
    mov w1, #42
    bl json_add_int

    mov x0, sp
    bl json_finish
    mov x19, x0
    mov w20, w1

    // Length should be 2 ("42")
    mov x0, x20
    mov x1, #2
    ldr x2, =name_int_len
    bl test_assert_eq

    add sp, sp, #JSON_CTX_SIZE + 64
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: json_finish returns correct length
test_json_finish_length:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #JSON_CTX_SIZE + 64

    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #64
    bl json_init

    // Build {"a":1}
    mov x0, sp
    bl json_start_obj

    mov x0, sp
    ldr x1, =test_a
    mov x2, #1
    bl json_add_key

    mov x0, sp
    mov w1, #1
    bl json_add_int

    mov x0, sp
    bl json_end_obj

    mov x0, sp
    bl json_finish

    // {"a":1} = 7 chars
    mov x0, x1
    mov x1, #7
    ldr x2, =name_finish_len
    bl test_assert_eq

    add sp, sp, #JSON_CTX_SIZE + 64
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Test Data
//=============================================================================

.section .rodata
section_name:
    .asciz "json builder"

name_empty_obj_len:
    .asciz "empty object is 2 chars"
name_empty_arr_len:
    .asciz "empty array is 2 chars"
name_obj_start:
    .asciz "object starts with {"
name_int_len:
    .asciz "integer 42 is 2 chars"
name_finish_len:
    .asciz "finish returns correct length"

test_key:
    .asciz "key"
test_value:
    .asciz "value"
test_a:
    .asciz "a"
