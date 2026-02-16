## Tiny Basic for the Z80

This is the Tiny Basic port done by [Doug Gabbard](http://retrodepot.net/) for the Z80.  Tiny Basic was developed by Palo Alto, written by Dr Li-Chen Wang in 1976.

I've taken the version for the [TEC-1F written by Brian Chiha](https://github.com/bchiha/Tiny-Basic-Z80) as he has corrected some minor errors and, and converted to a MOSlet. I've minimized the changes to keep it faithful to the original rommable version.

Refer to the attached PDF for a full documentation.

Summary of the changes:
* Reduced memory footprint to fit within 32k
* Changed the backspace to visually backspace instead of printing a slash
* STOP exits TinyBASIC
* Minor tweaks to make it assemble in ez80ASM
* Additional wrapper and loader added to allow it to load under MOS while remaining sympathetic to the original. This means the header section will look unusual.
* Computer specific routines set up for Agon
