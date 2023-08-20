# memsave

Usage: `memsave <file> <start> <length>`

A general `mos` utility to dump the content of memory into a file. Both `<start>` and `<length>` are in hex, and are 24 bit. i.e. you need to specify where in the full eZ80 memory space you wish to save.

Note that the utility runs at the absolute address of `0x0B000` which means it needs to run from the `mos` directory, and will overwrite the space it takes up before it can save the content.

