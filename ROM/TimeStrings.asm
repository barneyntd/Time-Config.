\*******************************************************\
\														\
\				Time strings							\
\														\
\*******************************************************\

.RTC_TLAtable
	EQUS "???"
.RTC_MonthsString
	EQUS "JanFebMarAprMayJunJulAugSepOctNovDec"
MonthsCount	= (P% - RTC_MonthsString)/3
.RTC_DaysString
	EQUS "SunMonTueWedThuFriSat"
DaysCount = (P% - RTC_DaysString)/3
.RTC_ListZoneString
	EQUS " = "
.RTC_UTCString
	EQUS "UTC",0,0

\*******************************************************\
\														\
\				Convert time to text					\
\														\
\*******************************************************\

.RTC_OutputText				\\ Save a character to (OSWORDPtr)+Y, or send it to OSASCI
{
	PHA
	LDA OSWORDPtr+1			\\ check output buffer
	BEQ printit				\\ if zero, print instead
	PLA
	STA (OSWORDPtr),Y
	INY
	RTS
.printit
	PLA
	INY
	JMP OSASCI
}

.RTC_BCDtoText				\\ Convert BCD byte to two ascii characters, or ?? if N set
							\\ A=BCD number, (OSWORDPtr)+Y write address, Y+=2
{
	BMI unsetBCD
	PHA
	LSR A
	LSR A
	LSR A
	LSR A
	JSR BCDdigit
	PLA
	AND #&0F
.BCDdigit		  			\\ Convert digit to ascii & inc Y; A=digit, (OSWORDPtr)+Y result
	CLC
	ADC #'0'
	JMP RTC_OutputText
.unsetBCD
	LDA #'?'
	JSR RTC_OutputText
	JMP RTC_OutputText
}

.RTC_TLAtoText				\\ Convert index to string from TLAtable, C set for ???
							\\ A = index  Y+=3
{
	BCC normalTLA
	LDA #0
.normalTLA
	STA TempSpace2
	ASL A
	ADC TempSpace2			\\ multiply by 3
	TAX
	LDA RTC_TLAtable,X
	JSR RTC_OutputText
	INX
	LDA RTC_TLAtable,X
	JSR RTC_OutputText
	INX
	LDA RTC_TLAtable,X
	JMP RTC_OutputText
}	
	
.RTC_readTimeString			\\ Read date & time from RTC & convert to string
	JSR RTC_readTime
.RTC_TimetoText				\\ convert time in TempSpace to string in (OSWORDPtr),Y or OSASCI
{
	LDY #0
	LDA TempWkday			\\ weekday
	CLC
	ADC #(RTC_DaysString - RTC_TLAtable) DIV 3
	JSR RTC_TLAtoText
	LDA #','
	JSR RTC_OutputText
	LDA TempDay				\\ day
	JSR RTC_BCDtoText
	LDA #' '
	JSR RTC_OutputText
	LDA TempMonth			\\ month
	CMP #&13
	BCS badMonth 
	CMP #10
	BCC monthBin
	SBC #6					\\ convert from BCD
.monthBin
	CLC
	ADC #(RTC_MonthsString - RTC_TLAtable - 1) DIV 3
.badMonth
	JSR RTC_TLAtoText
	LDA TempCentury			\\ century
	BPL centuryOK			\\ 00 - 79
	CMP #&99-&7F			\\ anything greater than &99 sets N
	BMI skipYears
.centuryOK
	LDA #' '
	JSR RTC_OutputText
	LDA TempCentury			\\ century
	JSR RTC_BCDtoText
	LDA TempYear			\\ year
	BPL yearOK				\\ 00 - 79
	CMP #&99-&7F			\\ anything greater than &99 sets N
.yearOK
	JSR RTC_BCDtoText
.skipYears
	LDA #'.'
	JSR RTC_OutputText
	LDA TempHour			\\ hour
	JSR RTC_BCDtoText
	LDA #':'
	JSR RTC_OutputText
	LDA TempMinute			\\ minute
	JSR RTC_BCDtoText
	LDA #':'
	JSR RTC_OutputText
	LDA TempSecond			\\ second
	JSR RTC_BCDtoText
	LDA #&0D
	JMP RTC_OutputText
}


