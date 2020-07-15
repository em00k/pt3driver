; ***************************************************************************
; * Simple example NextZXOS driver file                                     *
; ***************************************************************************
;
; This file generates the actual border.drv file which can be installed or
; uninstalled using the .install/.uninstall commands.
;
; The driver itself (border.asm) must first be built.
;
; Assemble this file with: pasmo border_drv.asm border.drv


; ***************************************************************************
; * Definitions                                                             *
; ***************************************************************************
; Pull in the symbol file for the driver itself and calculate the number of
; relocations used.
		device zxspectrumnext
		output pt3player.drv
		
        include "player.sym"

relocs  equ     (reloc_end-reloc_start)/2

; 2158

; ***************************************************************************
; * .DRV file header                                                        *
; ***************************************************************************
; The driver id must be unique, so current documentation on other drivers
; should be sought before deciding upon an id. This example uses $7f as a
; fairly meaningless value. A network driver might want to identify as 'N'
; for example.
begin:
		org     $0000

        defm    "NDRV"          ; .DRV file signature

        defb    $7f+$80         ; 7-bit unique driver id in bits 0..6
                                ; bit 7=1 if to be called on IM1 interrupts

        defb    relocs          ; number of relocation entries (0..255)

        defb    $80+$01         ; number of additional 8K DivMMC RAM banks
                                ; required (0..8); call init/shutdown
        ; NOTE: If bit 7 of the "mmcbanks" value above is set, .INSTALL and
        ;       .UNINSTALL will call your driver's $80 and $81 functions
        ;       to allow you to perform initialisation/shutdown tasks
        ;       (see border.asm for more details)

        defb    0               ; number of additional 8K Spectrum RAM banks
                                ; required (0..200)


; ***************************************************************************
; * Driver binary                                                           *
; ***************************************************************************
; The driver + relocation table should now be included.

        incbin  "pt3player.bin"


; ***************************************************************************
; * Additional bank images and patches                                      *
; ***************************************************************************
; If any 8K DivMMC RAM banks or 8K Spectrum RAM banks were requested, then
; preloaded images and patch lists should be provided.
;
;       First, for each mmcbank requested:
;
;       defb    bnk_patches     ; number of driver patches for this bank id
;       defw    bnk_size        ; size of data to pre-load into bank (0..8192)
;                               ; (remaining space will be erased to zeroes)
;       defs    bnk_size        ; data to pre-load into bank
;       defs    bnk_patches*2   ; for each patch, a 2-byte offset (0..511) in
;                               ; the 512-byte driver to write the bank id to
;       NOTE: The first patch for each mmcbank should never be changed by your
;             driver code, as .uninstall will use the value for deallocating.
;
;       Then, for each zxbank requested:
;
;       defb    bnk_patches     ; number of driver patches for this bank id
;       defw    bnk_size        ; size of data to pre-load into bank (0..8192)
;                               ; (remaining space will be erased to zeroes)
;       defs    bnk_size        ; data to pre-load into bank
;       defs    bnk_patches*2   ; for each patch, a 2-byte offset (0..511) in
;                               ; the 512-byte driver to write the bank id to
;       NOTE: The first patch for each zxbank should never be changed by your
;             driver code, as .uninstall will use the value for deallocating.

; Although our simple driver doesn't actually need any additional memory banks,
; we have requested 1 DivMMC bank and 3 Spectrum RAM banks as an example.

; First, the 1 DivMMC bank that was requested:

        defb    1                       ; 1 patch
        defw    0                       ; no data to be preloaded into this bank
                                        ; (it will be erased to zeroes)
        ; List of patches to be replaced with this bank's id
        defw    bankid_mmc0             ; offset in driver to patch the bank id

; Then the 3 Spectrum RAM banks that were requested:

; First bank:
        defb    1                       ; 1 patch
        defw    b0data_end-b0data       ; size of preload data

        ; The actual preloaded data follows (the remainder of the 8K bank will
        ; be erased to zeroes)
b0data:
        ;defs    800,$aa                 ; 800 bytes filled with $AA
        defm    "pt3driver by em00k"
        ;defs    20,$55                  ; 20 bytes filled with $55
		;incbin "
b0data_end:
        ; List of patches to be replaced with this bank's id
        defw    bankid_zx0              ; offset in driver to patch the bank id

; Second bank:
        defb    1                       ; 1 patch
        defw    0                       ; no data to be preloaded into this bank
                                        ; (it will be erased to zeroes)
        ; List of patches to be replaced with this bank's id
        defw    bankid_zx1              ; offset in driver to patch the bank id

; Third bank:
        defb    1                       ; 1 patch
        defw    b2data_end-b2data       ; size of preload data

        ; The actual preloaded data follows (the remainder of the 8K bank will
        ; be erased to zeroes)
b2data:
        defm    "test"
b2data_end:
        ; List of patches to be replaced with this bank's id
        defw    bankid_zx2              ; offset in driver to patch the bank id
drviverend:
		savebin "h:\mcgtest\pt3player.drv",begin,drviverend-begin

