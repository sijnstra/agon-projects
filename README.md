# agon-projects
Multiple projects for the Agon light. Click through to each project for more detailed instructions. Release versions are in the respective `Release` directories.

# hexdump
This is a mos tool to dump the hex and printable contents of a file for visual examination, allowing easy navigation through the file. Copy `hexdump.bin`
into your `/mos` directory and enjoy!

# hexdumpm
This is a mos tool to dump the hex and printable contents of memory for visual examination, allowing easy navigation through memory. Copy `hexdumpm.bin`
into your `/mos` directory and enjoy!

# memsave
A general tool to dump memory to a file. Note that this utility is built to run at 0x0B0000, so it will need to be run from the mos directory and will overwrite that address. Copy `memsave.bin` into your `/mos` directory and enjoy!

# strings
This is a minimal implementation of the *nix strings utility, allowing the user to search through a binary file for strings of a minimum length (specified in the command line). It demonstrates the use of the MOScalls `mos_fgetc` and `mos_feof`.
The binary is included in the strings/Release directory. Copy `strings.bin` into your `/mos` directory and enjoy!
