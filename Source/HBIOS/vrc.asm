;======================================================================
;	VIDEO DRIVER FOR VGARC
;	https://www.retrobrewcomputers.org/doku.php?id=builderpages:plasmo:vgarc1:vgarc1home
;
;	WRITTEN BY: WAYNE WARTHEN -- 5/1/2023
;======================================================================
;
; TODO:
;
;======================================================================
; VGARC DRIVER - CONSTANTS
;======================================================================
;
VRC_BASE	.EQU	$00		; FIRST CHAR DATA PORT
VRC_FONTBASE	.EQU	VRC_BASE + $0C	; FIRST FONT PORT
VRC_SCROLLIO	.EQU	$F5		; SCROLL REG PORT
;
VRC_KBDDATA	.EQU	$F4
VRC_KBDST	.EQU	$F5
;
VRC_ROWS	.EQU	48
VRC_COLS	.EQU	64
;
#DEFINE USEFONTVGARC
#DEFINE	VRC_FONT FONTVGARC
;
TERMENABLE	.SET	TRUE		; INCLUDE TERMINAL PSEUDODEVICE DRIVER
;
		.ECHO	"VRC: IO="
		.ECHO	VRC_BASE
		.ECHO	", KBD MODE=VRC"
		.ECHO	", KBD IO="
		.ECHO	VRC_KBDDATA
		.ECHO	"\n"
;
;======================================================================
; VRC DRIVER - INITIALIZATION
;======================================================================
;
VRC_INIT:
	LD	IY,VRC_IDAT		; POINTER TO INSTANCE DATA
;
	CALL	NEWLINE			; FORMATTING
	PRTS("VRC: IO=0x$")
	LD	A,VRC_BASE
	CALL	PRTHEXBYTE
	CALL	VRC_PROBE		; CHECK FOR HW PRESENCE
	JR	Z,VRC_INIT1		; CONTINUE IF HW PRESENT
;
	; HARDWARE NOT PRESENT
	PRTS(" NOT PRESENT$")
	OR	$FF			; SIGNAL FAILURE
	RET
;
VRC_INIT1:
	; RECORD DRIVER ACTIVE
	OR	$FF
	LD	(VRC_ACTIVE),A
	; DISPLAY CONSOLE DIMENSIONS
	LD	A,VRC_COLS
	CALL	PC_SPACE
	CALL	PRTDECB
	LD	A,'X'
	CALL	COUT
	LD	A,VRC_ROWS
	CALL	PRTDECB
	PRTS(" TEXT$")

	; HARDWARE INITIALIZATION
	CALL 	VRC_CRTINIT		; SETUP THE VGARC CHIP REGISTERS
	CALL	VRC_LOADFONT		; LOAD FONT DATA FROM ROM TO VGARC STORAGE
	CALL	VRC_VDARES		; RESET
	CALL	KBD_INIT		; INITIALIZE KEYBOARD DRIVER

	; ADD OURSELVES TO VDA DISPATCH TABLE
	LD	BC,VRC_FNTBL		; BC := FUNCTION TABLE ADDRESS
	LD	DE,VRC_IDAT		; DE := VGARC INSTANCE DATA PTR
	CALL	VDA_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED

	; INITIALIZE EMULATION
	LD	C,A			; C := ASSIGNED VIDEO DEVICE NUM
	LD	DE,VRC_FNTBL		; DE := FUNCTION TABLE ADDRESS
	LD	HL,VRC_IDAT		; HL := VGARC INSTANCE DATA PTR
	CALL	TERM_ATTACH		; DO IT

	XOR	A			; SIGNAL SUCCESS
	RET
