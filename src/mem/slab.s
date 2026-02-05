// Slab Allocator
// Fixed-size block allocator for dynamic memory management

.section .text
.global mem_init
.global mem_alloc
.global mem_free

// Configuration
.equ SLAB_BLOCK_SIZE, 128
.equ SLAB_NUM_BLOCKS, 64
.equ SLAB_BITMAP_SIZE, (SLAB_NUM_BLOCKS + 7) / 8  // 8 bytes for 64 blocks

// mem_init: Initialize the slab allocator
// Clears the bitmap to mark all blocks as free
mem_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Clear the bitmap (all blocks free = 0)
    ldr x0, =slab_bitmap
    mov x1, #SLAB_BITMAP_SIZE
    mov w2, #0
.clear_bitmap:
    cbz x1, .init_done
    strb w2, [x0], #1
    sub x1, x1, #1
    b .clear_bitmap

.init_done:
    ldp x29, x30, [sp], #16
    ret

// mem_alloc: Allocate a block of memory
// Input: x0 = size (must be <= SLAB_BLOCK_SIZE)
// Output: x0 = pointer to allocated block, or 0 if allocation failed
mem_alloc:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    // Check if requested size fits in a block
    cmp x0, #SLAB_BLOCK_SIZE
    b.gt .alloc_fail

    // Search bitmap for a free block
    ldr x19, =slab_bitmap
    mov w20, #0              // byte index
    mov w21, #SLAB_BITMAP_SIZE

.search_byte:
    cmp w20, w21
    b.ge .alloc_fail

    // Load bitmap byte
    ldrb w22, [x19, x20]

    // Check if any bit is free (0) in this byte
    cmp w22, #0xFF
    b.eq .next_byte

    // Find first free bit in this byte
    mov w1, #0               // bit index
.search_bit:
    cmp w1, #8
    b.ge .next_byte

    // Check if bit is free
    mov w2, #1
    lsl w2, w2, w1
    tst w22, w2
    b.ne .next_bit

    // Found free block! Mark it as allocated
    orr w22, w22, w2
    strb w22, [x19, x20]

    // Calculate block address
    // block_index = byte_index * 8 + bit_index
    lsl w3, w20, #3          // byte_index * 8
    add w3, w3, w1           // + bit_index

    // block_address = slab_pool + block_index * SLAB_BLOCK_SIZE
    ldr x0, =slab_pool
    mov w4, #SLAB_BLOCK_SIZE
    mul w3, w3, w4
    add x0, x0, x3

    // Zero out the block
    mov x4, x0
    mov w5, #SLAB_BLOCK_SIZE
.zero_block:
    cbz w5, .alloc_done
    strb wzr, [x4], #1
    sub w5, w5, #1
    b .zero_block

.alloc_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.next_bit:
    add w1, w1, #1
    b .search_bit

.next_byte:
    add w20, w20, #1
    b .search_byte

.alloc_fail:
    mov x0, #0
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// mem_free: Free an allocated block
// Input: x0 = pointer to block to free
// Returns: nothing (silently ignores invalid pointers)
mem_free:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // Validate pointer is within slab_pool
    ldr x19, =slab_pool
    cmp x0, x19
    b.lt .free_invalid

    // Check upper bound
    mov x1, #SLAB_BLOCK_SIZE * SLAB_NUM_BLOCKS
    add x1, x19, x1
    cmp x0, x1
    b.ge .free_invalid

    // Calculate block index
    sub x0, x0, x19          // offset from pool start
    mov x1, #SLAB_BLOCK_SIZE
    udiv x20, x0, x1         // block index

    // Check alignment (offset should be multiple of block size)
    msub x2, x20, x1, x0
    cbnz x2, .free_invalid

    // Calculate bitmap position
    // byte_index = block_index / 8
    // bit_index = block_index % 8
    lsr w1, w20, #3          // byte_index
    and w2, w20, #7          // bit_index

    // Clear the bit
    ldr x3, =slab_bitmap
    ldrb w4, [x3, x1]
    mov w5, #1
    lsl w5, w5, w2
    bic w4, w4, w5
    strb w4, [x3, x1]

.free_invalid:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Data
//=============================================================================

.section .bss
.balign 8
slab_pool:
    .skip SLAB_BLOCK_SIZE * SLAB_NUM_BLOCKS   // 8KB pool

.balign 8
slab_bitmap:
    .skip SLAB_BITMAP_SIZE                     // 8 bytes (64 bits for 64 blocks)
