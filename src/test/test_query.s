// Query Parameter Parser Unit Tests

.section .text
.global run_query_tests

run_query_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_query_single_param
    bl test_query_second_param
    bl test_query_not_found
    bl test_query_empty_string
    bl test_query_value_length

    ldp x29, x30, [sp], #16
    ret

// Test: Get single parameter from query string
test_query_single_param:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =query_single
    mov w1, #10              // "name=alice"
    ldr x2, =param_name
    mov w3, #4               // "name"
    bl query_get_param

    // Should return non-null
    ldr x1, =name_single_found
    bl test_assert_nonzero

    ldp x29, x30, [sp], #16
    ret

// Test: Get second parameter from query string
test_query_second_param:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =query_multi
    mov w1, #21              // "name=alice&city=paris"
    ldr x2, =param_city
    mov w3, #4               // "city"
    bl query_get_param

    // Should return non-null
    ldr x1, =name_second_found
    bl test_assert_nonzero

    ldp x29, x30, [sp], #16
    ret

// Test: Parameter not found returns null
test_query_not_found:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =query_single
    mov w1, #10
    ldr x2, =param_city
    mov w3, #4
    bl query_get_param

    mov x1, #0
    ldr x2, =name_not_found
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Empty query string returns null
test_query_empty_string:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #0
    mov w1, #0
    ldr x2, =param_name
    mov w3, #4
    bl query_get_param

    mov x1, #0
    ldr x2, =name_empty_query
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Returned value length is correct
test_query_value_length:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =query_single
    mov w1, #10              // "name=alice"
    ldr x2, =param_name
    mov w3, #4
    bl query_get_param
    // x0 = value ptr, x1 = value length

    // Length should be 5 ("alice")
    mov x0, x1
    mov x1, #5
    ldr x2, =name_value_len
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Test Data
//=============================================================================

.section .rodata
section_name:
    .asciz "query parser"

name_single_found:
    .asciz "single param found"
name_second_found:
    .asciz "second param found"
name_not_found:
    .asciz "missing param returns null"
name_empty_query:
    .asciz "empty query returns null"
name_value_len:
    .asciz "value length is correct"

query_single:
    .asciz "name=alice"

query_multi:
    .asciz "name=alice&city=paris"

param_name:
    .asciz "name"

param_city:
    .asciz "city"