;
;======================================================================
; VGARC DRIVER - VIDEO DISPLAY ADAPTER (VDA) FUNCTIONS
;======================================================================
;
VRC_FNTBL:
	.DW	VRC_VDAINI
	.DW	VRC_VDAQRY
	.DW	VRC_VDARES
	.DW	VRC_VDADEV
	.DW	VRC_VDASCS
	.DW	VRC_VDASCP
	.DW	VRC_VDASAT
	.DW	VRC_VDASCO
	.DW	VRC_VDAWRC
	.DW	VRC_VDAFIL
	.DW	VRC_VDACPY
	.DW	VRC_VDASCR
	.DW	KBD_STAT
	.DW	KBD_FLUSH
	.DW	KBD_READ
	.DW	VRC_VDARDC
#IF (($ - VRC_FNTBL) != (VDA_FNCNT * 2))
	.ECHO	"*** INVALID VRC FUNCTION TABLE ***\n"
	!!!!!
#ENDIF

VRC_VDAINI:
	; RESET VDA
	; CURRENTLY IGNORES VIDEO MODE AND BITMAP DATA
	CALL	VRC_VDARES	; RESET VDA
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDAQRY:
	LD	C,$00		; MODE ZERO IS ALL WE KNOW
	LD	D,VRC_ROWS	; ROWS
	LD	E,VRC_COLS	; COLS
	LD	HL,0		; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED YET
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDARES:
	XOR	A		; CLEAR ATTRIBUTES (REV VIDEO OFF)
	LD	(VRC_ATTR),A	; SAVE IT
	DEC	A		; INIT CUR NESTING, INIT TO HIDDEN
	LD	(VRC_CURSOR),A	; SAVE IT
	LD	HL,0		; ZERO THE SCROLL OFFSET
	LD	(VRC_OFF),HL	; SAVE VALUE
	XOR	A		; ZERO
	LD	(VRC_LOFF),A	; SCROLL OFFSET (LINES)
	LD	A,' '		; BLANK THE SCREEN
	LD	DE,VRC_ROWS*VRC_COLS	; FILL ENTIRE BUFFER
	CALL	VRC_FILL	; DO IT
	LD	DE,0		; ROW = 0, COL = 0
	CALL	VRC_XY		; SEND CURSOR TO TOP LEFT
	CALL	VRC_SHOWCUR	; NOW SHOW THE CURSOR
;
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDADEV:
	LD	D,VDADEV_VRC	; D := DEVICE TYPE
	LD	E,0		; E := PHYSICAL UNIT IS ALWAYS ZERO
	LD	H,0		; H := 0, DRIVER HAS NO MODES
	LD	L,VRC_BASE	; L := BASE I/O ADDRESS
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDASCS:
	SYSCHKERR(ERR_NOTIMPL)	; NOT IMPLEMENTED (YET)
	RET

VRC_VDASCP:
	CALL	VRC_XY		; SET CURSOR POSITION
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDASAT:
	; INCOMING IS:  -----RUB (R=REVERSE, U=UNDERLINE, B=BLINK)
	;
	; ALL WE SUPPORT IS REVERSE.  MOVE BIT TO BIT 7 OF ATTR BYTE
	LD	A,E		; GET ATTR VALUE
	RRCA			; ROTATE TO BIT 7
	RRCA
	RRCA
	AND	$80		; ENSURE ONLY BIT 7
	LD	(VRC_ATTR),A	; SAVE IT
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE

VRC_VDASCO:
	; INCOMING IS:  IBGRIBGR (I=INTENSITY, B=BLUE, G=GREEN, R=RED)
	;
	; NONE SUPPORTED, IGNORE
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE

VRC_VDAWRC:
	LD	A,E		; CHARACTER TO WRITE GOES IN A
	CALL	VRC_PUTCHAR	; PUT IT ON THE SCREEN
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDAFIL:
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	VRC_FILL	; DO THE FILL
	XOR	A		; SIGNAL SUCCESS
	RET

VRC_VDACPY:
	; LENGTH IN HL, SOURCE ROW/COL IN DE, DEST IS VRC_POS
	; BLKCPY USES: HL=SOURCE, DE=DEST, BC=COUNT
	PUSH	HL		; SAVE LENGTH
	CALL	VRC_XY2IDX	; ROW/COL IN DE -> SOURCE ADR IN HL
	POP	BC		; RECOVER LENGTH IN BC
	LD	DE,(VRC_POS)	; PUT DEST IN DE
	JP	VRC_BLKCPY	; DO A BLOCK COPY

VRC_VDASCR:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	RET	Z		; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,VRC_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	VRC_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	VRC_VDASCR	; LOOP
VRC_VDASCR1:
	CALL	VRC_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	VRC_VDASCR	; LOOP

;----------------------------------------------------------------------
; READ VALUE AT CURRENT VDU BUFFER POSITION
; RETURN E = CHARACTER, B = COLOUR, C = ATTRIBUTES
;----------------------------------------------------------------------

VRC_VDARDC:
	OR	$FF		; UNSUPPORTED FUNCTION
	RET
;
;======================================================================
; VGARC DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;
;----------------------------------------------------------------------
; PROBE FOR VGARC HARDWARE
;----------------------------------------------------------------------
;
; ON RETURN, ZF SET INDICATES HARDWARE FOUND
;
VRC_PROBE:
	LD	C,VRC_BASE + 1		; +1 AVOIDS LEDS
	LD	B,$00
	LD	A,$AA
	OUT	(C),A
	INC	B
	LD	A,$55
	OUT	(C),A
	DEC	B
	IN	A,(C)
	CP	$AA
	RET	NZ
	INC	B
	IN	A,(C)
	CP	$55
	RET
;
;----------------------------------------------------------------------
; CRTC DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
VRC_CRTINIT:
	XOR	A			; ZERO ACCUM
	LD	A,$80			; ACTIVATE AND ZERO HW SCROLL
	OUT	(VRC_SCROLLIO),A	; RESET HW SCROLL
	RET				; DONE
;
;----------------------------------------------------------------------
; LOAD FONT DATA
;----------------------------------------------------------------------
;
VRC_LOADFONT:
;
#IF USELZSA2
	LD	(VRC_STACK),SP		; SAVE STACK
	LD	HL,(VRC_STACK)		; AND SHIFT IT
	LD	DE,$2000		; DOWN 4KB TO
	OR	A			; CREATE A
	SBC	HL,DE			; DECOMPRESSION BUFFER
	LD	SP,HL			; HL POINTS TO BUFFER
	EX	DE,HL			; START OF STACK BUFFER
	PUSH	DE			; SAVE IT
	LD	HL,VRC_FONT		; START OF FONT DATA
	CALL	DLZSA2			; DECOMPRESS TO DE
	POP	HL			; RECALL STACK BUFFER POSITION
#ELSE
	LD	HL,VRC_FONT		; START OF FONT DATA
#ENDIF
;
#IF 0
	; THIS APPROACH TO LOADING FONTS IS BEST (FASTEST), BUT IS
	; CAUSING ARTIFACTS ON THE DISPLAYED FONTS WHEN RUN ON A
	; Z280.  IT IS NOT CLEAR WHAT THE PROBLEM IS (POSSIBLY
	; Z280 BUG), BUT FOR NOW WE AVOID THIS AND USE AN
	; ALTERNATIVE APPROACH BELOW.
	LD	DE,0+(128*8)-1		; LENGTH OF FONT DATA - 1
	ADD	HL,DE			; ADD TO HL
	LD	BC,VRC_FONTBASE+3	; WORK BACKWARDS
	OTDR				; DO 4 PAGES
	DEC	C
	OTDR
	DEC	C
	OTDR
	DEC	C
	OTDR
	DEC	C
#ENDIF
;
#IF 1
	; ALTERNATIVE APPROACH TO LOADING FONTS.  THIS ONE AVOIDS
	; THE USE OF OTDR WHICH SEEMS TO CAUSE PROBLEMS ON Z280.
	LD	B,0
	LD	C,VRC_FONTBASE
