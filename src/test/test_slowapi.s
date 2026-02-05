// SlowAPI Unit Tests
// Tests for request parsing, router, and HTTP utilities

.section .text
.global run_slowapi_tests

.include "src/slowapi/macros.s"

run_slowapi_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    // Request parsing tests
    bl test_parse_get_method
    bl test_parse_post_method
    bl test_parse_path_simple
    bl test_parse_path_with_query
    bl test_parse_query_string

    // HTTP completeness tests
    bl test_http_complete_simple
    bl test_http_incomplete_no_body
    bl test_http_incomplete_partial

    // Router tests
    bl test_route_table_not_empty
    bl test_method_constants

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Request Parsing Tests
//=============================================================================

// Test: Parse GET method
test_parse_get_method:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Parse the test request
    ldr x0, =test_get_request
    ldr x1, =test_get_request_len
    ldr w1, [x1]
    ldr x2, =test_req_ctx
    bl slowapi_parse_request

    // Check parse succeeded
    mov x1, #0
    ldr x2, =name_parse_get_ok
    bl test_assert_eq

    // Check method is GET
    ldr x0, =test_req_ctx
    ldr w0, [x0, #REQ_METHOD]
    mov x1, #METHOD_GET
    ldr x2, =name_method_get
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Parse POST method
test_parse_post_method:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Parse the test request
    ldr x0, =test_post_request
    ldr x1, =test_post_request_len
    ldr w1, [x1]
    ldr x2, =test_req_ctx
    bl slowapi_parse_request

    // Check parse succeeded
    mov x1, #0
    ldr x2, =name_parse_post_ok
    bl test_assert_eq

    // Check method is POST
    ldr x0, =test_req_ctx
    ldr w0, [x0, #REQ_METHOD]
    mov x1, #METHOD_POST
    ldr x2, =name_method_post
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Parse simple path
test_parse_path_simple:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Parse request with simple path
    ldr x0, =test_get_request
    ldr x1, =test_get_request_len
    ldr w1, [x1]
    ldr x2, =test_req_ctx
    bl slowapi_parse_request

    // Check parse succeeded first
    cmp w0, #0
    b.ne .path_parse_failed

    // Check path length ("/health" = 7 chars)
    ldr x0, =test_req_ctx
    ldr w0, [x0, #REQ_PATH_LEN]
    mov x1, #7
    ldr x2, =name_path_len
    bl test_assert_eq
    b .path_test_done

.path_parse_failed:
    mov x0, #0
    mov x1, #1
    ldr x2, =name_path_len
    bl test_assert_eq

.path_test_done:
    ldp x29, x30, [sp], #16
    ret

// Test: Parse path with query string
test_parse_path_with_query:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Parse request with query string
    ldr x0, =test_query_request
    ldr x1, =test_query_request_len
    ldr w1, [x1]
    ldr x2, =test_req_ctx
    bl slowapi_parse_request

    // Check parse succeeded first
    cmp w0, #0
    b.ne .query_parse_failed

    // Check path length excludes query
    ldr x0, =test_req_ctx
    ldr w0, [x0, #REQ_PATH_LEN]
    mov x1, #9                  // "/api/data" = 9 chars
    ldr x2, =name_path_no_query
    bl test_assert_eq
    b .query_test_done

.query_parse_failed:
    // Parse failed - report it
    mov x0, #0
    mov x1, #1
    ldr x2, =name_path_no_query
    bl test_assert_eq

.query_test_done:
    ldp x29, x30, [sp], #16
    ret

// Test: Parse query string
test_parse_query_string:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Parse request with query string
    ldr x0, =test_query_request
    ldr x1, =test_query_request_len
    ldr w1, [x1]
    ldr x2, =test_req_ctx
    bl slowapi_parse_request

    // Check parse succeeded first
    cmp w0, #0
    b.ne .query_str_parse_failed

    // Check query length is non-zero
    ldr x0, =test_req_ctx
    ldr w0, [x0, #REQ_QUERY_LEN]
    ldr x1, =name_query_present
    bl test_assert_nonzero
    b .query_str_test_done

.query_str_parse_failed:
    mov x0, #0
    ldr x1, =name_query_present
    bl test_assert_nonzero

.query_str_test_done:
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// HTTP Completeness Tests
//=============================================================================

// Test: Complete HTTP request detected
test_http_complete_simple:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_complete_http
    ldr x1, =test_complete_http_len
    ldr w1, [x1]
    bl http_check_complete

    mov x1, #1
    ldr x2, =name_http_complete
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Incomplete request (no \r\n\r\n)
test_http_incomplete_no_body:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_incomplete_http
    ldr x1, =test_incomplete_http_len
    ldr w1, [x1]
    bl http_check_complete

    mov x1, #0
    ldr x2, =name_http_incomplete
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Partial request (cut off mid-header)
test_http_incomplete_partial:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_partial_http
    ldr x1, =test_partial_http_len
    ldr w1, [x1]
    bl http_check_complete

    mov x1, #0
    ldr x2, =name_http_partial
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Router Tests
//=============================================================================

// Test: Route table is not empty
test_route_table_not_empty:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =__routes_start
    ldr x1, =__routes_end
    sub x0, x1, x0              // table size in bytes

    ldr x1, =name_routes_exist
    bl test_assert_nonzero

    ldp x29, x30, [sp], #16
    ret

// Test: Method constants are correct bitmasks
test_method_constants:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // GET should be 0x01
    mov x0, #METHOD_GET
    mov x1, #0x01
    ldr x2, =name_method_get_const
    bl test_assert_eq

    // POST should be 0x02
    mov x0, #METHOD_POST
    mov x1, #0x02
    ldr x2, =name_method_post_const
    bl test_assert_eq

    // GET | POST should be 0x03
    mov x0, #(METHOD_GET | METHOD_POST)
    mov x1, #0x03
    ldr x2, =name_method_combo
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Test Data
//=============================================================================

.section .rodata
section_name:
    .asciz "slowapi"

// Test names
name_parse_get_ok:
    .asciz "parse GET request succeeds"
name_method_get:
    .asciz "parsed method is GET"
name_parse_post_ok:
    .asciz "parse POST request succeeds"
name_method_post:
    .asciz "parsed method is POST"
name_path_len:
    .asciz "path length is correct"
name_path_no_query:
    .asciz "path excludes query string"
name_query_present:
    .asciz "query string is parsed"
name_http_complete:
    .asciz "complete HTTP request detected"
name_http_incomplete:
    .asciz "incomplete HTTP request detected"
name_http_partial:
    .asciz "partial HTTP request detected"
name_routes_exist:
    .asciz "route table is not empty"
name_method_get_const:
    .asciz "METHOD_GET is 0x01"
name_method_post_const:
    .asciz "METHOD_POST is 0x02"
name_method_combo:
    .asciz "METHOD_GET|POST is 0x03"

// Test HTTP requests
test_get_request:
    .ascii "GET /health HTTP/1.1\r\n"
    .ascii "Host: localhost\r\n"
    .ascii "\r\n"
test_get_request_end:
.equ test_get_request_len_val, test_get_request_end - test_get_request
.balign 4
test_get_request_len:
    .word test_get_request_len_val

test_post_request:
    .ascii "POST /api/echo HTTP/1.1\r\n"
    .ascii "Host: localhost\r\n"
    .ascii "Content-Length: 5\r\n"
    .ascii "\r\n"
    .ascii "hello"
test_post_request_end:
.equ test_post_request_len_val, test_post_request_end - test_post_request
.balign 4
test_post_request_len:
    .word test_post_request_len_val

test_query_request:
    .ascii "GET /api/data?page=1&limit=10 HTTP/1.1\r\n"
    .ascii "Host: localhost\r\n"
    .ascii "\r\n"
test_query_request_end:
.equ test_query_request_len_val, test_query_request_end - test_query_request
.balign 4
test_query_request_len:
    .word test_query_request_len_val

// Complete HTTP request (has \r\n\r\n)
test_complete_http:
    .ascii "GET / HTTP/1.1\r\n"
    .ascii "Host: test\r\n"
    .ascii "\r\n"
test_complete_http_end:
.equ test_complete_http_len_val, test_complete_http_end - test_complete_http
.balign 4
test_complete_http_len:
    .word test_complete_http_len_val

// Incomplete HTTP request (no \r\n\r\n terminator)
test_incomplete_http:
    .ascii "GET / HTTP/1.1\r\n"
    .ascii "Host: test\r\n"
test_incomplete_http_end:
.equ test_incomplete_http_len_val, test_incomplete_http_end - test_incomplete_http
.balign 4
test_incomplete_http_len:
    .word test_incomplete_http_len_val

// Partial HTTP request (cut off)
test_partial_http:
    .ascii "GET / HTTP/1.1\r\n"
    .ascii "Host:"
test_partial_http_end:
.equ test_partial_http_len_val, test_partial_http_end - test_partial_http
.balign 4
test_partial_http_len:
    .word test_partial_http_len_val

.section .bss
.balign 8
test_req_ctx:
    .skip REQ_SIZE
