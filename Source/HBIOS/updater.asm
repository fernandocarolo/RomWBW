;*****************************************************************************
; ROMWBW XMODEM FLASH UPDATER
;
; PROVIDES THE CAPABILTY TO UPDATE ROMWBW FROM THE SBC BOOT LOADER USING
; AN XMODEM FILE TRANSFER. FOR SYSTEMS WITH AN SST39SF040 FLASH CHIP.
;
; TO INSTALL, SAVE THIS FILE AS USRROM.ASM IN \RomWBW\Source\HBIOS
; AND REBUILD AND INSTALL THE NEW ROM VERSION.
;
; THE UPDATER CAN THEN BE ACCESSED USING THE "U" OPTION IN THE SBC BOOT LOADER.
;
; OPTION (C) AND (S) - CONSOLE AND SERIAL DEVICE
;
;  BY DEFAULT THE UPDATER IS SET TO USE THE FIRST ROMWBW CONSOLE DEVICE (0) FOR
;  DISPLAY OUTPUT AND FILES TRANSFER. IF YOU USE A DIFFERENT SERIAL DEVICE FOR
;  THE FILE TRANSFER, PROGRESS INFORMATION WILL BE DISPLAYED.
;
; OPTION (V) - WRITE VERIFY
;
;  BY DEFAULT EACH FLASH SECTOR WILL BE VERIFIED AFTER BEING WRITTEN. SLIGHT
;  PERFORMANCE IMPROVEMENTS CAN BE GAINED IF TURNED OFF AND COULD BE USED IF
;  YOU ARE EXPERIENCING RELIABLE TRANSFERS AND FLASHING.
;
; OPTION (R) - REBOOT
;  EXECUTE A COLD REBOOT. THIS SHOULD BE DONE AFTER A SUCCESSFUL UPDATE. IF
;  YOU PERFORM A COLD REBOOT AFTER A FAILED UPDATE THEN IT IS LIKELY THAT
;  YOUR SYSTEM WILL BE UNUSABLE AND REMOVING AND REPROGRAMMING THE FLASH
;  WILL BE REQUIRED.
;
; OPTION (U) - BEGIN UPDATE
;  WILL BEGIN THE UPDATE PROCESS. THE UPDATER WILL EXPECT TO START RECEIVING
;  AN XMODEM FILE ON THE SERIAL DEVICE UNIT.
;
;   XMODEM SENDS THE FILE IN PACKETS OF 128 BYTES. THE UPDATER WILL CACHE 32
;   PACKETS WHICH IS 1 FLASH SECTOR AND THEN WRITE THAT SECTOR TO THE
;   FLASH DEVICE.
;
;   IF USING SEPARATE CONSOLE, BANK AND SECTOR PROGESS INFORMATION WILL SHOWN
;
;    BANK 00 S00 S01 S02 S03 S04 S05 S06 S06 S07
;    BANK 01 S00 S01 S02 S03 S04 S05 S06 S06 S07
;    BANK 02 S00 S01 S02 S03 S04 S05 S06 S06 S07 etc
;
;   THE XMODEM FILE TRANSFER PROTOCOL DOES NOT PROVIDE ANY FILENAME OR SIZE
;   INFORMATION FOR THE TRANSFER SO THE UPDATER DOES NOT PERFORM ANY CHECKS
;   ON THE FILE SUITABILITY.
;
;   THE UPDATER EXPECTS THE FILE SIZE TO BE A MULTIPLE OF 4 KILOBYTES AND
;   WILL WRITE ALL DATA RECEIVED TO THE FLASH DEVICE. A SYSTEM UPDATE
;   FILE (128KB .IMG) OR COMPLETE ROM CAN BE RECEIVED AND WRITTEN (512KB OR
;   1024KB .ROM)
;
;   IF THE UPDATE FAILS IT IS RECOMMENDED THAT YOU RETRY BEFORE REBOOTING OR
;   EXITING TO THE SBC BOOT LOADER AS YOUR MACHINE MAY NOT BE BOOTABLE.
;
; OPTION (X) - EXIT TO THE SBC BOOT LOADER. THE SBC IS RELOADED FROM ROM AND
;  EXECUTED. AFTER A SUCCESSFUL UPDATE A REBOOT SHOULD BE PERFORMED. HOWEVER,
;  IN THE CASE OF A FAILED UPDATE THIS OPTION COULD BE USED TO ATTEMPT TO
;  LOAD CP/M AND PERFORM THE NORMAL XMODEM / FLASH PROCESS TO RECOVER.
;
; OPTION (D) - DUPLICATE FLASH #1 TO FLASH #2 WILL MAKE A COPY OF FLASH #1 
;  ONTO FLASH #2. THE PURPOSE OF THIS IS TO ENABLE MAKING A BACKUP COPY OF
;  THE CURRENT FLASH. 
;
; OPTION (1) AND (2) - CALCULATE AND DISPLAY CRC32 OF 1ST OR 2ND 512K ROM.
;
; OPTION (H) - DEBUG OPTION - SWITCH ON CPU CLOCK DIVIDER ON SBC-V2-004+
; OPTION (T) - DEBUG OPTION - TEST TIMER FOR 32S, 16S, 8S, 4S, 2S & 1S
;
;
; V.DEV	18/1/2021	PHIL SUMMERS, DIFFICULTYLEVELHIGH@GMAIL.COM
;			b1ackmai1er ON RETROBREWCOMPUTERS.ORG
;
;
; NOTES:
;  TESTED WITH TERATERM XMODEM.
;  PARTIAL WRITES CAN BE COMPLETED WITH 39SF040 CHIPS
;  OTHER CHIPS REQUIRE ENTIRE FLASH TO BE ERASED BEFORE BEFORE BEING WRITTEN.
;  SBC V2-005 MEGAFLASH REQUIRED FOR 1MB FLASH SUPPORT.
;  ASSUMES BOTH CHIPS ARE SAME TYPE
;  FAILURE HANDLING HAS NOT BEEN TESTED.
;  TIMING BROADLY CALIBRATED ON A Z80 SBC-V2
;  UNABIOS NOT SUPPORTED
;
; TERATERM:
; 
; MACROS CAN BE USED TO AUTOMATE SENDING ROM UPDATES OR ROMS IMAGES.
; TRANSMISSION STARTUP IS MORE RELIABLE WHEN THE CHECKSUM OPTION (1) IS SPECIFIED
;
; EXAMPLE MACRO FILE TO SEND *.UPD FILE, SELECT CHECKSUM MODE AND DISPLAY CRC32
;
; ;XMODEM send, checksum, display CRC32
; xmodemsend '\\DESKTOP-FI43VI2\Users\Phillip\Documents\GitHub\RomWBW\Binary\SBC_std_cust.upd' 1
; crc32file crc '\\DESKTOP-FI43VI2\Users\Phillip\Documents\GitHub\RomWBW\Binary\SBC_std_cust.rom'
; sprintf '0x%08X' crc
; messagebox inputstr 'CRC32'
;
; MAXIMUM SERIAL SPEED LIMITATIONS:
;
;  SBC-V2  UART NO FLOW CONTROL   2MHZ      | 9600
;  SBC-V2  UART NO FLOW CONTROL   4MHZ      | 19200
;  SBC-V2  UART NO FLOW CONTROL   5MHZ      | 19200
;  SBC-V2  UART NO FLOW CONTROL   8MHZ      | 38400
;  SBC-V2  UART NO FLOW CONTROL   10MHZ     | 38400
;  SBC-V2  USB-FIFO 2MHZ+                   | N/A
;  SBC-MK4 ASCI NO FLOW CONTROL   18.432MHZ | 9600
;  SBC-MK4 ASCI WITH FLOW CONTROL 18.432MHZ | 38400
;
; ACKNOWLEDGEMENTS:
;
; XR - Xmodem Receive for Z80 CP/M 2.2 using CON:
; Copyright 2017 Mats Engstrom, SmallRoomLabs
; Licensed under the MIT license
; https://github.com/SmallRoomLabs/xmodem80/blob/master/XR.Z80
;
; md.asm - ROMWBW memory disk driver
; https://github.com/wwarthen/RomWBW/blob/master/Source/HBIOS/md.asm
;
; CRC32 - J.G. HARSTON - mdfs.net/Info/Comp/Comms/CRC32.htm
;
;*****************************************************************************
;
#INCLUDE	"std.asm"
;
HBX_BNKSEL	.EQU	$FE2B
HBX_START	.EQU	$FE00
;
#DEFINE	HB_DI	DI
#DEFINE	HB_EI	EI
;
XFUDBG		.EQU	0
;
		.ORG    USR_LOC
