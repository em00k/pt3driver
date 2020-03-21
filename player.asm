; ***************************************************************************
; * Simple example NextZXOS driver                                          *
; ***************************************************************************
;
; This file is the 512-byte NextZXOS driver itself, plus relocation table.
;
; Assemble with: pasmo border.asm border.bin border.sym
;
; After this, border_drv.asm needs to be built to generate the actual
; driver file.

	device zxspectrumnext 
	
	output "player.bin"
	
musicbank	equ 40	
	
	macro nextreg_nn reg, value
		dw $91ed
		db reg
		db value
	endm	
		macro nextreg_a reg
		dw $92ed
		db reg
	endm

; ***************************************************************************
; * Entry points                                                            *
; ***************************************************************************
; Drivers are a fixed length of 512 bytes (although can have external 8K
; banks allocated to them if required).
;
; They are always assembled at origin $0000 and relocated at installation time.
;
; Your driver always runs with interrupts disabled, and may use any of the
; standard register set (AF,BC,DE,HL). Index registers and alternates must be
; preserved.
;
; No esxDOS hooks or restarts may be used. However, 3 calls are provided
; which drivers may use:
;
;       jp      $2000   ; drv_drvswapmmc
;                       ; Can be used to aid switching between allocated
;                       ; DivMMC banks (see example usage below).
;
;       call    $2003   ; drv_drvrtc
;                       ; Query the RTC. Returns BC=date, DE=time (as M_DATE)
;
;       call    $2006   ; drv_drvapi
;                       ; Access other drivers. Same parameters as M_DRVAPI.
;
; The stack is always located below $4000, so if ZX banks have been allocated
; they may be paged in at any location (MMU2..MMU7).
;
; If using other allocated DivMMC banks, note that the stack location is
; the 224 bytes $260d..$26ec inclusive. Therefore, if you wish to switch to other
; DivMMC banks (in particular using the mechanism below) you should leave this
; region of memory unused in each of your allocated DivMMC banks (or avoid any
; use of the stack, or take care of switching SP whenever you switch banks).
;
; If you do switch any banks, don't forget to restore the previous MMU settings
; afterwards.


; ***************************************************************************
; * Switching between allocated DivMMC banks                                *
; ***************************************************************************
; You can request DivMMC banks to be allocated to your driver, as well as
; (or instead of standard ZX memory banks). However, DivMMC banks are a more
; limited resource and are more awkward to use, since they can only be paged
; in at $2000..$3fff (where your driver code is already running in another
; DivMMC bank).
;
; If you wish to use DivMMC banks, the following helper code is provided
; in the driver's DivMMC bank at $2000 (drv_drvswapmmc):
;       $2000:  out     ($e3),a
;               ret
;
; One suggested method for switching between your allocated DivMMC banks
; and your driver is as follows:
;
; 1. In the preload data for each DivMMC bank (specified in the .DRV
;    file), include the following routine at the start (ie $2000):
;       $2000:  out     ($e3),a
;               push    bc              ; save B=driver bank
;               jp      (hl)
;
; 2. Provide the following subroutine somewhere within your 512-byte driver code:
;       call_externmmc:
;               push    af
;               in      a,($e3)
;               ld      b,a             ; save driver bank in B
;               pop     af
;               set     7,a             ; set bit 7 on DivMMC bank id to page
;               jp      $2000           ; jump to switch banks and "return"
;                                       ; to routine HL in external DivMMC bank
;
; 3. To call a routine in one of your allocated DivMMC banks, use this in
;    your driver code:
;               ld      hl,routineaddr
;               ld      a,divmmcbankid  ; (to be patched by .INSTALL)
;               call    call_externmmc
;
; 4. The routines in your allocated DivMMC banks should end with:
;               pop     af              ; A=driver bank id
;               jp      $2000           ; switch back to driver and return
;
; Don't forget that the stack takes up the region $260d..$26ec and so you
; should not use this region for any other purpose in your DivMMC banks if
; you are using this mechanism.


; ***************************************************************************
; * Entry points                                                            *
; ***************************************************************************

        org     $0000

; At $0000 is the entry point for API calls directed to your driver.
; B,DE,HL are available as entry parameters.

; If your driver does not provide any API, just exit with A=0 and carry set.
; eg:
;       xor     a
;       scf
;       ret

api_entry:
        jr      border_api
        nop

; At $0003 is the entry point for the interrupt handler. This will only be
; called if bit 7 of the driver id byte has been set in your .DRV file, so
; need not be implemented otherwise.

