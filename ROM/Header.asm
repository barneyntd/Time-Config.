\ System constants
OSWORDPtr	= &F0
OSWORDNum	= &EF
OSBYTEA		= &EF
OSBYTEX		= &F0
OSBYTEY		= &F1
TextPointer	= &F2		\\ Command line pointer
ReadRomPtr	= &F6
ErrorPtr	= &FD
TempSpace	= &A8		\\ A8 - AF supposed to be usable for OS commands
TempSpace2	= &E4		\\ E4 - E6 general purpose, used by GSINIT/GSREAD
OSBYTE		= &FFF4
OSWORD		= &FFF1
EVENTV		= &220
OSASCI		= &FFE3
OSWRCH		= &FFEE
OSNEWL		= &FFE7
GSREAD		= &FFC5
GSINIT		= &FFC2
OSRDRM		= &FFB9
OSARGS		= &FFDA
OS_RomTable	= &02A1
OS_RomBytes = &0DF0
OS_ROMNum	= &F4
ROMSEL		= &FE30





\*******************************************************\
\														\
\				ROM header								\
\														\
\*******************************************************\

	JMP SET_defaultLang				\\ pretend to be a language
	JMP ROM_service
	EQUB %11000010					\\ 6502 code, no relocation, language, service
.ROM_copyrightOffset
	EQUB ROM_copyright - codeStart - 1
.ROM_versionBin
	EQUB 04							\\ version 04
.ROM_title
	EQUS "Time & Config.", 0		\\ Title
.ROM_version
	EQUS "0.04", 0					\\ Version
.ROM_copyright
	EQUS "(C) 2025 Barney Hilken", 0
	EQUD 0

.ROM_service
{
	CMP #&FF
	BNE notTube
	JMP SET_TubeControl
.notTube
	CMP #1
	BNE notSetup
	JSR VIA_setup			\\ Setup after reset
	JMP SET_Startup
.notSetup
	CMP #3
	BNE notDefaultFS
	JMP SET_defaultFS
.notDefaultFS
	CMP #4
	BNE notCommand
	JMP CMD_Command			\\ perform OSCLI command
.notCommand
	CMP #7
	BNE notOSBYTE
	LDA OSBYTEA				\\ Check OSBYTE number
	CMP #&A1
	BNE notOSBYTEA1
	LDX OSBYTEX
	CLC
	JSR FRAM_readByte		\\ perform OSBYTE &A1
	LDA #0
	RTS
.notOSBYTEA1
	CMP #&A2
	BNE notOSBYTEA2
	LDX OSBYTEX
	LDY OSBYTEY
	CLC
	JSR FRAM_writeByte		\\ perform OSBYTE &A2
	LDA #0
	RTS
.notOSBYTEA2
	LDA #7
	RTS
.notOSBYTE
	CMP #8
	BNE notOSWORD
	LDA OSWORDNum			\\ Check OSWORD number
	CMP #&0E
	BNE notOSWORD0E
	JMP OSWORD0E			\\ perform OSWORD &0E
.notOSWORD0E
	CMP #&0F
	BNE notOSWORD0F
	JMP OSWORD0F			\\ perform OSWORD &0F
.notOSWORD0F
	LDA #8
	RTS
.notOSWORD
	CMP #9
	BNE notHelp
	JMP Help				\\ perform *HELP
.notHelp
IF CONFIGFSPS
	CMP #&F					\\ vectors claimed
	BNE notFileServer
	JMP SET_fileServer
.notFileServer
ENDIF
	CMP #&28
	BNE notUnKnConf
	JMP CON_Configure		\\ perform CONFIGURE service
.notUnKnConf
	CMP #&29
	BNE notUnKnStat
	JMP CON_Status			\\ perform STATUS service
.notUnKnStat
	RTS
}

\*******************************************************\
\														\
\				*HELP									\
\														\
\*******************************************************\

.Help
{
	TYA
	PHA							\\ save character position
	LDX #helpTable-commandTable
	JSR CMD_matchCommand		\\ check list of help headings
	BEQ noHelpTerm
	BPL doneHelp				\\ not one of ours
	JSR helpHeading
	LDX TempSpace+1			\\ index of recognised help heading
	BNE notTChelp
	LDX #0
	JSR CMD_Help				\\ print list of commands & parameters
	JMP doneHelp
.notTChelp
	JSR STR_PrintString
	EQUS "  Timestrings",13,0
	LDX #&FF
.helpLoop1
	LDA #' '
	JSR OSWRCH
	JSR OSWRCH
	JSR OSWRCH
.helpLoop
	JSR OSWRCH
	INX
	LDA timestr1,X
	BNE helpLoop
	JSR OSNEWL
	LDA timestr1+1,X
	BNE helpLoop1
	BEQ doneHelp
.noHelpTerm
	JSR helpHeading
	LDX #helpTable-commandTable
	JSR CMD_Help				\\ print list of help headings
.doneHelp
	PLA
	TAY							\\ restore character pos
	LDA #9						\\ pass on to other roms
	RTS
	
.helpHeading
	JSR OSNEWL
	LDY #0
	LDA ROM_title,Y
.titleLoop
	JSR OSWRCH					\\ print rom title
	INY
	LDA ROM_title,Y
	BNE titleLoop
	LDA #' '
.versionLoop
	JSR OSWRCH					\\ print rom version
	INY
	LDA ROM_title,Y
	BNE versionLoop
	JMP OSNEWL					\\ print newline
}