;
; ASCII codes
;
LF:		.EQU	'J'-40h		; ^J LF
CR: 		.EQU 	'M'-40h		; ^M CR/ENTER
SOH:		.EQU	'A'-40h		; ^A CTRL-A
EOT:		.EQU	'D'-40h		; ^D = End of Transmission
ACK:		.EQU	'F'-40h		; ^F = Positive Acknowledgement
NAK:		.EQU	'U'-40h		; ^U = Negative Acknowledgement
CAN:		.EQU	'X'-40h		; ^X = Cancel
BSPC:		.EQU	'H'-40h		; ^H = Backspace
;
; Start of code
;
	LD	(oldSP),SP		; SETUP STACK BELOW HBIOS
	LD	SP,HBX_START-MD_CSIZ	; ALLOW FOR RELOCATABLE CODE AREA
;
	LD	HL,MD_FSTART		; COPY FLASH
	LD	DE,HBX_START-MD_CSIZ	; ROUTINES TO
	LD	BC,MD_CSIZ		; HIGH MEMORY
	LDIR
;
	LD	BC,$F8F2		; LOOKUP
	RST	08			; CURRENT	
	LD	B,$FA			; CONSOLE
	LD	HL,$112			; DEVICE
	RST	08			; TO USE AS
	LD	A,E			; DEFAULT
	LD	(CONDEV),A
;
	LD	BC,$F8F2		; LOOKUP
	RST	08			; CURRENT	
	LD	B,$FA			; SERIAL
	LD	HL,$110			; DEVICE
	RST	08			; TO USE AS
	LD	A,E			; DEFAULT
	LD	(SERDEV),A
;
	LD	HL,msgHeader		; PRINT
	CALL	PRTSTR0			; GREETING
;
RESTART:
	LD	DE,$0000		; SET UP START
	LD	(MD_FBAS),DE		; BANK AND SECTOR

	LD	HL,MD_FIDEN		; IDENTIFY CHIP
	CALL	MD_FNCALL		; AT THIS BANK/SECTOR

	LD	HL,$B7BF		; IS IT A 39SF040
	XOR	A
	SBC	HL,BC	
	LD	A,0
	JR	Z,CHPFND		; YES IT IS ...
;
	LD	HL,$A401		; IS IT A 29F040
	XOR	A
	SBC	HL,BC
	LD	A,1
	JR	Z,CHPFND		; YES IT IS ...
;
	LD	HL,$131F		; IS IT AN AT49F040
	XOR	A
	SBC	HL,BC
	LD	A,2
	JR	Z,CHPFND		; YES IT IS
;
	LD	HL,$A41F		; IS IT AN AT29C040
	XOR	A
	SBC	HL,BC
	LD	A,3
	JR	Z,CHPFND		; YES IT IS
;
	LD	HL,$E220		; IS IT AN M29F040
	XOR	A
	SBC	HL,BC
	LD	A,4
	JR	Z,CHPFND		; YES IT IS
;
	LD	HL,$A4C2		; IS IT AN MX29F040
	SBC	HL,BC
	LD	A,5
;
	JP	NZ,FAILBC		; SUPPORTED CHIP NOT FOUND
;
CHPFND:	LD	A,2
	LD	(ERATYP),A		; SAVE ERASE TYPE

	LD	BC,$F8F0		; GET CPU SPEED
	RST	08			; AND MULTIPLY
	LD	A,L			; BY 4
	ADD	A,A			; TO CREATE
	ADD	A,A			; TIMEOUT DELAY
	LD	(TmoFct),A		; FACTOR 
;
MENULP:	LD	DE,$0000		; ENSURE WE ARE STARTING
	LD	(MD_FBAS),DE		; AT BANK 0 SECTOR 0

	LD	HL,ERATYP
	RES	7,(HL)
;
	LD	HL,msgCRLF
	CALL	PRTSTR0
	CALL	MENU			; DISPLAY MENU
;
	CALL	GETINP			; GET SELECTION
;
	CP	'U'			; BEGIN
	JR	Z,BEGUPD		; TRANSFER
;
	CP	'V'			; CHECK FOR
	JP	Z,OPTIONV		; VERIFY TOGGLE
