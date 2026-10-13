#!/usr/bin/env python3
"""Print an ELF shared library's machine, NEEDED libraries, SONAME and LOAD
segment alignment (Android needs 16 KiB alignment for 16 KiB page devices).

Usage: python scripts/elf_info.py <lib.so> [...]
"""
import struct
import sys

MACHINES = {3: "x86", 40: "arm", 62: "x86_64", 183: "aarch64"}


def info(path):
    data = open(path, "rb").read()
    if data[:4] != b"\x7fELF":
        return f"{path}: not an ELF file"
    is64 = data[4] == 2
    end = "<" if data[5] == 1 else ">"
    if is64:
        (machine,) = struct.unpack_from(end + "H", data, 18)
        phoff, = struct.unpack_from(end + "Q", data, 32)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 54)
    else:
        (machine,) = struct.unpack_from(end + "H", data, 18)
        phoff, = struct.unpack_from(end + "I", data, 28)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 42)
    loads, dynamic = [], None
    for i in range(phnum):
        off = phoff + i * phentsize
        if is64:
            p_type, _, p_offset, p_vaddr, _, p_filesz, _, p_align = struct.unpack_from(end + "IIQQQQQQ", data, off)
        else:
            p_type, p_offset, p_vaddr, _, p_filesz, _, _, p_align = struct.unpack_from(end + "IIIIIIII", data, off)
        if p_type == 1:
            loads.append(p_align)
        elif p_type == 2:
            dynamic = (p_offset, p_filesz, p_vaddr)
    needed, soname = [], None
    if dynamic:
        entries, strtab = [], None
        fmt, size = (end + "qQ", 16) if is64 else (end + "iI", 8)
        for off in range(dynamic[0], dynamic[0] + dynamic[1], size):
            tag, val = struct.unpack_from(fmt, data, off)
            if tag == 0:
                break
            entries.append((tag, val))
            if tag == 5:
                strtab = val
        # DT_STRTAB is a virtual address; map it through the LOAD segments.
        if strtab is not None:
            for i in range(phnum):
                off = phoff + i * phentsize
                if is64:
                    p_type, _, p_offset, p_vaddr, _, p_filesz, _, _ = struct.unpack_from(end + "IIQQQQQQ", data, off)
                else:
                    p_type, p_offset, p_vaddr, _, p_filesz, _, _, _ = struct.unpack_from(end + "IIIIIIII", data, off)
                if p_type == 1 and p_vaddr <= strtab < p_vaddr + p_filesz:
                    base = strtab - p_vaddr + p_offset
                    break

            def name(v):
                return data[base + v:data.index(b"\0", base + v)].decode()

            needed = [name(v) for t, v in entries if t == 1]
            soname = next((name(v) for t, v in entries if t == 14), None)
    return (f"{path}: {MACHINES.get(machine, machine)}, soname={soname}, "
            f"needed={needed}, load_align={sorted(set(loads))}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(info(p))
