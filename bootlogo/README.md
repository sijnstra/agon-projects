# bootlogo
This is a MOSlet to show an Agon boot logo including screen capabilities. It's written in 24-bit ADL mode and designed to be used only as a MOSlet. The code is a repurposed and re-written version of [Steve Lovejoy's Agon BBCBASIC logo header](https://github.com/The-8bit-Noob/AGON_BASIC_HEADER/).

# usage
Copy `bootlogo.bin` into your `/mos` then add `bootlogo` to the end of your `autoexec.txt`, and the software will display the current screen capabilities next to the Agon logo.

You can specify *any* parameter to suppress the colour bars. e.g. `bootlogo -` will show the logo except for the colour bars.

The software also takes advantage of user-defined fonts to display the logo, and now resets the font at the end.

Recommended minimum version of VDP to support the codes that are used is Console8 VDP 2.4.0.

## Example screens:
![bootlogo run in autoexec with defaults](bootlogo_autoexec.PNG)

![bootlogo from command line in mode 3](bootlogo_mode3.PNG)

# Source code
Source code is provided. The code can be compiled natively using `ez80asm`.

Notable VDP inclusions in the source code are:
<li>Programming characters for the purpose of displaying the logo.</li>
<li>Resetting the programmed characters back to default, including a special code to wait to draw the screen properly before the reset. This extra code prevents a race condition where the font is dropped before it has finished drawing the characters that use it.</li>
<li>Preserving the text colour setting by reading the current colour, storing it, and then checking against each colour in the palette for the matching colour.</li>