;
	CP	'X'			; CHECK FOR
	JP	Z,FAILUX		; USER EXIT
;
	CP	'R'			; CHECK FOR
	JP	Z,REBOOT		; COLD REBOOT REQUEST
;
	CP	'C'			; CHECK FOR
	JP	Z,OPTIONC		; CONSOLE CHANGE
;
	CP	'S'			; CHECK FOR
	JP	Z,OPTIONS		; SERIAL CHANGE
;
	CP	'D'			; DUPLICATE
	JP	Z,OPTIOND		; FLASH
;
	CP	'1'			; CALCULATE
	JP	Z,OPTION1		; CRC 512K FLASH
;
	CP	'2'			; CALCULATE
	JP	Z,OPTION2		; CRC 1024K FLASH
;
#IF	(XFUDBG)
	CP	'3'			; CALCULATE
	JP	Z,OPTION3		; CRC FLASH #2
;
	CP	'T'			; TEST TIMEOUT
	JP	Z,OPTIONT		; LOOP
;
	CP	'H'			; HALF
	JP	Z,OPTIONH		; SPEED SWITCH
;
	CP	'F'			; DEBUG
	JP	Z,OPTIONF		; DUMP
;
	CP	'E'			; ERASE
	JP	Z,OPTIONE		; CHIP #1
;
	CP	'Z'			; ERASE
	JP	Z,OPTIONR		; CHIP #2
#ENDIF
;
	JR	MENULP
;
BEGUPD:	CALL	SERST			; EMPTY SERIAL BUFFER
	OR	A			; SO WE HAVE A CLEAN
	JR	Z,SERCLR		; START ON TRANSFER
	CALL	SERIN
	JR	BEGUPD
;
SERCLR:	LD	HL,msgInstr		; PROVIDE
	CALL	PRTSTR0			; INSTRUCTION
;
	LD	A,(SERDEV)		; IF CONSOLE AND SERIAL
	LD	HL,CONDEV		; DEVICE ARE THE SAME,
	SUB	(HL)			; BLOCK ALL TEXT
	LD	(BLKCOUT),A		; OUTPUT DURING TRANSFER
;
	LD 	A,1			; THE FIRST PACKET IS NUMBER 1
	LD 	(pktNo),A
	LD 	A,255-1			; ALSO STORE THE 1-COMPLEMENT OF IT
	LD 	(pktNo1c),A
;
	LD	DE,sector4k		; POINT TO START OF SECTOR TO WRITE
;
GetNewPacket:
	LD	HL,retrycnt		; WE RETRY 20 TIMES BEFORE GIVING UP
	LD 	(HL),20
;
NPloop:	LD 	B,6			; 6 SECONDS OF TIMEOUT BEFORE EACH NEW BLOCK
	CALL	GetCharTmo
	JP 	NC,NotPacketTimeout
;
	DEC 	(HL)			; REACHED MAX NUMBER OF RETRIES?
	JP 	Z,FAILRT		; YES, PRINT MESSAGE AND EXIT
;
	LD 	C,NAK			; SEND A NAK TO THE UPLOADER
	CALL	SEROUT
	JR 	NPloop
;
NotPacketTimeout:
	CP	EOT			; DID UPLOADER SAY WE'RE FINISHED?
	JP	Z,Done			; YES, THEN WE'RE DONE
	CP 	CAN			; UPLOADER WANTS TO FAIL TRANSFER?
	JP 	Z,FAILCN		; YES, THEN WE'RE ALSO DONE
	CP	SOH			; DID WE GET A START-OF-NEW-PACKET?
	JR	NZ,NPloop		; NO, GO BACK AND TRY AGAIN
;
	LD	HL,packet		; SAVE THE RECEIVED CHAR INTO THE...
	LD	(HL),A			; ...PACKET BUFFER AND...
	INC 	HL			; ...POINT TO THE NEXT LOCATION
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A                  ; SHOULD BE PACKET NUMBER
	INC 	HL
	JR	C,FAILTO
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A			; SHOULD BE PACKET NUMBER
	INC 	HL                      ; COMPLEMENT
	JR	C,FAILTO
;
	LD 	C,128			; GET 128 MORE CHARACTERS FOR A FULL PACKET
GetRestOfPacket:
	CALL	GetCharTmo1		; GET CHARACTER
	JR	C,FAILTO
;
	LD	(HL),A
	INC 	HL			; SAVE THE RECEIVED CHAR INTO THE...
	LD	(DE),A                  ; ...PACKET BUFFER AND...
	INC	DE                      ; ...POINT TO THE NEXT LOCATION
;
	DEC	C
	JP	NZ,GetRestOfPacket
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A                  ; SHOULD BE CHECKSUM
	JR	C,FAILTO
;
	LD	HL,packet+3		; CALCULATE CHECKSUM FROM 128 BYTES OF DATA
	LD	B,128
	XOR	A
csloop:	ADD	A,(HL)			; JUST ADD UP THE BYTES
	INC	HL
	DJNZ	csloop
;
	XOR	(HL)			; HL POINTS TO THE RECEIVED CHECKSUM SO
	JR	NZ,FAILCS		; BY XORING IT TO OUR SUM WE CHECK FOR EQUALITY
;
	LD	HL,(pktNo)		; CHECK
	LD	BC,(packet+1)		; AGREEMENT
;	XOR	A                       ; PACKET
	SBC	HL,BC                   ; NUMBERS
	JR	NZ,FAILPN
;
	LD	A,C			; HAVE WE RECEIVED A BLOCK OF 32
	DEC	A			; XMODEM PACKETS?
	AND	%00011111		; IF YES THEN WERE WE
	CP	%00011111		; HAVE ENOUGH TO
	LD	A,0			; WRITE A FLASH SECTOR
	CALL	Z,WSEC			; ASSUME FLASH SUCCESSFUL
;
	OR	A			; EXIT IF WE GOT A
	JR	NZ,FAILWF		; WRITE VERIFICATION ERROR
;
	LD	HL,pktNo		; UPDATE THE PACKET COUNTERS
	INC 	(HL)
	INC	HL
	DEC	(HL)
;
	LD 	C,ACK			; TELL UPLOADER THAT WE'RE HAPPY WITH WITH
	CALL	SEROUT			; PACKET AND GO BACK AND FETCH SOME MORE
;
	JP	GetNewPacket
;
FAILTO:	LD	HL,msgTimout		; TIMEOUT WAITING 
	JR	ERRRX			; FOR CHARACTER
