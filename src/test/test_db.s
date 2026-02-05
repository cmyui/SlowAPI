// Database Layer Unit Tests

.section .text
.global run_db_tests

run_db_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_db_create_returns_id
    bl test_db_get_returns_data
    bl test_db_count_increments
    bl test_db_delete_removes_record
    bl test_db_get_not_found

    ldp x29, x30, [sp], #16
    ret

// Test: db_create returns positive ID
test_db_create_returns_id:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init
    bl db_init

    ldr x0, =test_record
    mov x1, #8
    bl db_create

    // ID should be >= 1
    cmp x0, #1
    cset x0, ge
    mov x1, #1
    ldr x2, =name_create_id
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: db_get retrieves stored data
test_db_get_returns_data:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init
    bl db_init

    // Create record
    ldr x0, =test_record
    mov x1, #8
    bl db_create
    mov w19, w0              // save ID

    // Get record
    mov w0, w19
    bl db_get
    mov x20, x0              // data ptr

    // Check data ptr is non-null
    mov x0, x20
    ldr x1, =name_get_data
    bl test_assert_nonzero

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: db_count increments after create
test_db_count_increments:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init
    bl db_init

    // Get initial count
    bl db_count
    mov w19, w0

    // Create record
    ldr x0, =test_record
    mov x1, #8
    bl db_create

    // Get new count
    bl db_count

    // Should be initial + 1
    add w1, w19, #1
    ldr x2, =name_count_inc
    bl test_assert_eq

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: db_delete removes record
test_db_delete_removes_record:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init
    bl db_init

    // Create record
    ldr x0, =test_record
    mov x1, #8
    bl db_create
    mov w19, w0              // save ID

    // Delete record
    mov w0, w19
    bl db_delete

    // Should return 0 (success)
    mov x1, #0
    ldr x2, =name_delete_ok
    bl test_assert_eq

    // Try to get deleted record
    mov w0, w19
    bl db_get

    // Should return null
    mov x1, #0
    ldr x2, =name_delete_gone
    bl test_assert_eq

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: db_get returns null for non-existent ID
test_db_get_not_found:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init
    bl db_init

    // Try to get ID 9999
    mov w0, #9999
    bl db_get

    mov x1, #0
    ldr x2, =name_get_notfound
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Test Data
//=============================================================================

.section .rodata
section_name:
    .asciz "database"

name_create_id:
    .asciz "db_create returns positive ID"
name_get_data:
    .asciz "db_get returns data pointer"
name_count_inc:
    .asciz "db_count increments after create"
name_delete_ok:
    .asciz "db_delete returns success"
name_delete_gone:
    .asciz "deleted record is not found"
name_get_notfound:
    .asciz "db_get returns null for bad ID"

test_record:
    .ascii "testdata"