\*******************************************************\
\														\
\				Convert to/from Acorn BCD				\
\														\
\*******************************************************\

.RTC_readTimeBCD			\\ Read date & time from RTC & convert to Acorn BCD format
	JSR RTC_readTime
.RTC_TimeToABCD				\\ Convert RTC time to Acorn format BCD time
							\\ OSWORDPtr=buffer address for result, buffer size = 7
	LDY #6
.RTC_TimeToABCD2
{
	LDA TempSecond			\\ seconds
	BMI errorTimeBCD		\\ clock integrity failed
	STA (OSWORDPtr),Y
	DEY						\\ #5
	LDA TempMinute			\\ minutes
	STA (OSWORDPtr),Y
	DEY						\\ #4
	LDA TempHour			\\ hours
	STA (OSWORDPtr),Y
	DEY						\\ #3
	LDX TempWkday			\\ weekdays
	INX						\\ fix different day representation
	TXA
	STA (OSWORDPtr),Y
	DEY						\\ #2
	LDA TempDay				\\ days
	STA (OSWORDPtr),Y
	DEY						\\ #1
	LDA TempMonth			\\ months
	STA (OSWORDPtr),Y
	DEY						\\ #0
	LDA TempYear			\\ years
	STA (OSWORDPtr),Y
	RTS
.errorTimeBCD				\\ time unreliable, so return &FFFFFFFFFFFFFF
	LDA #&FF
.timeErrLoop
	STA (OSWORDPtr),Y
	DEY
	BPL timeErrLoop
	RTS
}

IF OSWORDE8
.RTC_readTimeBCD8
{
	JSR RTC_readTime
	LDY #7					\\ data is shifted for century
	JSR RTC_TimeToABCD2
	DEY
	LDA TempCentury
	STA (OSWORDPtr),Y
	RTS
}
ENDIF

.RTC_ABCDtoTime				\\ Convert Acorn format BCD time to RTC time
							\\ OSWORDPtr=buffer address for data, buffer size = 7
	LDY #6
.RTC_ABCDtoTime2
{
	LDA (OSWORDPtr),Y
	STA TempSecond			\\ seconds
	DEY						\\ #5
	LDA (OSWORDPtr),Y
	STA TempMinute			\\ minutes
	DEY						\\ #4
	LDA (OSWORDPtr),Y
	STA TempHour			\\ hours
	DEY						\\ #3
	LDA (OSWORDPtr),Y
	TAX
	DEX						\\ fix different day representation
	STX TempWkday			\\ weekdays
	DEY						\\ #2
	LDA (OSWORDPtr),Y
	STA TempDay				\\ days
	DEY						\\ #1
	LDA (OSWORDPtr),Y
	STA TempMonth			\\ months
	DEY						\\ #0
	LDA (OSWORDPtr),Y
	STA TempYear			\\ years
	BMI century19			\\ assume year '80 - '99 is century 19
	LDA #&20				\\ assume year '00 - '79 is century 20
	BNE storeCentury
.century19
	LDA #&19
.storeCentury
	STA TempCentury
	RTS
}

.RTC_ConvertTimeString		\\ Convert Acorn format BCD to string
							\\ OSWORDPtr=buffer address for data and result, buffer size = 8
{
	LDY #7					\\ the data is one byte shifted
	JSR RTC_ABCDtoTime2		\\ convert to RTC time
	JMP RTC_TimetoText		\\ and print to string
}

IF OSWORDE8
.RTC_ConvertTimeString8
{
	LDY #8					\\ the data is two bytes shifted
	JSR RTC_ABCDtoTime2		\\ convert to RTC time
	DEY
	LDA (OSWORDPtr),Y		\\ century
	STA TempCentury
	JMP RTC_TimetoText		\\ and print to string
}
ENDIF

