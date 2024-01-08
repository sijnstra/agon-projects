# charIOh

Usage: `charioh`

charIOh is a CHARacter I/O - Hex demonstration `mos` utility to demonstrate terminal mode entry and exit, and provide a simple test for showing the hex values for input keys except:
<li>Escape is captured and shown as an 'e', with the following 2 characters displayed literally. This is mainly to show what arrow keys and function keys return.</li>
<li>CTRL-C is used to exit.</li>

Note: Graceful exit requires Console8 vdp 2.2.1 or above. This cannot gracefully exit with MOS vdp 1.0.4 or lower as there is no exit from terminal on those version.

Works from the `/mos` directory.

This was built using the ZDSII development environment from Zilog, along with a `hex2bin` tool. The binary executable is in the `Release` directory.
