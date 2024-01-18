# unzip

Usage: <br>
`load unzip.bin`<br>
`run . {dir/}gzipfile {*}`<br>
optional: run multiple times without needing to re-load unzip.bin

If a destination is given, all files are extracted including directory structure.

NOTES:
<li>Spaces are not supported well in file or directory names. To avoid issues, spaces are converted to underscores.</li>
<li>File and directory path lengths are limited to a maximum of 255 characters.</li>

If not, files is checked for CRC

IMPORTANT: does NOT work as MOSlet due to working memory requirements.

Original unzipping core algorithms based on https://github.com/agn453/UNZIP-CPM-Z80 