.RTC_ReadCTZBCD				\\ read century and timezone from FRAM as BCD to buffer
{
	LDX #NVR_Century
	LDY #3
	JSR FRAM_readBytes		\\ read century, hour offset, minute offset
	LDY #2
.readCTZloop
	LDA TempSpace,Y
	STA (OSWORDPtr),Y		\\ copy result to buffer
	DEY
	BPL readCTZloop
	RTS
}

.RTC_readAlarmBCD			\\ Read date & time from NVRAM & convert to ABCD; A = alarm no, or N for set time
{
	JSR RTC_readSavedTime
	JMP RTC_TimeToABCD
}
	
\*******************************************************\
\														\
\				Convert BCD to binary					\
\														\
\*******************************************************\

.BCDtoBinary				\\ convert BCD in A to binary. Uses TempSpace2
{
	STA TempSpace2
	AND #&F0				\\ high digit * 16
	LSR A					\\ high digit * 8
	STA TempSpace2+1
	LSR A
	LSR A					\\ high digit * 2
	ADC TempSpace2+1		\\ high digit * 10 (C is clear from shift)
	STA TempSpace2+1
	LDA TempSpace2
	AND #&0F				\\ low digit
	ADC TempSpace2+1		\\ low digit + high digit * 10 (C is clear last ADC)
	RTS						
}

\*******************************************************\
\														\
\				Parse time string						\
\														\
\*******************************************************\

.RTC_ASCdigit				\\ Convert ascii digit in (OSWORDPtr),Y to BCD & inc Y; returns &FF & N set if not '0'-'9'
{
	LDA (OSWORDPtr),Y
	INY
	CMP #'9'+1				\\ error if greater than '9'
	BCS badDigit
	SBC #'0'-1				\\ carry is clear, so -1
	BCS goodDigit			\\ error if less than '0'
.badDigit
	LDA #&FF				\\ error
.goodDigit
	RTS
}
	
.RTC_textToBCD		 		\\ convert 2 ascii digits in (OSWORDPtr),Y to BCD & Y+=2; returns &FF & C clear if not number,
{
	JSR RTC_ASCdigit		\\ calculate tens digit
	BMI noMatch				\\ if error, return
	ASL A
	ASL A
	ASL A
	ASL A
	STA TempSpace2+2		\\ save tens value
	JSR RTC_ASCdigit		\\ calculate units
	BMI noMatch				\\ if error, return
	ORA TempSpace2+2		\\ add tens
	SEC
	RTS
}
	
.RTC_matchWord				\\ look up 3 character word in (OSWORDPtr),Y in list & Y+=3; return index (from 0) or &FF in X & N set
							\\ last list element in (TempSpace2),Y, no of elements - 1 in X
{
	STX TempSpace
	STY TempSpace+1
.wordLoop
	LDX #3					\\ 3 characters per word
.letterLoop
	LDA (OSWORDPtr),Y		\\ next letter
	EOR (TempSpace2),Y		\\ compare with list
	AND #LO(NOT(&20))		\\ ignore capitalisation
	BNE notThisWord			\\ characters don't match
	INY						\\ next character
	DEX
	BNE letterLoop			\\ repeat
.noMoreWords
	LDX TempSpace			\\ word index
	RTS
.notThisWord
	DEC TempSpace
	BMI noMoreWords			\\ end of list
	LDY TempSpace+1			\\ restore Y to start of word
	LDA TempSpace2
	SEC
	SBC #3					\\ back three characters in list
	STA TempSpace2
	BCS wordLoop
	DEC TempSpace2+1
	JMP wordLoop
}

.RTC_ParseTime				\\ parse string of the form hh:mm:ss in (OSWORDPtr),Y
							\\ seconds, minutes, hours in TempSpace; C clear for no match
{
	JSR RTC_textToBCD
	BCC noMatch
	CMP #&24
	BCS noMatch
	STA TempHour			\\ hours
	LDA #':'
	CMP (OSWORDPtr),Y		\\ check for ':'
	BNE noMatch
	INY						\\ skip ':'
.*RTC_ParseMinute
	JSR RTC_textToBCD
	BCC noMatch
	CMP #&60
	BCS noMatch
	STA TempMinute			\\ minutes
	LDA #':'
	CMP (OSWORDPtr),Y		\\ check for ':'
	BNE noMatch
	INY						\\ skip ':'
	JSR RTC_textToBCD
	BCC noMatch
	CMP #&60
	BCS noMatch
	STA TempSecond			\\ seconds
	SEC
	RTS
.^noMatch
	CLC
	RTS
}

