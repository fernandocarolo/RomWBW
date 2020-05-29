;
;==================================================================================================
;   RAM FLOPPY DISK DRIVER
;==================================================================================================
;
;
;
RF_U0IO		.EQU	$A0		; BASED ADDRESS OF RAMFLOPPY 1
RF_U1IO		.EQU	$A4		; BASED ADDRESS OF RAMFLOPPY 2
RF_U2IO		.EQU	$A8		; BASED ADDRESS OF RAMFLOPPY 3
RF_U3IO		.EQU	$AC		; BASED ADDRESS OF RAMFLOPPY 4
;
; IO PORT OFFSETS
;
RF_DAT		.EQU	0		; DATA IN/OUT ONLT TO SRAM      - R/W
RF_AL		.EQU	1		; ADDRESS LOW FOR RAMF MEMORY   - W/O 
RF_AH		.EQU	2		; ADDRESS HIGH FOR RAMF MEMORY  - W/O
RF_ST		.EQU	3		; STATUS PORT			- R/O
;
; RF DEVICE CONFIGURATION
;
RF_DEVCNT	.EQU	RFCNT		; NUMBER OF RF DEVICES SUPPORTED
RF_CFGSIZ	.EQU	8		; SIZE OF CFG TBL ENTRIES
RF_MAXRF	.EQU	4		; MAXIMUM NUMBERS OF DEVICES SUPPORTED
;
RF_DEV	.EQU	0			; OFFSET OF DEVICE NUMBER (BYTE)
RF_STAT	.EQU	1			; OFFSET OF STATUS (BYTE)
RF_LBA	.EQU	2			; OFFSET OF LBA (DWORD)
RF_IOAD	.EQU	7			; OFFSET OF DEVICE IO ADDRESS

#IF ($RF_DEVCNT > RF_MAXRF)
	.ECHO	"*** ONLY 4 RAM FLOPPY DEVICES SUPPORTED ***\n"
RF_DEVCNT	.SET	RF_MAXRF	
#ENDIF
;
; DEVICE CONFIG TABLE (RAM DEVICE FIRST TO MAKE IT ALWAYS FIRST DRIVE)
;
RF_CFGTBL:
	; DEVICE 0
	.DB	0			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	0			; UNUSED
	.DB	RF_U0IO			; DEVICE BASE ADDR
#IF (RF_DEVCNT > 1)
	; DEVICE 1
	.DB	1			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	0			; UNUSED
	.DB	RF_U1IO			; DEVICE BASE ADDR
#ENDIF
#IF (RF_DEVCNT > 2)
	; DEVICE 2
	.DB	2			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	0			; UNUSED
	.DB	RF_U2IO			; DEVICE BASE ADDR
#ENDIF
;	; DEVICE 3
#IF (RF_DEVCNT > 3)
	.DB	3			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	0			; UNUSED
	.DB	RF_U3IO			; DEVICE BASE ADDR
#ENDIF
;
#IF ($ - RF_CFGTBL) != (RF_DEVCNT * RF_CFGSIZ)
	.ECHO	"*** INVALID RF CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
;
;
RF_INIT:
	CALL	NEWLINE			; FORMATTING
	PRTS("RF:$")		

	LD	B,RF_DEVCNT		; LOOP CONTROL
	LD	IY,RF_CFGTBL		; START OF CFG TABLE
RF_INIT0:
	CALL	RF_UNIT
	PUSH	BC			; SAVE LOOP CONTROL
	LD	BC,RF_FNTBL		; BC := FUNC TABLE ADR
	PUSH	IY			; CFG ENTRY POINTER
	POP	DE			; COPY TO DE
	CALL	DIO_ADDENT		; ADD ENTRY, BC IS NOT DESTROYED
	LD	BC,RF_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	POP	BC			; RESTORE BC
	DJNZ	RF_INIT0		; LOOP AS NEEDED

	PRTS(" DEVICES=$")		; DISPLAY NUMBER	
	LD	A,RF_DEVCNT		; OF DEVICES
	CALL	PRTDECB
;
	XOR	A			; INIT SUCCEEDED
	RET				; RETURN
