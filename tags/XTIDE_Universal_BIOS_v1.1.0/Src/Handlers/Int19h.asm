; File name		:	Int19h.asm
; Project name	:	IDE BIOS
; Created date	:	3.8.2007
; Last update	:	2.5.2010
; Author		:	Tomi Tilli
; Description	:	Int 19h BIOS functions (Boot Strap Loader).

; Section containing code
SECTION .text

B_READ_RETRY_TIMES	EQU	3	; Number of times to retry
B_READ_RETRY_DELAY	EQU	3	; Timer ticks between retries


;--------------------------------------------------------------------
; Int 19h software interrupt handler for late initialization.
; Calls actual Int 19h after initialization is complete.
;
; Int19h_LateInitialization
;	Parameters:
;		Nothing
;	Returns:
;		Never returns
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_LateInitialization:
	call	Initialize_ShouldSkip			; Skip initialization?
	jc		SHORT .SkipInitialization
	call	Initialize_AndDetectDrives
	int		INTV_BOOTSTRAP					; Call actual boot loader
.SkipInitialization:
	call	RamVars_Initialize				; RAMVARS must be initialized even for simple boot loader
	; Fall to Int19h_SimpleBootLoader

;--------------------------------------------------------------------
; Simple boot loader.
; Boot sequence is fixed to 00h, 80h and INT 18h.
;
; Int19h_SimpleBootLoader
;	Parameters:
;		Nothing
;	Returns:
;		Never returns
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_SimpleBootLoader:
	sti										; Enable interrupts
	call	RamVars_GetSegmentToDS
	xor		dx, dx
	call	Int19h_TryToLoadBootSectorFromDL
	jc		SHORT Int19h_JumpToBootSector
	mov		dl, 80h
	call	Int19h_TryToLoadBootSectorFromDL
	jc		SHORT Int19h_JumpToBootSector
	call	Int19h_BootFailure				; Should never return		
	jmp		SHORT Int19h_SimpleBootLoader

;--------------------------------------------------------------------
; Boots if boot sector is successfully read from the drive.
;
; Int19h_TryToLoadBootSectorFromDL
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;		DS:		RAMVARS segment
;	Returns:
;		ES:BX:	Ptr to boot sector (if successfull)
;		CF:		Set if boot sector loaded succesfully
;				Cleared if failed to load boot sector
;	Corrupts registers:
;		AX, CX, DH, DI, (DL if failed to read boot sector)
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_TryToLoadBootSectorFromDL:
	call	BootPrint_TryToBootFromDL
	call	Int19h_LoadFirstSectorFromDL
	jc		SHORT .FailedToLoadFirstSector
	cmp		WORD [es:bx+510], 0AA55h		; Valid boot sector?
	jne		SHORT .FirstSectorNotBootable
	call	BootPrint_BootSectorLoaded
	stc
	ret
.FailedToLoadFirstSector:
	call	BootPrint_FailedToLoadFirstSector
	clc
	ret
.FirstSectorNotBootable:
	call	BootPrint_FirstSectorNotBootable
	clc
	ret

;--------------------------------------------------------------------
; Reads first sector (boot sector) from drive DL.
;
; Int19h_LoadFirstSectorFromDL
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;	Returns:
;		AH:		INT 13h error code
;		ES:BX:	Ptr to boot sector (if successfull)
;		CF:		Cleared if read successfull
;				Set if any error
;	Corrupts registers:
;		AL, CX, DH, DI
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_LoadFirstSectorFromDL:
	LOAD_BDA_SEGMENT_TO	es, bx				; ES:BX now points to...
	mov		bx, BOOTVARS.rgbBootSect		; ...boot sector location
	mov		di, B_READ_RETRY_TIMES			; Retry counter
ALIGN JUMP_ALIGN
.ReadRetryLoop:
	call	Int19h_LoadFirstSectorFromDLToESBX
	jnc		SHORT .Return
	call	Int19h_ResetDriveOrWait
	dec		di								; Decrement retry counter
	jnz		SHORT .ReadRetryLoop			; Loop while retries left
	stc
ALIGN JUMP_ALIGN
.Return:
	ret

;--------------------------------------------------------------------
; Reads first sector (boot sector) from drive DL to ES:BX.
;
; Int19h_LoadFirstSectorFromDLToESBX
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;		ES:BX:	Destination buffer for boot sector
;	Returns:
;		AH:		INT 13h error code
;		ES:BX:	Ptr to boot sector
;		CF:		Cleared if read successfull
;				Set if any error
;	Corrupts registers:
;		AL, CX, DH
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_LoadFirstSectorFromDLToESBX:
	mov		ax, 0201h						; Read 1 sector
	mov		cx, 1							; Cylinder 0, Sector 1
	xor		dh, dh							; Head 0
	int		INTV_DISK_FUNC
	ret


;--------------------------------------------------------------------
; Reset drive controller or waits a while before retrying
; to load boot sector.
;
; Int19h_ResetDriveOrWait
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;		DI:		Retry counter
;	Returns:
;		Nothing
;	Corrupts registers:
;		CX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_ResetDriveOrWait:
	test	di, 1<<0						; Reset on every other retry
	jnz		SHORT .ResetDrive
	mov		cx, B_READ_RETRY_DELAY			; Wait for a while
	jmp		SoftDelay_TimerTicks
ALIGN JUMP_ALIGN
.ResetDrive:
	xor		cx, cx
	xchg	cx, ax							; AH=0h, Disk Controller Reset
	int		INTV_DISK_FUNC
	xchg	ax, cx							; Restore AX
	ret


;--------------------------------------------------------------------
; Jumps to boot sector pointed by ES:BX.
;
; Int19h_JumpToBootSector
;	Parameters:
;		DL:		Drive to boot from (translated, 00h or 80h)
;		ES:BX:	Ptr to boot sector
;	Returns:
;		Never returns
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_JumpToBootSector:
	push	es								; Push boot sector segment
	push	bx								; Push boot sector offset
	call	Int19h_ClearSegmentsForBoot
	xor		dh, dh							; Device supported by INT 13h
	retf

;--------------------------------------------------------------------
; Clears DS and ES registers to zero.
;
; Int19h_ClearSegmentsForBoot
;	Parameters:
;		Nothing
;	Returns:
;		DS=ES:	Zero
;	Corrupts registers:
;		AX
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_ClearSegmentsForBoot:
	xor		ax, ax
	mov		ds, ax
	mov		es, ax
	ret


;--------------------------------------------------------------------
; Calls INT 18h (ROM Basic or Boot Failure). Called after booting from
; floppy drive or hard disk fails.
;
; Int19h_BootFailure
;	Parameters:
;		Nothing
;	Returns:
;		Should never return (but might)
;--------------------------------------------------------------------
ALIGN JUMP_ALIGN
Int19h_BootFailure:
	call	Int19h_ClearSegmentsForBoot
	int		INTV_BOOT_FAILURE
	ret
