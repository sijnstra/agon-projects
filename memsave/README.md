# memsave

Usage: `memsave <file> <start> <length>`

A general `mos` utility to dump the content of memory into a file. Both `<start>` and `<length>` are in hex, and are 24 bit. i.e. you need to specify where in the full eZ80 memory space you wish to save.

Note that the utility runs at the absolute address of `0x0B000` which means it needs to run from the `mos` directory, and will overwrite the space it takes up before it can save the content.

# example uses
`memsave zealdisk.zfs 90000 10000` after rebooting to MOS from Zeal8bitOS, assuming it was previously loaded and used, save a 64k ZealFS disk image file from memory to `zealdisk.zfs`
