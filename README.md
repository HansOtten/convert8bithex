# convert8bithex

Command line version of *Convert 8 bit hex files* (Lazarus GUI V3.1) by Hans Otten.
Converts between BIN, PRG, hex, Intel hex, MOS papertape, TIM papertape,
Motorola S-record, Apple 1 hex and KIM-1 tape files, and can write assembler
define-byte source.

## Build

    fpc -O2 convert8bithex.lpr

Free Pascal 3.2 or later, no Lazarus or LCL needed. This builds on Windows, Linux and macOS.
Line endings follow the platform (CR LF on Windows, LF on Unix), the same as the GUI.

## Usage

    convert8bithex [options] infile outfile

| Option | Meaning |
|---|---|
| `-i, --in FORMAT` | input format (default: from the infile extension) |
| `-o, --out FORMAT` | output format (default: from the outfile extension) |
| `-s, --start ADDR` | hex load address for bin and hex input (default 0000) |
| `-m, --merge` | one output covering all parts, gaps filled |
| `--fill BYTE` | hex fill byte for gaps with `-m` (default FF) |
| `-k, --tapeid ID` | hex KIM-1 tape ID for kim output (default 00) |
| `-d, --define TEXT` | directive for define output (default `.byte $`) |
| `-y, --yes` | overwrite existing output files |
| `-q, --quiet` | only report errors |
| `-h, --help` / `-V, --version` | help / version |

Formats and extensions:

| Format | Extensions | Notes |
|---|---|---|
| `bin` | .bin .rom | no address, use `-s` |
| `prg` | .prg | first two bytes are the load address (low, high) |
| `hex` | .hex | two hex digits per byte, no address, use `-s` |
| `ihex` | .ihex .ihx | Intel hex |
| `mos` | .ptp .pap | MOS / KIM-1 papertape |
| `tim` | .tim | TIM papertape |
| `srec` | .srec .s19 .mot | Motorola S1/S5/S9 |
| `apple1` | .ahex | Apple 1 monitor format |
| `kim` | .tap | KIM-1 tape file with ID |
| `define` | .asm | output only |

Exit codes: 0 ok, 1 command line error, 2 load error, 3 save error.

## Multipart files

Intel hex, papertape, S-record and Apple 1 files can hold several address
ranges. Each contiguous range is loaded as a part (maximum 64).

* **Split (default).** Output to `bin`, `prg`, `hex`, `apple1` or `kim` gives one file per
  part, with the start address appended to the name:

      convert8bithex monitor.ihex monitor.bin
        -> monitor0200.bin  monitor1000.bin

  Each PRG part gets its own load address as its header. KIM tape IDs count up from `-k`.
* **Merge (`-m`).** One file from the lowest to the highest address, with gaps set to
  the `--fill` byte. This works for every output format:

      convert8bithex -m --fill 00 monitor.ihex monitor.bin

Formats that hold addresses themselves (`ihex`, `mos`, `tim`, `srec`) write all
parts into one file even without `-m`.

## Examples

    convert8bithex kb9.tap kb9.ptp
    convert8bithex -s E000 rom.bin rom.srec
    convert8bithex -o define -d ".byte $" rom.bin rom.asm
    convert8bithex -i mos -o ihex tape.txt tape.ihex

## Source files

* `convert8bithex.lpr` command line handling, merge, reporting
* `hexglobals.pas` shared buffers and state (the non-GUI part of the old `mainconvert`)
* `loadhexformats.pas`, `savehexformats.pas` the format units from the GUI,
  now with `uses hexglobals` and the fixes below

### Fixes in the format units (they also apply to the GUI)

* S-record save dropped the last byte when a part's size was 16n+1.
* KIM tape load read one byte more than the save writes, so it could not reload its own .tap files.
* Apple 1 save wrote an address line with nothing after it at the end of a part, which broke at FFFF.
* PRG save wrote part 1's address as the header of every part.

The GUI also took the PRG header, the S9 address and the define header from the
start address field, not from the loaded data. The command line version uses the
start of the loaded data instead.

MIT License, Copyright (c) 2019-2026 Hans Otten
