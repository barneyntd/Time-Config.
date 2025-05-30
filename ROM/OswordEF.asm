.OSW_saveTempSpace
{
	PLA
	STA TempSpace2			\\ save return address
	PLA
	STA TempSpace2+1
	STY TempSpace2+2		\\ save Y
	LDY #7
.saveLoop
	LDA TempSpace,Y
	PHA
	DEY
	BPL saveLoop
	LDY TempSpace2+2		\\ restore Y
	LDA TempSpace2+1		\\ restore return address
	PHA
	LDA TempSpace2
	PHA
	RTS
}

.OSW_restoreTempSpace
{
	PLA
	STA TempSpace2			\\ save return address
	PLA
	STA TempSpace2+1
	STY TempSpace2+2		\\ save Y
	LDY #0
.saveLoop
	PLA
	STA TempSpace,Y
	INY
	CPY #8
	BNE saveLoop
	LDY TempSpace2+2		\\ restore Y
	LDA TempSpace2+1		\\ restore return address
	PHA
	LDA TempSpace2
	PHA
	RTS
}


\*******************************************************\
\														\
\				OSWORD 14								\
\														\
\*******************************************************\

.OSWORD0E					\\ Read clock in various ways. Sets A to 0 if done or 8 if not done
{
	JSR OSW_saveTempSpace
	LDY #0
	LDA (OSWORDPtr),Y		\\ function determined by first byte in buffer
	BNE notReadTimeString	\\ 0: read date & time as string
	JSR RTC_readTimeString
	JMP used
.notReadTimeString
	CMP #1					\\ 1: read date & time as BCD
	BNE notReadTimeBCD
	JSR RTC_readTimeBCD
	JMP used
.notReadTimeBCD
	CMP #2					\\ 2: convert BCD date & time to string
	BNE notConvertBCDTime	
	JSR RTC_ConvertTimeString
	JMP used
.notConvertBCDTime
	CMP #5					\\ 5: read century & timezone as BCD
	BNE notReadTimezone	
	JSR RTC_ReadCTZBCD
	JMP used
.notReadTimezone
	CMP #6					\\ 6: read alarm date & time as BCD
	BNE notReadAlarmBCD
	INY
	LDA (OSWORDPtr),Y		\\ alarm number determined by second byte in buffer
	JSR RTC_readAlarmBCD
	JMP used
.notReadAlarmBCD
IF OSWORDE8
	CMP #9					\\ 9: read date & time as BCD with century
	BNE notReadTimeBCD8
	JSR RTC_readTimeBCD8
	JMP used
.notReadTimeBCD8
	CMP #10					\\ 10: convert BCD date & time to string with century
	BNE notConvertBCDTime8	
	JSR RTC_ConvertTimeString8
	JMP used
.notConvertBCDTime8
ENDIF
	JMP unused
}


\*******************************************************\
\														\
\				OSWORD 15								\
\														\
\*******************************************************\

.OSWORDJMPtable
	EQUW OSW_oneChar-1, OSW_unused-1, RTC_setTZNZone-1, RTC_tuneClock-1
	EQUW OSW_unused-1, RTC_setTimeZone-1, RTC_incSeconds-1, RTC_setTimeOnly-1
	EQUW RTC_setTimeZoneMin-1, OSW_unused-1, OSW_unused-1, OSW_unused-1
	EQUW OSW_unused-1, OSW_unused-1, RTC_setDateOnly-1, OSW_unused-1
	EQUW OSW_unused-1, OSW_unused-1,OSW_unused-1, OSW_unused-1
	EQUW OSW_unused-1, OSW_unused-1,OSW_unused-1, RTC_setDateTime-1

.OSWORD0F					\\ set date, time & alarm from string. Sets A to 0 if done or 8 if not done
{
	JSR OSW_saveTempSpace
	LDY #0
	LDA (OSWORDPtr),Y
	BEQ unused
	INY
	JSR OSW_timeCommand
	BCS used
.^unused
	JSR OSW_restoreTempSpace
	LDA #8
	RTS
.^used
	JSR OSW_restoreTempSpace
	LDA #0
	RTS
}

.OSW_timeCommand
{
	CMP #25
	BCS OSW_unused
	ASL A
	TAX
	LDA OSWORDJMPtable-1,X	\\ address high
	PHA
	LDA OSWORDJMPtable-2,X	\\ address low
	PHA
	RTS
.*OSW_unused
	CLC
	RTS
}

.OSW_oneChar
{
	LDA (OSWORDPtr),Y
	AND #LO(NOT(&20))		\\ ignore capitalisation
	CMP #'S'
	BNE OSW_unused
	JSR RTC_Synchronise
	SEC
	RTS
}


