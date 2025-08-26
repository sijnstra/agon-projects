# CPCpic
Loads a CPC palette file and Screen file and displays it as it would have loaded in an interleaved wipe fashion. Only supports Mode 0. Supports with and without the AMS-DOS header, detected by file length. No checks are made for validity of file contents.

You can assemble using `ez80asm CPCpic.asm` or download your the pre-built binary `CPCpic.bin`.

# Usage
`CPCpic [file.PAL] [file.SCR]` where it requires both a palette file `[file.PAL]` and the screen image file `[file.SCR]`

Works in either /mos or /bin directory. Minimum VDP version 2.3.0.

`clown0.pal` and `clown0.scr` are provided for testing.