;
COUTON:	LD	A,$FF			; TURN ON 
	LD	(BLKCOUT),A		; OUTPUT
	RET
;
Done:	LD	C,ACK			; TELL UPLOADER 
	CALL	SEROUT			; WE'RE DONE
Done1:	LD 	HL,msgSuccess		; BACK TO
	JR	MSGRS			; MENU
;
FAILWF:	LD	HL,msgFailWrt		; FLASH
	JR	MSGRS			; VERIFY FAIL
;
FAILRT:	LD	HL,msgRetry		; RETRY
	JR	ERRRX			; TIMEOUT FAIL
;
FAILCS:	LD	HL,msgChkSum		; CHECKSUM
	JR	ERRRX			; ERROR
;
FAILPN:	LD	HL,msgPacErr		; PACKET
	JR	ERRRX			; NUMBER ERROR
;
FAILCN:	LD 	HL,msgCancel		; TRANSMISSION
	JR	ERRRX			; FAILURE
;
FAILUX:	LD	HL,msgUserEx		; USER
	JR	Die			; EXIT
;
FAILBC:	LD	HL,msgUnsupC		; UNSUPPORTED
	JR	Die			; FLASH CHIP
;
ERRRX:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; DISPLAY TRANSMISSION
	LD	HL,msgFailure		; RECEIPT ERROR
	CALL 	PRTSTR0
	JP	RESTART
;
MSGRS:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; DISPLAY
	JP	RESTART			; MESSAGE
;
REBOOT:	LD	HL,msgReboot		; REBOOT MESSAGE
	CALL 	PRTSTR0
	LD	C,BF_SYSRES_COLD	; COLD RESTART
	JR	Die1
;
Die:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; Prints message and exits from program
	LD	C,BF_SYSRES_WARM	; WARM START
Die1:	LD	B,BF_SYSRESET		; SYSTEM RESTART
	LD	SP,(oldSP)
	CALL	$FFF0			; CALL HBIOS
	RET

WSEC:	CALL	DISPROG			; DISPLAY PROGRESS
;
WSEC1:	LD	A,(ERATYP)		; SECTOR
	OR	A			; ERASE?
	JP	Z,WSEC4
;
	JP	M,WSEC3			; SKIP ERASE?
;
	LD	HL,MD_FERAC		; SETUP CHIP ERASE
	SET	7,A			; SET FLAG SO
	LD	(ERATYP),A		; WE DONT ERASE AGAIN
	JR	WSEC2
;	
WSEC4:	LD	HL,MD_FERAS		; SET ERASE SECTOR
WSEC2:	CALL	MD_FNCALL		; ERASE CHIP OR SECTOR
;
WSEC3:	LD	IX,sector4k		; WRITE THIS
	LD	HL,MD_FWRIT		; BANK / SECTOR
	CALL	MD_FNCALL
;
	LD	A,(WRTVER)		; VERIFY
	OR	A			; WRITE IF
	JR	Z,NOVER			; OPTION SET
;
	LD	IX,sector4k		; VERIFY
	LD	HL,MD_FVERI		; WRITE
	CALL	MD_FNCALL
	LD	(VERRES),A		; SAVE STATUS
;
NOVER:	LD	DE,sector4k		; POINT BACK TO START OF 4K BUFFER
;
	LD	HL,MD_FBAS
	LD	A,(HL)			; DID WE JUST
	SUB	$70			; DO LAST
	JR	NZ,NXTS2		; SECTOR
;
	LD	(HL),A			; RESET SECTOR TO 0
	INC	HL
	INC	(HL)			; NEXT BANK
;
	CP	$10			; IF WE ARE AT THE
	JR	NZ,NXTS3		; START OF A NEW
	LD	HL,ERATYP		; CHIP THEN ALLOW
	RES	7,(HL)			; CHIP ERASE BY
	JR	NXTS3			; RESETTING FLAG
;
NXTS2:	LD	A,$10			; NEXT SECTOR
	ADD	A,(HL)			; EACH SECTOR IS $1000
	LD	(HL),A			; SO WE JUST INCREASE HIGH BYTE
;
NXTS3:	LD	A,(VERRES)		; EXIT WITH STATUS
	RET
;
DISPROG:LD	A,(BLKCOUT)		; SKIP OUTPUT
	OR	A			; IF OUTPUT
	RET	Z			; BLOCKED
;
	LD	A,(MD_SECT)		; IF SECTOR IS 0
	OR	A			; THEN DISPLAY
	JR	NZ,DISP1		; BANK # PREFIX
	LD	HL,msgBank
	CALL	PRTSTR0
	LD	A,(MD_BANK)
	CALL	PRTHEXB
;
DISP1:	LD	C,' '			; DISPLAY
	CALL	CONOUT			; CURRENT
	LD	C,'S'			; SECTOR
	CALL	CONOUT
	LD	A,(MD_SECT)
	RRCA
	RRCA
	RRCA
	RRCA
	CALL	PRTHEXB
	RET
;
; WAITS FOR UP TO B SECONDS FOR A CHARACTER TO BECOME AVAILABLE AND
; RETURNS IT IN A WITHOUT ECHO AND CARRY CLEAR. IF TIMEOUT THEN CARRY
; IT SET.
;
; 4MHZ  20 SECONDS TmoFct = 16
; 10MHZ 20 SECONDS TmoFct = 39
;
GetCharTmo1:
	LD	B,1			; WAIT 1 SECOND FOR SERIAL INPUT
GetCharTmo:
	CALL	SERST			; IF THERE IS A 
	OR	A			; CHARACTER AVAILABLE
	JR 	NZ,GotChrX		; EXIT NOW OTHERWISE POLL
GCtmoa:	PUSH	BC
	LD	BC,255			; C=CONSTANT (255) FOR INNER TIMING LOOP
TmoFct:	.EQU	$-1			; B=SPEED FACTOR WHICH GETS UPDATED AT START
GCtmob:	PUSH	BC
	LD	B,C
GCtmoc:	PUSH	BC
	CALL	SERST
	OR	A			; A CHAR AVAILABLE?
	JR 	NZ,GotChar		; YES, GET OUT OF LOOP
	POP	BC
	DJNZ	GCtmoc
	POP	BC
	DJNZ	GCtmob
	POP	BC
	DJNZ	GetCharTmo
	SCF 				; SET CARRY SIGNALS TIMEOUT
	RET
