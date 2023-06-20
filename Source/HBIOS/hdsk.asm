;
;==================================================================================================
;   HDSK DISK DRIVER
;==================================================================================================
;
; IO PORT ADDRESSES
;
HDSK_IO		.EQU	$FD
;
HDSK_CMDNONE	.EQU	0
HDSK_CMDRESET	.EQU	1
HDSK_CMDREAD	.EQU	2
HDSK_CMDWRITE	.EQU	3
HDSK_CMDPARAM	.EQU	4
;
; HDSK DEVICE CONFIGURATION
;
HDSK_DEVCNT	.EQU	2		; NUMBER OF HDSK DEVICES SUPPORTED
HDSK_CFGSIZ	.EQU	6		; SIZE OF CFG TBL ENTRIES
;
HDSK_DEV	.EQU	0		; OFFSET OF DEVICE NUMBER (BYTE)
HDSK_STAT	.EQU	1		; OFFSET OF STATUS (BYTE)
HDSK_LBA	.EQU	2		; OFFSET OF LBA (DWORD)
;
HDSK_CFGTBL:
	; DEVICE 0
	.DB	0			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
#IF (HDSK_DEVCNT >= 2)
	; DEVICE 1
	.DB	1			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
#ENDIF
;
#IF ($ - HDSK_CFGTBL) != (HDSK_DEVCNT * HDSK_CFGSIZ)
	.ECHO	"*** INVALID HDSK CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
; STATUS
;
HDSK_STOK	.EQU	0		; OK
HDSK_STNOTRDY	.EQU	-1		; NOT READY
;
;
;
HDSK_INIT:
	CALL	NEWLINE			; FORMATTING
	PRTS("HDSK:$")
	PRTS(" DEVICES=$")
	LD	A,HDSK_DEVCNT
	CALL	PRTDECB
;
; SETUP THE DISPATCH TABLE ENTRIES
;
	XOR	A			; ZERO ACCUM
	LD	(HDSK_CURDEV),A		; INIT CURRENT DEVICE NUM
	LD	IY,HDSK_CFGTBL		; START OF DEV CFG TABLE
HDSK_INIT0:
	CALL	HDSK_PROBE		; HARDWARE PROBE
	JR	NZ,HDSK_INIT1		; SKIP DEVICE IF NOT PRESENT
	LD	BC,HDSK_FNTBL		; BC := DRIVER FUNC TABLE ADDRESS
	PUSH	IY			; CFG ENTRY POINTER
	POP	DE			; ... TO DE
	CALL	DIO_ADDENT		; ADD ENTRY TO GLOBAL DISK TABLE
	CALL	HDSK_INITDEV		; PERFORM DEVICE INITIALIZATION
HDSK_INIT1:
	LD	BC,HDSK_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	LD	HL,HDSK_CURDEV		; POINT TO CURRENT DEVICE
	INC	(HL)			; AND INCREMENT IT
	LD	A,(IY)			; GET FIRST BYTE OF ENTRY
	INC	A			; TEST FOR END OF TABLE ($FF)
	JR	NZ,HDSK_INIT0		; IF NOT, LOOP
;
	XOR	A			; INIT SUCCEEDED
	RET				; RETURN
;
; PROBE FOR DEVICE EXISTENCE
;
HDSK_PROBE:
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
; INITIALIZE DEVICE
;
HDSK_INITDEV:
	LD	(IY+HDSK_STAT),HDSK_STNOTRDY	; STATUS := NOT READY
	XOR	A			; CLEAR ACCUM
	LD	(IY+HDSK_LBA+0),A	; ZERO LBA
	LD	(IY+HDSK_LBA+1),A	; ...
	LD	(IY+HDSK_LBA+2),A	; ...
	LD	(IY+HDSK_LBA+3),A	; ...
	XOR	A			; SIGNAL SUCCESS (REDUNDANT)
	RET				; AND DONE
;
; DRIVER FUNCTION TABLE
;
HDSK_FNTBL:
	.DW	HDSK_STATUS
	.DW	HDSK_RESET
	.DW	HDSK_SEEK
	.DW	HDSK_READ
	.DW	HDSK_WRITE
	.DW	HDSK_VERIFY
	.DW	HDSK_FORMAT
	.DW	HDSK_DEVICE
	.DW	HDSK_MEDIA
	.DW	HDSK_DEFMED
	.DW	HDSK_CAP
	.DW	HDSK_GEOM
#IF (($ - HDSK_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID HDSK FUNCTION TABLE ***\n"
#ENDIF
;
;
;
HDSK_VERIFY:
HDSK_FORMAT:
HDSK_DEFMED:
	SYSCHKERR(ERR_NOTIMPL)			; INVALID SUB-FUNCTION
	RET
;
;
;
HDSK_STATUS:
	LD	A,(IY+HDSK_STAT)	; LOAD STATUS
	OR	A			; SET FLAGS
	RET
;
;
;
HDSK_RESET:
	JP	HDSK_DSKRESET
;
; GET DISK CAPACITY
;   RETURN DE:HL=BLOCK COUNT, BC=BLOCK SIZE
;   ASSUME 1GB MEDIA SIZE, SO 1GB / 512B
;   IS $200000 SECTORS
;
HDSK_CAP:
	LD	DE,$20			; BLOCK COUNT MSW
	LD	HL,0			; BLOCK COUNT LSW
	LD	BC,512			; 512 BYTE SECTOR
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
HDSK_GEOM:
	; FOR LBA, WE SIMULATE CHS ACCESS USING 16 HEADS AND 16 SECTORS
	; RETURN HS:CC -> DE:HL, SET HIGH BIT OF D TO INDICATE LBA CAPABLE
	CALL	HDSK_CAP		; GET TOTAL BLOCKS IN DE:HL, BLOCK SIZE TO BC
	LD	L,H			; DIVIDE BY 256 FOR # TRACKS
	LD	H,E			; ... HIGH BYTE DISCARDED, RESULT IN HL
	LD	D,$80 | 16		; HEADS / CYL = 16, SET LBA BIT
	LD	E,16			; SECTORS / TRACK = 16
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
HDSK_DEVICE:
	LD	D,DIODEV_HDSK		; D := DEVICE TYPE
	LD	E,(IY+HDSK_DEV)		; E := PHYSICAL DEVICE NUMBER
	LD	C,%00110000		; C := ATTRIBUTES, NON-REMOVABLE HARD DISK
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,HDSK_IO		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
HDSK_MEDIA:
	LD	E,MID_HD		; HARD DISK MEDIA
	LD	D,0			; D:0=0 MEANS NO MEDIA CHANGE
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
HDSK_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+HDSK_LBA+0),L	; SAVE NEW LBA
	LD	(IY+HDSK_LBA+1),H	; ...
	LD	(IY+HDSK_LBA+2),E	; ...
	LD	(IY+HDSK_LBA+3),D	; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
HDSK_READ:
	CALL	HB_DSKREAD		; HOOK HBIOS DISK READ SUPERVISOR
	LD	A,HDSK_CMDREAD
	JR	HDSK_RW
;
;
;
HDSK_WRITE:
	CALL	HB_DSKWRITE		; HOOK HBIOS DISK WRITE SUPERVISOR
	LD	A,HDSK_CMDWRITE
	JR	HDSK_RW
;
;
;
HDSK_RW:
	LD	(HDSK_CMD),A		; SET COMMAND BYTE
	LD	(HDSK_DMA),HL		; SAVE INITIAL DMA
	LD	A,E			; SECTOR COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR READ/WRITE COUNT
	LD	A,(IY+HDSK_DEV)		; GET DEVICE NUMBER
	LD	(HDSK_DRV),A		; ... AND SET FIELD IN HDSK PARM BLOCK

	; RESET HDSK INTERFACE IF NEEDED
	LD	A,(IY+HDSK_STAT)	; GET CURRENT STATUS
	OR	A			; SET FLAGS
	PUSH	BC			; SAVE COUNTERS
	CALL	NZ,HDSK_DSKRESET	; RESET IF NOT READY
	POP	BC			; RESTORE COUNTERS
	JR	NZ,HDSK_RW6		; ABORT ON FAILURE

