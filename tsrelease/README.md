
Simple 6 channel PT3 player driver for NextBasic

ts player (c)2004-2007 s.v.bulba

- Load the "tsplayer" into Bank 20
- Save out your 6 channel song as two seperate pt3 files in Vortex Tracker
- Load 1.pt3 into BANK 20, offset 3109
- Load 2.pt3 into BANK 20, offset 8192

Install the driver to play music.

```
#program tstest
  10 RUN AT 3: CLS 
  20 PRINT "6ch PT3 driver"
  30 PRINT "Load in tsplayer to bank 20"
  40 PRINT ''"Then save your TS PT3 from Vortex as 2 seperate pt3 files"
  50 PRINT "Load 1.pt3 > Bank 20,offset 3109"
  60 PRINT "Load 2.pt3 > Bank 20,offset 8192"''"Then install the driver"
  70 LOAD "tsplayer" BANK 20: LOAD "Monster1.pt3" BANK 20, 3109, 3580
  80 LOAD "Monster2.pt3" BANK 20,8192,1365
  90  .install tsplayer.drv: ; Play song                                            
 100 LET s$="                 playing 6ch pt3 monster by em00k (orginal amiga mod by tip) ......"
 110 LET s$=s$(2 TO LEN s$)+s$(1)
 120 PRINT AT 10,0;s$( TO 31)
 130 IF INKEY$ ="" THEN PAUSE 5: GO TO %110
 140  .uninstall tsplayer.drv : STOP : ; Stop song, end prog.                        
 150 STOP 
 160 RUN AT 3: REMOUNT : SAVE "tstest.bas">
```


