
.timestr1
	EQUS "S",0
.timestr3
	EQUS "zzz",0
.timestr4
	EQUS "T+tt",0
.timestr6
	EQUS "zzz+hh",0
.timestr7
	EQUS "S+ss.cc",0
.timestr8
	EQUS "hh:mm:ss",0
.timestr9
	EQUS "zzz+hh:mm",0
.timestr15
	EQUS "www,dd mmm yyyy",0
.timestr24
	EQUS "www,dd mmm yyyy.hh:mm:ss",0
	EQUB 0

.helpTime
	EQUS "(<timestr>)",0
.helpTimeZone
	EQUS "<zzz>=(<zzz>+/-<00-19>(:<00-59>))",0
.helpConf
	EQUS "(<config>)",0
.helpRom
	EQUS "<0-F>",0
.help7
	EQUS "<0-7>",0
.help8
	EQUS "<0-8>",0
.help255
	EQUS "<0-255>",0
.helpTV
	EQUS "<252-3>(,<0-1>)",0
IF CONFIGFSPS
.helpSid
	EQUS "(<0-127>.)<0-255>",0
ENDIF
.helpAlt
	EQUS " /",0								\\ must be last

helpBase = P% - &100
IF timestr1 < helpBase OR helpTime - helpBase < &80
   ERROR "Table too large"
ENDIF

.commandTable
	EQUS "TIME", helpTime - helpBase
	EQUS "CONFIGURE", helpConf - helpBase
	EQUS "STATUS", helpConf - helpBase
	EQUS "UNPLUG", helpRom - helpBase
	EQUS "INSERT", helpRom - helpBase
	EQUS "ROMS", &FF
	EQUB 0

.configTable
	EQUS "BAUD", help8 - helpBase
	EQUS "BOOT", helpAlt - helpBase
	EQUS "NOBOOT", &FF
	EQUS "CAPS", helpAlt - helpBase
	EQUS "NOCAPS", helpAlt - helpBase
	EQUS "SHCAPS", &FF
	EQUS "DATA", help7 - helpBase
	EQUS "DELAY", help255 - helpBase
	EQUS "FDRIVE", help7 - helpBase
	EQUS "FILE", helpRom - helpBase
	EQUS "IGNORE", help255 - helpBase
	EQUS "LANG", helpRom - helpBase
	EQUS "LOUD", helpAlt - helpBase
	EQUS "QUIET", &FF
	EQUS "MODE", help7 - helpBase
	EQUS "TUBE", helpAlt - helpBase
	EQUS "NOTUBE", &FF
	EQUS "PRINT", help7 - helpBase
	EQUS "REPEAT", help255 - helpBase
	EQUS "TV", helpTV - helpBase
	EQUS "TIMEZONE", helpTimeZone - helpBase
	EQUB 0
IF CONFIGFSPS
.fspsTable
	EQUS "FS", helpSid - helpBase
	EQUS "PS", helpSid - helpBase
	EQUB 0
ENDIF

.helpTable
	EQUS "T&C",&FF
	EQUS "TIME",&FF
	EQUB 0
	
IF P% - commandTable > &FF
	ERROR "Table too large"
ENDIF

.cmdJmpTable
	EQUW CMD_Time-1, CMD_Configure-1, CMD_Status-1, CMD_Unplug-1, CMD_Insert-1, CMD_Roms-1


.CMD_printTerm
{
	LDA #' '
	JSR OSWRCH
.printLoop
	JSR OSWRCH
	INX
	LDA commandTable-1,X
	BPL printLoop
	RTS
}

.CMD_Help							\\ List all commands from commandTable,X, with corresponding helpBase strings
{
	JSR CMD_printTerm
	CMP #&FF
	BEQ noHelpParam
.helpParam
	TAY
	LDA #' '
.paramLoop
	JSR OSWRCH
	INY
	BEQ CMD_Help
	LDA helpBase-1,Y
	BNE paramLoop
.noHelpParam
	JSR OSNEWL
	LDA commandTable,X
	BNE CMD_Help
IF CONFIGFSPS
	CPX #fspsTable-commandTable-1
	BNE notFSPS
	LDX OS_ROMNum
	LDA OS_RomBytes,X
	AND #&40
	BEQ notFSPS
	LDX #fspsTable-commandTable
	BNE CMD_Help
.notFSPS
ENDIF
	RTS
}


