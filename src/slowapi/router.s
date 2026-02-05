// SlowAPI Router
// Route matching and dispatch with path parameter support

.include "src/config.s"

.section .text
.global slowapi_dispatch

.include "src/slowapi/macros.s"

// slowapi_dispatch: Match request to route and call handler
// Input: x0 = request context ptr
// Output: Calls appropriate handler or sends error response
slowapi_dispatch:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    mov x19, x0             // request context

    // Get request path and method
    ldr x20, [x19, #REQ_PATH]       // path pointer
    ldr w21, [x19, #REQ_PATH_LEN]   // path length
    ldr w22, [x19, #REQ_METHOD]     // method

    // Clear path param fields
    str xzr, [x19, #REQ_PATH_PARAM]
    str wzr, [x19, #REQ_PATH_PARAM_LEN]

.if DEBUG
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_dispatch
    bl uart_puts
    ldp x19, x20, [sp], #16
.endif

    // Get route table bounds
    ldr x23, =__routes_start
    ldr x24, =__routes_end

    // Track if we found a path match (for 405 vs 404)
    mov w25, #0             // path_matched flag

.route_loop:
    cmp x23, x24
    b.ge .no_route_match

    // Load route entry
    ldr x26, [x23, #ROUTE_PATH]      // route path ptr
    ldr w27, [x23, #ROUTE_PATH_LEN]  // route path len
    ldr w28, [x23, #ROUTE_METHODS]   // route methods

    // Try to match this route (handles both static and parameterized routes)
    mov x0, x20             // request path
    mov w1, w21             // request path length
    mov x2, x26             // route path
    mov w3, w27             // route path length
    mov x4, x19             // request context (for storing path param)
    bl match_route

    // x0 = 1 if matched, 0 otherwise
    cbz x0, .next_route

    // Path matches! Set flag
    mov w25, #1

    // Check if method matches
    cmp w22, w28
    b.ne .next_route

    // Match found! Call handler with request context in x0
    ldr x3, [x23, #ROUTE_HANDLER]
    mov x0, x19

.if DEBUG
    stp x0, x3, [sp, #-16]!
    ldr x0, =msg_handler
    bl uart_puts
    ldp x0, x3, [sp], #16
.endif

    blr x3

    // Handler returns - we're done
    b .dispatch_done

.next_route:
    add x23, x23, #ROUTE_SIZE
    b .route_loop

.no_route_match:
    // Check if path matched but method didn't
    cbnz w25, .method_not_allowed

    // 404 Not Found
    mov w0, #STATUS_NOT_FOUND
    bl resp_error
    b .dispatch_done

.method_not_allowed:
    // 405 Method Not Allowed
    mov w0, #STATUS_METHOD_NOT_ALLOWED
    bl resp_error

.dispatch_done:
    ldp x27, x28, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// match_route: Match request path against route pattern
// Supports path parameters like /api/hotels/{id}
// Input: x0 = request path, w1 = request path length
//        x2 = route pattern, w3 = route pattern length
//        x4 = request context (to store extracted param)
// Output: x0 = 1 if match, 0 if no match
match_route:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov x19, x0             // request path
    mov w20, w1             // request path length
    mov x21, x2             // route pattern
    mov w22, w3             // route pattern length
    mov x23, x4             // request context

    mov w24, #0             // request path index
    mov w25, #0             // route pattern index

.match_loop:
    // Check if we've consumed both strings
    cmp w25, w22
    b.ge .check_req_end

    // Get current route char
    ldrb w0, [x21, x25]

    // Check for '{' - start of parameter
    cmp w0, #'{'
    b.eq .match_param

    // Check if we still have request chars
    cmp w24, w20
    b.ge .no_match

    // Compare characters
    ldrb w1, [x19, x24]
    cmp w0, w1
    b.ne .no_match

    // Advance both
    add w24, w24, #1
    add w25, w25, #1
    b .match_loop

.match_param:
    // Found '{', find matching '}'
    mov w26, w25            // start of {
    add w25, w25, #1        // skip '{'

.find_close_brace:
    cmp w25, w22
    b.ge .no_match          // malformed pattern

    ldrb w0, [x21, x25]
    cmp w0, #'}'
    b.eq .found_close_brace

    add w25, w25, #1
    b .find_close_brace

.found_close_brace:
    add w25, w25, #1        // skip '}'

    // Now extract the path parameter value
    // It runs from w24 to either end of string or next '/'
    mov w26, w24            // param start in request

.find_param_end:
    cmp w24, w20
    b.ge .param_end_found

    ldrb w0, [x19, x24]
    cmp w0, #'/'
    b.eq .param_end_found

    add w24, w24, #1
    b .find_param_end

.param_end_found:
    // Store path param: pointer and length
    add x0, x19, x26        // param pointer
    str x0, [x23, #REQ_PATH_PARAM]
    sub w0, w24, w26        // param length
    str w0, [x23, #REQ_PATH_PARAM_LEN]

    b .match_loop

.check_req_end:
    // Route pattern consumed, check if request path is also consumed
    cmp w24, w20
    b.ne .no_match

    // Full match!
    mov x0, #1
    b .match_done

.no_match:
    mov x0, #0

.match_done:
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.if DEBUG
.section .rodata
msg_dispatch:
    .asciz "[ROUTER] "
msg_handler:
    .asciz "->handler "
.endif
