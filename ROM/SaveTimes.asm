\*******************************************************\
\														\
\				Read & write named timezones			\
\														\
\*******************************************************\

.RTC_resetTZN
{
	LDX #NVR_TZDefs
.resetLoop1
	SEC
	LDY defaultTZN-NVR_TZDefs,X
	JSR FRAM_writeByte
	INX
	CPX #NVR_TZDefs+10
	BCC resetLoop1
.resetLoop2
	SEC
	JSR FRAM_writeByte
	INX
	CPX #NVR_TZDefs+NVR_TZDefsSpace
	BCC resetLoop2
	RTS
.defaultTZN
	EQUS "GMT",0,0,"BST",1,0
}

.RTC_rewriteTZN						\\ X is index of name in FRAM, Y is position of next char
{
	CPX #NVR_TZDefs
	BCC foundUTC
	TXA
	PHA
	CLC
	JSR GSINIT						\\ skip spaces
	CMP #'='
	BNE badTimezone
	INY
	CLC
	JSR GSINIT						\\ skip spaces
	BEQ delete
	JSR RTC_ParseTZN				\\ base timezone
	BCC badTimezone
	JSR GSREAD
	BCS gotOffset
	DEY
	JSR RTC_ParseTimeZone
	BCC badTimezone
	JSR GSREAD
	BCS gotOffset
	DEY
	JSR RTC_ParseTimeZoneMin
	BCC badTimezone
.gotOffset
	PLA
	ADC #2							\\ C is set
	TAX
	SEC
	LDY TempHourOffset
	JSR FRAM_writeByte
	INX
	LDY TempMinuteOffset
	JSR FRAM_writeByte
	LDA #0
	RTS
.delete
	PLA
	TAX
	LDY #0
	SEC
	JSR FRAM_writeByte
	TYA
	RTS
.foundUTC
	LDX #&FF
	JSR CMD_doError
	EQUS 176, "Can't redefine UTC", 0
.badTimezone
	LDX #helpTimeZone-helpBase
	JSR CMD_doError
	EQUS 220, "Bad timezone, expecting ", 0
}

.RTC_ListZones
{
	LDX #NVR_TZDefs
.listLoop
	STX TempSpace2
	LDY #5
	JSR FRAM_readBytes
	LDA TempTZN
	BEQ skip
	LDY #4
	LDA #' '					\\ print four spaces
.spcLoop
	JSR OSWRCH
	DEY
	BNE spcLoop
.firstLoop
	LDA TempTZN,Y				\\ print character from TLA
	JSR OSWRCH
	INY
	CPY #3
	BCC firstLoop
	LDY #0
	LDA RTC_ListZoneString
.secondLoop
	JSR OSWRCH					\\ print character from format string
	INY
	LDA RTC_ListZoneString,Y
	BNE secondLoop
	LDA TempHourOffset
	BPL offsetNotNeg
	LDA #'-'
	JSR OSWRCH
	SED
	SEC
	LDA #&60
	SBC TempMinuteOffset
	CMP #&60
	BNE noCarry
	LDA #0
.noCarry
	STA TempMinuteOffset
	LDA #0
	SBC TempHourOffset			\\ negate offset
	CLD
	BNE printOffset
.offsetNotNeg
	LDA #'+'
	JSR OSWRCH
	LDA TempHourOffset
.printOffset
	JSR STR_PrintBCD
	LDA #':'
	JSR OSWRCH
	LDA TempMinuteOffset
	JSR STR_PrintBCD
	LDA #' '
	JSR OSWRCH
.skip
	LDA TempSpace2
	CLC
	ADC #5
	TAX
	CMP #NVR_TZDefs+NVR_TZDefsSpace
	BCC listLoop
	JSR OSNEWL
	RTS
}




\*******************************************************\
\														\
\				Read & write saved time					\
\														\
\*******************************************************\

.RTC_readSavedTime
{
	BPL readAlarmBCD
	LDX #NVR_SetTime
	LDY #8
	JMP FRAM_readBytes		\\ read seconds .. century
.readAlarmBCD				\\ Read date & time from NVRAM to TempSpace; A = alarm no
	RTS
}

.RTC_saveSetTime
{
	LDX #NVR_MinuteOffset
	SEC
	JSR FRAM_readByte		\\ look up timezone minutes
	TYA
	SED
	JSR RTC_subMinutes		\\ subtract timezone minutes from time
	LDX #NVR_HourOffset
	SEC
	JSR FRAM_readByte		\\ look up timezone hours
	STY TempSpace2
	LDA #0
	SEC
	SBC TempSpace2
	JSR RTC_addHours		\\ subtract timezone hours from time
	CLD
	LDX #NVR_SetTime
	LDY #8
	SEC
	JMP FRAM_writeBytes
}

