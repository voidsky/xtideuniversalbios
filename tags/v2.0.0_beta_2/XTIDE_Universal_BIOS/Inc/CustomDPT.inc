; Project name	:	XTIDE Universal BIOS
; Description	:	Defines for DPT structs containing custom
;					Disk Parameter Table used by this BIOS.

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2012 by XTIDE Universal BIOS Team.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
;

%ifndef CUSTOMDPT_INC
%define CUSTOMDPT_INC

; Base DPT for all device types
struc DPT	; 10 or 18 bytes
	; General Disk Parameter Table related
	.wFlags:
	.bFlagsLow				resb	1
	.bFlagsHigh				resb	1
	.bIdevarsOffset			resb	1	; Offset to IDEVARS for this drive
	.bInitError				resb	1	; Flags for AH=09h initialization errors

	; CHS variables
	.wLchsCylinders			resb	2	; (1...1027, yes 1027)
	.wLchsHeadsAndSectors:
	.bLchsHeads				resb	1	; (1...255)
	.bLchsSectorsPerTrack	resb	1	; (1...63)
	.bPchsHeads				resb	1	; (1...16)

	; LBA and remaining P-CHS variables
%ifdef MODULE_EBIOS
	.bPchsSectorsPerTrack	resb	1
	.wPchsCylinders			resb	2
	.twLbaSectors			resb	6	; 48-bit sector count for LBA addressing
%else
							resb	1	; Alignment
%endif
endstruc

	; Bit definitions for DPT.bFlagsLow
	MASKL_DPT_CHS_SHIFT_COUNT			EQU	(3<<0)				; Bits 0...1, P-CHS to L-CHS bit shift count (0...3)
	MASKL_DPT_TRANSLATEMODE				EQU	MASK_DRVPARAMS_TRANSLATEMODE	; Bits 2...3, NORMAL, LARGE or Assisted LBA addressing mode
	FLGL_DPT_ASSISTED_LBA				EQU	(1<<(TRANSLATEMODE_FIELD_POSITION+1))
	FLGL_DPT_SLAVE						EQU	FLG_DRVNHEAD_DRV	; Bit 4, Drive is a Slave Drive
%ifdef MODULE_IRQ
	FLGL_DPT_ENABLE_IRQ					EQU	(1<<5)				; Bit 5, Enable IRQ
%endif
%ifdef MODULE_EBIOS
	FLGL_DPT_LBA_AND_EBIOS_SUPPORTED	EQU	FLG_DRVNHEAD_LBA	; Bit 6, Drive supports LBA and so EBIOS functions can be supported
	FLGL_DPT_LBA48						EQU	(1<<7)				; Bit 7, Drive supports 48-bit LBA (Must be bit 7!)
%endif


	; Bit definitions for DPT.bFlagsHigh
	FLGH_DPT_BLOCK_MODE_SUPPORTED		EQU	(1<<1)	; Bit 1, Use block transfer commands (must be bit 1!)
%ifdef MODULE_SERIAL
	FLGH_DPT_SERIAL_DEVICE				EQU	(1<<2)	; Bit 2, Serial Port Device
%endif
%ifdef MODULE_IRQ
	FLGH_DPT_INTERRUPT_IN_SERVICE		EQU	(1<<3)	; Bit 3, Set when waiting for IRQ
%endif
%ifdef MODULE_FEATURE_SETS
	FLGH_DPT_POWER_MANAGEMENT_SUPPORTED	EQU (1<<5)	; Bit 4, Drive supports power management
%endif
%ifdef MODULE_ADVANCED_ATA
	FLGH_DPT_IORDY						EQU	(1<<7)	; Bit 5, Controller and Drive supports IORDY
%endif

	; Serial device only
%ifdef MODULE_SERIAL_FLOPPY
	FLGH_DPT_SERIAL_FLOPPY						EQU	(1<<4)
	FLGH_DPT_SERIAL_FLOPPY_TYPE_MASK			EQU	0e0h
	FLGH_DPT_SERIAL_FLOPPY_TYPE_FIELD_POSITION	EQU	5
%endif


	; Flags for DPT_ADVANCED_ATA.bInitError
	FLG_INITERROR_FAILED_TO_SELECT_DRIVE				EQU (1<<0)
	FLG_INITERROR_FAILED_TO_INITIALIZE_CHS_PARAMETERS	EQU (1<<1)
	FLG_INITERROR_FAILED_TO_SET_WRITE_CACHE				EQU (1<<2)
	FLG_INITERROR_FAILED_TO_RECALIBRATE_DRIVE			EQU (1<<3)
	FLG_INITERROR_FAILED_TO_SET_BLOCK_MODE				EQU (1<<4)
	FLG_INITERROR_FAILED_TO_SET_PIO_MODE				EQU (1<<5)
	FLG_INITERROR_FAILED_TO_INITIALIZE_STANDBY_TIMER	EQU	(1<<6)
	FLG_INITERROR_FAILED_TO_ENABLE_8BIT_PIO_MODE		EQU	(1<<7)



; DPT for ATA devices
struc DPT_ATA	; 10/18 bytes + 2 bytes = 12/20 bytes
	.dpt					resb	DPT_size
	.bBlockSize				resb	1	; Current block size in sectors (do not set to zero!)
	.bDevice				resb	1	; Device Type from IDEVARS (overrided when 32-bit controller detected)
endstruc



; Additional variables needed to initialize and reset Advanced IDE Controllers.
; EBDA must be reserved for DPTs when using these!
%ifdef MODULE_ADVANCED_ATA
struc DPT_ADVANCED_ATA	; 12/20 bytes + 8 bytes = 20/28 bytes
	.dpt_ata				resb	DPT_ATA_size
	.wControllerID			resb	2	; Controller specific ID WORD (from Advanced Controller detection)
	.wControllerBasePort	resb	2	; Advanced Controller port (not IDE port)
	.wMinPioCycleTime		resb	2	; Minimum PIO Cycle Time in ns
	.bPioMode				resb	1	; Best supported PIO mode
							resb	1
endstruc
%endif


; DPT for Serial devices
%ifdef MODULE_SERIAL
struc DPT_SERIAL	; 8/18 bytes + 2 bytes = 10/20 bytes
	.dpt					resb	DPT_size
	.wSerialPortAndBaud:
	.bSerialPort			resb	1	; Serial connection I/O port address, divided by 4
	.bSerialBaud			resb 	1	; Serial connection baud rate divisor
endstruc
%endif


; This is the common size for all DPTs. All DPTs must be equal size.
%ifdef MODULE_ADVANCED_ATA
	LARGEST_DPT_SIZE			EQU		DPT_ADVANCED_ATA_size
%else
	LARGEST_DPT_SIZE			EQU		DPT_ATA_size
%endif


	; Number of Sectors per Track is fixed to 63 for LBA assist calculation.
	; 1024 cylinders, 256 heads, 63 sectors = 8.4 GB limit (but DOS does not support more than 255 heads)
	MAX_LCHS_CYLINDERS			EQU		1024
	LBA_ASSIST_SPT				EQU		63


%endif ; CUSTOMDPT_INC