im1_entry:
		push af ,bc, de, hl, ix, iy
		ex af, af'
		push af
		
		nextreg_nn $54,musicbank
		call 32768+5
		nextreg_nn $54,04
		pop af
		ex af, af'
		pop iy, ix, hl, de, bc, af     
		ret 

reloc_1:
        ld      a,(colour)
        inc     a                       ; increment stored border colour
        and     $07
reloc_2:
        ld      (colour),a
        out     ($fe),a                 ; set it
        ret


; ***************************************************************************
; * Simple example API                                                      *
; ***************************************************************************
; On entry, use B=call id with HL,DE other parameters.
; (NOTE: HL will contain the value that was either provided in HL (when called
;        from dot commands) or IX (when called from a standard program).
;
; When called from the DRIVER command, DE is the first input and HL is the second.
;
; When returning values, the DRIVER command will place the contents of BC into
; the first return variable, then DE and then HL.

border_api:
	
        bit     7,b                     ; check if B>=$80
        jr      nz,standard_api         ; on for standard API functions if so

        djnz    bnot1                   ; On if B<>1

; B=1: set values.

reloc_3:
        ld      (value1),de
reloc_4:
        ld      (value2),hl
        and     a                       ; clear carry to indicate success
        ret

; B=2: get values.

bnot1:
        djnz    bnot2                   ; On if B<>2
reloc_5:
        ld      a,(colour)
        ld      b,0
        ld      c,a
reloc_6:
        ld      de,(value1)
reloc_7:
        ld      hl,(value2)
        and     a                       ; clear carry to indicate success
        ret

; Unsupported values of B.

bnot2:
api_error:
        xor     a                       ; A=0, unsupported call id
        scf                             ; Fc=1, signals error
        ret


; ***************************************************************************
; * Standard API functions                                                  *
; ***************************************************************************
; API calls $80..$ff are used in a standard way by NextZXOS.
;
; If (and only if) you have set bit 7 of the "mmcbanks" value in your
; driver file's header, then 2 special calls are made to allow you to
; perform any necessary initialisation or shutdown of your driver
; when it is .INSTALLed and .UNINSTALLed:
;
; B=$80: initialise
; B=$81: shutdown
;
; Each of these calls is made with the following parameters:
;  HL=address of structure containing:
;       byte 0: # of 8K ZX RAM banks allocated (as specified in .DRV header)
;       bytes 1+: list of bank ids for the allocated 8K ZX RAM banks
;  DE=address of structure containing:
;       byte 0: # of 8K DivMMC RAM banks allocated (as specified in .DRV header)
;       bytes 1+: list of bank ids for the allocated 8K DivMMC RAM banks
;
; These bank lists are in main RAM ($4000-$ffff) so be careful not to
; page them out during use. They are temporary structures and only
; available during the initialise ($80) and shutdown ($81) calls.
;
; Note that the initialise ($80) call is made after the allocated RAM
; banks have been erased and preloaded with data from your .DRV file.
; Most drivers will therefore probably not need to use these lists, as
; the allocated bank ids can also be patched directly into your driver
; code during the .INSTALL process.
;
; The shutdown ($81) call does NOT need to deallocate the RAM banks -
; this will be done by the .UNINSTALL dot command.
;
; When exiting the calls, return with carry clear to indicate success.
; If carry is set on call $80, the .INSTALL procedure will be aborted.
; If carry is set on call $81, the .UNINSTALL procedure will be aborted.

standard_api:
        ; The example border driver sets bit 7 of mmcbanks,
        ; so needs to provide API calls $80 and $81.
        ld      a,b
        and     $7f
        jr      z,driver_init           ; on for call $80, initialise
        dec     a
        jr      nz,channel_api          ; if not $81, must be a channel API call

; B=$81: shutdown driver
;        This call is optional and should be provided if you set bit 7 of
;        the mmcbanks value in the driver header.
;        Exit with carry clear if the driver can be safely UNINSTALLed, or
;        carry set to abort the UNINSTALL process.

driver_shutdown:
		nextreg_nn $54,musicbank
		call 32768+8
		nextreg_nn $54,4
        and     a                       ; always safe to uninstall this driver
        ret

; B=$80: initialise driver
;        This call is optional and should be provided if you set bit 7 of
;        the mmcbanks value in the driver header.
;        Exit with carry clear if the driver can be safely INSTALLed, or
;        carry set to abort the INSTALL process.
;        This call is provided for drivers that might need additional
;        hardware initialisation.

driver_init:
		
		nextreg_nn $54,musicbank
		call 32768
		nextreg_nn $54,4
        and     a                       ; always safe to install this driver
        ret

; The following calls are used to allow your driver to support
; channels for i/o (manipulated with BASIC commands like OPEN #).
; Each call is optional - just return with carry set and A=0
; for any calls that you don't want to provide.
;
; B=$f7: return output status
; B=$f8: return input status
; B=$f9: open channel
; B=$fa: close channel
; B=$fb: output character
; B=$fc: input character
; B=$fd: get current stream pointer
; B=$fe: set current stream pointer
; B=$ff: get stream size/extent

channel_api:
        ld      a,b
        sub     $f7                     ; set zero flag if call $f7
                                        ; (return output status)
        jr      c,api_error             ; exit if unsupported (<$f7)
        ld      b,a                     ; B=0..8
        jr      nz,bnotf7               ; on if not $f7 (output status)


; B=$f7: return output status
; This call is entered with D=handle.
; You should return BC=$ffff if the device is ready to accept a character
; to be output, or BC=$0000 if it is not ready.
; NOTE: NextBASIC does not use this call for standard channel i/o, but it
;       may be useful to provide it for use by machine-code programs or
;       for NextBASIC programs using the DRIVER command.
; This call is also used by CP/M for printer drivers (with id "P") and
; AUX drivers (with id "X").

        ld      bc,$ffff                ; our device always ready for output
        and     a                       ; clear carry to indicate success
        ret


; B=$f8: return input status
; This call is entered with D=handle.
; You should return BC=$ffff if the device has an input character available
; to be read, or BC=$0000 if there is no character currently available.
; NOTE: NextBASIC does not use this call for standard channel i/o, but it
;       may be useful to provide it for use by machine-code programs or
;       for NextBASIC programs using the DRIVER command.
; This call is also used by CP/M for AUX drivers (with id "X").

bnotf7:
        djnz    bnotf8
        ld      bc,$ffff                ; our device always ready for input
        and     a                       ; clear carry to indicate success
        ret


; B=$f9: open channel
; In the documentation for your driver you should describe how it should be
; opened. The command used will determine the input parameters provided to
; this call (this example assumes your driver id is ASCII 'X', ie $58):
; OPEN #n,"D>X"         ; simple open: HL=DE=0
; OPEN #n,"D>X>string"  ; open with string: HL=address, DE=length
;                       ; NOTE: be sure to check for zero-length strings
; OPEN #n,"D>X,p1,p2"   ; open with numbers: DE=p1, HL=p2 (zeros if not provided)
;
; This call should return a channel handle in A. This allows your driver
; to support multiple different concurrent channels if desired.
; If your device is simple you may choose to ignore the channel handles
; in this and other calls.
;
; If you return with any error (carry set), "Invalid filename" will be reported
; and no stream will be opened.
;
; For this example, we will only allow a single channel to be opened at
; a time, by performing a simple check:

bnotf8:
        djnz    bnotf9
reloc_8:
        ld      a,(chanopen_flag)
        and     a
        jr      nz,api_error            ; exit with error if already open
        ld      a,1
reloc_9:
        ld      (chanopen_flag),a       ; signal "channel open"
        ret                             ; exit with carry reset (from AND above)
                                        ; and A=handle=1


; Subroutine to validate handle for our simple channel

validate_handle:
        dec     d                       ; D should have been 1
        ret     z                       ; return if so
        pop     af                      ; otherwise discard return address
        jr      api_error               ; and exit with error


; B=$fa: close channel
; This call is entered with D=handle, and should close the channel
; If it cannot be closed for some reason, exit with an error (this will be
; reported as "In use").

bnotf9:
        djnz    bnotfa                  ; on if not call $fa
reloc_10:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
        xor     a
reloc_11:
        ld      (chanopen_flag),a       ; signal "channel closed"
        ret                             ; exit with carry reset (from XOR)

; B=$fb: output character
; This call is entered with D=handle and E=character.
; If you return with carry set and A=$fe, the error "End of file" will be
; reported. If you return with carry set and A<$fe, the error
; "Invalid I/O device" will be reported.
; Do not return with A=$ff and carry set; this will be treated as a successful
; call.

bnotfa:
        djnz    bnotfb                  ; on if not call $fb
reloc_12:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
reloc_13:
        ld      a,(output_ptr)
reloc_14:
        call    calc_buffer_add         ; HL=address within buffer
        ld      (hl),e                  ; store character
        inc     a
        and     $1f
reloc_15:
        ld      (output_ptr),a          ; update pointer
        ret                             ; exit with carry reset (from AND)

; B=$fc: input character
; This call is entered with D=handle.
; You should return the character in A (with carry reset).
; If no character is currently available, return with A=$ff and carry set.
; This will cause INPUT # or NEXT # to continue calling until a character
; is available.
; If you return with carry set and A=$fe, the error "End of file" will be
; reported. If you return with carry set and any other value of A, the error
; "Invalid I/O device" will be reported.

bnotfb:
        djnz    bnotfc                  ; on if not call $fc
reloc_16:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
reloc_17:
        ld      a,(input_ptr)
reloc_18:
        call    calc_buffer_add         ; HL=address within buffer
        ld      e,(hl)                  ; get character
        inc     a
        and     $1f
reloc_19:
        ld      (input_ptr),a           ; update pointer
        ld      a,e                     ; A=character
        ret                             ; exit with carry reset (from AND)

; B=$fd: get current stream pointer
; This call is entered with D=handle.
; You should return the pointer in DEHL (with carry reset).

bnotfc:
        djnz    bnotfd                  ; on if not call $fd
reloc_20:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
reloc_21:
        ld      a,(input_ptr)
        ld      l,a
        ld      h,0                     ; HL=stream pointer
        ld      d,h
        ld      e,h
        and     a                       ; reset carry (successful call)
        ret


; B=$fe: set current stream pointer
; This call is entered with D=handle and IXHL=pointer.
; Exit with A=$fe and carry set if the pointer is invalid (will result in
; an "end of file" error).
; NOTE: Normally you should not use IX as an input parameter, as it cannot
;       be set differently to HL if calling via the esxDOS-compatible API.
;       This call is a special case that is only made by NextZXOS.

bnotfd:
        djnz    bnotfe                  ; on if not call $fe
reloc_22:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
        ld      a,l                     ; check if pointer >$1f
        and     $e0
        or      h
        or      ixl
        or      ixh
        scf
        ld      a,$fe
        ret     nz                      ; exit with A=$fe and carry set if so
        ld      a,l
reloc_23:
        ld      (input_ptr),a           ; set the pointer
        and     a                       ; reset carry (successful call)
        ret


; B=$ff: get stream size/extent
; This call is entered with D=handle
; You should return the size/extent in DEHL (with carry reset).

bnotfe:
reloc_24:
        call    validate_handle         ; check D is our handle (does not return
                                        ; if invalid)
        ld      hl,32                   ; our simple channel is always size 32
        ld      d,h
        ld      e,h
        and     a                       ; reset carry (successful call)
        ret


; ***************************************************************************
; * Validate handle for our simple channel                                  *
; ***************************************************************************

calc_buffer_add:
        push    af                      ; save offset into buffer
reloc_25:
        ld      hl,channel_data         ; base address
        add     a,l                     ; add on offset
        ld      l,a
        ld      a,0
        adc     a,h
        ld      h,a
        pop     af                      ; restore offset
        ret


; ***************************************************************************
; * Data                                                                    *
; ***************************************************************************

colour:
        defb    0
value1:
        defw    0

value2:
        defw    0

chanopen_flag:
        defb    0

input_ptr:
        defb    0

output_ptr:
        defb    0

channel_data:
        defs    32

; Our driver header will specify these values to be patched with the ids
; of the external banks allocated to us.
bankid_mmc0:
        defb    0
bankid_zx0:
        defb    0
bankid_zx1:
        defb    0
bankid_zx2:
        defb    0


; ***************************************************************************
; * Relocation table                                                        *
; ***************************************************************************
; This follows directly after the full 512 bytes of the driver.

size	equ	$

	if $>512
		;.ERROR Driver code exceeds 512 bytes
	else
			defs    512-$
	endif

; Each relocation is the offset of the high byte of an address to be relocated.

reloc_start:
        defw    reloc_1+2
        defw    reloc_2+2
        defw    reloc_3+3
        defw    reloc_4+2
        defw    reloc_5+2
        defw    reloc_6+3
        defw    reloc_7+2
        defw    reloc_8+2
        defw    reloc_9+2
        defw    reloc_10+2
        defw    reloc_11+2
        defw    reloc_12+2
        defw    reloc_13+2
        defw    reloc_14+2
        defw    reloc_15+2
        defw    reloc_16+2
        defw    reloc_17+2
        defw    reloc_18+2
        defw    reloc_19+2
        defw    reloc_20+2
        defw    reloc_21+2
        defw    reloc_22+2
        defw    reloc_23+2
        defw    reloc_24+2
        defw    reloc_25+2
reloc_end:

