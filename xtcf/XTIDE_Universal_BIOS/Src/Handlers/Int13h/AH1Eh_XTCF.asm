; Project name	:	XTIDE Universal BIOS
; Description	:	Int 13h function AH=1Eh, Lo-tech XT-CF features
;
; More information at http://www.lo-tech.co.uk/XT-CF

;
; XTIDE Universal BIOS and Associated Tools
; Copyright (C) 2009-2010 by Tomi Tilli, 2011-2013 by XTIDE Universal BIOS Team.
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

; Modified by JJP for XT-CFv3 support, Mar-13

; Section containing code
SECTION .text

;--------------------------------------------------------------------
; Int 13h function AH=1Eh, Lo-tech XT-CF features.
; This function is supported only by XTIDE Universal BIOS.
;
; AH1Eh_HandlerForXTCFfeatures
;	Parameters:
;		AL, CX:		Same as in INTPACK
;		DL:		Translated Drive number
;		DS:DI:		Ptr to DPT (in RAMVARS segment)
;		SS:BP:		Ptr to IDEPACK
;	Parameters on INTPACK:
;		AL:		XT-CF subcommand (see XTCF.inc for more info)
;	Returns with INTPACK:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;--------------------------------------------------------------------
AH1Eh_HandlerForXTCFfeatures:
%ifndef USE_186
	call	ProcessXTCFsubcommandFromAL
	jmp		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
%else
	push		Int13h_ReturnFromHandlerAfterStoringErrorCodeFromAH
	; Fall to ProcessXTCFsubcommandFromAL
%endif


;--------------------------------------------------------------------
; ProcessXTCFsubcommandFromAL
;	Parameters:
;		AL:		XT-CF subcommand (see XTCF.inc for more info)
;		DS:DI:		Ptr to DPT (in RAMVARS segment)
;		SS:BP:		Ptr to IDEPACK
;	Returns:
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
ProcessXTCFsubcommandFromAL:
	; IS_THIS_DRIVE_XTCF. We check this for all commands.
	call	AccessDPT_IsThisDeviceXTCF
	jne	XTCFnotFound
	and		ax, BYTE 7Fh				; Subcommand now in AX (clears AH and CF)
	jz	.ReturnWithSuccess				; Sub-function IS_THIS_DRIVE_XTCF (=0)

	dec		ax					; Test subcommand...
	jz	.GetXTCFtransferMode				; ...for value 1 (GET_XTCF_TRANSFER_MODE)
	dec		ax					; Test subcommand...
	jz	.SetXTCFtransferMode				; ...for value 2 (SET_XTCF_TRANSFER_MODE)
	jmp	XTCFnotFound					; otherwise, invalid sub-function requested

.ReturnWithSuccess:
	ret							; return with AH and CF cleared

.GetXTCFtransferMode:
	mov		al, BYTE [di+DPT_ATA.bDevice]		; get current mode from DPT
	mov		[bp+IDEPACK.intpack+INTPACK.dh], al	; and return mode via INTPACK...
	ret							; ...with AH and CF cleared

.SetXTCFtransferMode:
	mov		al, [bp+IDEPACK.intpack+INTPACK.dh]	; get specified mode (eg XTCF_DMA_MODE) 
	; and fall to AH1Eh_ChangeXTCFmodeBasedOnControlRegisterInAL


;--------------------------------------------------------------------
; AH1Eh_ChangeXTCFmodeBasedOnModeInAL
;	Parameters:
;		AL:		XT-CF Mode (see XTCF.inc)
;		DS:DI:		Ptr to DPT (in RAMVARS segment)
;		SS:BP:		Ptr to IDEPACK
;	Returns:	
;		AH:		Int 13h return status
;		CF:		0 if successful, 1 if error
;	Corrupts registers:
;		AL, BX, CX, DX, SI
;--------------------------------------------------------------------
AH1Eh_ChangeXTCFmodeBasedOnModeInAL:
	; Note: Control register (as of XT-CFv3) is now a write-only register,
	;       whos purpose is *only* to raise DRQ.  The register cannot be read.
	;       Selected transfer mode is stored in BIOS variable (DPT_ATA.bDevice).

	; We always need to enable 8-bit mode since 16-bit mode is restored
	; when controller is reset (AH=00h or 0Dh)
	; 
	; Note that when selecting 'DEVICE_8BIT_PIO_MODE_WITH_BIU_OFFLOAD' mode,
	; the ATA device (i.e. CompactFlash card) will operate in 8-bit mode, but
	; data will be transferred from it's data register using 16-bit CPU instructions
	; like REP INSW.  This works because XT-CF adapters are 8-bit cards, and
	; the BIU in the machine splits each WORD requested by the CPU into two 8-bit
	; ISA cycles at base+0h and base+1h.  The XT-CF cards do not decode A0, hence
	; both accesses appear the same to the card and the BIU then re-constructs
	; the data for presentation to the CPU.
	;
	; Also note though that some machines, noteably AT&T PC6300, have hardware
	; errors in the BIU logic, resulting in reversed byte ordering.  Therefore,
	; mode DEVICE_8BIT_PIO is the default transfer mode for best system
	; compatibility.

	ePUSH_T	bx, AH23h_Enable8bitPioMode

	; Convert mode to device type (see XTCF.inc for full details)
	add		al, 0			; XTCF_8BIT_PIO_MODE = 0
	jz	.Set8bitPioMode
	dec		al			; XTCF_8BIT_PIO_MODE_WITH_BIU_OFFLOAD = 1
	jz	.Set8bitPioModeWithBIUOffload
	dec		al			; XTCF_DMA_MODE = 2
	jz	.SetDMATransferMode
	; any other value, set PIO 8-bit mode anyway so fall to .Set8bitPioMode

.Set8bitPioMode:
	mov		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_XTCF_PIO8
	ret		; through AH23h_Enable8bitPioMode

.Set8bitPioModeWithBIUOffload:
	mov		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_XTCF_PIO8_WITH_BIU_OFFLOAD
	ret		; through AH23h_Enable8bitPioMode

.SetDMATransferMode:
	mov		BYTE [di+DPT_ATA.bDevice], DEVICE_8BIT_XTCF_DMA
	; DMA transfers have limited block size, which is checked in AH24h_SetBlockSize
	mov		al, [di+DPT_ATA.bBlockSize]
	jmp	AH24h_SetBlockSize
	; exit via ret in AH24_SetBlockSize then through AH23h_Enable8bitPioMode


;--------------------------------------------------------------------
; AH1Eh_DetectXTCFwithBasePortInDX
;	Parameters:
;		DX:		Base I/O port address to check
;	Returns:
;		AH:		RET_HD_SUCCESS if XT-CF is found from port
;				RET_HD_INVALID if XT-CF is not found
;		CF:		Cleared if XT-CF found
;				Set if XT-CF not found
;	Corrupts registers:
;		AL
;--------------------------------------------------------------------
AH1Eh_DetectXTCFwithBasePortInDX:
; Note this detection routine is not possible now, since the control
; register cannot be read.
; 
; Hard-coded to return found at 300h, to enable testing of the rest of the
; BIOS.
;
;	push		dx
;	add		dl, XTCF_CONTROL_REGISTER_INVERTED_in	; set DX to XT-CF config register (inverted)
;	in		al, dx		; get value
;	mov		ah, al		; save in ah
;	inc		dx			; set DX to XT-CF config register (non-inverted)
;	in		al, dx		; get value
;	not		al			; invert value
;	pop		dx
;	sub		ah, al		; do they match? (clear AH if they do)
;	jz		SHORT XTCFfound
;
	cmp		dx, 300h
	je	XTCFfound

XTCFnotFound:
AH1Eh_LoadInvalidCommandToAHandSetCF:
	stc					; set carry flag since XT-CF not found
	mov		ah, RET_HD_INVALID
XTCFfound:
	ret					; and return