;
RF_UNIT:
	PRTS(" IO=0x$")			; DISPLAY
	LD	A,(IY+RF_IOAD)		; PORT AND
	CALL	PRTHEXBYTE		; WRITE 
	PRTS(" WP=$")			; PROTECT
	ADD	A,RF_ST			; STATUS OF
	LD	C,A			; THIS DEVICE
	IN	A,(C)
	AND	1
	JR	Z,RF_NO_WP1
	PRTS("ON$")
	RET
RF_NO_WP1:
	PRTS("OFF$")
	RET
;
;
;
RF_FNTBL:
	.DW	RF_STATUS
	.DW	RF_RESET
	.DW	RF_SEEK
	.DW	RF_READ
	.DW	RF_WRITE
	.DW	RF_VERIFY
	.DW	RF_FORMAT
	.DW	RF_DEVICE
	.DW	RF_MEDIA
	.DW	RF_DEFMED
	.DW	RF_CAP
	.DW	RF_GEOM
#IF (($ - RF_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID MD FUNCTION TABLE ***\n"
#ENDIF
;
RF_VERIFY:
RF_FORMAT:
RF_DEFMED:
	CALL	SYSCHK			; INVALID SUB-FUNCTION
	LD	A,ERR_NOTIMPL
	OR	A
	RET
;
;
;
RF_STATUS:
	XOR	A			; STATUS ALWAYS OK
	RET
;
;
;
RF_RESET:
	XOR	A			; ALWAYS OK
	RET
;
;
;
RF_CAP:
	LD	DE,0
	LD	HL,$2000		; 8192 BLOCKS OF 512 BYTES
	XOR	A
	RET
;
;
;
RF_GEOM:
	; FOR LBA, WE SIMULATE CHS ACCESS USING 16 HEADS AND 16 SECTORS
	; RETURN HS:CC -> DE:HL, SET HIGH BIT OF D TO INDICATE LBA CAPABLE
	CALL	RF_CAP			; GET TOTAL BLOCKS IN DE:HL, BLOCK SIZE TO BC
	LD	L,H			; DIVIDE BY 256 FOR # TRACKS
	LD	H,E			; ... HIGH BYTE DISCARDED, RESULT IN HL
	LD	D,16 | $80		; HEADS / CYL = 16, SET LBA CAPABILITY BIT
	LD	E,16			; SECTORS / TRACK = 16
	RET				; DONE, A STILL HAS RF_CAP STATUS
;
;
;
RF_DEVICE:
	LD	D,DIODEV_RF		; D := DEVICE TYPE
	LD	E,(IY+RF_DEV)		; E := PHYSICAL DEVICE NUMBER
	LD	C,%00110000		; C := ATTRIBUTES, NON-REMOVABLE RAM FLOPPY
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,(IY+RF_IOAD)		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
RF_MEDIA:
	LD	E,MID_RF		; RAM FLOPPY MEDIA
	LD	D,0			; D:0=0 MEANS NO MEDIA CHANGE
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
RF_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+RF_LBA+0),L		; SAVE NEW LBA
	LD	(IY+RF_LBA+1),H		; ...
	LD	(IY+RF_LBA+2),E		; ...
	LD	(IY+RF_LBA+3),D		; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
