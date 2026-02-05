#!/bin/bash
qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -nographic \
    -kernel kernel.elf
