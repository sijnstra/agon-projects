# OSbootZ
A tool to boot up Zeal-OS, also runs from the `/mos` directory. Only a binary is available at the moment. Source may be released in future. The second optional parameter loads a 64k ZealFS image into memory at `0x090000`, which can be saved again upon reboot using [`memsave`](https://github.com/sijnstra/agon-projects/edit/main/memsave/). This means you can import and export files into ZealOS.

# Build Notes
when you build the Agon version of [ZealOS binary](https://github.com/sijnstra/Zeal-8-bit-OS) you'll need to use the build that includes the romdisk, by default called `os_with_romdisk.img`. The romdisk loads into memory in the 64k page immediately after the operating system.

ZealOS 8bit is designed got the z80, and was originally written for the ZealOS 8bit hardware, using a z80 as the CPU. The ZealOS hardware also uses a common technique for z80 beased systems to access greater than 64k. This is known as a Memory Management Unit, or MMU for short. It allows other parts of memory to be mapped into the accessible 64k window. The eZ80 has no such feature as it natively handles 24 bit addressing. This means that you cannot switch in 16k memory pages in the same way as the ZealOS hardware, so the no-MMU version is used. This will help you understand the operations when you read the link above.

# Memory map
* `040000-04FFFFh` Zeal OS operating system and working memory
* `050000-05FFFFh` Zeal OS ROMdisk read-only filesystem. Maps to `A:\` and holds the `init.bin` shell
* `090000-09FFFFh` Optional ZealFS based RAMdisk
