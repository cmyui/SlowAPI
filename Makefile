# ARM64 bare-metal toolchain
AS = aarch64-none-elf-as
LD = aarch64-none-elf-ld
OBJCOPY = aarch64-none-elf-objcopy

# Output files
KERNEL_ELF = kernel.elf
KERNEL_BIN = kernel.bin

# Source files
SRCS = src/boot.s src/uart.s
OBJS = $(SRCS:.s=.o)

# Flags
ASFLAGS = -g
LDFLAGS = -T linker.ld -nostdlib

.PHONY: all clean run

all: $(KERNEL_ELF)

$(KERNEL_ELF): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJS) $(KERNEL_ELF) $(KERNEL_BIN)

run: $(KERNEL_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(KERNEL_ELF)
