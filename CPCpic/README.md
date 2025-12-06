# CPCpic
Loads a CPC palette file and Screen file and displays it as it would have loaded in an interleaved wipe fashion. Only supports Mode 0. Supports with and without the AMS-DOS header, detected by file length. No checks are made for validity of file contents.

You can assemble using `ez80asm CPCpic.asm` or download your the pre-built binary `CPCpic.bin`.

# Usage
`CPCpic [file.PAL] [file.SCR] [1-9]` where it requires both a palette file `[file.PAL]` and the screen image file `[file.SCR]`

The 1-9 is a single digit optional additional parameter to wait 1-9 seconds before exiting automatically. A keypress will still exit early. Without this parameter it will simply wait for a keypress.

Works in either /mos or /bin directory. Minimum VDP version 2.3.0.

`clown0.pal` and `clown0.scr` are provided for testing.

