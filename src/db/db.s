// Generic Database Layer
// Simple record storage using slab allocator

.section .text
.global db_init
.global db_create
.global db_get
.global db_delete
.global db_list
.global db_count

// Record header layout (prepended to user data)
.equ REC_ID,        0   // 4 bytes: auto-assigned ID
.equ REC_SIZE,      4   // 4 bytes: user data size
.equ REC_DATA,      8   // variable: user data starts here

// Database configuration
.equ DB_MAX_RECORDS, 64

// db_init: Initialize the database
// Assumes memory allocator is already initialized
db_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Reset next ID to 1
    ldr x0, =db_next_id
    mov w1, #1
    str w1, [x0]

    // Reset record count
    ldr x0, =db_record_count
    str wzr, [x0]

    // Clear records array
    ldr x0, =db_records
    mov x1, #DB_MAX_RECORDS
.clear_records:
    cbz x1, .db_init_done
    str xzr, [x0], #8
    sub x1, x1, #1
    b .clear_records

.db_init_done:
    ldp x29, x30, [sp], #16
    ret

// db_create: Create a new record
// Input: x0 = pointer to data, x1 = data size
// Output: x0 = assigned ID (> 0), or 0 on failure
db_create:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0              // data pointer
    mov w20, w1              // data size

    // Check if we have room for the record (header + data)
    add w0, w20, #REC_DATA
    cmp w0, #128             // must fit in slab block
    b.gt .create_fail

    // Allocate a block
    bl mem_alloc
    cbz x0, .create_fail
    mov x21, x0              // record pointer

    // Get and increment next ID
    ldr x0, =db_next_id
    ldr w22, [x0]            // current ID
    add w1, w22, #1
    str w1, [x0]             // next ID

    // Fill record header
    str w22, [x21, #REC_ID]
    str w20, [x21, #REC_SIZE]

    // Copy user data
    add x0, x21, #REC_DATA
    mov x1, x19
    mov w2, w20
.copy_data:
    cbz w2, .copy_done
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    sub w2, w2, #1
    b .copy_data

.copy_done:
    // Find free slot in records array
    ldr x0, =db_records
    mov w1, #0               // index
.find_slot:
    cmp w1, #DB_MAX_RECORDS
    b.ge .create_fail_free

    ldr x2, [x0, x1, lsl #3]
    cbz x2, .slot_found

    add w1, w1, #1
    b .find_slot

.slot_found:
    // Store record pointer
    str x21, [x0, x1, lsl #3]

    // Increment record count
    ldr x0, =db_record_count
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Return ID
    mov w0, w22
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.create_fail_free:
    mov x0, x21
    bl mem_free

.create_fail:
    mov x0, #0
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// db_get: Get a record by ID
// Input: x0 = record ID
// Output: x0 = pointer to record data (after header), or 0 if not found
//         x1 = data size
db_get:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov w19, w0              // target ID

    // Search records array
    ldr x0, =db_records
    mov w1, #0               // index
.get_search:
    cmp w1, #DB_MAX_RECORDS
    b.ge .get_not_found

    ldr x2, [x0, x1, lsl #3]
    cbz x2, .get_next

    // Check if ID matches
    ldr w3, [x2, #REC_ID]
    cmp w3, w19
    b.eq .get_found

.get_next:
    add w1, w1, #1
    b .get_search

.get_found:
    // Return pointer to data and size
    ldr w1, [x2, #REC_SIZE]
    add x0, x2, #REC_DATA
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.get_not_found:
    mov x0, #0
    mov x1, #0
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// db_delete: Delete a record by ID
// Input: x0 = record ID
// Output: x0 = 0 on success, -1 on failure
db_delete:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov w19, w0              // target ID

    // Search records array
    ldr x20, =db_records
    mov w21, #0              // index
.delete_search:
    cmp w21, #DB_MAX_RECORDS
    b.ge .delete_not_found

    ldr x22, [x20, x21, lsl #3]
    cbz x22, .delete_next

    // Check if ID matches
    ldr w0, [x22, #REC_ID]
    cmp w0, w19
    b.eq .delete_found

.delete_next:
    add w21, w21, #1
    b .delete_search

.delete_found:
    // Clear slot in array
    str xzr, [x20, x21, lsl #3]

    // Free the memory block
    mov x0, x22
    bl mem_free

    // Decrement record count
    ldr x0, =db_record_count
    ldr w1, [x0]
    sub w1, w1, #1
    str w1, [x0]

    mov x0, #0
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.delete_not_found:
    mov x0, #-1
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// db_list: Iterate over all records
// Input: x0 = callback function pointer
//        x1 = user context (passed to callback as x2)
// Callback signature: callback(x0 = id, x1 = data_ptr, x2 = data_size, x3 = context)
// If callback returns non-zero, iteration stops
db_list:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0              // callback
    mov x20, x1              // user context

    ldr x21, =db_records
    mov w22, #0              // index

.list_loop:
    cmp w22, #DB_MAX_RECORDS
    b.ge .list_done

    ldr x23, [x21, x22, lsl #3]
    cbz x23, .list_next

    // Call callback with record info
    ldr w0, [x23, #REC_ID]   // id
    add x1, x23, #REC_DATA   // data pointer
    ldr w2, [x23, #REC_SIZE] // data size
    mov x3, x20              // context

    blr x19

    // Check if callback wants to stop
    cbnz x0, .list_done

.list_next:
    add w22, w22, #1
    b .list_loop

.list_done:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// db_count: Get the number of records
// Output: x0 = record count
db_count:
    ldr x0, =db_record_count
    ldr w0, [x0]
    ret

//=============================================================================
// Data
//=============================================================================

.section .bss
.balign 4
db_next_id:
    .skip 4

.balign 4
db_record_count:
    .skip 4

.balign 8
db_records:
    .skip 8 * DB_MAX_RECORDS
