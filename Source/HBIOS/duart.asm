;
;==================================================================================================
; DUART DRIVER (SERIAL PORT)
;==================================================================================================
;
;  SETUP PARAMETER WORD:
;  +-------+---+-------------------+ +---+---+-----------+---+-------+
;  |       |RTS| ENCODED BAUD RATE | |DTR|XON|  PARITY   |STP| 8/7/6 |
;  +-------+---+---+---------------+ ----+---+-----------+---+-------+
;    F   E   D   C   B   A   9   8     7   6   5   4   3   2   1   0
;       -- MSB (D REGISTER) --           -- LSB (E REGISTER) --
;
;  MODE REGISTER 1
;
;    D7      D6      D5      D4      D3      D2      D1      D0
;  +-------+-------+-------+-------+-------+-------+-------+-------+
;  | RXRTS | RXINT | EMODE |  PARITY MODE  |  SEL  |   BITS/CHAR   |
;  +-------+-------+-------+-------+-------+-------+-------+-------+
;
;	RXRTS:	AUTOMATIC CONTROL OF /RTS BY RECEIVER
;		0 = NO
;		1 = YES
;	RXINT:	RECEIVE INTERRUPT SELECT
;		0 = RXRDY
;		1 = FFULL
;	EMODE:	ERROR MODE
;		0 = BY CHARACTER
;		1 = BY BLOCK
;	PARITY MODE:
;		00 = WITH PARITY
;		01 = FORCE PARITY
;		10 = NO PARITY
;		11 = MULTIDROP MODE
;	SEL:	PARITY TYPE
;		0 = EVEN / SPACE
;		1 = ODD / MARK
;	BITS/CHAR:
;		00 = 5
;		01 = 6
;		10 = 7
;		11 = 8
;
;  MODE REGISTER 2
;
;    D7      D6      D5      D4      D3      D2      D1      D0
;  +-------+-------+-------+-------+-------+-------+-------+-------+
;  | CHANNEL MODE  | TXRTS | TXCTS |        STOP BIT LENGTH        |
;  +-------+-------+-------+-------+-------+-------+-------+-------+
;
;	CHANNEL MODE:
;		00 = NORMAL
;		01 = AUTO-ECHO
;		10 = LOCAL LOOP
;		11 = REMOTE LOOP
;	TXRTS:	AUTOMATIC CONTROL OF /RTS BY TRANSMITTER
;		0 = NO
;		1 = YES
;	TXCTS:	AUTOMATIC CONTROL OF TRANSMITTER BY /CTS
;		0 = NO
;		1 = YES
;	STOP BIT LENGTH:
;		0 =  9/16
;		1 = 10/16 = 5/8
;		2 = 11/16
;		3 = 12/16 = 3/4
;		4 = 13/16
;		5 = 14/16 = 7/8
;		6 = 15/16
;		7 = 16/16 =   1
;		8-F = LENGTHS OF 0-7 PLUS ONE
;		IF BITS/CHAR = 5 THEN ADD AN ADDITIONAL HALF BIT
;
DUART_DEBUG		.EQU	FALSE
;
DUART_NONE		.EQU	0		; UNKNOWN OR NOT PRESENT
DUART_2681		.EQU	1		; OLD '681 WITHOUT IVR/GPR
DUART_26C92		.EQU	2		; '92 WITH MR0
DUART_XR88C681		.EQU	3		; EXAR/MAXLINEAR CHIP WITH Z-MODE
;
DUART_BAUD_INV		.EQU	$FF		; INVALID BAUD RATE
DUART_BAUD_ACR7		.EQU	%10000000	; ACR BIT 7 = 1
DUART_BAUD_X1		.EQU	%01000000	; BRG EXTEND BIT = 1 ('681)
DUART_BAUD_EXT1		.EQU	%00100000	; EXTENDED TABLE 1 ('92)
DUART_BAUD_EXT2		.EQU	%00010000	; EXTENDED TABLE 2 ('92)
;
; PER CHANNEL REGISTERS (CHANNEL A AT OFFSET 0, CHANNEL B AT OFFSET 8)
;
DUART_MR		.EQU	$00		; MODE REGISTER (R/W)
DUART_SR		.EQU	$01		; STATUS REGISTER (READ)
DUART_CSR		.EQU	$01		; CLOCK SELECT REGISTER (WRITE)
DUART_CR		.EQU	$02		; COMMAND REGISTER (WRITE)
DUART_RX		.EQU	$03		; RECEIVER HOLDING REGISTER (READ)
DUART_TX		.EQU	$03		; TRANSMITTER HOLDING REGISTER (WRITE)
;
; PER CHIP REGISTERS
;
DUART_IPCR		.EQU	$04		; INPUT PORT CHANGE REGISTER (READ)
DUART_ACR		.EQU	$04		; AUXILLIARY CONTROL REGISTER (WRITE)
DUART_ISR		.EQU	$05		; INTERRUPT STATUS REGISTER (READ)
DUART_IMR		.EQU	$05		; INTERRUPT MASK REGISTER (WRITE)
DUART_CTU		.EQU	$06		; COUNTER/TIMER UPPER BYTE REGISTER (R/W)
DUART_CTL		.EQU	$07		; COUNTER/TIMER LOWER BYTE REGISTER (R/W)
DUART_GPR		.EQU	$0C		; GENERAL PURPOSE REGISTER (R/W)
DUART_IVR		.EQU	$0C		; INTERRUPT VECTOR REGISTER (R/W)
DUART_IPR		.EQU	$0D		; INPUT PORT REGISTER (READ)
DUART_OPCR		.EQU	$0D		; OUTPUT PORT CONFIGURATION REGISTER (WRITE)
DUART_STCR		.EQU	$0E		; START COUNTER/TIMER COMMAND (READ)
DUART_SOPR		.EQU	$0E		; SET OUTPUT PORT REGISTER (WRITE)
DUART_SPCR		.EQU	$0F		; STOP COUNTER/TIMER COMMAND (READ)
DUART_ROPR		.EQU	$0F		; RESET OUTPUT PORT REGISTER (WRITE)
;
; COMMAND REGISTER
;
DUART_CR_ENA_RX		.EQU	%00000100	; ENABLE RECEIVER
DUART_CR_DIS_RX		.EQU	%00001000	; DISABLE RECEIVER
DUART_CR_ENA_TX		.EQU	%00000001	; ENABLE TRANSMITTER
DUART_CR_DIS_TX		.EQU	%00000010	; DISABLE TRANSMITTER
DUART_CR_NOP		.EQU	$00		; NULL COMMAND
DUART_CR_MR1		.EQU	$10		; RESET MR POINTER TO MR1
DUART_CR_RESET_RX	.EQU	$20		; RESET RECEIVER
DUART_CR_RESET_TX	.EQU	$30		; RESET TRANSMITTER
DUART_CR_RESET_ERR	.EQU	$40		; RESET ERROR STATUS
DUART_CR_RESET_BRK	.EQU	$50		; RESET BREAK STATUS
DUART_CR_START_BRK	.EQU	$60		; START BREAK
DUART_CR_STOP_BRK	.EQU	$70		; STOP BREAK
DUART_CR_SET_RX_X	.EQU	$80		; SET RECEIVER BRG EXTEND BIT (X=1)
DUART_CR_CLR_RX_X	.EQU	$90		; CLEAR RECEIVER BRG EXTEND BIT (X=0)
DUART_CR_SET_TX_X	.EQU	$A0		; SET TRANSMITTER BRG EXTEND BIT (X=1)
DUART_CR_CLR_TX_X	.EQU	$B0		; CLEAR TRANSMITTER BRG EXTEND BIT (X=0)
DUART_CR_MR0		.EQU	$B0		; RESET MR POINTER TO MR0 (26C92 ONLY)
DUART_CR_STANDBY	.EQU	$C0		; SET STANDBY MODE (CHANNEL A ONLY)
DUART_CR_RESET_IUS	.EQU	$C0		; RESET IUS LATCH (CHANNEL B ONLY)
DUART_CR_ACTIVE		.EQU	$D0		; SET ACTIVE MODE (CHANNEL A ONLY)
DUART_CR_ZMODE		.EQU	$D0		; SET Z-MODE (CHANNEL B ONLY)
;
; DUART STATUS REGISTER
;
DUART_SR_RXRDY		.EQU	%00000001	; RECEIVER READY
DUART_SR_RXFULL		.EQU	%00000010	; RECEIVE FIFO FULL
DUART_SR_TXRDY		.EQU	%00000100	; TRANSMITTER READY
DUART_SR_TXEMPTY	.EQU	%00001000	; TRANSMITTER FIFO EMPTY
DUART_SR_OVERRUN	.EQU	%00010000	; OVERRUN ERROR
DUART_SR_PARITY		.EQU	%00100000	; PARITY ERROR
DUART_SR_FRAMING	.EQU	%01000000	; FRAMING ERROR
DUART_SR_BREAK		.EQU	%10000000	; RECEIVED BREAK
;
; DUART MODE REGISTER 0
;
DUART_MR0_NORMAL	.EQU	%00000000	; NORMAL BAUD RATE TABLE
DUART_MR0_EXT1		.EQU	%00000001	; EXTENDED BAUD RATE TABLE 1
DUART_MR0_EXT2		.EQU	%00000100	; EXTENDED BAUD RATE TABLE 2
;
; DUART MODE REGISTER 1
;
DUART_MR1_RXRTS		.EQU	%10000000	; RECEIVER CONTROLS RTS
DUART_MR1_PARNONE	.EQU	%00010000	; NO PARITY
DUART_MR1_PARODD	.EQU	%00000100	; ODD PARITY
DUART_MR1_PAREVEN	.EQU	%00000000	; EVEN PARITY
DUART_MR1_PARMARK	.EQU	%00001100	; MARK PARITY
DUART_MR1_PARSPACE	.EQU	%00001000	; SPACE PARITY
;
; DUART MODE REGISTER 2
;
DUART_MR2_TXCTS		.EQU	%00010000	; CTS CONTROLS TRANSMITTER
DUART_MR2_STOP1		.EQU	%00000111	; 1 STOP BIT (1.5 IF 5 BITS/CHAR)
DUART_MR2_STOP2		.EQU	%00001111	; 2 STOP BITS (2.5 IF 5 BITS/CHAR)
;
;
#DEFINE	DUART_INP(RID)	CALL DUART_INP_IMP \ .DB RID
#DEFINE	DUART_OUTP(RID)	CALL DUART_OUTP_IMP \ .DB RID
;
;
;
DUART_PREINIT:
;
; SETUP THE DISPATCH TABLE ENTRIES
;
	LD	B,DUART_CFGCNT		; LOOP CONTROL
	XOR	A			; ZERO TO ACCUM
	LD	(DUART_DEV),A		; CURRENT DEVICE NUMBER
	LD	IY,DUART_CFG		; POINT TO START OF CFG TABLE
DUART_PREINIT0:
	PUSH	BC			; SAVE LOOP CONTROL
	CALL	DUART_DETECT		; DETERMINE DUART TYPE
	POP	BC			; RESTORE LOOP CONTROL
	LD	(IY + 1),A		; SAVE TYPE IN CONFIG TABLE
	OR	A			; SET FLAGS
	JR	Z,DUART_PREINIT1	; SKIP IT IF NOTHING FOUND
;	
	PUSH	BC			; SAVE LOOP CONTROL
	PUSH	IY
	POP	DE			; DE := UNIT INSTANCE TABLE ADDRESS
	LD	BC,DUART_FNTBL		; BC := FUNCTION TABLE ADDRESS
	CALL	NZ,CIO_ADDENT		; ADD ENTRY IF DUART FOUND, BC:DE
	POP	BC			; RESTORE LOOP CONTROL
;
DUART_PREINIT1:
	LD	DE,DUART_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,DE			; BUMP IY TO NEXT ENTRY
	DJNZ	DUART_PREINIT0		; LOOP UNTIL DONE
;
	LD	B,DUART_CFGCNT		; LOOP CONTROL
	LD	IY,DUART_CFG		; POINT TO START OF CFG TABLE
DUART_PREINIT2:
	PUSH	BC			; SAVE LOOP CONTROL
	CALL	DUART_INITUNIT		; INITIALIZE UNIT
	POP	BC			; RESTORE LOOP CONTROL
	LD	DE,DUART_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,DE			; BUMP IY TO NEXT ENTRY
	DJNZ	DUART_PREINIT2		; LOOP UNTIL DONE
;
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; DUART INITIALIZATION ROUTINE
;
DUART_INITUNIT:
	; CHECK IF PORT IS PRESENT
	LD	A,(IY + 1)		; GET TYPE FROM CONFIG TABLE
	OR	A			; SET FLAGS
	RET	Z			; ABORT IF NOTHING THERE
	
	; UPDATE WORKING DUART DEVICE NUM
	LD	HL,DUART_DEV		; POINT TO CURRENT DUART DEVICE NUM
	LD	A,(HL)			; PUT IN ACCUM
	INC	(HL)			; INCREMENT IT (FOR NEXT LOOP)
	LD	(IY),A			; UDPATE UNIT NUM
	
	; SET DEFAULT CONFIG
	LD	DE,-1			; LEAVE CONFIG ALONE
	JP	DUART_INITDEV		; IMPLEMENT IT AND RETURN
;
;
;
DUART_INIT:
	LD	B,DUART_CFGCNT		; COUNT OF POSSIBLE DUART UNITS
	LD	IY,DUART_CFG		; POINT TO START OF CFG TABLE
DUART_INIT1:
	PUSH	BC			; SAVE LOOP CONTROL
	LD	A,(IY + 1)		; GET DUART TYPE
	OR	A			; SET FLAGS
	CALL	NZ,DUART_PRTCFG		; PRINT IF NOT ZERO
	
	POP	BC			; RESTORE LOOP CONTROL
	LD	DE,DUART_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,DE			; BUMP IY TO NEXT ENTRY
	DJNZ	DUART_INIT1		; LOOP TILL DONE
;
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; DRIVER FUNCTION TABLE
;
DUART_FNTBL:
	.DW	DUART_IN
	.DW	DUART_OUT
	.DW	DUART_IST
	.DW	DUART_OST
	.DW	DUART_INITDEV
	.DW	DUART_QUERY
	.DW	DUART_DEVICE
#IF (($ - DUART_FNTBL) != (CIO_FNCNT * 2))
	.ECHO	"*** INVALID DUART FUNCTION TABLE ***\n"
#ENDIF
;
;
;
DUART_IN:
	CALL	DUART_IST		; RECEIVED CHAR READY?
	JR	Z,DUART_IN		; LOOP IF NOT
	DUART_INP(DUART_RX)		; GET CHAR READ IN A
	LD	E,A			; CHAR READ TO E
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
;
;
DUART_OUT:
	CALL	DUART_OST		; READY FOR CHAR?
	JR	Z,DUART_OUT		; LOOP IF NOT
	LD	A,E			; GET CHAR TO SEND IN A
	DUART_OUTP(DUART_TX)		; SEND CHAR FROM A
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
DUART_IST:
	DUART_INP(DUART_SR)		; GET CHANNEL STATUS REGISTER IN A
	AND	DUART_SR_RXRDY		; ISOLATE RXRDY BIT
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ACCUM := 1 TO SIGNAL 1 CHAR WAITING
	RET				; DONE
;
;
;
DUART_OST:
	DUART_INP(DUART_SR)		; GET CHANNEL STATUS REGISTER IN A
	AND	DUART_SR_TXRDY		; ISOLATE TXRDY BIT
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ACCUM := 1 TO SIGNAL 1 BUFFER POSITION
	RET				; DONE
;
;
;
DUART_INITDEV:
	; TEST FOR -1 WHICH MEANS USE CURRENT CONFIG (JUST REINIT)
	LD	A,D			; TEST DE FOR
	AND	E			; ... VALUE OF -1
	INC	A			; ... SO Z SET IF -1
	JR	NZ,DUART_INITDEV1	; IF DE == -1, REINIT CURRENT CONFIG
;
	; LOAD EXISTING CONFIG TO REINIT
	LD	E,(IY + 8)		; LOW BYTE
	LD	D,(IY + 9)		; HIGH BYTE
;
DUART_INITDEV1:
	; GET CLOCK SELECT FROM TABLE
	LD	HL,DUART_BAUDTBL_681	; GET START OF XR88C681 TABLE IN HL
	LD	A,(IY + 1) 		; GET DUART TYPE
	CP	DUART_26C92		; IS IT A 26C92?
	JR	NZ,DUART_INITDEV1A	; NO, SKIP NEXT INSTRUCTION
	LD	HL,DUART_BAUDTBL_92	; GET START OF SC26C92 TABLE IN HL
;
DUART_INITDEV1A:
	LD	A,D			; GET CONFIG MSB
	AND	$1F			; ISOLATE ENCODED BAUD RATE
	CALL	ADDHLA			; HL -> ENTRY
	LD	A,(HL)			; A = ENTRY
	INC	A			; A = $FF?
	JP	Z,DUART_INITDEVZ	; INVALID RATE, ERROR OUT
	DEC	A			; GET ORIGINAL VALUE BACK
;
	; GOT A VALID RATE, COMMIT NEW CONFIG
	LD	(IY + 8),E		; SAVE LOW WORD
	LD	(IY + 9),D		; SAVE HI WORD
;
	; START OF ACTUAL DUART CHANNEL CONFIGURATION
	LD	L,A			; SAVE BAUD TABLE ENTRY IN L
	LD	A,DUART_CR_DIS_RX | DUART_CR_DIS_TX
	DUART_OUTP(DUART_CR)		; DISABLE RECEIVER AND TRANSMITTER
	LD	A,DUART_CR_RESET_RX
	DUART_OUTP(DUART_CR)		; RESET RECEIVER
	LD	A,DUART_CR_RESET_TX
	DUART_OUTP(DUART_CR)		; RESET TRANSMITTER
	LD	A,DUART_CR_RESET_ERR
	DUART_OUTP(DUART_CR)		; RESET ERROR STATUS
	LD	A,(IY + 1)		; GET DUART TYPE
	CP	DUART_26C92		; IS IT A 26C92?
	JR	Z,DUART_INITDEV1B	; YES
	CALL	DUART_SETBAUD_681	; NO, CALL '681 BRG SETUP
	JR	DUART_INITDEV2
;
DUART_INITDEV1B:
	CALL	DUART_SETBAUD_92	; CALL '92 BRG SETUP
;
DUART_INITDEV2:
;
	; SET PARITY AND WORD SIZE
	LD	A,DUART_CR_MR1
	DUART_OUTP(DUART_CR)		; SET MR POINTER TO MR1
	LD	A,E			; GET LOW WORD OF CONFIG IN A
	AND	%00111000		; KEEP ONLY PARITY BITS
	RRA
	RRA
	RRA				; SHIFT PARITY BITS INTO AN INDEX
	LD	HL,DUART_PARTBL		; GET START OF TABLE IN HL
	CALL	ADDHLA			; HL -> ENTRY
	LD	B,(HL)			; BUILD MR1 IN B
	LD	A,E			; GET LOW WORD OF CONFIG IN A
	AND	%00000011		; WORD LENGTH BITS ARE THE SAME
	OR	B			; MERGE PARITY BITS
	OR	DUART_MR1_RXRTS		; ALWAYS ENABLE RECEIVER CONTROL OF RTS
	DUART_OUTP(DUART_MR)		; WRITE MR1 (AND SET MR POINTER TO MR2)
;
	; SET STOP BITS
	LD	A,E			; GET LOW WORD OF CONFIG IN A
	LD	B,DUART_MR2_STOP1	; BUILD MR2 IN B
	AND	%00000100		; KEEP ONLY STOP BITS
	JR	Z,DUART_INITDEV4	; 1 STOP BIT
	LD	B,DUART_MR2_STOP2	; 2 STOP BITS, REPLACE B
;
DUART_INITDEV4:
	LD	A,B			; GET MR2 IN A
	;OR	DUART_MR2_TXCTS		; ALWAYS ENABLE CTS CONTROL OF TRANSMITTER
	DUART_OUTP(DUART_MR)		; WRITE MR2
;
	; RE-ENABLE RECEIVER AND TRANSMITTER
	LD	A,DUART_CR_ENA_RX | DUART_CR_ENA_TX
	DUART_OUTP(DUART_CR)		; ENABLE RECEIVER AND TRANSMITTER
;
	; EXPLICITLY ASSERT RTS (SEEMS TO BE REQUIRED FOR SOME CHIPS TO DO AUTO-RTS)
	LD	L,%00000001		; RTS FOR CHANNEL A IS IN BIT 0
	LD	A,(IY)			; GET UNIT NUMBER IN A
	AND	L			; MASK ALL BUT CHANNEL
	JR	Z,DUART_INITDEV5	; ZERO INDICATES CHANNEL A
	SLA	L			; MOVE INTO BIT 1, RTS FOR CHANNEL B
;
DUART_INITDEV5:
	LD	A,(IY + 2)		; GET BASE ADDRESS OF CHIP
	ADD	A,DUART_SOPR		; SET OUTPUT BITS
	LD	C,A			; GET PORT IN C
	OUT	(C),L			; OUTPUT PORT IS INVERTED BUT SO IS RTS
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
DUART_INITDEVZ:
;
	; INVALID BAUD RATE
	DEC	A			; A WAS $00, GET BACK $FF
	RET				; RETURN ERROR STATUS
;
; INITIALIZE BRG FOR '681 DUART
;
DUART_SETBAUD_681:
	; SET ACR
	LD	C,(IY + 6)		; GET SHADOW ACR FOR THIS CHIP
	LD	B,(IY + 7)		; BC IS POINTER
	LD	A,(BC)			; GET SHADOW ACR IN A
	AND	%01111111		; MASK OUT BIT 7
	LD	H,A			; SAVE IT IN H
	LD	A,L			; TABLE ENTRY IS IN L, GET IT IN A
	AND	DUART_BAUD_ACR7		; SEE IF ACR[7] SHOULD BE SET (BIT MASK SHOULD ACTUALLY _BE_ BIT 7)
	OR	H			; MERGE IN REST OF ACR
	LD	H,A			; SAVE IT IN H
	LD	A,(IY + 2)		; GET CHIP BASE IN A
	ADD	A,DUART_ACR		; ADD OFFSET OF ACR
	LD	C,A			; C = ACR PORT
	; YES, THIS OVERWRITES ACR[7] REGARDLESS OF THE OTHER CHANNEL,
	; BUT CURRENTLY THE TABLE IS SET SO EVERY VALID RATE HAS ACR[7] SET
	OUT	(C),H			; WRITE VALUE
	; SELECT PER-CHANNEL EXTENDED TABLE
	LD	A,L			; CALLED WITH TABLE ENTRY IN L, MOVE IT TO A
	AND	DUART_BAUD_X1		; SEE IF SELECT EXTEND BIT SHOULD BE SET
	JR	Z,DUART_SETBAUD_681A	; NO, CLEAR IT
	LD	A,DUART_CR_SET_RX_X	; YES, SET EXTEND BIT
	DUART_OUTP(DUART_CR)		; SET FOR RECEIVER
	LD	A,DUART_CR_SET_TX_X
	DUART_OUTP(DUART_CR)		; SET FOR TRANSMITTER
	JR	DUART_SETBAUD_681B
;
DUART_SETBAUD_681A:
	; CLEAR EXTEND BIT
	LD	A,DUART_CR_CLR_RX_X
	DUART_OUTP(DUART_CR)		; CLEAR FOR RECEIVER
	LD	A,DUART_CR_CLR_TX_X
	DUART_OUTP(DUART_CR)		; CLEAR FOR TRANSMITTER
;
DUART_SETBAUD_681B:
	; SET BRG CLOCK SELECT
	LD	A,L			; GET BAUD TABLE ENTRY IN A
	AND	$0F			; GET CLOCK SELECT BITS
	LD	L,A			; SAVE IT IN L
	RLA
	RLA
	RLA
	RLA				; MOVE IT INTO THE HIGH NIBBLE
	OR	L			; AND MERGE BACK IN LOW NIBBLE
	DUART_OUTP(DUART_CSR)		; SET CLOCK SELECT
	RET
;
DUART_BAUDTBL_681:
	; ASSUME XR88C681 RUNS AT 3.6864MHZ
	.DB	%0000 | DUART_BAUD_X1	; 75
	.DB	%0011 | DUART_BAUD_X1	; 150
	.DB	%0100			; 300
	.DB	%0101			; 600
	.DB	%0110			; 1200
	.DB	%1000			; 2400
	.DB	%1001			; 4800
	.DB	%1011			; 9600
	.DB	%1100 | DUART_BAUD_X1	; 19200
	.DB	%1100			; 38400
	.DB	DUART_BAUD_INV		; 76800
	.DB	DUART_BAUD_INV		; 153600
	.DB	DUART_BAUD_INV		; 307200
	.DB	DUART_BAUD_INV		; 614400
	.DB	DUART_BAUD_INV		; 1228800
	.DB	DUART_BAUD_INV		; 2457600
	.DB	DUART_BAUD_INV		; 225
	.DB	DUART_BAUD_INV		; 450
	.DB	DUART_BAUD_INV		; 900
	.DB	%1010 | DUART_BAUD_X1	; 1800
	.DB	%0100 | DUART_BAUD_X1	; 3600
	.DB	%1010			; 7200
	.DB	%0101 | DUART_BAUD_X1	; 14400
	.DB	%0110 | DUART_BAUD_X1	; 28800
	.DB	%0111 | DUART_BAUD_X1	; 57600
	.DB	%1000 | DUART_BAUD_X1	; 115200
	.DB	DUART_BAUD_INV		; 230400
	.DB	DUART_BAUD_INV		; 460800
	.DB	DUART_BAUD_INV		; 921600
	.DB	DUART_BAUD_INV		; 1843200
	.DB	DUART_BAUD_INV		; 3686400
	.DB	DUART_BAUD_INV		; 7372800
;
; INITIALIZE BRG FOR '92 DUART
;
DUART_SETBAUD_92:
	; SET ACR
	LD	C,(IY + 6)		; GET SHADOW ACR FOR THIS CHIP
	LD	B,(IY + 7)		; BC IS POINTER
	LD	A,(BC)			; GET SHADOW ACR IN A
	AND	%01111111		; MASK OUT BIT 7
	LD	H,A			; SAVE IT IN H
	LD	A,L			; TABLE ENTRY IS IN L, GET IT IN A
	AND	DUART_BAUD_ACR7		; SEE IF ACR[7] SHOULD BE SET (BIT MASK SHOULD ACTUALLY _BE_ BIT 7)
	OR	H			; MERGE IN REST OF ACR
	LD	H,A			; SAVE IT IN H
	LD	A,(IY + 2)		; GET CHIP BASE IN A
	ADD	A,DUART_ACR		; ADD OFFSET OF ACR
	LD	C,A			; C = ACR PORT
	; YES, THIS OVERWRITES ACR[7] REGARDLESS OF THE OTHER CHANNEL,
	; BUT CURRENTLY THE TABLE IS SET SO EVERY VALID RATE HAS ACR[7] SET
	OUT	(C),H			; WRITE VALUE
	; SELECT NORMAL OR EXTENDED BAUD RATE TABLES
	LD	H,DUART_MR0_NORMAL	; ASSUME NORMAL
	LD	A,L			; GET TABLE ENTRY IN A AGAIN
	AND	DUART_BAUD_EXT1		; SHOULD EXT1 BE SET?
	JR	Z,DUART_SETBAUD_92A	; NO, CHECK NEXT VALUE
	LD	H,DUART_MR0_EXT1	; YES, SET IT
	JR	DUART_SETBAUD_92C
;
DUART_SETBAUD_92A:
	LD	A,L			; GET TABLE ENTRY IN A ONCE MORE
	AND	DUART_BAUD_EXT2		; SHOULD EXT2 BE SET?
	JR	Z,DUART_SETBAUD_92C	; NO, CONTINUE
	LD	H,DUART_MR0_EXT2	; YES, SET IT
;
DUART_SETBAUD_92C:
	; H NOW CONTAINS MR0
	LD	A,(IY + 2)		; GET CHIP BASE IN A
	ADD	A,DUART_CR		; WE WANT TO WRITE THE COMMAND REGISTER OF CHANNEL A, EVEN IF WE'RE CHANNEL B
	LD	C,A			; C = CRA
	LD	A,DUART_CR_MR0		; RESET MR POINTER TO MR0
	OUT	(C),A			; WRITE COMMAND
	LD	A,(IY + 2)		; GET CHIP BASE IN A
	ADD	A,DUART_MR		; NOW WE WANT TO WRITE TO MR0 OF CHANNEL A
	LD	C,A			; C = MRA
	; AS WITH ACR[7] THE TABLE IS SET SO EVERY VALID RATE IS FROM
	; THE SAME TABLE
	OUT	(C),H
	; SET BRG CLOCK SELECT
	LD	A,L			; GET BAUD TABLE ENTRY IN A YET AGAIN
	AND	$0F			; GET CLOCK SELECT BITS
	LD	L,A			; SAVE IT IN L
	RLA
	RLA
	RLA
	RLA				; MOVE IT INTO THE HIGH NIBBLE
	OR	L			; AND MERGE BACK IN LOW NIBBLE
	DUART_OUTP(DUART_CSR)		; SET CLOCK SELECT OF CURRENT CHANNEL
	RET
;
DUART_BAUDTBL_92:
	; ASSUME SC26C92 RUNS AT 7.3728MHZ
	.DB	DUART_BAUD_INV					; 75
	.DB	DUART_BAUD_INV					; 150
	.DB	DUART_BAUD_INV					; 300
	.DB	DUART_BAUD_INV					; 600
	.DB	DUART_BAUD_INV					; 1200
	.DB	DUART_BAUD_INV					; 2400
	.DB	DUART_BAUD_INV					; 4800
	.DB	%1001 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 9600
	.DB	%1011 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 19200
	.DB	%1100 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 38400
	.DB	DUART_BAUD_INV					; 76800
	.DB	DUART_BAUD_INV					; 153600
	.DB	DUART_BAUD_INV					; 307200
	.DB	DUART_BAUD_INV					; 614400
	.DB	DUART_BAUD_INV					; 1228800
	.DB	DUART_BAUD_INV					; 2457600
	.DB	DUART_BAUD_INV					; 225
	.DB	DUART_BAUD_INV					; 450
	.DB	DUART_BAUD_INV					; 900
	.DB	DUART_BAUD_INV					; 1800
	.DB	DUART_BAUD_INV					; 3600
	.DB	DUART_BAUD_INV					; 7200
	.DB	%0000 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 14400
	.DB	%0011 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 28800
	.DB	%0100 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 57600
	.DB	%0101 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 115200
	.DB	%0110 | DUART_BAUD_EXT2 | DUART_BAUD_ACR7	; 230400
	.DB	DUART_BAUD_INV					; 460800
	.DB	DUART_BAUD_INV					; 921600
	.DB	DUART_BAUD_INV					; 1843200
	.DB	DUART_BAUD_INV					; 3686400
	.DB	DUART_BAUD_INV					; 7372800
;
DUART_PARTBL:
	.DB	DUART_MR1_PARNONE	; 0 = NO PARITY (ALSO ALL EVEN ENTRIES)
	.DB	DUART_MR1_PARODD	; 1 = ODD PARITY
	.DB	DUART_MR1_PARNONE
	.DB	DUART_MR1_PAREVEN	; 3 = EVEN PARITY
	.DB	DUART_MR1_PARNONE
	.DB	DUART_MR1_PARMARK	; 5 = MARK PARITY
	.DB	DUART_MR1_PARNONE
	.DB	DUART_MR1_PARSPACE	; 7 = SPACE PARITY
;
;
;
DUART_QUERY:
	LD	E,(IY + 8)		; FIRST CONFIG BYTE TO E
	LD	D,(IY + 9)		; SECOND CONFIG BYTE TO D
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
;
;
DUART_DEVICE:
	LD	D,CIODEV_DUART		; D := DEVICE TYPE
	LD	E,(IY)			; E := PHYSICAL UNIT
	LD	C,$00			; C := DEVICE TYPE, 0x00 IS RS-232
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,(IY+3)		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
; DUART DETECTION ROUTINE
;
DUART_DETECT:
;
	; FIRST SEE IF IT LOOKS LIKE A 16X50-STYLE UART
	LD	A,(IY + 2)		; GET BASE PORT OF CHIP
	ADD	A,4			; BASE + 4 = ACR (DUART), MCR (1ST 16X50)
	LD	H,A			; H := ACR/MCR PORT ADDRESS
	ADD	A,2			; BASE + 6 = CTU (DUART), MSR (1ST 16X50)
	LD	B,A			; B := CTU/MSR PORT ADDRESS
	INC	A			; BASE + 7 = CTL (DUART), SCR (1ST 16X50)
	LD	D,A			; D := CTL/SCR PORT ADDRESS
	ADD	A,7			; BASE + 14 = STCR (DUART), MSR (2ND 16X50)
	LD	E,A			; E := STCR/MSR PORT ADDRESS
	INC	A			; BASE + 15 = SPCR (DUART), SCR (2ND 16X50)
	LD	C,A			; SPCR
	IN	A,(C)			; STOP COUNTER/TIMER, JUST IN CASE
	LD	C,H			; ACR/MCR
	IN	L,(C)			; GET ORIGINAL VALUE (ACTUALLY IPCR ON DUART) IN L
	LD	A,$30			; ENABLE A SOURCE FOR THE COUNTER/TIMER
	OUT	(C),A			; WRITE TO ACR/MCR
	LD	A,$A5			; TEST VALUE
	LD	C,B			; CTU
	OUT	(C),A			; WRITE TEST VALUE TO CTU
	LD	A,$FF			; LARGE VALUE TO PREVENT CTL FROM ROLLING OVER WHILE WE TEST
	LD	C,D			; CTL
	OUT	(C),A			; WRITE LARGE VALUE TO CTL
	LD	C,E			; STCR
	IN	A,(C)			; START COUNTER/TIMER (LATCH CTU, CTL)
	INC	C			; C := SPCR
	IN	A,(C)			; STOP COUNTER/TIMER
	LD	C,H			; ACR/MCR
	OUT	(C),L			; WRITE ORIGINAL VALUE OF MCR (ACR GETS SET ON DUART LATER)
	LD	C,B			; CTU
	IN	A,(C)			; READ BACK TEST VALUE
	CP	$A5			; CHECK FOR TEST VALUE
	JR	NZ,DUART_DETECT_NONE	; NO, PROBABLY NOT A DUART
	IN	A,(C)			; CHECK TEST VALUE AGAIN,
	CP	$A5			; ... IN RARE CASE DELTAS IN MSR WERE SET TO OUR TEST
	JR	NZ,DUART_DETECT_NONE	; ALMOST CERTAINLY NOT A DUART
	; SEE IF MR1 AND MR2 ARE DISTINCT
	LD	A,DUART_CR_MR1		; SET MR POINTER TO MR1
	DUART_OUTP(DUART_CR)		; SEND COMMAND
	LD	A,1			; WRITE TEST VALUE TO MR1
	DUART_OUTP(DUART_MR)		; WRITE MR1 AND SET POINTER TO MR2
	XOR	A			; WRITE 0 TO MR2
	DUART_OUTP(DUART_MR)		; WRITE MR2 AND KEEP POINTER TO MR2
	LD	A,DUART_CR_MR1		; SET MR POINTER TO MR1 (AGAIN)
	DUART_OUTP(DUART_CR)		; SEND COMMAND
	DUART_INP(DUART_MR)		; GET VALUE OF MR1 IN A
	CP	1			; CHECK FOR TEST VALUE
	JR	NZ,DUART_DETECT_NONE	; NOPE, UNKNOWN DEVICE OR NOT PRESENT
;
	; TEST FOR FUNCTIONAL GENERAL PURPOSE REG, IF NOT, WE HAVE A 2681
	LD	A,$5A			; LOAD TEST VALUE
	DUART_OUTP(DUART_GPR)		; PUT IT IN GENERAL PURPOSE REGISTER
	DUART_INP(DUART_GPR)		; READ IT BACK
	CP	$5A			; CHECK IT
	JR	NZ,DUART_DETECT_2681	; OLD CHIP
;
	; TEST FOR MR0 REGISTER, IN WHICH CASE WE HAVE A 26C92 OF SOME SORT
	LD	A,DUART_CR_MR0		; SET MR POINTER TO MR0
	DUART_OUTP(DUART_CR)		; THIS IS HARMLESS ON OTHER CHIPS
	LD	A,1			; WRITE TEST VALUE TO MR0
	DUART_OUTP(DUART_MR)		; WRITE TO MR0 ON 26C92, MR2 STILL SET ON OTHERS
	LD	A,DUART_CR_MR1		; SET MR POINTER TO MR1
	DUART_OUTP(DUART_CR)		; THIS WORKS ON ALL CHIPS
	XOR	A			; WRITE 0 TO MR1
	DUART_OUTP(DUART_MR)		; WRITE MR1 AND SET POINTER TO MR2
	XOR	A			; ALSO WRITE 0 TO MR2
	DUART_OUTP(DUART_MR)		; WRITE MR2 AND KEEP POINTER TO MR2
	LD	A,DUART_CR_MR0		; SET POINTER TO MR0
	DUART_OUTP(DUART_CR)		; POINTER IS STILL MR2 ON OTHER CHIPS
	DUART_INP(DUART_MR)		; GET VALUE OF MR0 IN A
	AND	1			; MASK TEST VALUE IN BIT 1
	JR	NZ,DUART_DETECT_26C92	; IF IT'S SET, THIS MUST BE A '92 WITH MR0

	JR	DUART_DETECT_XR88C681	; ASSUME WE HAVE A FANCY EXAR CHIP
;
DUART_DETECT_NONE:
	LD	A,DUART_NONE
	RET
;
DUART_DETECT_2681:
	LD	A,DUART_2681
	RET
;
DUART_DETECT_26C92:
	LD	A,DUART_26C92
	RET
;
DUART_DETECT_XR88C681
	LD	A,DUART_XR88C681
	RET
;
;
;
DUART_PRTCFG:
	; ANNOUNCE PORT
	CALL	NEWLINE			; FORMATTING
	PRTS("DUART$")			; FORMATTING
	LD	A,(IY)			; DEVICE NUM
	CALL	PRTDECB			; PRINT DEVICE NUM
	PRTS(": IO=0x$")		; FORMATTING
	LD	A,(IY + 3)		; GET CHANNEL BASE PORT
	CALL	PRTHEXBYTE		; PRINT BASE PORT

	; PRINT THE DUART TYPE
	CALL	PC_SPACE		; FORMATTING
	LD	A,(IY + 1)		; GET DUART TYPE BYTE
	RLCA				; MAKE IT A WORD OFFSET
	LD	HL,DUART_TYPE_MAP	; POINT HL TO TYPE MAP TABLE
	CALL	ADDHLA			; HL := ENTRY
	LD	E,(HL)			; DEREFERENCE
	INC	HL			; ...
	LD	D,(HL)			; ... TO GET STRING POINTER
	CALL	WRITESTR		; PRINT IT
;
	; ALL DONE IF NO DUART WAS DETECTED
	LD	A,(IY + 1)		; GET DUART TYPE BYTE
	OR	A			; SET FLAGS
	RET	Z			; IF ZERO, NOT PRESENT
;
	PRTS(" MODE=$")			; FORMATTING
	LD	E,(IY + 8)		; LOAD CONFIG
	LD	D,(IY + 9)		; ... WORD TO DE
	CALL	PS_PRTSC0		; PRINT CONFIG
;
	XOR	A
	RET
;
; ROUTINES TO READ/WRITE PORTS INDIRECTLY
;
; READ VALUE OF DUART PORT ON TOS INTO REGISTER A
;
DUART_INP_IMP:
	EX	(SP),HL		; SWAP HL AND TOS
	PUSH	BC		; PRESERVE BC
	LD	A,(IY + 3)	; GET DUART IO BASE PORT
	OR	(HL)		; OR IN REGISTER ID BITS
	LD	C,A		; C := PORT
	IN	A,(C)		; READ PORT INTO A
	POP	BC		; RESTORE BC
	INC	HL		; BUMP HL PAST REG ID PARM
	EX	(SP),HL		; SWAP BACK HL AND TOS
	RET
;
; WRITE VALUE IN REGISTER A TO DUART PORT ON TOS
;
DUART_OUTP_IMP:
	EX	(SP),HL		; SWAP HL AND TOS
	PUSH	BC		; PRESERVE BC
	LD	B,A		; PUT VALUE TO WRITE IN B
	LD	A,(IY + 3)	; GET DUART IO BASE PORT
	OR	(HL)		; OR IN REGISTER ID BITS
	LD	C,A		; C := PORT
	OUT	(C),B		; WRITE VALUE TO PORT
	POP	BC		; RESTORE BC
	INC	HL		; BUMP HL PAST REG ID PARM
	EX	(SP),HL		; SWAP BACK HL AND TOS
	RET
;
;
;
DUART_TYPE_MAP:
			.DW	DUART_STR_NONE
			.DW	DUART_STR_2681
			.DW	DUART_STR_26C92
			.DW	DUART_STR_XR88C681

DUART_STR_NONE		.DB	"<NOT PRESENT>$"
DUART_STR_2681		.DB	"2681$"
DUART_STR_26C92		.DB	"26C92$"
DUART_STR_XR88C681	.DB	"XR88C681$"
;
; WORKING VARIABLES
;
DUART_DEV		.DB	0		; DEVICE NUM USED DURING INIT
;
; PER-CHIP VARIABLES
;
DUART0_ACR		.DB	0		; SHADOW ACR (DUART 0)
;
#IF (DUARTCNT >= 2)
;
DUART1_ACR		.DB	0		; SHADOW ACR (DUART 1)
;
#ENDIF
;
; DUART PORT TABLE
;
DUART_CFG:
;
DUART0A_CFG:
	; 1ST DUART MODULE CHANNEL A
	.DB	0			; IY	DEVICE NUMBER (SET DURING INIT)
	.DB	0			; IY+1	DUART TYPE (SET DURING INIT)
	.DB	DUART0BASE		; IY+2	BASE PORT (CHIP)
	.DB	DUART0BASE + $00	; IY+3	BASE PORT (CHANNEL)
	.DW	DUART0B_CFG		; IY+4	POINTER TO OTHER CHANNEL
	.DW	DUART0_ACR		; IY+6	POINTER TO SHADOW ACR FOR THIS CHIP
	.DW	DUART0ACFG		; IY+8	LINE CONFIGURATION
	.DB	1			; IY+10	MULTIPLIER WRT 3.6864MHZ CLOCK
;
	.ECHO	"DUART: IO="
	.ECHO	DUART0BASE + $00
	.ECHO	", CHANNEL A\n"
;
DUART_CFGSIZ	.EQU	$ - DUART_CFG	; SIZE OF ONE CFG TABLE ENTRY
;
DUART0B_CFG:
	; 1ST DUART MODULE CHANNEL B
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; DUART TYPE (SET DURING INIT)
	.DB	DUART0BASE		; BASE PORT (CHIP)
	.DB	DUART0BASE + $08	; BASE PORT (CHANNEL)
	.DW	DUART0A_CFG		; POINTER TO OTHER CHANNEL
	.DW	DUART0_ACR		; POINTER TO SHADOW ACR FOR THIS CHIP
	.DW	DUART0BCFG		; LINE CONFIGURATION
	.DB	1			; MULTIPLIER WRT 3.6864MHZ CLOCK
;
	.ECHO	"DUART: IO="
	.ECHO	DUART0BASE + $08
	.ECHO	", CHANNEL B\n"
;
#IF (DUARTCNT >= 2)
;
DUART1A_CFG:
	; 2ND DUART MODULE CHANNEL A
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; DUART TYPE (SET DURING INIT)
	.DB	DUART1BASE		; BASE PORT (CHIP)
	.DB	DUART1BASE + $00	; BASE PORT (CHANNEL)
	.DW	DUART1B_CFG		; POINTER TO OTHER CHANNEL
	.DW	DUART1_ACR		; POINTER TO SHADOW ACR FOR THIS CHIP
	.DW	DUART1ACFG		; LINE CONFIGURATION
	.DB	1			; MULTIPLIER WRT 3.6864MHZ CLOCK
;
	.ECHO	"DUART: IO="
	.ECHO	DUART1BASE + $00
	.ECHO	", CHANNEL A\n"
;
DUART1B_CFG:
	; 2ND DUART MODULE CHANNEL B
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; DUART TYPE (SET DURING INIT)
	.DB	DUART1BASE		; BASE PORT (CHIP)
	.DB	DUART1BASE + $08	; BASE PORT (CHANNEL)
	.DW	DUART1A_CFG		; POINTER TO OTHER CHANNEL
	.DW	DUART1_ACR		; POINTER TO SHADOW ACR FOR THIS CHIP
	.DW	DUART1BCFG		; LINE CONFIGURATION
	.DB	1			; MULTIPLIER WRT 3.6864MHZ CLOCK
;
	.ECHO	"DUART: IO="
	.ECHO	DUART1BASE + $08
	.ECHO	", CHANNEL B\n"
;
#ENDIF
;
DUART_CFGCNT	.EQU    ($ - DUART_CFG) / DUART_CFGSIZ
