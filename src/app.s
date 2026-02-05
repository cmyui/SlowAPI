// SlowAPI Hotel CRUD Application
// Demonstrates path parameters, JSON building, and in-memory database

.section .text

.include "src/slowapi/macros.s"

// Hotel record layout (stored in database)
.equ HOTEL_NAME_OFF,    0    // 32 bytes: name (null-terminated)
.equ HOTEL_CITY_OFF,    32   // 32 bytes: city (null-terminated)
.equ HOTEL_SIZE,        64
.equ HOTEL_NAME_MAX,    31   // max name length (leave 1 for null)
.equ HOTEL_CITY_MAX,    31   // max city length

//=============================================================================
// ROUTES
//=============================================================================

// GET / - Homepage
ENDPOINT METHOD_GET, "/"
handler_index:
    ldr x0, =html_index
    ldr x1, =html_index_len
    ldr w1, [x1]
    b resp_html

// GET /api/hotels - List all hotels
ENDPOINT METHOD_GET, "/api/hotels"
handler_list_hotels:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #JSON_CTX_SIZE + 1024  // JSON context + buffer

    // Initialize JSON builder
    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #1024
    bl json_init

    // Start array
    mov x0, sp
    bl json_start_arr

    // Iterate over all hotels
    ldr x0, =list_hotel_callback
    mov x1, sp               // pass JSON context as user data
    bl db_list

    // End array
    mov x0, sp
    bl json_end_arr

    // Get result
    mov x0, sp
    bl json_finish
    // x0 = buffer, x1 = length

    bl resp_json

    add sp, sp, #JSON_CTX_SIZE + 1024
    ldp x29, x30, [sp], #16
    ret

