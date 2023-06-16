# hexdump

Usage: `hexdump [-c] <file>`

A simple `mos` utility to dump the content of any file, with columns showing file location, hex contents and printable characters.

The default is now pages mode, allowing you to page forward and backward through the file. The option `-c` enables continuous mode, dumping the contents continuously to the display. In continuous mode `CTRL-C`, `ESC` or `q` will exit if needed.

![hexdump screenshot](hexdump.PNG)
