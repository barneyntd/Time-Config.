\ NVRAM locations (upper page)
NVR_Flags		= &FF
NVR_Flags_8099	= %10000000			\\ Year is '80 - '99
NVR_Flags_FLY	= %01000000			\\ False leap year, not yet corrected
NVR_Century		= &FC
NVR_HourOffset	= &FD				\\ Hour offset from UTC for timezone & summertime
NVR_MinuteOffset= &FE				\\ minute offset
NVR_SetTime		= &F0				\\ time clock was set, in UTC, eight bytes
NVR_TZDefs		= &A0				\\ start of saved timezone names
NVR_TZDefsSpace	= &50				\\ 16 * 5 = 80 bytes, three letters, hour, minute

\*******************************************************\
\														\
\				Time format								\
\														\
\*******************************************************\

TempSecond			= TempSpace			\\ seconds, 00 - 59 BCD
TempMinute			= TempSpace+1		\\ minutes, 00 - 59 BCD
TempHour			= TempSpace+2		\\ hours, 00 - 23 BCD
TempDay				= TempSpace+3		\\ day of month, 01 - 31 BCD
TempWkday			= TempSpace+4		\\ Sunday = 0 - Saturday = 6
TempMonth			= TempSpace+5		\\ months, 01 - 12 BCD
TempYear			= TempSpace+6		\\ year, 00 - 99 BCD
TempCentury			= TempSpace+7		\\ century, 00 - 99 BCD



\*******************************************************\
\														\
\				Timezone format							\
\														\
\*******************************************************\

TempTZN				= TempSpace			\\ name, three alphabetic characters
TempHourOffset		= TempSpace+3		\\ hours, -19 - +19 signed BCD
TempMinuteOffset	= TempSpace+4		\\ minutes, 00 - 59 BCD


\*******************************************************\
\														\
\				Read RTC registers						\
\														\
\*******************************************************\


.RTC_readTime				\\ Read date & time from RTC & correct using flags
{
	LDA #RTC_TD_sec			\\ seconds register
	LDX #7					\\ seconds, minutes, hours, days, weekdays, months, years
	LDY #0
	JSR RTC_readBytes
	LDA TempSecond			\\ if seconds are invalid, everything is
	BPL timeOK
	LDA #&FF
	LDX #7
.copyloop2
	STA TempSpace,X
	DEX
	BPL copyloop2
	RTS
.timeOK
	LDX #NVR_Century
	SEC
	JSR FRAM_readByte		\\ look up century
	STY TempCentury
	LDX #NVR_Flags
	SEC
	JSR FRAM_readByte		\\ look up flags; result in Y
	LDA TempYear			\\ year
	BMI year8099			\\ year is 80-99
	TYA
	BPL noCenturyInc		\\ NVR_Flags_8099 not set
	PHA						\\ save flags
	LDA TempCentury			\\ century
	SED
	CLC
	ADC #1					\\ add one in BCD mode
	CLD
	STA TempCentury
	TAY
	LDX #NVR_Century
	SEC
	JSR FRAM_writeByte		\\ save century in NVRAM
	PLA						\\ flags
	AND #LO(NOT(NVR_Flags_8099))	\\ clear 80-99 flag
	TAY
.noCenturyInc
	AND #NVR_Flags_FLY		\\ check false leap year
	BEQ noDayInc
	LDA TempYear			\\ year
	BNE dayInc				\\ year after '00
	LDA #2					\\ Feb
	CMP TempMonth			\\ month
	BCC dayInc				\\ month after feb
	BNE noDayInc			\\ month before feb
	LDA TempDay				\\ day
	CMP #&29
	BCC noDayInc			\\ day before 29th
	DEC TempDay				\\ avoid double increment
.dayInc
	TYA
	PHA						\\ save flags
	LDA #&01
	SED
	JSR RTC_addMonthDays	\\ increment day to fix unneeded leap year
	CLD
	LDA #RTC_TD_sec
	LDY #0					\\ start from TempSpace
	LDX #7					\\ seconds, minutes, hours, day, weekday, month, year
	JSR RTC_sendBytes		\\ save new date
	PLA						\\ flags
.clearFLYandSave
	AND #LO(NOT(NVR_Flags_FLY))	\\ clear FLY flag
.^saveFlags
	TAY
.noDayInc
	LDX #NVR_Flags
	SEC
	JMP FRAM_writeByte		\\ save flags in NVRAM and return
.year8099
	TYA						\\ flags
	BPL checkCentury		\\ NVR_Flags_8099 clear
	SEC
	RTS
.^checkCentury
	LDA TempCentury			\\ century
	AND #&13
	CMP #&03				\\ ends in 03 or 07
	BEQ nextDiv4			\\ next century is leap year
	CMP #&11				\\ ends in 11, 15 or 19
	BEQ nextDiv4			\\ next century is leap year
	TYA						\\ flags
	ORA #NVR_Flags_8099 OR NVR_Flags_FLY	\\ set both flags
	BNE saveFlags			\\ save flags in NVRAM and return
.nextDiv4
	TYA						\\ flags
	ORA #NVR_Flags_8099		\\ set 80-99 flag
	BNE clearFLYandSave		\\ clear FLY flag, save flags in NVRAM and return
}