.RTC_ParseWeekday
{
	STY TempSpace2
	LDA #LO(RTC_DaysString + DaysCount*3)
	SEC
	SBC TempSpace2
	STA TempSpace2
	LDA #HI(RTC_DaysString + DaysCount*3)
	SBC #0
	STA TempSpace2+1
	LDX #DaysCount
	JSR RTC_matchWord		\\ find weekday
	BMI noMatch
	STX TempWkday			\\ weekdays; Sun = 0
	SEC
	RTS
}

.RTC_ParseMonth
{
	STY TempSpace2
	LDA #LO(RTC_MonthsString + MonthsCount*3)
	SEC
	SBC TempSpace2
	STA TempSpace2
	LDA #HI(RTC_MonthsString + MonthsCount*3)
	SBC #0
	STA TempSpace2+1
	LDX #MonthsCount
	JSR RTC_matchWord		\\ find month
	BMI noMatch
	INX
	TXA
	CMP #10
	BCC decimalOK2
	ADC #6-1				\\ C is set, so 6-1 to convert to BCD
.decimalOK2
	STA TempMonth
	SEC
	RTS
}

.RTC_ParseDate				\\ parse string of the form www,dd mmm yyyy in (OSWORDPtr),Y,
							\\ day, weekday, month, year, century in TempSpace+3; C clear for no match
{
	JSR RTC_ParseWeekday	\\ find weekday
	BCC noMatch
	LDA #','
	CMP (OSWORDPtr),Y		\\ check for ','
	BNE noMatch
	INY						\\ skip ','
	JSR RTC_textToBCD		\\ find day
	BCC noMatch
	STA TempDay				\\ days
	LDA #' '
	CMP (OSWORDPtr),Y		\\ check for ' '
	BNE noMatch
	INY						\\ skip ' '
	JSR RTC_ParseMonth		\\ find month
	BCC noMatch
	LDA #' '
	CMP (OSWORDPtr),Y		\\ check for ' '
	BNE noMatch
	INY
	JSR RTC_textToBCD		\\ read century
	BCC noMatch
	STA TempCentury			\\ century
	JSR RTC_textToBCD		\\ read year
	BCC noMatch
	STA TempYear			\\ year
	TYA
	PHA
	LDY TempMonth			\\ month
	JSR RTC_monthLength
	CMP TempDay				\\ day of month: C clear if day past end of month
	PLA
	TAY
	RTS
}

.RTC_ParseTZN				\\ parse three letter time zone, hours in TempSpace+3, mins in TempSpace+4, X=NVRAM loc
{
	STY TempSpace2			\\ save char position
	LDX #NVR_TZDefs-5		\\ one before start of saved zones
	STX TempSpace2+1
	LDX #5
.utcLoop
	LDA RTC_UTCString-1,X		\\ copy "UTC",0,0 into TempSpace
	STA TempTZN-1,X
	DEX
	BNE utcLoop
.nameLoop
	LDA TempTZN,X
	CMP (OSWORDPtr),Y
	BNE nextName
	INY
	INX
	CPX #3
	BCC nameLoop
	LDX TempSpace2+1
	RTS
.nextName
	LDA TempSpace2+1
	CLC
	ADC #5
	CMP #NVR_TZDefs+NVR_TZDefsSpace
	BCS notFound
	STA TempSpace2+1
	TAX
	LDY #5
	JSR FRAM_readBytes		\\ read name, hour & minute
	LDY TempSpace2
	LDX #0
	BEQ nameLoop
.notFound
	LDY TempSpace2
	CLC
	RTS	
}

