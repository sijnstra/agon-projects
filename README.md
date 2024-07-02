# agon-projects
Multiple projects for the Agon light. Click through to each project for more detailed instructions. Release versions are in the respective `Release` directories.

# 2048
[2048.bin](https://github.com/sijnstra/agon-projects/tree/main/2048) is a port of the popular game 2048, including source. Copy `ansiplay.bin` into your `/mos` (or bin) directory and enjoy!

# ANSIplay
[ansiplay.bin](https://github.com/sijnstra/agon-projects/tree/main/ANSIplay) is a mos tool that plays `.ANS` format ANSI text files, including displaying any available metadata. Copy `ansiplay.bin` into your `/mos` directory and enjoy!

# bootlogo
[bootlogo.bin](https://github.com/sijnstra/agon-projects/tree/main/bootlogo) is a mos tool that shows the Agon Light logo along with the current screen capabilties. Copy `bootlogo.bin` into your `/mos` then add `bootlogo` to the end of your `autoexec.txt` and enjoy!

# calc24
[calc24.bin](https://github.com/sijnstra/agon-projects/tree/main/calc24) is a mos tool that is intended to provide both a simple 24 bit integer calculator in hex and decimal, working both as a command line or interactive tool. The integer routines may also be useful for other projects. Copy `calc24.bin` into your `/mos` directory ready to use.

# charIO-hex
[charioh.bin](https://github.com/sijnstra/agon-projects/tree/main/charIO-hex) is a mos tool to demonstrate terminal mode, and display the keyboard codes to screen in hex. It should make an easy template to understand terminal mode. Copy `charioh.bin`
into your `/mos` directory and enjoy!

# fonttest
[fonttest.bas](https://github.com/sijnstra/agon-projects/tree/main/fonttest) is a tool to demonstrate the creation of reverse text and underlines text fonts, using more recent Agon/Console8 VDP features for manipulating fonts in buffers. Minimum version of VDP is 2.8.1. The code is heavily commented and written in BBC BASIC.

# gunzip
[gunzip.bin](https://github.com/sijnstra/agon-projects/tree/main/gunzip) allows you to uncompress gzip compressed files natively on Agon MOS. Note that this utility can NOT run as a MOSlet. Copy `gunzip.bin` into your `/` directory and use the `load` and `run` commands to execute. Documentation is included when you `run` without parameters.

# hexdump
[hexdump.bin](https://github.com/sijnstra/agon-projects/tree/main/hexdump) is a mos tool to dump the hex and printable contents of a file for visual examination, allowing easy navigation through the file. Copy `hexdump.bin`
into your `/mos` directory and enjoy!

# hexdumpm
[hexdumpm.bin](https://github.com/sijnstra/agon-projects/tree/main/hexdumpm) is a mos tool to dump the hex and printable contents of memory for visual examination, allowing easy navigation through memory. Copy `hexdumpm.bin`
into your `/mos` directory and enjoy!

# memsave
[memsave.bin](https://github.com/sijnstra/agon-projects/tree/main/memsave) is a general tool to dump memory to a file. Note that this utility is built to run at 0x0B0000, so it will need to be run from the mos directory and will overwrite that address. Copy `memsave.bin` into your `/mos` directory and enjoy!

# OSboot
[OSboot.bin](https://github.com/sijnstra/agon-projects/tree/main/OSboot) tool to boot up [TRS-OS](https://danielpaulmartin.com/home/research/) which in turn opens the door to run well-behaved TRS-80 Model 4 software natively on the Agon. This needs to run from the `/mos` directory. Only a binary is available at the moment. Source may be released in future. There are additional parameters which are explaned when you click through, including selecting colour and an optional disk image. The memory map also allows for import and export of files via this loading method.

# OSbootZ
[OSbootZ.bin](https://github.com/sijnstra/agon-projects/tree/main/OSbootZ) tool to boot up Zeal-OS, also runs from the `/mos` directory. Only a binary is available at the moment. Source may be released in future. The second optional parameter loads a 64k ZealFS image into memory at `0x090000`, which can be saved again upon reboot using `memsave`. This means you can import and export files into ZealOS.

# strings
[strings.bin](https://github.com/sijnstra/agon-projects/tree/main/strings) is a minimal implementation of the *nix strings utility, allowing the user to search through a binary file for strings of a minimum length (specified in the command line). It demonstrates the use of the MOScalls `mos_fgetc` and `mos_feof`.
The binary is included in the strings/Release directory. Copy `strings.bin` into your `/mos` directory and enjoy!

# TRSCOLR
[TRSCLOR/CMD](https://github.com/sijnstra/agon-projects/tree/main/TRSCOLR) is a utility to change text colour from the command line under TRS-OS on the Agon Light computer.

# unzip
[unzip.bin](https://github.com/sijnstra/agon-projects/tree/main/unzip) allows you to uncompress zip compressed file libraries natively on Agon MOS. Note that this utility can NOT run as a MOSlet. Copy `unzip.bin` into your `/` directory and use the `load` and `run` commands to execute. Documentation is included when you `run` without parameters.