RF_READ:
	CALL	HB_DSKREAD		; HOOK HBIOS DISK READ SUPERVISOR
	LD	BC,RF_RDSEC		; GET ADR OF SECTOR READ FUNC
	LD	(RF_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	JR	RF_RW			; CONTINUE TO GENERIC R/W ROUTINE
;
;
;
RF_WRITE:
	CALL	HB_DSKWRITE		; HOOK HBIOS DISK WRITE SUPERVISOR
	LD	BC,RF_WRSEC		; GET ADR OF SECTOR WRITE FUNC
	LD	(RF_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	CALL	RF_CHKWP		; WRITE PROTECTED?
	JR	Z,RF_RW			; IF 0, NOT WP, CONTINUE WITH GENERIC R/W ROUTINE
	LD	E,0			; ZERO SECTORS WRITTEN
	LD	A,ERR_READONLY		; SIGNAL ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
;
;
RF_RW:
	LD	(RF_DSKBUF),HL		; SAVE DISK BUFFER ADDRESS
	LD	A,E			; BLOCK COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR READ/WRITE COUNT
	CALL	RF_SETIO		; SET BASE PORT IO ADR FOR SELECTED UNIT
RF_RW1:
	PUSH	BC			; SAVE COUNTERS
	LD	HL,(RF_RWFNADR)		; GET PENDING IO FUNCTION ADDRESS
	CALL	JPHL			; ... AND CALL IT
	JR	NZ,RF_RW2		; IF ERROR, SKIP INCREMENT
	; INCREMENT LBA
	LD	A,MD_LBA		; OFFSET OF LBA VALUE
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE
	; INCREMENT DMA
	LD	HL,RF_DSKBUF+1		; POINT TO MSB OF BUFFER ADR
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES
	XOR	A			; SIGNAL SUCCESS
RF_RW2:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,RF_RW3		; IF ERROR, BAIL OUT
	INC	C			; BUMP COUNT OF SECTORS READ
	DJNZ	RF_RW1			; LOOP AS NEEDED
RF_RW3:
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(RF_DSKBUF)		; CURRENT DMA TO HL
	OR	A			; SET FLAGS BASED ON RETURN CODE
	RET	Z			; RETURN SUCCESS
	LD	A,ERR_IO		; SIGNAL IO ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
; READ SECTOR
;
RF_RDSEC:
	CALL	RF_SETADR		; SEND SECTOR STARTING ADDRESS TO CARD
	LD	HL,(RF_DSKBUF)		; HL := DISK BUFFER ADDRESS
	LD	B,0			; INIT BYTE COUNTER
	LD	A,(RF_IO)		; GET IO PORT BASE
	OR	RF_DAT			; OFFSET TO DAT PORT
	LD	C,A			; PUT IN C FOR PORT IO
	INIR				; READ 256 BYTES
	INIR				; AND ANOTHER 256 BYTES FOR 512 TOTAL
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
; WRITE SECTOR
;
RF_WRSEC:
	CALL	RF_SETADR		; SEND SECTOR STARTING ADDRESS TO CARD
	LD	HL,(RF_DSKBUF)		; HL := DISK BUFFER ADDRESS
	LD	B,0			; INIT BYTE COUNTER
	LD	A,(RF_IO)		; GET IO PORT BASE
	OR	RF_DAT			; OFFSET TO DAT PORT
	LD	C,A			; PUT IN C FOR PORT IO
	OTIR				; WRITE 256 BYTES
	OTIR				; AND ANOTHER 256 BYTES FOR 512 TOTAL
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
;
;
RF_SETIO:
	LD	A,(IY+RF_IOAD)		; GET THE IO PORT
	LD	(RF_IO),A		; OF THE DEVICE WE
	RET				; ARE WORKING ON
;
;
;
RF_SETADR:				; OUTPUT THE
	LD	A,(RF_IO)		; LOGICAL BLOCK
	OR	RF_AL			; ADDRESS TO THE
	LD	C,A			; TO THE MSB AND
	LD	A,(IY+RF_LBA+0)		; LSB SECTRK
	OUT	(C),A			; REGISTERS. 
	LD	A,(IY+RF_LBA+1)		; BYTE COUNTER
	INC	C			; IS RESET
	OUT	(C),A
	RET
;
;
;
RF_CHKWP:
	CALL	RF_SETIO		; SET BASE PORT IO ADR FOR SELECTED UNIT
	LD	A,(RF_IO)		; GET IO PORT BASE
	OR	RF_ST			; OFFSET TO ST PORT
	LD	C,A			; PUT PORT ADR IN C FOR IO
	IN	A,(C)			; READ ST PORT
	BIT	0,A			; CHECK WRITE PROTECT (BIT 0)
	RET				; RET WP STATUS IN ZF, NZ=WP
;
;
;
RF_IO		.DB	0		; PORT ADDRESS OF ACTIVE DEVICE
RF_RWFNADR	.DW	0
;
RF_DSKBUF	.DW	0
