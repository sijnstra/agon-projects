# OSbootZ
A tool to boot up Zeal-OS, also runs from the `/mos` directory. Only a binary is available at the moment. Source may be released in future. The second optional parameter loads a 64k ZealFS image into memory at `0x090000`, which can be saved again upon reboot using [`memsave`](https://github.com/sijnstra/agon-projects/edit/main/memsave/). This means you can import and export files into ZealOS.

Note: when you build the Agon version of [ZealOS binary](https://github.com/sijnstra/Zeal-8-bit-OS) you'll need to use the build that includes the romdisk, by default called `os_with_romdisk.img`.
