// Query Parameter Parser
// Parses URL query strings (e.g., "name=hilton&city=toronto")

.section .text
.global query_get_param

// query_get_param: Get a parameter value from a query string
// Input: x0 = query string pointer (e.g., "name=hilton&city=toronto")
//        x1 = query string length
//        x2 = parameter name pointer (e.g., "name")
//        x3 = parameter name length
// Output: x0 = value pointer (into original string), or 0 if not found
//         x1 = value length
query_get_param:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov x19, x0              // query string
    mov w20, w1              // query length
    mov x21, x2              // param name
    mov w22, w3              // param name length

    // Handle empty query string
    cbz x19, .param_not_found
    cbz w20, .param_not_found

    mov w23, #0              // current position in query string

.search_param:
    // Check if we have enough chars left for "name="
    sub w0, w20, w23
    add w1, w22, #1          // name length + '='
    cmp w0, w1
    b.lt .param_not_found

    // Compare parameter name at current position
    add x0, x19, x23         // current position
    mov x1, x21              // param name
    mov w2, w22              // name length
.compare_name:
    cbz w2, .check_equals

    ldrb w3, [x0], #1
    ldrb w4, [x1], #1
    cmp w3, w4
    b.ne .skip_to_next

    sub w2, w2, #1
    b .compare_name

.check_equals:
    // Name matched, check for '='
    ldrb w3, [x0]
    cmp w3, #'='
    b.ne .skip_to_next

    // Found! x0 points to '=', value starts at x0+1
    add x24, x0, #1          // value start

    // Find value end (& or end of string)
    add w25, w23, w22        // skip name
    add w25, w25, #1         // skip '='
    mov x26, x24             // value pointer
.find_value_end:
    cmp w25, w20
    b.ge .value_found

    ldrb w0, [x26]
    cmp w0, #'&'
    b.eq .value_found

    add x26, x26, #1
    add w25, w25, #1
    b .find_value_end

.value_found:
    // Calculate value length
    sub x1, x26, x24
    mov x0, x24
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.skip_to_next:
    // Skip to next '&' or end
.skip_loop:
    cmp w23, w20
    b.ge .param_not_found

    add x0, x19, x23
    ldrb w1, [x0]
    add w23, w23, #1

    cmp w1, #'&'
    b.ne .skip_loop

    // Found '&', continue searching
    b .search_param

.param_not_found:
    mov x0, #0
    mov x1, #0
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