;
GotChar:POP	BC
	POP	BC
	POP	BC
GotChrX:CALL	SERIN
	OR	A 			; CLEAR CARRY SIGNALS SUCCESS
	RET
;
GETINP:	CALL	CONIN			; GET A CHARACTER
	LD	C,A			; RETURN SEQUENCE
	CALL	CONOUT			; CONVERT TO UPPERCASE
	LD	C,BSPC			; RETURN CHARACTER IN A
	CALL	CONOUT
	LD	B,A
	CP	BSPC
	JR	Z,GETINP
GETINP2:CALL	CONIN
	CP	BSPC
	JR	Z,GETINP
	CP	CR
	JR	NZ,GETINP2
	LD	A,B
	LD	C,A
	CALL	CONOUT
	CP	'a'			; BELOW 'A'?
	JR	C,GETINP3		; IF SO, NOTHING TO DO
	CP	'z'+1			; ABOVE 'Z'?
	JR	NC,GETINP3		; IF SO, NOTHING TO DO
	AND	~$20			; CONVERT CHARACTER TO LOWER
GETINP3:RET
;
PRTSTR0:LD	A,(HL)			; PRINT MESSAGE POINTED TOP HL UNTIL 0
	or	A			; CHECK IF GOT ZERO?
	RET	Z			; IF ZERO RETURN TO CALLER
	LD 	C,A
	CALL	CONOUT			; ELSE PRINT THE CHARACTER
	INC	HL
	JP	PRTSTR0
;
MENU:	LD	HL,msgConsole		; DISPLAY
	CALL	PRTSTR0			; CONSOLE
	LD	A,(CONDEV)		; DEVICE
	ADD	A,'0'
	LD	C,A
	CALL	CONOUT
;
	LD	HL,msgIODevice		; DISPLAY
	CALL	PRTSTR0			; SERIAL
	LD	A,(SERDEV)		; DEVICE
	ADD	A,'0'
	LD	C,A
	CALL	CONOUT
;
	LD	HL,msgWriteV		; DISPLAY
	CALL	PRTSTR0			; VERIFY
	LD	A,(WRTVER)		; OPTION
	OR	A
	LD	HL,msgYES
	JR	NZ,MENU1
	LD	HL,msgNO
MENU1:	CALL	PRTSTR0
;
	LD	HL,msgBegin		; DISPLAY OTHER
	CALL	PRTSTR0			; MENU OPTIONS
	RET
;
OPTIOND:CALL	COUTON			; TURN ON OUTPUT
;
	LD	HL,msgConfirm		; CONFIRM
	CALL	PRTSTR0			; OK
	CALL	GETINP			; TO
	CP	'Y'			; PROCEED
	JP	NZ,MENULP
DUPL:	LD	HL,msgCopying	
	CALL	PRTSTR0	
;
	LD	A,(ERATYP)		; CHECK IF WE
	OR	A			; NEED TO DO
	JR	Z,NOERA1		; A CHIP ERASE
;
	LD	HL,$1000
	LD	(MD_FBAS),HL
	LD	HL,MD_FERAC		; ERASE 
	CALL	MD_FNCALL		; CHIP #2
	OR	A
	JP	FAILWF
;
NOERA1:	LD	B,16			; LOOP THROUGH 16 BANKS
;
	XOR	A			; START AT
	LD	(MD_BANK),A		; BANK 0
;
NXTB:	PUSH	BC
;
	XOR	A			; START AT
	LD	(MD_SECT),A		; SECTOR 0
;
	LD	B,8			; LOOP THROUGH 8 SECTORS
NXTS:	PUSH	BC
;	
	CALL	DISPROG			; DISPLAY PROGRESS
;
	LD	IX,sector4k		; READ SECTOR 
	LD	HL,MD_FREAD		; FROM ROM #1
	CALL	MD_FNCALL
;
	LD	HL,MD_BANK		; SET CHIP #2
	SET	4,(HL)
;
	LD	A,(ERATYP)		; SKIP ERASE
	OR	A			; IF SECTOR ERASE
	JR	NZ,NOERA2		; IS NOT SUPPORTED
;
	LD	HL,MD_FERAS		; ERASE SECTOR
	CALL	MD_FNCALL		; ON ROM #2
	OR	A
	JR	NZ,VERF
;
NOERA2:	LD	IX,sector4k		; WRITE SECTOR
	LD	HL,MD_FWRIT		; ON ROM #2
	CALL	MD_FNCALL
;
	LD	A,(WRTVER)		; VERIFY
	OR	A			; WRITE IF
	JR	Z,NOVER1		; OPTION
;
	LD	IX,sector4k		; VERIFY
	LD	HL,MD_FVERI		; WRITE
	CALL	MD_FNCALL
	OR	A			; EXIT IF
	JR	NZ,VERF			; VERIFY FAILED
;
NOVER1:	LD	HL,MD_BANK		; RESET TO CHIP #1
	RES	4,(HL)
;
	LD	A,(MD_SECT)		; POINT TO	
	ADD	A,$10			; NEXT
	LD	(MD_SECT),A		; SECTOR
;
	POP	BC			; LOOP
	DJNZ	NXTS			; NEXT SECTOR
;
	LD	HL,MD_BANK		; POINT TO	; 00-15 = CHIP 1
	INC	(HL)			; NEXT BANK	; 16-21 = CHIP 2
;
	POP	BC			; LOOP
	DJNZ	NXTB			; NEXT BANK
;
	JP	Done1			; SUCCESS. RETURN TO MENU
;
VERF:	POP	BC			; EXIT WITH FAIL
	POP	BC			; FAIL MESSAGE AND 
	JP	FAILWF			; RETURN TO MENU
;
OPTIONV:LD	A,(WRTVER)		; TOGGLE
	CPL				; VERIFY
	LD	(WRTVER),A		; FLAG
	JP	MENULP			; BACK TO MENU
;
OPTIONC:LD	HL,msgEnterUnit		; GET
	CALL	PRTSTR0			; CONSOLE
	CALL	GETINP			; UNIT NUMBER
	CP	'0'
	JR	C,CONCLR
	CP	'9' + 1
	JR	NC,CONCLR
	SUB	'0'
	LD	(CONDEV),A
CLRCON:	CALL	CONST			; EMPTY CONSOLE BUFFER
	OR	A			; SO WE DON'T HAVE ANY
	JR	Z,CONCLR		; FALSE ENTRIES
	CALL	CONIN
	JR	CLRCON

