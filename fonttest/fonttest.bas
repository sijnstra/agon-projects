10 GOSUB 8000 : REM Print test message
20 FONT = 1 : REM set font number we will use for reverse text
30 GOSUB 1100 : REM copy system font into the buffer FONT
40 GOSUB 1200 : REM reverse the bitmaps in the font
50 GOSUB 1000 : REM set FONT as the current font
60 GOSUB 8000 : REM Print test message
100 FONT = 2 : REM set font number we will use for underlined text
110 GOSUB 1100 : REM copy system font into the buffer FONT
120 GOSUB 1300 : REM manipulate the bitmaps in the font to create underline
130 GOSUB 1000 : REM set FONT as the current fon
140 GOSUB 8000 : REM Print test message
200 FONT = 3 : REM set font number we will use for both underlined and reverse text
210 GOSUB 1100 : REM copy system font into the buffer FONT
220 GOSUB 1300 : REM manipulate the bitmaps in the font to create underline
230 GOSUB 1200 : REM reverse the bitmaps in the font. Could also be done in a single step.
240 GOSUB 1000 : REM set FONT as the current fon
250 GOSUB 8000 : REM Print test message
300 FONT = 1 : REM set the font back to reverse text
310 GOSUB 1000 : REM set FONT as the current fon
320 GOSUB 8000 : REM Print test message
500 FONT = -1 : GOSUB 1000
510 PRINT : PRINT"Font testing with ";: FONT = 2 : GOSUB 1000 : PRINT "underline";
520 FONT = -1 : GOSUB 1000
530 PRINT " ";: FONT = 1 : GOSUB 1000 : PRINT "and reverse";
540 FONT = -1 : GOSUB 1000
550 PRINT " ";: FONT = 3 : GOSUB 1000 : PRINT "and also both"
990 FONT = -1
995 GOSUB 1000
999 END
1000 REM VDU 23, 0, &95, 0, bufferId; flags: Select font
1010 VDU 23, 0, &95, 0, FONT; 0
1020 RETURN
1100 REM VDU 23, 0, &95, 5, bufferId;: Copy system font to buffer
1110 VDU 23, 0, &95, 5, FONT;
1120 RETURN
1200 REM VDU 23, 0, &A0, bufferId; 5, operation, offset; [count;] <operand>, [arguments]
1210 VDU 23, 0, &A0, FONT; 5, &40, 0; 256*8;
1220 REM &40 is NOT operation with count being number of bytes to process
1230 RETURN
1300 REM VDU 23, 0, &A0, bufferId; 5, operation, offset; [count;] <operand>, [arguments]
1310 VDU 23, 0, &A0, FONT; 5, &C7, 0; 8*255;
1320 REM &80 is multi-byte operation with count being number of bytes to process which matches the number of bytes sent
1330 FOR I = 0 TO 254 : VDU 0, 0, 0, 0, 0, 0, 0, 255 : NEXT
1340 RETURN
2000 REM VDU 23, 0, &C3: Swap the screen buffer and/or wait for VSYNC **
2010 VDU 23, 0, &C3
2020 RETURN
8000 PRINT "TESTING lazy testing _12345!@#$%qg"; : REM test message to include descending characters
8010 RETURN
