# logoplay

Assets and an example `obey` file (also works with `exec`) to run are in the c8logo directory. The logoplay17.bin needs to be in the /mos directory for this to work.

This requires at least MOS 2 for `exec` or MOS 3 for `obey` and requires version 2.10.0 or later for the VDP for the graphics and sound to work.

Please note: The loose notes below are draft, and not intended to be full notes. I intend to improve the detail on this at a later date.

# Asset creation
The original video was downloaded from [[https://heber.co.uk/agon-cosole8/]]

## Audio
Audio was extracted using OpenShot Video Editor.

I used WSL2 running Ubuntu Linux to convert the audio file with `ffmpeg`.

To make the audio file as agon-native as possible, it was created as pcm with Agon defaults:
```bash
ffmpeg -i Console8.wav -ac 1 -f s8 -ar 16384 C8raw.pcm
```

## Video
Frames were extracted from the video as 176x144 at 12fps using OpenShot Video Editor.

Gimp with Batch tool was used to process each frame.

Needed crop -> posterize -> convert to indexed (4) -> save as PCX

Then used linux `cat` to string them all together as a single blob.


# Source code
`logoplay17` is assembled with `ez80asm`
