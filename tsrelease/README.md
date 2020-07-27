
Simple 6 channel PT3 player driver for NextBasic

ts player (c)2004-2007 s.v.bulba

Load the "tsplayer" into Bank 20

Save out your 5 channel song as two seperate pt3 files in Vortex Tracker

Load 1.pt3 into BANK 20, offset 3109
Load 2.ot3 into BANK 20, offset 8192

Install the driver to play music.


#program tstest
   3 RUN AT 3: CLS 
   
  10 PRINT "6ch PT3 driver"
  
  20 PRINT "Load in tsplayer to bank 20"
  
  21 PRINT ''"Then save your TS PT3 from Vortex as 2 seperate pt3 files"
  
  22 PRINT "Load 1.pt3 > Bank 20,offset 3109"
  
  23 PRINT "Load 2.pt3 > Bank 20,offset 8192"''"Then install the driver"
  
  30 LOAD "tsplayer" BANK 20: LOAD "Monster1.pt3" BANK 20, 3109, 3580
  
  31 LOAD "Monster2.pt3" BANK 20,8192,1365
  
  40  .install tsplayer.drv: ; Play song                       
  
  50 LET s$="                 playing 6ch pt3 monster by em00k (orginal amiga mod by tip) ......"
  
  60 LET s$=s$(2 TO LEN s$)+s$(1)
  
  70 PRINT AT 10,0;s$( TO 31)
  
  80 IF INKEY$ ="" THEN PAUSE 5: GO TO 60 
  
 200  .uninstall tsplayer.drv : STOP : ; Stop song, end prog.     
 
9998 STOP 

9999 RUN AT 3: REMOUNT : SAVE "tstest.bas"