CONCLR:	JP	MENULP			; BACK TO MENU
;
OPTIONS:LD	HL,msgEnterUnit		; GET
	CALL	PRTSTR0        		; CONSOLE
	CALL	GETINP         		; UNIT
	CP	'0'
	JR	C,CONCLR
	CP	'9' + 1
	JR	NC,CONCLR
	SUB	'0'            		; NUMBER
	LD	(SERDEV),A
;
	JP	MENULP			; BACK TO MENU
;
#IF	(XFUDBG)
OPTIONT:LD	HL,msgCRLF		; TEST DELAY 32S, 16S, 8S, 4S, 2S, 1S
	CALL	PRTSTR0
	LD	B,32			; START DELAY IS 32 SECONDS
TSTDLY:	PUSH	BC
	LD	C,'>'			; DISPLAY START
	CALL	CONOUT			; INDICATOR
	LD	A,B
	CALL	PRTHEXB
	CALL	GetCharTmo		; DELAY B SECONDS
	LD	C,'<'			; DISPLAY STOP
	CALL	CONOUT			; INDICATOR
	POP	BC
	SRL	B			; NEXT DELAY IS HALF PREVIOUS
	JR	NZ,TSTDLY		; RETURN TO MENU
	JP	MENULP			; WHEN DELAY GETS TO 1 SECOND
;
OPTIONH:LD	A,8			; TURN ON THE SBC-V2-004+
	OUT	(RTCIO),A		; CLOCK DIVIDER
	LD	HL,TmoFct		; AND ADJUST
	SRL	(HL)			; DELAY FACTOR (/2)
	JP	MENULP			; BACK TO MENU
;
OPTIONF:LD	HL,msgCRLF		; DISPLAY
	CALL	PRTSTR0			; BANK
	LD	C,'b'			; SECTOR
	CALL	CONOUT			; TIMEOUT
	LD	A,(MD_BANK)		; CHIP
	CALL	PRTHEXB
	LD	C,'s'
	CALL	CONOUT
	LD	A,(MD_SECT)
	CALL	PRTHEXB
	LD	C,'t'
	CALL	CONOUT
	LD	A,(TmoFct)
	CALL	PRTHEXB
	LD	C,'c'
	CALL	CONOUT
	LD	A,(ERATYP)
	CALL	PRTHEXB
;
	LD	HL,msgCRLF		; DISPLAY
	CALL	PRTSTR0			; ACK/NAK BYTE
	LD	HL,packet		; DISPLAY
	LD	B,3			; LAST	
DMPBUF2:LD	A,(HL)			; NUMBERS
	CALL	PRTHEXB
	LD	C,' '
	CALL	CONOUT
	INC	HL
	DJNZ	DMPBUF2
	LD	HL,msgCRLF
	CALL	PRTSTR0
	LD	B,128			; DISPLAY
	LD	HL,packet+3		; LAST 
DMPBUF:	LD	A,(HL)			; PACKET
	CALL	PRTHEXB			; CONTENTS
	LD	C,' '
	CALL	CONOUT
	LD	A,B
	SUB	2
	AND	%00001111
	CP	%00001111
	JR	NZ,DMPBUF1
	PUSH	HL
	LD	HL,msgCRLF
	CALL	PRTSTR0
	POP	HL
DMPBUF1:INC	HL
	DJNZ	DMPBUF
	JP	MENULP
;
OPTIONR:LD	HL,msgErase		; DISPLAY
	CALL	PRTSTR0			; ERASE CHIP
	LD	HL,$1000		; SET CHIP
	LD	(MD_FBAS),HL		; ADDRESS
	LD	HL,MD_FERAC		; ERASE
	CALL	MD_FNCALL		; AND WRITE
	OR	A
	JP	NZ,FAILWF
	JP	Done1
;
OPTIONE:LD	HL,msgErase		; DISPLAY
	CALL	PRTSTR0			; ERASE CHIP
	LD	HL,MD_FERAC		; ERASE
	CALL	MD_FNCALL		; AND WRITE
	OR	A
	JP	NZ,FAILWF
	JP	Done1
#ENDIF
;
SEROUT:	PUSH	HL			; SERIAL OUTPUT CHARACTER IN C
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$01
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
SERST:	PUSH	HL			; SERIAL STATUS. RETURN CHARACTERS AVAILABLE IN A
	PUSH	DE
	PUSH	BC
	LD	B,$02
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
SERIN:	PUSH	HL			; SERIAL INPUT. WAIT FOR A CHARACTER ADD RETURN IT IN A
	PUSH	DE
	PUSH	BC
	LD	B,$00
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	LD	A,E
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONOUT:	PUSH	HL			; CONSOLE OUTPUT CHARACTER IN C
	PUSH	DE			; OUTPUT IS BLOCKED DURING THE
	PUSH	BC			; FILE TRANSFER WHEN THE
	PUSH	AF
	LD	A,(BLKCOUT)		; CONSOLE AND SERIAL LINE
	OR	A			; ARE THE SAME
	JR	Z,CONOUT1
	LD	E,C
	LD	B,$01
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
CONOUT1:POP	AF
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONST:	PUSH	HL			; CONSOLE STATUS. RETURN CHARACTERS AVAILABLE IN A
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$02
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONIN:	PUSH	HL			; CONSOLE INPUT. WAIT FOR A CHARACTER ADD RETURN IT IN A
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$00
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
	LD	A,E
	POP	BC
	POP	DE
	POP	HL
	RET
;
PRTHEXB:PUSH	AF			; PRINT HEX BYTE IN A TO CONSOLE
	PUSH	DE
	CALL	HEXASC
	LD	C,D
	CALL	CONOUT
	LD	C,E
	CALL	CONOUT
	POP	DE
	POP	AF
	RET

HEXASC:	LD	D,A
	CALL	HEXCONV
	LD	E,A
	LD	A,D
	RLCA
	RLCA
	RLCA
	RLCA
	CALL	HEXCONV
	LD	D,A
	RET
;
HEXCONV:AND	0FH			; CONVERT LOW NIBBLE OF A TO ASCII HEX
	ADD	A,90H
	DAA
	ADC	A,40H
	DAA
	RET

OPTION3:LD	HL,$1000		; CRC32 STARTING
	LD	(MD_FBAS),HL            ; BANK $10 SECTOR $00
	LD	B,16                    ; 16 BANKS (512K)
	JR	CALCCRC	

