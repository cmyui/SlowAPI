// Slab Allocator Unit Tests

.section .text
.global run_slab_tests

run_slab_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_alloc_returns_nonzero
    bl test_alloc_returns_aligned
    bl test_alloc_zeroes_memory
    bl test_free_and_realloc
    bl test_alloc_too_large_fails
    bl test_multiple_allocs_distinct

    ldp x29, x30, [sp], #16
    ret

// Test: Basic allocation returns non-null
test_alloc_returns_nonzero:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init

    mov x0, #64
    bl mem_alloc

    ldr x1, =name_alloc_nonzero
    bl test_assert_nonzero

    ldp x29, x30, [sp], #16
    ret

// Test: Allocation returns 8-byte aligned pointer
test_alloc_returns_aligned:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init

    mov x0, #64
    bl mem_alloc

    // Check alignment (low 3 bits should be 0)
    and x0, x0, #7
    mov x1, #0
    ldr x2, =name_alloc_aligned
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Allocated memory is zeroed
test_alloc_zeroes_memory:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init

    mov x0, #64
    bl mem_alloc
    mov x19, x0

    // Check first 8 bytes are zero
    ldr x0, [x19]
    mov x1, #0
    ldr x2, =name_alloc_zeroed
    bl test_assert_eq

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: Free then realloc returns same block
test_free_and_realloc:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init

    // Allocate
    mov x0, #64
    bl mem_alloc
    mov x19, x0

    // Free
    mov x0, x19
    bl mem_free

    // Reallocate - should get same block back
    mov x0, #64
    bl mem_alloc
    mov x20, x0

    mov x0, x19
    mov x1, x20
    ldr x2, =name_realloc_same
    bl test_assert_eq

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Test: Allocation larger than block size fails
test_alloc_too_large_fails:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init

    // Try to allocate 256 bytes (block size is 128)
    mov x0, #256
    bl mem_alloc

    mov x1, #0
    ldr x2, =name_alloc_too_large
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Multiple allocations return distinct pointers
test_multiple_allocs_distinct:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl mem_init

    mov x0, #64
    bl mem_alloc
    mov x19, x0

    mov x0, #64
    bl mem_alloc
    mov x20, x0

    // Should be different
    mov x0, x19
    mov x1, x20
    ldr x2, =name_allocs_distinct
    bl test_assert_neq

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Test Data
//=============================================================================

.section .rodata
section_name:
    .asciz "slab allocator"

name_alloc_nonzero:
    .asciz "mem_alloc returns non-null"
name_alloc_aligned:
    .asciz "mem_alloc returns aligned pointer"
name_alloc_zeroed:
    .asciz "allocated memory is zeroed"
name_realloc_same:
    .asciz "free then alloc returns same block"
name_alloc_too_large:
    .asciz "alloc > block size returns null"
name_allocs_distinct:
    .asciz "multiple allocs return distinct ptrs"
