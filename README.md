# SlowAPI

A bare-metal ARM64 HTTP server written entirely in assembly, running on QEMU
with no OS, no C runtime, and no standard library. Implements a full network
stack from Ethernet frames up through a web framework with JSON responses.

~5700 lines of ARM64 assembly (~9200 including tests and benchmarks).

## Architecture

```
Application (app.s)
    Hotel CRUD API endpoints
        |
SlowAPI Framework (slowapi/)
    Route matching, HTTP parsing, JSON builder, response builder
        |
TCP/IP Stack (net/)
    TCP state machine, IPv4, ARP, Ethernet
        |
Device Drivers (drivers/)
    Virtio-net (MMIO), PL011 UART, ARM64 timer
        |
Hardware (QEMU virt, Cortex-A72)
```

Everything is written from scratch: memory allocator, network stack, web
framework, database, JSON serialization.

### Components

| Directory | What it does |
|---|---|
| `src/drivers/` | PL011 UART, virtio-net device driver, ARM64 generic timer |
| `src/net/` | Ethernet, ARP, IPv4 (with checksum), TCP (full state machine on port 80) |
| `src/mem/` | Slab allocator (64 blocks x 128 bytes, bitmap-tracked) |
| `src/db/` | In-memory record store with auto-increment IDs |
| `src/slowapi/` | Web framework: route macros, HTTP parser, router with path params, JSON builder, response builder, query string parser |
| `src/app.s` | Application endpoints (Hotel CRUD API) |
| `src/boot.s` | Entry point: stack setup, driver init, main polling loop |
| `src/test/` | Unit tests for every layer (10 test modules) |
| `src/bench/` | Cycle-counted benchmarks for core operations |

### SlowAPI

Routes are defined with an `ENDPOINT` macro that places entries into a linker
section, building the route table at link time:

```asm
ENDPOINT METHOD_GET, "/api/hotels"
handler_list_hotels:
    FRAME_ENTER 1, 128
    // ... build JSON response ...
    FRAME_LEAVE
    ret
```

The router supports parameterized paths (`/api/hotels/{id}`) with automatic
extraction into the request context.

## Prerequisites

```bash
# ARM64 bare-metal toolchain
brew install --cask gcc-aarch64-embedded

# QEMU
brew install qemu
```

## Build & Run

```bash
make          # build kernel.elf
make run      # boot in QEMU, HTTP server on localhost:8888
make test     # run unit tests
make bench    # run benchmarks
make clean    # remove build artifacts
```

The server listens on port 80 inside QEMU, forwarded to `localhost:8888`:

```bash
# In another terminal
curl http://localhost:8888/
curl http://localhost:8888/api/hotels
curl -X POST -d "Hilton,Toronto" http://localhost:8888/api/hotels
curl http://localhost:8888/api/hotels/1
curl -X DELETE http://localhost:8888/api/hotels/1
```

Exit QEMU with `Ctrl-A X`.