OPTION1:LD	HL,$0000		; CRC32 STARTING
	LD	(MD_FBAS),HL		; BANK $00 SECTOR $00
	LD	B,16			; 16 BANKS (512K)
	JR	CALCCRC
;
OPTION2:LD	HL,$0000		; CRC32 STARTING
	LD	(MD_FBAS),HL		; BANK $00 SECTOR $00
	LD	B,32			; 32 BANKS (1024K)
;
CALCCRC:CALL	COUTON			; TURN ON OUTPUT
;
	LD	HL,msgCalc
	CALL	PRTSTR0
;
	LD	HL,$FFFF		; SET THE
	LD	(CRC),HL		; START CRC
	LD	(CRC+2),HL		; CONDITION

;	LD	B,16			; 
CRCLP1:	PUSH	BC			; LOOP THROUGH ALL BANKS
	LD	B,8			; LOOP THROUGH
CRCLP2:	PUSH	BC			; 8 SECTORS
;
	PUSH	BC
	CALL	DISPROG			; DISPLAY PROGRESS
;
	LD	IX,sector4k		; READ 
	LD	HL,MD_FREAD		; A SECTOR
	CALL	MD_FNCALL
	CALL	CRC32			; CALCULATE CRC
	POP	BC
;
	LD	A,(MD_SECT)		; POINT
	ADD	A,$10			; TO NEXT
	LD	(MD_SECT),A		; SECTOR
	
	POP	BC			; NEXT
	DJNZ	CRCLP2			; SECTOR

	XOR	A			; RESET SECTOR
	LD	(MD_SECT),A		; START

	LD	HL,MD_BANK		; POINT TO
	INC	(HL)			; NEXT BANK

	POP	BC			; NEXT 
	DJNZ	CRCLP1			; BANK
;
	LD	HL,msgCRC32		; DISPLAY
	CALL	PRTSTR0			; RESULT
	LD	HL,CRC+3
	LD	B,4
DISPCRC:LD	A,$FF
	XOR	(HL)
	CALL	PRTHEXB
	DEC	HL
	DJNZ	DISPCRC
;
	JP	MENULP
;
CRC32:	LD	IX,sector4k		; CALCULATE
	LD	BC,4096			; CRC32 OF
	LD	DE,(CRC)		; EACH SECTOR
	LD	HL,(CRC+2)
BYTELP:	PUSH	BC
	LD	A,(IX)
	XOR	E
	LD	B,8
ROTLP:	SRL	H
	RR	L
	RR	D
	RRA
	JP	NC,CLEAR
	LD	E,A
	LD	A,H
	XOR	$ED
	LD	H,A
	LD	A,L
	XOR	$B8
	LD	L,A
	LD	A,D
	XOR	$83
	LD	D,A
	LD	A,E
	XOR	$20
CLEAR:	DEC	B
	JP	NZ,ROTLP
	LD	E,A
	INC	IX
	POP	BC
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,BYTELP
	LD	(CRC),DE
	LD	(CRC+2),HL

	RET
;
;======================================================================
; CALCULATE BANK AND ADDRESS DATA FROM MEMORY ADDRESS
;
; ON ENTRY DE:HL CONTAINS 32 BIT MEMORY ADDRESS.
; ON EXIT  B     CONTAINS BANK SELECT BYTE
;          C     CONTAINS HIGH BYTE OF SECTOR ADDRESS
;======================================================================
;
;MD_CALBAS:
;
;	PUSH	HL
;	LD	A,E			; BOTTOM PORTION OF SECTOR
;	AND	$0F			; ADDRESS THAT GETS WRITTEN
;	RLC	H			; WITH ERASE COMMAND BYTE
;	RLA				; A15 GETS DROPPED OFF AND
;	LD	B,A			; ADDED TO BANK SELECT
;
;	LD	A,H			; TOP SECTION OF SECTOR
;	RRA				; ADDRESS THAT GETS WRITTEN
;	AND	$70			; TO BANK SELECT PORT
;	LD	C,A
;	POP	HL
;
;	LD	(MD_FBAS),BC		; SAVE BANK AND SECTOR FOR USE IN FLASH ROUTINES
;	RET
;
MD_FSTART:	.EQU	$		; FLASH ROUTINES WHICH GET RELOCATED TO HIGH MEMORY
;
;======================================================================
; COMMON FUNCTION CALL FOR:
;
;  MD_FIDEN_R - IDENTIFY FLASH CHIP
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;   ON EXIT  BC      CONTAINS THE CHIP ID BYTES.
;            A       NO STATUS IS RETURNED
;
;  MD_FERAS_R - ERASE FLASH SECTOR
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;   ON EXIT  A       RETURNS STATUS 0=SUCCESS NZ=FAIL
;
;  MD_FREAD_R - READ FLASH SECTOR
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO WHERE TO SAVE DATA
;   ON EXIT  A       NO STATUS IS RETURNED
;
;  MD_VERI_R - VERIFY FLASH SECTOR
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO DATA TO COMPARE.
;   ON EXIT  A       RETURNS STATUS 0=SUCCESS NZ=FAIL
;
;  MD_FWRIT_R - WRITE FLASH SECTOR
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO DATA TO BE WRITTEN
;   ON EXIT  A       NO STATUS IS RETURNED
;
;  MD_FERAC_R - ERASE FLASH CHIP
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;   ON EXIT  A       RETURNS STATUS 0=SUCCESS FF=FAIL
;
; GENERAL OPERATION:
;  FLASH LIBRARY CODE NEEDS TO BE RELOCATED TO UPPER MEMORY
;  STACK NEEDS TO BE SETUP IN UPPER MEMORY
;  DEPENDING ON ROUTINE, RETURNS WITH STATUS CODE IN A.
;======================================================================
;
MD_FNCALL:
	LD	DE,$0000		; PRESET DE TO SAVE SPACE
	LD	BC,(MD_FBAS)		; PUT BANK AND SECTOR DATA IN BC
;
	LD	A,(HB_CURBNK)		; WE ARE STARTING IN HB_CURBNK
;
	HB_DI
	CALL	MD_FJPHL
	HB_EI
;
	LD	A,C			; RETURN WITH STATUS IN A
	RET
;
MD_FJPHL:
	JP	(HL)