.CMD_matchCommand					\\ Search for the word at (TextPointer),Y from commandTable,X
									\\ return with A = CommandTable,X & TempSpace+1 = index for match, TempSpace+2 = start of matched term, N set for match
									\\ N clear & A = 4 for no match, Z set for blank
{
	LDA #0
	STA TempSpace+1				\\ save table index
	CLC
	JSR GSINIT
	BEQ blankCommand
	STY TempSpace					\\ save start of word
.wordLoop
	STX TempSpace+2
.matchLoop
	JSR GSREAD						\\ next character
	BCS endWord						\\ end of word
	CMP #'.'
	BEQ abbrev						\\ abbreviation
	EOR commandTable,X
	AND #LO(NOT(&20))				\\ capitalise
	BNE notMatch
	INX
	BNE matchLoop
.endWord
	LDA commandTable,X				\\ check for end of word in table
	BPL skipLoop2					\\ no match
	RTS								\\ match
.skipLoop
	INX	
.abbrev
	LDA commandTable,X				\\ check for end of word in table
	BPL skipLoop					\\ skip over unabbreviated word
	RTS
.skipLoop2
	INX	
.notMatch
	LDA commandTable,X
	BPL	skipLoop2					\\ skip over unmatched word
	INC TempSpace+1					\\ increment table index
	LDY TempSpace					\\ go back to start of word
	INX								\\ next word in table
	LDA commandTable,X				\\ check for table end
	BNE wordLoop
IF CONFIGFSPS
	CPX #fspsTable-commandTable-1
	BNE notFSPS
	LDX OS_ROMNum
	LDA OS_RomBytes,X
	AND #&40
	BEQ notFSPS
	LDX #fspsTable-commandTable
	BNE wordLoop
.notFSPS
ENDIF
	LDA #4
.blankCommand
	RTS
}

.CMD_Command
{
	LDX #0
	JSR CMD_matchCommand
	BPL passCommand					\\ either blank or no match
	LDA TempSpace+1
	ASL A
	TAX
	LDA cmdJmpTable+1,X				\\ address high
	PHA
	LDA cmdJmpTable,X				\\ address low
	PHA
.passCommand
	RTS
}

.CMD_doError
{
	PLA
	STA ErrorPtr
	PLA
	STA ErrorPtr+1
	LDA #0								\\ opcode for BRK
	TAY
.errorLoop
	STA &0100,Y
	INY
	LDA (ErrorPtr),Y
	BNE errorLoop
.errorLoop2
	LDA helpBase,X
	STA &0100,Y
	INY
	INX
	CMP #0
	BNE errorLoop2
	JMP &0100
}

.CMD_Time
{
	CLC
	JSR GSINIT				\\ skip spaces
	BNE setTime				\\ not end of line
.printTime
	LDY #0
	STY OSWORDPtr+1			\\ don't save in buffer
	JSR RTC_readTimeString	\\ read current time and send to OSWRCH
.doneTime
	LDA #0
	RTS
.setTime
	STY TempSpace			\\ save Y
	LDX #1					\\ count rest of line, except trailing spaces
.setTimeLoop
	STX TempSpace+1
.noSaveLoop
	INY
	INX
	LDA (TextPointer),Y
	CMP #&0D				\\ check for end of line
	BEQ endOfText
	CMP #' '				\\ check for whitespace
	BNE setTimeLoop
	BEQ noSaveLoop
.endOfText
	LDA TextPointer
	STA OSWORDPtr
	LDA TextPointer+1
	STA OSWORDPtr+1
	LDY TempSpace			\\ back to saved point
	LDA TempSpace+1			\\ retrieve length without trailing whitespace
	JSR OSW_timeCommand
	BCS doneTime
	LDX #&FF
	JSR CMD_doError
	EQUS 220, "Bad timestr", 0
}

.CMD_Configure
{
	LDX #&28
.serviceCall
	CLC
	JSR GSINIT					\\ check for end of line
	PHP							\\ save result
	LDA #143
	JSR OSBYTE					\\ issue service call &28 or &29 to roms
	PLP
	BEQ noParams				\\ if no config term, can't be an error
	TXA							\\ X is zero if some rom dealt with it, NZ otherwise
	BNE error
.noParams
	LDA #0
	RTS
.error
	LDX #&FF
	JSR CMD_doError
	EQUS 254, "Bad config", 0

.*CMD_Status
	LDX #&29
	BNE serviceCall
}