\*******************************************************\
\														\
\				Write RTC registers						\
\														\
\*******************************************************\

.RTC_resetClock
{
	LDA #RTC_C1
	LDX #RTC_C1_RESET
	JSR RTC_sendByte		\\ reset clock chip
	LDX #NVR_SetTime		\\ start of clock variables
	LDY #0
	SEC
.wipeLoop
	JSR FRAM_writeByte
	INX
	BNE wipeLoop
	RTS
}

.RTC_setTimeOnly			\\ set time from string in format hh:mm:ss in (OSWORDPtr),Y
{
	JSR RTC_ParseTime
	BCC badString			\\ no match
	LDA #RTC_TD_sec
	LDY #0					\\ start from TempSpace
	LDX #3					\\ seconds, minutes, hours
	JSR RTC_sendBytes
	LDA #RTC_TD_day
	LDX #4					\\ day, wkday, month, year
	JSR RTC_readBytes
	LDX #NVR_Century
	SEC
	JSR FRAM_readByte		\\ get century
	STY TempCentury
	JSR RTC_saveSetTime
	SEC						\\ no error
.^badString
	RTS						\\ carry is clear
}
	
.RTC_setDateOnly			\\ set date from string in format www,dd mmm yyyy in (OSWORDPtr),Y
{
	JSR RTC_ParseDate
	BCC badString
	LDA #RTC_TD_day
	LDY #3					\\ start from TempSpace+3
	LDX #4					\\ day, weekday, month, year
	JSR RTC_sendBytes
	JSR RTC_setCentury
	SEC
	RTS
}

.RTC_setDateTime			\\ set date & time from string in format www,dd mmm yyyy.hh:mm:ss in (OSWORDPtr),Y
{
	JSR RTC_ParseDate
	BCC badString
	LDA #'.'
	CMP (OSWORDPtr),Y		\\ check for '.'
	BNE badString
	INY						\\ skip '.'
	JSR RTC_ParseTime
	BCC badString			\\ no match
	LDA #RTC_TD_sec
	LDY #0					\\ start from TempSpace
	LDX #7					\\ seconds, minutes, hours, day, weekday, month, year
	JSR RTC_sendBytes
	JSR RTC_setCentury
	JSR RTC_saveSetTime
	SEC
	RTS
}

.RTC_setCentury				\\ set century from contents of TempSpace+7 & flags from date in TempSpace
	LDY TempCentury			\\ Century
	LDX #NVR_Century		\\ address to store it
	SEC
	JSR FRAM_writeByte		\\ save century
.RTC_setFlags				\\ set flags according to date in TempSpace
{
	LDX #NVR_Flags
	SEC
	JSR FRAM_readByte		\\ look up flags; result in Y
	LDA TempYear			\\ year
	BPL year0079			\\ year is 00-79
	JMP checkCentury
.year0079
	LDA TempCentury			\\ century
	AND #&13
	BEQ notFLY				\\ century ending 00 04 or 08
	CMP #&12
	BEQ notFLY				\\ century ending 12 or 16
	LDA TempYear			\\ year
	BNE notFLY				\\ year after '00
	LDA TempMonth
	CMP #3					\\ March
	BCS notFLY				\\ month after feb
	TYA
	ORA #NVR_Flags_FLY		\\ set false leap year flag
	AND #LO(NOT(NVR_Flags_8099))	\\ clear 80-79 flag
	JMP saveFlags			\\ save flags and return
.notFLY
	TYA
	AND #LO(NOT(NVR_Flags_8099 OR NVR_Flags_FLY))	\\ clear both flags
	JMP saveFlags			\\ save flags and return
}