;
#INCLUDE "flashlib.inc"
;
MD_FEND		.EQU	$
MD_CSIZ		.EQU	MD_FEND-MD_FSTART	; HOW MUCH SPACE WE NEED FOR RELOCATABLE CODE
;
MD_FIDEN	.EQU	HBX_START-MD_CSIZ+MD_FIDEN_R-MD_FSTART	; CALL ADDRESS FOR IDENTIFY FLASH CHIP
MD_FERAS	.EQU	HBX_START-MD_CSIZ+MD_FERAS_R-MD_FSTART	; CALL ADDRESS FOR ERASE FLASH SECTOR
MD_FREAD 	.EQU	HBX_START-MD_CSIZ+MD_FREAD_R-MD_FSTART	; CALL ADDRESS FOR READ FLASH SECTOR
MD_FVERI 	.EQU	HBX_START-MD_CSIZ+MD_FVERI_R-MD_FSTART	; CALL ADDRESS FOR VERIFY FLASH SECTOR
MD_FWRIT 	.EQU	HBX_START-MD_CSIZ+MD_FWRIT_R-MD_FSTART	; CALL ADDRESS FOR WRITE FLASH SECTOR
MD_FERAC	.EQU	HBX_START-MD_CSIZ+MD_FERAC_R-MD_FSTART	; CALL ADDRESS FOR ERASE FLASH CHIP
;
; Message strings
;
msgHeader:	.DB 	CR,LF,CR,LF,"ROMWBW XMODEM FLASH UPDATER",CR,LF,0
msgConfirm:	.DB	CR,LF,CR,LF,"ENTER Y TO CONFIRM OVERWRITE : ",0
msgInstr:	.DB	CR,LF,CR,LF,"START TRANSFER OF YOUR UPDATE IMAGE OR ROM",CR,LF,0
msgUserEx:	.DB	CR,LF,"UPDATER EXITED BY USER",CR,LF,0
msgBank:	.DB	CR,LF,"BANK ",0
msgUnsupC:	.DB	CR,LF,"FLASH CHIP NOT SUPPORTED",CR,LF,0
msgReboot:	.DB	CR,LF,"REBOOTING ...",CR,LF,0
msgCopying:	.DB	CR,LF,"COPYING ...",CR,LF,0
msgCalc:	.DB	CR,LF,"CALCULATING ...",CR,LF,0
msgErase:	.DB	CR,LF,"ERASING ...",CR,LF,0
msgCRC32:	.DB	CR,LF,CR,LF,"CRC32 : ",0
msgFailWrt:	.DB	CR,LF,"FLASH WRITE FAILED",CR,LF,0
msgFailure:	.DB	CR,LF,"TRANSMISSION FAILED",CR,LF,0
msgCancel:	.DB	CR,LF,"TRANSMISSION CANCELLED",CR,LF,0
msgConsole:	.DB	CR,LF,"(C) Set Console Device  : ",0
msgIODevice:	.DB	CR,LF,"(S) Set Serial Device   : ",0
msgWriteV:	.DB	CR,LF,"(V) Toggle Write Verify : ",0
msgBegin:	.DB	CR,LF,"(R) Reboot"
		.DB	CR,LF,"(U) Begin Update"
		.DB	CR,LF,"(X) Exit to Rom Loader"
		.DB	CR,LF,"(D) Duplicate Flash #1 to #2"
		.DB	CR,LF,"(1) CRC 512K Flash"
		.DB	CR,LF,"(2) CRC 1024K Flash"
#IF	(XFUDBG)
		.DB	CR,LF,"(H) Select half speed"
		.DB	CR,LF,"(T) Test timeout"
		.DB	CR,LF,"(F) Dump Debug Data"
		.DB	CR,LF,"(E) Erase Flash chip #1"
		.DB	CR,LF,"(Z) Erase Flash chip #2"
		.DB	CR,LF,"(3) CRC Flash chip #2"
#ENDIF
		.DB	CR,LF,CR,LF,"Select : ",0
msgSuccess:	.DB	CR,LF,CR,LF,"COMPLETED WITHOUT ERRORS ",CR,LF,0
msgEnterUnit:	.DB	CR,LF,"ENTER UNIT NUMBER : ",0
msgCRLF:	.DB	CR,LF,0
msgYES:		.DB	"YES",0
msgNO:		.DB	"NO",0
msgPacErr:	.DB	CR,LF,"PACKET COUNT MISMATCH ERROR",CR,LF,0
msgChkSum	.DB	CR,LF,"CHECKSUM ERROR",CR,LF,0
msgRetry	.DB	CR,LF,"ERROR, RETRY COUNT EXCEEDED",CR,LF,0
msgTimout	.DB	CR,LF,"ERROR, RECEIVE TIMEOUT",CR,LF,0
;
; Variables
;
CONDEV:		.DB	$00		; HBIOS CONSOLE DEVICE NUMBER
SERDEV:		.DB	$00		; HBIOS SERIAL DEVICE NUMBER USED FOR XMODEM TRANSFER
WRTVER:		.DB	$FF		; WRITE VERIFY OPTION FLAG
VERRES:		.DB	$00		; WRITE VERIFY RESULT
BLKCOUT:	.DB	$FF		; BLOCK TEXT OUTPUT DURING TRANSFER IF ZERO
ERATYP		.DB	$00		; HOLDS THE ERASE TYPE FLAG FOR VARIOUS CHIPS
oldSP:		.DW	0		; The orginal SP to be restored before exiting
retrycnt:	.DB 	0		; Counter for retries before giving up
chksum:		.DB	0		; For calculating the checksum of the packet
pktNo:		.DB 	0 		; Current packet Number
pktNo1c:	.DB 	0 		; Current packet Number 1-complemented
MD_FBAS		.DW	$FFFF		; CURRENT BANK AND SECTOR
MD_SECT		.EQU	MD_FBAS		;  BANK BYTE
MD_BANK		.EQU	MD_FBAS+1	;  SECTOR BYTE
CRC		.DW	$FFFF		; CRC32
		.DW	$FFFF
;
packet:		.DB 	0		; SOH
		.DB	0		; PacketN
		.DB	0		; -PacketNo,
		.FILL	128,0		; data*128,
		.DB	0 		; chksum
;
sector4k:	.EQU	$		; 32 PACKETS GET ACCUMULATED HERE BEFORE FLASHING
;
SLACK		.EQU	(USR_END - $)
		.FILL	SLACK,$FF
		.ECHO	"User ROM space remaining: "
		.ECHO	SLACK
		.ECHO	" bytes.\n"
		.END