// Callback for db_list: adds a hotel to JSON array
// x0 = id, x1 = data ptr, x2 = data size, x3 = context (JSON ctx)
list_hotel_callback:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov w19, w0              // id
    mov x20, x1              // data ptr (hotel record)
    mov x21, x3              // JSON context

    // Check if we need a comma (check if array already has content)
    // Simple heuristic: if length > 1 (just '['), add comma
    ldr w0, [x21, #12]       // JSON_LEN
    cmp w0, #1
    b.le .no_comma_needed

    mov x0, x21
    bl json_comma

.no_comma_needed:
    // Start hotel object
    mov x0, x21
    bl json_start_obj

    // Add "id": <id>
    mov x0, x21
    ldr x1, =key_id
    mov x2, #2
    bl json_add_key
    mov x0, x21
    mov w1, w19
    bl json_add_int

    // Add comma
    mov x0, x21
    bl json_comma

    // Add "name": "<name>"
    mov x0, x21
    ldr x1, =key_name
    mov x2, #4
    bl json_add_key

    // Get name length (strlen)
    add x22, x20, #HOTEL_NAME_OFF
    mov x0, x22
    bl strlen_simple
    mov w1, w0

    mov x0, x21
    mov x2, x1               // length
    mov x1, x22              // name pointer
    bl json_add_string

    // Add comma
    mov x0, x21
    bl json_comma

    // Add "city": "<city>"
    mov x0, x21
    ldr x1, =key_city
    mov x2, #4
    bl json_add_key

    // Get city length
    add x22, x20, #HOTEL_CITY_OFF
    mov x0, x22
    bl strlen_simple
    mov w1, w0

    mov x0, x21
    mov x2, x1
    mov x1, x22
    bl json_add_string

    // End hotel object
    mov x0, x21
    bl json_end_obj

    // Return 0 to continue iteration
    mov x0, #0

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// GET /api/hotels/{id} - Get single hotel
ENDPOINT METHOD_GET, "/api/hotels/{id}"
handler_get_hotel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #JSON_CTX_SIZE + 512

    mov x19, x0              // request context

    // Parse ID from path param
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    // x0 = parsed ID (or 0 if failed)

    cbz x0, .get_hotel_404
    mov w20, w0              // hotel ID

    // Get hotel from database
    mov w0, w20
    bl db_get
    // x0 = data ptr, x1 = data size

    cbz x0, .get_hotel_404
    mov x19, x0              // hotel data

    // Build JSON response
    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #512
    bl json_init

    mov x0, sp
    mov x1, x19
    mov w2, w20
    bl build_hotel_json

    mov x0, sp
    bl json_finish
    bl resp_json

    add sp, sp, #JSON_CTX_SIZE + 512
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.get_hotel_404:
    mov w0, #STATUS_NOT_FOUND
    bl resp_error
    add sp, sp, #JSON_CTX_SIZE + 512
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// POST /api/hotels - Create hotel
// Body format: "name,city"
ENDPOINT METHOD_POST, "/api/hotels"
handler_create_hotel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    sub sp, sp, #HOTEL_SIZE + JSON_CTX_SIZE + 512

    mov x19, x0              // request context

    // Get body
    ldr x20, [x19, #REQ_BODY]
    ldr w21, [x19, #REQ_BODY_LEN]

    cbz x20, .create_bad_request
    cbz w21, .create_bad_request

    // Parse "name,city" format
    // Find comma
    mov x0, x20
    mov w1, w21
    mov w2, #','
    bl find_char
    // x0 = pointer to comma, or 0 if not found

    cbz x0, .create_bad_request
    mov x22, x0              // comma position

    // Build hotel record on stack
    add x0, sp, #JSON_CTX_SIZE + 512  // hotel record buffer

    // Copy name (from body start to comma)
    sub w1, w22, w20         // name length
    cmp w1, #HOTEL_NAME_MAX
    b.gt .create_bad_request
    cbz w1, .create_bad_request

    mov x2, x0               // dest
    mov x3, x20              // src (body start)
.copy_name:
    cbz w1, .name_copied
    ldrb w4, [x3], #1
    strb w4, [x2], #1
    sub w1, w1, #1
    b .copy_name
.name_copied:
    strb wzr, [x2]           // null terminate

    // Copy city (from after comma to end)
    add x0, sp, #JSON_CTX_SIZE + 512
    add x3, x22, #1          // skip comma
    add x2, x0, #HOTEL_CITY_OFF

    // Calculate city length
    add x4, x20, x21         // body end
    sub w1, w4, w3           // city length
    cmp w1, #HOTEL_CITY_MAX
    b.gt .create_bad_request
    cbz w1, .create_bad_request

.copy_city:
    cbz w1, .city_copied
    ldrb w4, [x3], #1
    strb w4, [x2], #1
    sub w1, w1, #1
    b .copy_city
.city_copied:
    strb wzr, [x2]           // null terminate

    // Create record in database
    add x0, sp, #JSON_CTX_SIZE + 512
    mov x1, #HOTEL_SIZE
    bl db_create
    // x0 = new ID (or 0 on failure)

    cbz x0, .create_server_error
    mov w20, w0              // new hotel ID

    // Get the record back to build response
    mov w0, w20
    bl db_get
    mov x21, x0              // hotel data ptr

    // Build JSON response
    mov x0, sp
    add x1, sp, #JSON_CTX_SIZE
    mov x2, #512
    bl json_init

    mov x0, sp
    mov x1, x21
    mov w2, w20
    bl build_hotel_json

    mov x0, sp
    bl json_finish
    // x0 = buffer, x1 = length

    mov x2, x1
    mov x1, x0
    mov w0, #STATUS_CREATED
    mov w3, #CTYPE_JSON
    bl resp_status

    add sp, sp, #HOTEL_SIZE + JSON_CTX_SIZE + 512
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.create_bad_request:
    mov w0, #STATUS_BAD_REQUEST
    bl resp_error
    add sp, sp, #HOTEL_SIZE + JSON_CTX_SIZE + 512
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.create_server_error:
    mov w0, #STATUS_SERVER_ERROR
    bl resp_error
    add sp, sp, #HOTEL_SIZE + JSON_CTX_SIZE + 512
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// DELETE /api/hotels/{id} - Delete hotel
ENDPOINT METHOD_DELETE, "/api/hotels/{id}"
handler_delete_hotel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0              // request context

    // Parse ID from path param
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int

    cbz x0, .delete_404
    mov w20, w0

    // Delete from database
    mov w0, w20
    bl db_delete
    // x0 = 0 success, -1 failure

    cmp x0, #0
    b.ne .delete_404

    // 204 No Content
    bl resp_no_content

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.delete_404:
    mov w0, #STATUS_NOT_FOUND
    bl resp_error
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// HELPER FUNCTIONS
//=============================================================================

// build_hotel_json: Build JSON for a hotel
// Input: x0 = JSON context, x1 = hotel data ptr, w2 = hotel ID
build_hotel_json:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // JSON context
    mov x20, x1              // hotel data
    mov w21, w2              // hotel ID

    // Start object
    mov x0, x19
    bl json_start_obj

    // "id": <id>
    mov x0, x19
    ldr x1, =key_id
    mov x2, #2
    bl json_add_key
    mov x0, x19
    mov w1, w21
    bl json_add_int

    mov x0, x19
    bl json_comma

    // "name": "<name>"
    mov x0, x19
    ldr x1, =key_name
    mov x2, #4
    bl json_add_key

    add x22, x20, #HOTEL_NAME_OFF
    mov x0, x22
    bl strlen_simple

    mov x2, x0
    mov x0, x19
    mov x1, x22
    bl json_add_string

    mov x0, x19
    bl json_comma

    // "city": "<city>"
    mov x0, x19
    ldr x1, =key_city
    mov x2, #4
    bl json_add_key

    add x22, x20, #HOTEL_CITY_OFF
    mov x0, x22
    bl strlen_simple

    mov x2, x0
    mov x0, x19
    mov x1, x22
    bl json_add_string

    // End object
    mov x0, x19
    bl json_end_obj

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// parse_int: Parse decimal integer from string
// Input: x0 = string pointer, w1 = length
// Output: x0 = parsed value (0 on failure)
parse_int:
    cbz x0, .parse_fail
    cbz w1, .parse_fail

    mov x2, #0               // result
    mov w3, #0               // index

.parse_loop:
    cmp w3, w1
    b.ge .parse_done

    ldrb w4, [x0, x3]

    // Check if digit
    cmp w4, #'0'
    b.lt .parse_fail
    cmp w4, #'9'
    b.gt .parse_fail

    // result = result * 10 + digit
    mov x5, #10
    mul x2, x2, x5
    sub w4, w4, #'0'
    add x2, x2, x4

    add w3, w3, #1
    b .parse_loop

.parse_done:
    mov x0, x2
    ret

.parse_fail:
    mov x0, #0
    ret

// strlen_simple: Get string length
// Input: x0 = null-terminated string
// Output: x0 = length (not including null)
strlen_simple:
    mov x1, x0
    mov x2, #0
.strlen_loop:
    ldrb w3, [x1], #1
    cbz w3, .strlen_done
    add x2, x2, #1
    b .strlen_loop
.strlen_done:
    mov x0, x2
    ret

// find_char: Find character in string
// Input: x0 = string, w1 = length, w2 = character to find
// Output: x0 = pointer to character, or 0 if not found
find_char:
    cbz w1, .find_not_found
.find_loop:
    ldrb w3, [x0]
    cmp w3, w2
    b.eq .find_found
    add x0, x0, #1
    sub w1, w1, #1
    cbnz w1, .find_loop
.find_not_found:
    mov x0, #0
    ret
.find_found:
    ret

//=============================================================================
// JSON CONTEXT SIZE (from json.s)
//=============================================================================
.equ JSON_CTX_SIZE, 16

//=============================================================================
// STATIC DATA
//=============================================================================
.section .rodata

key_id:
    .asciz "id"
key_name:
    .asciz "name"
key_city:
    .asciz "city"

html_index:
    .ascii "<html><head><title>SlowAPI Hotel API</title></head>"
    .ascii "<body><h1>SlowAPI Hotel API</h1>"
    .ascii "<p>A CRUD API for hotels, written in pure ARM64 assembly</p>"
    .ascii "<h2>Endpoints:</h2>"
    .ascii "<ul>"
    .ascii "<li>GET /api/hotels - List all hotels</li>"
    .ascii "<li>GET /api/hotels/{id} - Get a specific hotel</li>"
    .ascii "<li>POST /api/hotels - Create a hotel (body: name,city)</li>"
    .ascii "<li>DELETE /api/hotels/{id} - Delete a hotel</li>"
    .ascii "</ul>"
    .ascii "<h2>Try it:</h2>"
    .ascii "<pre>"
    .ascii "# Create a hotel\n"
    .ascii "curl -X POST -d 'Hilton,Toronto' http://localhost:8888/api/hotels\n\n"
    .ascii "# List all hotels\n"
    .ascii "curl http://localhost:8888/api/hotels\n\n"
    .ascii "# Get a specific hotel\n"
    .ascii "curl http://localhost:8888/api/hotels/1\n\n"
    .ascii "# Delete a hotel\n"
    .ascii "curl -X DELETE http://localhost:8888/api/hotels/1"
    .ascii "</pre>"
    .ascii "</body></html>"
html_index_end:

.section .data
html_index_len:
    .word html_index_end - html_index