\*******************************************************\
\														\
\				Update RTC registers					\
\														\
\*******************************************************\

.RTC_setTimeZoneMin				\\ adjust time depending on string zzz+hh:mm or zzz-hh:mm
{
	JSR RTC_ParseTZN			\\ parse zzz
	BCC noChange
	JSR RTC_ParseTimeZone		\\ parse +/-hh
	BCC noChange
	JSR RTC_ParseTimeZoneMin	\\ parse :mm
	JMP doSetTZNZone
}

.RTC_setTimeZone				\\ adjust time depending on string zzz+hh or zzz-hh
{
	JSR RTC_ParseTZN			\\ parse zzz
	BCC noChange
	JSR RTC_ParseTimeZone		\\ parse +/-hh
	JMP doSetTZNZone
}

.RTC_setTZNZone				\\ adjust time depending on TLA in (OSWORDPtr),Y
{
	JSR RTC_ParseTZN		\\ parse new offset, hours in TempSpace+3, mins in TempSpace+4
.^doSetTZNZone
	BCC noChange			\\ not recognised
	LDX #NVR_MinuteOffset
	JSR FRAM_readByte		\\ look up old minute offset (C is set)
	STY TempSpace2			\\ save for subtraction
	LDY TempMinuteOffset	\\ new minute offset
	JSR FRAM_writeByte		\\ save new minute offset (C is still set)
	TYA
	SED
	SBC TempSpace2			\\ subtract old offset (C still set)
	PHP						\\ save the carry
	BCS positive
	ADC #&60				\\ convert negative minutes
.positive
	PHA						\\ save minute difference
	LDX #NVR_HourOffset
	JSR FRAM_readByte		\\ look up old hour offset (C is set)
	STY TempSpace2			\\ save for subtraction
	LDY TempHourOffset		\\ new hour offset
	JSR FRAM_writeByte		\\ save new hour offset (C is still set)
	PLA
	PLP						\\ retrieve carry
	PHA
	TYA
	SBC TempSpace2
	PHA						\\ save hour difference
	CLD
	JSR RTC_readTime		\\ read date & time into TempSpace
	SED
	PLA						\\ hour difference
	JSR RTC_addHours		\\ calculate new time
	PLA						\\ minute differencee
	JSR RTC_addMinutes		\\ calculate new time
	CLD
	LDA #RTC_TD_sec			\\ seconds register
	LDX #7					\\ seconds, minutes, hours, days, weekdays, months, years
	LDY #0
	JSR RTC_sendBytes		\\ save updated date & time from TempSpace
	JMP RTC_setCentury		\\ save century and flags
.^noChange
	RTS
}
	
.RTC_incSeconds				\\ adjust time depending on string S+ss.cc or S-ss.cc
{
	JSR RTC_ParseInc
	BCC noChange			\\ not recognised
	TAX
	JSR RTC_ParseDec
	BCC noChange
	SED
	TXA
	STA TempSpace2+2
	BPL positive
	LDA #&50-1
	ADC TempSpace2			\\ calculate 50-(-cc); C is set
	STA TempSpace2			\\ save (50-(-cc))MOD100
	JMP either
.positive	
	LDA #&50
	SBC TempSpace2			\\ calculate 50-cc; C is set
	STA TempSpace2			\\ save (50-cc)MOD100
	ROL A					\\ put C in bit 0
	EOR #1					\\ flip it
	ROR A					\\ put it back
.either
	LDA TempSpace2+1
	ADC #0					\\ add C
	CLD
	BCS overflow			\\ overflow
	PHA						\\ save ss - (50 - cc)DIV100; TempSpace2+1 is mangled by BCDtoBinary
	CLD
	LDA TempSpace2			\\ (50 - cc)MOD100
	JSR BCDtoBinary			\\ low digit + high digit * 10
	STA TempSpace2
	JSR RTC_Synchronise		\\ wait for seconds to tick
	LDX TempSpace2			\\ (50 - cc)MOD100 binary
	JSR RTC_setupDelay		\\ start counting centiseconds
	JSR RTC_readTime
	PLA						\\ ss - (50 - cc)DIV100
	SED
	BIT TempSpace2+2
	BMI negative
	JSR RTC_addSeconds
	JMP either2
.overflow
	CLC
	RTS
.negative
	JSR RTC_subSeconds
.either2
	CLD
	JSR RTC_delay			\\ wait for centisecond count
	JSR RTC_stopClock		\\ clear clock dividers
	LDA #RTC_TD_sec
	LDY #0					\\ start from TempSpace
	LDX #7					\\ seconds, minutes, hours, day, weekday, month, year
	JSR RTC_sendBytes		\\ set new time
	JSR RTC_startClock		\\ restart clock
	JMP RTC_saveSetTime
}

