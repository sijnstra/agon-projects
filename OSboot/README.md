# OSboot
This tool is to boot up [TRS-OS](https://danielpaulmartin.com/home/research/). It only runs from the `/mos` directory. Only a binary is available at the moment. Source may be released in future.

TRS-OS was designed and built by Danial Paul Martin as a way to run LS-DOS on modern (eZ80) based hardware, and is made available on Agon by a combination of Daniel's work on TRS-OS development along with my development of this loader. You can download the [TRS-OS binary via here](https://danielpaulmartin.com/how%20do%20i%20get/).

It is *highly* recommended that you update your VDP to include ADDS25 terminal emulation. At time of writing, this has not been merged into the main branch and required VDP files from [here](https://github.com/sijnstra/vdp-gl).

# Usage
`OSboot [-X] <binaryfile> [diskfile]`

The first optional parameter specifies the colour: `-1` (red) ... `-7` (white). Default is `-2` (green).

The `<binaryfile>` is the TRS-OS binary, downloaded using the link above.

The third optional parameter loads a virtual disk image into memory at `0x45300`, in JV1 or DiskDISK format, up to 200K in size. The image can be saved again upon reboot using [`memsave`](https://github.com/sijnstra/agon-projects/edit/main/memsave/). This means you can import and export files into TRS-OS.