.RTC_ParseTimeZone			\\ parse string of the form +hh or -hh, add hours to TempSpace+3
{
	LDA (OSWORDPtr),Y		\\ + or - sign
	TAX
	INY
	JSR RTC_textToBCD		\\ read number
	BCC noMatch2
	CPX #'+'
	BEQ plusMatch
	CPX #'-'
	BNE noMatch2
	STA TempSpace2
	LDA TempHourOffset		\\ load timezone
	SED
	SBC TempSpace2			\\ subtract number; C is set from CPX
	JMP limitCheck
.plusMatch
	SED
	CLC
	ADC TempHourOffset		\\ add timezone
.^limitCheck
	CLD
	CMP #&20
	BCC below20
	CMP #&81
	BCC noMatch2
.below20
	STA TempHourOffset
	SEC
	RTS
.^noMatch2
	CLC
	RTS
}

.RTC_ParseTimeZoneMin			\\ parse string of the form :mm or :mm, add mins to TempSpace+4, carry to TempSpace+3
{
	LDA (OSWORDPtr),Y
	CMP #':'
	BNE noMatch2
	INY
	JSR RTC_textToBCD		\\ read number
	BCC noMatch2
	CPX #'+'
	BEQ plusMatch
	CPX #'-'
	BNE noMatch2
	STA TempSpace2
	LDA TempMinuteOffset	\\ timezone minutes
	SED
	SBC TempSpace2			\\ C is set from CPX
	BCS noCarry
	ADC #&60
	STA TempMinuteOffset
	LDA TempHourOffset
	SBC #1					\\ C is set from ADC
	JMP limitCheck
.noCarry
	STA TempMinuteOffset
	CLD
	SEC
	RTS
.plusMatch
	CLC
	SED
	ADC TempMinuteOffset	\\ timezone minutes
	BCS carry1
	CMP #&60
	BCC noCarry
.carry1
	SBC #&60				\\ carry is set
	STA TempMinuteOffset
	LDA TempHourOffset
	CLC
	ADC #1
	JMP limitCheck
}

.RTC_ParseInc				\\ parse string of the form S+ or S-, return 1 or &FF in A
{
	LDA (OSWORDPtr),Y
	AND #LO(NOT(&20))		\\ ignore capitalisation
	CMP #'S'
	BNE noMatch3
	INY
	LDA (OSWORDPtr),Y		\\ + or - sign
	CMP #'+'
	BEQ plusMatch
	CMP #'-'
	BNE noMatch3
	LDA #'+'-2
.plusMatch
	INY
	SBC #'+'-1				\\ C is set from comparisons
	SEC
	RTS
}

.RTC_ParseDec				\\ parse string of the form ss.cc
{
	JSR RTC_textToBCD		\\ read ss
	BCC noMatch3
	STA TempSpace2+1
	LDA (OSWORDPtr),Y		\\ decimal point
	CMP #'.'
	BNE noMatch3
	INY
	JSR RTC_textToBCD		\\ read cc
	BCC noMatch3
	STA TempSpace2
	SEC
	RTS
.^noMatch3
	CLC
	RTS
}

.RTC_ParseTuningOffset		\\ parse string of the form T+tt or T-tt
{
	LDA (OSWORDPtr),Y		\\ check for 'T'
	AND #LO(NOT(&20))		\\ ignore capitalisation
	CMP #'T'
	BNE noMatch3
	INY
	INY						\\ skip + or - sign
	JSR RTC_textToBCD		\\ read number
	BCC noMatch3
	JSR BCDtoBinary
	STA TempSpace			\\ save number
	CMP #64					\\ limit to +-63
	BCS noMatch3
	DEY
	DEY
	DEY						\\ go back to +-sign
	LDA (OSWORDPtr),Y
	CMP #'+'
	BEQ plusMatch3
	CMP #'-'
	BNE noMatch3
	LDA #0
	SBC TempSpace			\\ negate number; C is set
	SEC
	RTS
.plusMatch3
	LDA TempSpace			\\ C is set
	RTS
}