.RTC_tuneClock
{
	JSR RTC_ParseTuningOffset
	BCC badParse
	STA TempSpace2
	LDA #RTC_offset
	JSR RTC_readByte
	TXA
	ASL A					\\ double & put mode in C, sign in bit 7
	BCS courseMode
	BPL offsetpos
	SEC						\\set C = N
.offsetpos
	ROR A					\\ if in fine mode, undouble it, preserving sign
.courseMode
	CLC
	ADC TempSpace2			\\ calc new value
	BVC noOverflow
	LDA #&7F				\\ max value
	ADC #0					\\ C is sign after overflow
.noOverflow
	STA TempSpace2
	BIT TempSpace2			\\ check bits 6 & 7
	BVC noFlip
	BPL useCourse
	AND #&7F
	BVS doneOffset
.noFlip
	BPL doneOffset
.useCourse
	SEC
	ROR A
.doneOffset	
	TAX
	LDA #RTC_offset
	SEC
	JMP RTC_sendByte
.badParse
	RTS
}

\*******************************************************\
\														\
\				Date Arithmetic							\
\														\
\*******************************************************\

.RTC_addSeconds             \\ add accumulator seconds to time in RTC format. 0 <= A <= 99. Assumes D set
{
	CLC
	ADC TempSecond          \\ Seconds
	BCC under100
	SBC #&20                \\ C is set
	BCC under120
	STA TempSecond
	LDA #&2                 \\ carry +2
	BNE RTC_addMinutes
.under120
	ADC #&60				\\ C is clear; add 120-60
.carry1
	STA TempSecond
	LDA #&1                 \\ carry +1
	BNE RTC_addMinutes
.under100
	CMP #&60
	BCC under60
	SBC #&60
	JMP carry1
.under60
	STA TempSecond
	RTS
}

.RTC_subSeconds             \\ subtract accumulator seconds from time in RTC format. 0 <= A <= 99. Assumes D set
{
	LDX TempSecond
	STA TempSecond
	TXA
	SEC
	SBC TempSecond          \\ Minutes
	BCS nonNeg
	ADC #&60                \\ C is clear
	BCC underm60
	STA TempSecond
	LDA #&1                 \\ carry -1
	BNE RTC_subMinutes
.underm60
	ADC #&60				\\ C is clear
	STA TempSecond
	LDA #&2                 \\ carry -2
	BNE RTC_subMinutes
.nonNeg
	STA TempSecond
	RTS
}

.RTC_addMinutes             \\ add accumulator minutes to time in RTC format. 0 <= A <= 99. Assumes D set
{
	CLC
	ADC TempMinute          \\ Minutes
	BCC under100
	SBC #&20                \\ C is set
	BCC under120
	STA TempMinute
	LDA #&2                 \\ carry +2
	BNE RTC_addHours
.under120
	ADC #&60				\\ C is clear; add 120-60
.carry1
	STA TempMinute
	LDA #&1                 \\ carry +1
	BNE RTC_addHours
.under100
	CMP #&60
	BCC under60
	SBC #&60
	JMP carry1
.under60
	STA TempMinute
	RTS
}

.RTC_subMinutes             \\ subtract accumulator minutes from time in RTC format. 0 <= A <= 99. Assumes D set
{
	LDX TempMinute
	STA TempMinute
	TXA
	SEC
	SBC TempMinute          \\ Minutes
	BCS nonNeg
	ADC #&60                \\ C is clear
	BCC underm60
	STA TempMinute
	LDA #&99                 \\ carry -1
	BNE RTC_addHours
.underm60
	ADC #&60				\\ C is clear
	STA TempMinute
	LDA #&98                 \\ carry -2
	BNE RTC_addHours
.nonNeg
	STA TempMinute
	RTS
}