HDSK_RW0:
	PUSH	BC			; SAVE COUNTERS
	XOR	A			; A = 0
	LD	(HDSK_RC),A		; CLEAR RETURN CODE
;
#IF (DSKYENABLE)
	LD	A,HDSK_LBA
	CALL	LDHLIYA
	CALL	HB_DSKACT		; SHOW ACTIVITY
#ENDIF
;
	; CONVERT LBA HHHH:LLLL (4 BYTES)
	; TO HDSK TRACK/SECTOR TTTT:SS (3 BYTES)
	; SAVING TO HDSK PARM BLOCK
	; (IY+HDSK_LBA+0) ==> (HDSK_SEC)
	LD	A,(IY+HDSK_LBA+0)
	LD	(HDSK_SEC),A
	; (IY+HDSK_LBA+1) ==> (HDSK_TRK+0)
	LD	A,(IY+HDSK_LBA+1)
	LD	(HDSK_TRK+0),A
	; (IY+HDSK_LBA+2) ==> (HDSK_TRK+1)
	LD	A,(IY+HDSK_LBA+2)
	LD	(HDSK_TRK+1),A

	; EXECUTE COMMAND
	LD	B,7			; SIZE OF PARAMETER BLOCK
	LD	HL,HDSK_PARMBLK		; ADDRESS OF PARAMETER BLOCK
	LD	C,$FD			; HDSK CMD PORT
	OTIR				; SEND IT

	; GET RESULT
	IN	A,(C)			; GET RESULT CODE
	LD	(HDSK_RC),A		; SAVE IT
	OR	A			; SET FLAGS

#IF (HDSKTRACE > 0)
	PUSH	AF			; SAVE RETURN CODE
#IF (HDSKTRACE == 1)
	CALL	NZ,HDSK_PRT		; DIAGNOSE ERRORS ONLY
#ENDIF
#IF (HDSKTRACE >= 2)
	CALL	HDSK_PRT		; DISPLAY ALL READ/WRITE RESULTS
#ENDIF
	POP	AF			; RESTORE RETURN CODE
#ENDIF

	JR	NZ,HDSK_RW5		; BAIL OUT ON ERROR

	; INCREMENT LBA
	LD	A,HDSK_LBA		; LBA OFFSET IN CFG ENTRY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE

	; INCREMENT DMA
	LD	HL,HDSK_DMA+1		; POINT TO MSB OF DMA
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES

	XOR	A			; A := 0 SIGNALS SUCCESS

HDSK_RW5:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,HDSK_RW6		; IF ERROR, GET OUT

	INC	C			; RECORD SECTOR COMPLETED
	DJNZ	HDSK_RW0		; LOOP AS NEEDED

HDSK_RW6:
	; RETURN WITH SECTORS READ IN E AND UPDATED DMA ADDRESS IN HL
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(HDSK_DMA)		; CURRENT DMA TO HL
	OR	A			; SET FLAGS BASED ON RETURN CODE
	RET	Z			; RETURN IF SUCCESS
	LD	A,ERR_IO		; SIGNAL IO ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
;
;
HDSK_DSKRESET:
;
#IF (HDSKTRACE >= 2)
	CALL	NEWLINE
	LD	DE,HDSKSTR_PREFIX
	CALL	WRITESTR
	CALL	PC_SPACE
	LD	DE,HDSKSTR_RESET
	CALL	WRITESTR
#ENDIF
;
	LD	B,32
	LD	A,HDSK_CMDRESET
HDSK_DSKRESET1:
	OUT	($FD),A
	DJNZ	HDSK_DSKRESET1

	XOR	A			; STATUS = OK
	LD	(IY+HDSK_STAT),A	; SAVE IT

	RET
