

.CMD_Unplug
{
	JSR ROM_plugSetup
	EOR #&FF
	AND TempSpace+1
.^plugDone
	TAY
	CLC
	JSR FRAM_writeByte
	LDA #0
	RTS
}

.CMD_Insert
{
	JSR ROM_plugSetup
	ORA TempSpace+1
	JMP plugDone
}

.ROM_plugSetup
{
	JSR STR_ParseHex
	STA TempSpace				\\ save rom number
	BCS ROM_plugData
	LDX #helpRom-helpBase
	JSR CMD_doError
	EQUS 128, "Bad rom id, expecting ", 0
	
.*ROM_plugData					\\ expects rom id in TempSpace, returns NVRAM data in TempSpace+1 & bitmask in A & NVRAM address in X
	LDX #6						\\ FRAM address is 6 or 7
	LDA TempSpace
	AND #%00001000
	BEQ noinc
	INX
.noinc
	CLC
	JSR FRAM_readByte
	STY TempSpace+1				\\ save FRAM data
	LDA TempSpace
	AND #7
	TAY
	SEC
	LDA #%00000000
.shiftloop
	ROL A
	DEY
	BPL shiftloop
	RTS
}


.CMD_Roms
{
	LDY #swramCheckEnd-swramCheck-1
.copyLoop
	LDA swramCheck,Y
	STA &100,Y
	DEY
	BPL copyLoop
	
	LDY #15
.romsLoop
	STY TempSpace
	LDA #HI(ROM_versionBin)
	STA ReadRomPtr+1
	LDA #LO(ROM_versionBin)
	STA ReadRomPtr
	JSR OSRDRM
	STA TempSpace+2
	LDY TempSpace
	EOR #&FF	
	LDX OS_ROMNum
	JSR &100
	JSR OSRDRM
	LDY TempSpace
	EOR #&FF
	EOR TempSpace+2
	BNE notSWRam
	LDA TempSpace+2
	LDX OS_ROMNum
	JSR &100
	LDA #0
	BEQ swRam
.notSWRam
	LDA OS_RomTable,Y
	BNE swRam
.emptySlot
	LDY TempSpace
	DEY
	BPL romsLoop
	LDA #0
	RTS
.swRam
	STA TempSpace+2
	JSR STR_PrintString
	EQUS "  Rom ",0	
	LDA TempSpace
	JSR STR_printDigit
	JSR STR_PrintString
	EQUS ": (",0
	JSR ROM_plugData
	AND TempSpace+1
	BEQ unplugged
	LDA #' '
	BNE plugged
.unplugged
	LDA #'U'
.plugged
	JSR OSWRCH
	LDY TempSpace
	LDA OS_RomTable,Y
	BMI service
	LDA #' '
	BNE noService
.service
	LDA #'S'
.noService
	JSR OSWRCH
	LDA OS_RomTable,Y
	AND #%01000000
	BNE lang
	LDA #' '
	BNE notLang
.lang
	LDA #'L'
.notLang
	JSR OSWRCH
	LDA TempSpace+2
	BEQ swRam2
	LDA #' '
	BNE notSWRam2
.swRam2
	LDA #'W'
.notSWRam2	
	JSR OSWRCH
	LDA #')'
	JSR OSWRCH
	LDA OS_RomTable,Y
	BEQ emptySWRam
	LDA #HI(ROM_copyrightOffset)
	STA ReadRomPtr+1
	LDA #LO(ROM_copyrightOffset)
	STA ReadRomPtr
	LDY TempSpace
	JSR OSRDRM
	STA TempSpace+2
	LDA #&08
	STA ReadRomPtr
	JSR printRomStr
	LDA ReadRomPtr
	CMP TempSpace+2
	BEQ noVersion
	JSR printRomStr		
.noVersion
	JSR OSNEWL
	JMP emptySlot
	
.emptySWRam
	JSR STR_PrintString
	EQUS " -Empty SWRAM-",0
	JMP noVersion
	
.printRomStr
	LDA #' '
.titleLoop
	JSR OSWRCH
	INC ReadRomPtr
	LDY TempSpace
	JSR OSRDRM
	BNE titleLoop
	RTS
	
.swramCheck
	STY OS_ROMNum
	STY ROMSEL
	STA ROM_versionBin
	STX OS_ROMNum
	STX ROMSEL
	RTS
.swramCheckEnd
}