VRC_LOADFONT1:
	LD	A,(HL)
	OUT	(C),A
	INC	HL
	INC	B
	JR	NZ,VRC_LOADFONT1
	INC	C
	LD	A,C
	CP	VRC_FONTBASE + 4
	JR	NZ,VRC_LOADFONT1
#ENDIF
;
#IF USELZSA2
	LD	HL,(VRC_STACK)		; ERASE DECOMPRESS BUFFER
	LD	SP,HL			; BY RESTORING THE STACK
	RET				; DONE
VRC_STACK	.DW	0
#ELSE
	RET
#ENDIF
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
VRC_XY:
	PUSH	DE			; SAVE NEW POSITION FOR NOW
	CALL	VRC_HIDECUR		; HIDE THE CURSOR
	POP	DE			; RECOVER INCOMING ROW/COL
	CALL	VRC_XY2IDX		; CONVERT ROW/COL TO BUF IDX
	LD	(VRC_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
	JP	VRC_SHOWCUR		; SHOW THE CURSOR AND EXIT
;
;----------------------------------------------------------------------
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;----------------------------------------------------------------------
;
VRC_XY2IDX:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,VRC_COLS		; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET, H * E = HL, E=0, B=0
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN

	LD	DE,(VRC_OFF)		; SCREEN OFFSET
	ADD	HL,DE			; ADJUST
;
	PUSH	HL			; SAVE IT
	LD	DE,VRC_ROWS * VRC_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VRC_XY2IDX1		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	RET				; DONE
VRC_XY2IDX1:
	POP	HL			; NO WRAP, RESTORE
	RET				; RETURN
;
;----------------------------------------------------------------------
; SHOW OR HIDE CURSOR
;----------------------------------------------------------------------
;
; VGARC USES HIGH BIT OF CHAR VALUE FOR INVERSE VIDEO.  WE HAVE NO
; HARDWARE CURSOR, SO WE LEVERAGE THE INVERSE VIDEO TO SHOW A CURSOR.
; SINCE ANY OPERATION THAT POTENTIALLY OVERWERITES THE CURSOR POSITION
; COULD DESTROY THE CURSOR, WE HAVE A COUPLE FUNCTIONS TO SHOW AND
; HIDE THE CURSOR.  A VARIABLE IS USED TO TRACK THE SHOW/HIDE
; OPERATIONS BECAUSE WE MAY HAVE NESTED CALLS.  ZERO MEANS SHOW
; REAL CURSOR.  ANY VALUE LESS THAN ZERO MEANS HIDDEN.
;
VRC_SHOWCUR:
	LD	A,(VRC_CURSOR)		; GET CURRENT NESTING VALUE
	INC	A			; INCREMENT TO SHOW
	LD	(VRC_CURSOR),A		; SAVE IT
	RET	NZ			; ALREADY SHOWN, NOTHING TO DO
;
	; WE TRANSITIONED FROM NON-ZERO TO ZERO.  NEED TO ACTUALLY
	; SHOW THE CURSOR NOW.
;
	JR	VRC_FLIPCUR
;
VRC_HIDECUR:
	LD	A,(VRC_CURSOR)		; GET CURRENT NESTING VALUE
	DEC	A			; DECREMENT TO HIDE
	LD	(VRC_CURSOR),A		; SAVE IT
	INC	A			; BACK TO ORIGINAL VALUE
	RET	NZ			; ALREADY HIDDEN, NOTHING TO DO
;
	; WE TRANSITIONED FROM ZERO TO NEGATIVE.  NEED TO ACTUALLY
	; HIDE THE CURSOR NOW.  SINCE SHOWING AND HIDING ARE THE
	; SAME OPERATION (FLIP REV VID BIT), WE REUSE CODE ABOVE.
;
	JR	VRC_FLIPCUR
;
VRC_FLIPCUR:
	; SHOWING OR HIDING THE CURSOR IS THE SAME OPERATION.
	; SO WE USE COMMON CODE TO FLIP THE REV VID BIT.
	LD	HL,(VRC_POS)		; CURSOR POSITION
	LD	B,L			; INVERT FOR I/O
	LD	C,H
	IN	A,(C)			; GET VALUE
	XOR	$80			; FLIP REV VID BIT
	OUT	(C),A			; WRITE NEW VALUE
	RET
;
;----------------------------------------------------------------------
; WRITE VALUE IN A TO CURRENT VDU BUFFER POSITION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
VRC_PUTCHAR:
	; WRITE CHAR AT CURRENT CURSOR POSITION.  SINCE THE CURSOR
	; IS JUST THE HIGH BIT (REV VIDEO), WE FIRST TURN OFF THE
	; CURSOR, WRITE THE CHAR, UPDATE THE CURSOR POSITION, AND
	; FINALLY TURN THE CURSOR BACK ON AT THE NEW POSITION.
;
	PUSH	AF			; SAVE INCOMING CHAR
	CALL	VRC_HIDECUR		; HIDE CURSOR
	POP	AF
	LD	HL,(VRC_POS)		; GET CUR BUF POSITION
	LD	B,L			; INVERT FOR I/O
	LD	C,H
	AND	$7F			; SUPPRESS ATTRIBUTE (HI BIT)
	LD	L,A			; PUT VALUE IN L
	LD	A,(VRC_ATTR)		; GET CURRENT ATTRIBUTE
	OR	L			; COMBINE WITH CHAR VALUE
	OUT	(C),A			; WRITE VALUE TO BUFFER
;
	; SET CURSOR AT NEW POSITION
	LD	HL,(VRC_POS)		; GET CURRENT BUF OFFSET
	INC	HL			; INCREMENT
	PUSH	HL			; SAVE IT
	LD	DE,VRC_ROWS * VRC_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VRC_PUTCHAR1		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	LD	HL,0			; BACK TO START
	JR	VRC_PUTCHAR2		; CONTINUE
VRC_PUTCHAR1:
	POP	HL			; NO WRAP, RESTORE
VRC_PUTCHAR2:
	LD	(VRC_POS),HL		; SAVE NEW POSITION
	JP	VRC_SHOWCUR		; SHOW IT AND RETURN
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
VRC_FILL:
	LD	(VRC_FILL1+1),A		; SAVE FILL CHAR
	PUSH	DE			; SAVE INCOMING DE
	CALL	VRC_HIDECUR		; HIDE CURSOR
	POP	DE			; RESTORE INCOMING DE
	LD	HL,(VRC_POS)		; STARTING POSITION
;
VRC_FILL1:
	LD	A,$FF			; FILL CHAR
	LD	B,L			; INVERT FOR I/O
	LD	C,H
	OUT	(C),A			; PUT CHAR TO BUF
;
	DEC	DE			; DECREMENT COUNT
	LD	A,D			; TEST FOR ZERO
	OR	E
	JP	Z,VRC_SHOWCUR		; EXIT VIA SHOW CURSOR IF DONE
;
	INC	HL			; INCREMENT
	PUSH	HL			; SAVE IT
	LD	BC,VRC_ROWS * VRC_COLS	; BC := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,BC			; SUBTRACT FROM HL
	JR	C,VRC_FILL2		; BYPASS IF NO WRAP
	POP	BC			; THROW AWAY TOS
	LD	HL,0			; BACK TO START
	JR	VRC_FILL3		; CONTINUE
VRC_FILL2:
	POP	HL			; NO WRAP, RESTORE
VRC_FILL3:
	LD	(VRC_POS),HL		; SAVE NEW POSITION
	JR	VRC_FILL1		; LOOP TILL DONE
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VRC_SCROLL:
	; SCROLL DOWN 1 LINE VIA HARDWARE
	CALL	VRC_HIDECUR		; SUPPRESS CURSOR
	LD	A,(VRC_LOFF)		; GET LINE OFFSET
	INC	A			; BUMP
	CP	VRC_ROWS		; OVERFLOW?
	JR	C,VRC_SCROLL1		; IF NOT, SKIP
	XOR	A			; ELSE, BACK TO ZERO
VRC_SCROLL1:
	LD	(VRC_LOFF),A		; SAVE NEW VALUE
	OR	$80			; SET HW SCROLL ENABLE BIT
	OUT	(VRC_SCROLLIO),A	; DO IT
;
	; ADJUST BUFFER OFFSET
	LD	HL,(VRC_OFF)		; BUFFER OFFSET
	LD	DE,VRC_COLS		; COLUMNS
	ADD	HL,DE			; ADD TO GET NEW OFFSET
	PUSH	HL			; SAVE IT
	LD	DE,VRC_ROWS * VRC_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VRC_SCROLL2		; BYPASS IF NO WRAP
	POP	DE			; BURN TOS
	JR	VRC_SCROLL3		; CONTINUE
VRC_SCROLL2:
	POP	HL			; NO WRAP, RESTORE HL
VRC_SCROLL3:
	LD	(VRC_OFF),HL		; SAVE NEW OFFSET
;
	; FILL EXPOSED LINE
	LD	HL,(VRC_POS)		; GET CURSOR POS
	PUSH	HL			; SAVE IT
	LD	D,VRC_ROWS - 1		; LAST ROW
	LD	E,0			; FIRST COLUMN
	CALL	VRC_XY2IDX		; HL = START OF LAST LINE
	LD	(VRC_POS),HL		; SET FILL POSITION
	LD	A,' '			; FILL WITH BLANKS
	LD	DE,VRC_COLS		; FILL ONE LINE
	CALL	VRC_FILL		; FILL LAST LINE
	POP	HL			; RECOVER CURSOR POS
	LD	(VRC_POS),HL		; PUT VALUE BACK
;
	; ADJUST CURSOR POSITION 
	LD	HL,(VRC_POS)		; CURSOR POSITION
	LD	DE,VRC_COLS		; COLUMNS
	ADD	HL,DE			; NEW CURSOR POS
	PUSH	HL			; SAVE IT
	LD	DE,VRC_ROWS * VRC_COLS	; DE := DISPLAY SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VRC_SCROLL4		; BYPASS IF NO WRAP
	POP	DE			; BURN TOS
	JR	VRC_SCROLL5		; CONTINUE
VRC_SCROLL4:
	POP	HL			; NO WRAP, RESTORE HL
VRC_SCROLL5:
	LD	(VRC_POS),HL		; SAVE NEW CURSOR POS
	JP	VRC_SHOWCUR		; EXIT VIA SHOW CURSOR
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VRC_RSCROLL:
	; SCROLL UP 1 LINE VIA HARDWARE
	CALL	VRC_HIDECUR		; SUPPRESS CURSOR
	LD	A,(VRC_LOFF)		; GET LINE OFFSET
	DEC	A			; BUMP
	CP	$FF			; OVERFLOW?
	JR	NZ,VRC_RSCROLL1		; IF NOT, SKIP
	LD	A,VRC_ROWS - 1		; ELSE, BACK TO LAST ROW
VRC_RSCROLL1:
	LD	(VRC_LOFF),A		; SAVE NEW VALUE
	OR	$80			; SET HW SCROLL ENABLE BIT
	OUT	(VRC_SCROLLIO),A	; DO IT
;
	; ADJUST BUFFER OFFSET
	LD	HL,(VRC_OFF)		; BUFFER OFFSET
	LD	DE,VRC_COLS		; COLUMNS
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT TO GET NEW OFFSET
	PUSH	HL			; SAVE IT
	JR	NC,VRC_RSCROLL2		; BYPASS IF NO WRAP
	LD	DE,VRC_ROWS * VRC_COLS	; DISPLAY SIZE
	ADD	HL,DE			; HANDLE WRAP
	POP	DE			; BURN TOS
	JR	VRC_RSCROLL3		; CONTINUE
VRC_RSCROLL2:
	POP	HL			; NO WRAP, RESTORE HL
VRC_RSCROLL3:
	LD	(VRC_OFF),HL		; SAVE NEW OFFSET
;
	; FILL EXPOSED LINE
	LD	HL,(VRC_POS)		; GET CURSOR POS
	PUSH	HL			; SAVE IT
	LD	D,0			; FIRST ROW
	LD	E,0			; FIRST COLUMN
	CALL	VRC_XY2IDX		; HL = START OF FIRST LINE
	LD	(VRC_POS),HL		; SET FILL POSITION
	LD	A,' '			; FILL WITH BLANKS
	LD	DE,VRC_COLS		; FILL ONE LINE
	CALL	VRC_FILL		; FILL FIRST LINE
	POP	HL			; RECOVER CURSOR POS
	LD	(VRC_POS),HL		; PUT VALUE BACK
;
	; ADJUST CURSOR POSITION 
	LD	HL,(VRC_POS)		; CURSOR POSITION
	LD	DE,VRC_COLS		; COLUMNS
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; NEW CURSOR POS
	PUSH	HL			; SAVE IT
	JR	NC,VRC_RSCROLL4		; BYPASS IF NO WRAP
	LD	DE,VRC_ROWS * VRC_COLS	; DISPLAY SIZE
	ADD	HL,DE			; HANDLE WRAP
	POP	DE			; BURN TOS
	JR	VRC_RSCROLL5		; CONTINUE
VRC_RSCROLL4:
	POP	HL			; NO WRAP, RESTORE HL
VRC_RSCROLL5:
	LD	(VRC_POS),HL		; SAVE NEW CURSOR POS
	JP	VRC_SHOWCUR		; EXIT VIA SHOW CURSOR
;
;----------------------------------------------------------------------
; BLOCK COPY BC BYTES FROM HL TO DE
;----------------------------------------------------------------------
;
VRC_BLKCPY:
	PUSH	BC
	PUSH	HL
	CALL	VRC_HIDECUR
	POP	HL
	POP	BC
;
VRC_BLKCPY1:
	LD	A,B
	OR	C
	JP	Z,VRC_SHOWCUR		; EXIT VIA SHOW CURSOR
;
	PUSH	BC			; SAVE LOOP CTL
	LD	B,L			; INVERT FOR I/O
	LD	C,H
	IN	A,(C)			; GET SOURCE CHAR
	LD	B,E			; INVERT FOR I/O
	LD	C,D
	OUT	(C),A			; WRITE DEST CHAR
	POP	BC			; RESTORE LOOP CTL
;
	INC	HL			; NEXT SRC CHAR
	INC	DE			; NEXT DEST CHAR
	DEC	BC			; DEC COUNT
	JR	VRC_BLKCPY1		; LOOP TILL DONE
;
;==================================================================================================
;   VGARC DRIVER - DATA
;==================================================================================================
;
VRC_ATTR	.DB	0	; CURRENT COLOR
VRC_POS		.DW 	0	; CURRENT DISPLAY POSITION
VRC_OFF		.DW	0	; SCREEN START OFFSET INTO DISP BUF
VRC_LOFF	.DB	0	; LINE OFFSET INTO DISP BUF
VRC_CURSOR	.DB	0	; CURSOR NESTING LEVEL
VRC_ACTIVE	.DB	FALSE	; FLAG FOR DRIVER ACTIVE
;
;==================================================================================================
;   VGA DRIVER - INSTANCE DATA
;==================================================================================================
;
VRC_IDAT:
	.DB	KBDMODE_VRC	; VGARC KEYBOARD CONTROLLER
	.DB	VRC_KBDST
	.DB	VRC_KBDDATA