;
;
;
HDSK_PRT:
	CALL	NEWLINE

	LD	DE,HDSKSTR_PREFIX
	CALL	WRITESTR

	CALL	PC_SPACE
	LD	DE,HDSKSTR_CMD
	CALL	WRITESTR
	LD	A,(HDSK_CMD)
	CALL	PRTHEXBYTE

	CALL	PC_SPACE
	CALL	PC_LBKT
	LD	A,(HDSK_CMD)
	LD	DE,HDSKSTR_NONE
	CP	HDSK_CMDNONE
	JP	Z,HDSK_PRTCMD
	LD	DE,HDSKSTR_RESET
	CP	HDSK_CMDRESET
	JP	Z,HDSK_PRTCMD
	LD	DE,HDSKSTR_READ
	CP	HDSK_CMDREAD
	JP	Z,HDSK_PRTCMD
	LD	DE,HDSKSTR_WRITE
	CP	HDSK_CMDWRITE
	JP	Z,HDSK_PRTCMD
	LD	DE,HDSKSTR_PARAM
	CP	HDSK_CMDPARAM
	JP	Z,HDSK_PRTCMD
	LD	DE,HDSKSTR_UNKCMD
HDSK_PRTCMD:
	CALL	WRITESTR
	CALL	PC_RBKT

	LD	A,(HDSK_CMD)
	CP	HDSK_CMDREAD
	JR	Z,HDSK_PRTRW
	CP	HDSK_CMDWRITE
	JR	Z,HDSK_PRTRW
	RET

HDSK_PRTRW:
	CALL	PC_SPACE
	LD	A,(HDSK_DRV)
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	LD	BC,(HDSK_TRK)
	CALL	PRTHEXWORD
	CALL	PC_SPACE
	LD	A,(HDSK_SEC)
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	LD	BC,(HDSK_DMA)
	CALL	PRTHEXWORD

	CALL	PC_SPACE
	LD	DE,HDSKSTR_ARROW
	CALL	WRITESTR

	CALL	PC_SPACE
	LD	DE,HDSKSTR_RC
	CALL	WRITESTR
	LD	A,(HDSK_RC)
	CALL	PRTHEXBYTE

	CALL	PC_SPACE
	CALL	PC_LBKT
	LD	A,(HDSK_RC)
	LD	DE,HDSKSTR_STOK
	CP	HDSK_STOK
	JP	Z,HDSK_PRTRC
	LD	DE,HDSKSTR_STUNK

HDSK_PRTRC:
	CALL	WRITESTR
	CALL	PC_RBKT

	RET
;
;
;
HDSKSTR_PREFIX	.TEXT	"HDSK:$"
HDSKSTR_CMD	.TEXT	"CMD=$"
HDSKSTR_RC	.TEXT	"RC=$"
HDSKSTR_ARROW	.TEXT	"-->$"
HDSKSTR_NONE	.TEXT	"NONE$"
HDSKSTR_RESET	.TEXT	"RESET$"
HDSKSTR_READ	.TEXT	"READ$"
HDSKSTR_WRITE	.TEXT	"WRITE$"
HDSKSTR_PARAM	.TEXT	"PARAM$"
HDSKSTR_UNKCMD	.TEXT	"UNKCMD$"
HDSKSTR_STOK	.TEXT	"OK$"
HDSKSTR_STUNK	.TEXT	"UNKNOWN ERROR$"
;
;==================================================================================================
;   HDSK DISK DRIVER - DATA
;==================================================================================================
;
HDSK_RC		.DB	0		; CURRENT RETURN CODE
HDSK_CURDEV	.DB	0		; CURRENT DEVICE NUMBER
;
HDSK_PARMBLK:
HDSK_CMD	.DB	0		; COMMAND (HDSK_READ, HDSK_WRITE, ...)
HDSK_DRV	.DB	0		; 0..7, HDSK DRIVE NUMBER
HDSK_SEC	.DB	0		; 0..255 SECTOR
HDSK_TRK	.DW	0		; 0..2047 TRACK
HDSK_DMA	.DW	0		; ADDRESS FOR SECTOR DATA EXCHANGE