.RTC_addHours				\\ add accumulator hours to time in RTC format. -38<=A<=38. Assumes D set
{
	CLC
	ADC TempHour			\\ Hours
	CMP #&62				\\ treat anything above 61 as negative
	BCS negHours
	LDX #&0					\\ carry
	SEC
.carryLoop1
	STA TempHour
	SBC #&24				\\ C is still set
	BCC notOverHours
	INX						\\ carry +1
	BNE carryLoop1
.negHours
	LDX #&9A				\\ carry = -0
	CLC
.carryLoop2
	DEX						\\ carry -1
	ADC #&24				\\ C is clear
	BCC carryLoop2
	STA TempHour
.notOverHours
	TXA
	BNE RTC_addDays
	RTS
.*RTC_addDays				\\ add accumulator days to time in RTC format. -20<=A<=20 Assumes D set
	PHA						\\ save increment for month day
	CLC
	ADC TempWkday			\\ weekday (0-6)
	CMP #&66				\\ treat anything above 65 as negative
	BCS negWeekDays
.wkDayLoop1
	CMP #&7
	BCC wkDayDone
	SBC #&7					\\ C is set
	BCS wkDayLoop1			\\ always true
.negWeekDays
	CLC
.wkDayLoop2
	ADC #&7					\\ C is still clear
	BCC wkDayLoop2
.wkDayDone
	STA TempWkday
	PLA						\\ restore increment for month day
.*RTC_addMonthDays			\\ add accumulator days to time in RTC format without changing weekday. -20<=A<=20 Assumes D set
	CLC
	ADC TempDay				\\ Days
	STA TempDay				\\ new day
	AND #&FF				\\ set flags
	BEQ negDays				\\ treat zero as negative
	BPL posDays
.negDays
	LDA TempMonth			\\ month
	SEC
	SBC #&1					\\ last month
	TAY						\\ sets flags
	BNE lastMonthOK
	LDY #&12
.lastMonthOK
	JSR RTC_monthLength		\\ calculate length of last month; year can't change if February
	CLC
	ADC TempDay				\\ add negative day to month length
	STA TempDay	
	LDA #&99				\\ carry -1
	BNE RTC_addMonths		\\ always
.posDays
	LDY TempMonth			\\ month
	JSR RTC_monthLength		\\ calculate length of this month
	CMP TempDay				\\ check if day is over month length
	BCC overDays			\\ day > month length
	RTS
.overDays
	STA TempSpace2			\\ save month length
	LDA TempDay				\\ day
	SEC
	SBC TempSpace2			\\ subtract month length
	STA TempDay	
	LDA #1					\\ carry +1
.*RTC_addMonths				\\ add accumulator months to time in RTC format. -12<=A<=12 Assumes D set
	CLC
	ADC TempMonth			\\ Months
	AND #&FF				\\ set flags
	BEQ negMonths			\\ treat zero as negative
	BMI negMonths
	CMP #&13
	BCS overMonths
	STA TempMonth
	RTS
.negMonths
	CLC
	ADC #&12
	STA TempMonth
	LDA TempYear			\\ years
	SEC
	SBC #&1
	STA TempYear
	LDA TempCentury			\\ centuries
	SBC #&0					\\ C from years
	STA TempCentury
	RTS
.overMonths
	SBC #&12				\\ C is set
	STA TempMonth
	LDA #&1					\\ carry +1
.*RTC_addYears				\\ add accumulator years to time in RTC format. 0 <= A <= 99. Assumes D set
	CLC
	ADC TempYear			\\ Years
	STA TempYear
	LDA TempCentury			\\ centuries
	ADC #&0					\\ C from years
	STA TempCentury
	RTS
}

.RTC_MonthLengths
	EQUB &31,&28,&31,&30,&31,&30,&31,&31,&30,0,0,0,0,0,0,&31,&30,&31

.RTC_monthLength			\\ calculate length of month in Y, from year in RTC format
{
	CPY #&2					\\ February
	BEQ leapCheck
	LDA RTC_MonthLengths-1,Y	\\ look up in table
	RTS
.leapCheck
	LDA TempYear			\\ year
	BNE leapCheck2
	LDA TempCentury			\\ century
.leapCheck2
	AND #&13
	BEQ leapYear
	CMP #&12
	BEQ leapYear
.notLeapYear
	LDA #&28				\\ February, not a leap year
	RTS
.leapYear
	LDA #&29				\\ February, leap year
	RTS
}
