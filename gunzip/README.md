# gunzip

Usage: <br>
`load gunzip.bin`<br>
`run . {dir/}gzipfile {dir/destfile}`<br>
optional: run multiple times without needing to re-load gunzip.bin

If a destination is given, files are extracted (equivalent to gzip -dv)

If not, files is checked and header shown (equivalent to gzip -tv)

Note: does NOT work as MOSlet due to working memory requirements.
