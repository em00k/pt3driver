# pt3driver
pt3 driver for NextZXOS

v1.1 fixed banking issue

a pt3 driver for NextZXOS

Readme from release:

pt3drive for NextZXOS - emk2020 / DMS
-------------------------------------

This driver can playback a pt3 file 
while running basic. The bank that is 
always used is basic bank 20. First
the player is loaded, than you load 
your tune in at an offset of 2158.
You will need to supply the length of 
the pt3.  

10 load "player" bank 20 
20 load "tune.pt3 bank 20,2158,[length]

Once done you can initalise the music

.install pt3player.drv 

The music will begin to play. You can
stop the music with 

.uninstall pt3player.drv 

This shouldn't intefere with basic as long
as you dont use bank 20 :)

enjoy
