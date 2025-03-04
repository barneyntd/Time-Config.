	REM   ---------   Set these variables for your daylight saving scheme
	TZ1Hr=0:TZ1Min=0:REM     hour & minute offsets at new year
	TZ1End$="lst Sun Mar.01:00:00":REM    end of TZ1 time. Specify as either "ooo www mmm.hh:mm:ss" or "dd mmm.hh:mm:ss"
	TZ2Hr=1:TZ2Min=0:REM     hour & minute offsets at mid year
	TZ2End$="lst Sun Oct.02:00:00":REM    end of TZ2 time.

	PROCTRecord:PROCTimeData
	
	Now%=FNNow
	TZ1End%=FNParseSpec(TZ1End$):TZ2End%=FNParseSpec(TZ2End$)
	IF TZ2Hr>TZ1Hr OR TZ2Hr=TZ1Hr AND TZ2Min>TZ1Min THEN TZ1Start%=FNChangeTZ(TZ2End%,TZ2Hr,TZ2Min,TZ1Hr,TZ1Min) ELSE TZ1Start%=TZ2End%
	IF TZ1Hr>TZ2Hr OR TZ1Hr=TZ2Hr AND TZ1Min>TZ2Min THEN TZ2Start%=FNChangeTZ(TZ1End%,TZ1Hr,TZ1Min,TZ2Hr,TZ2Min) ELSE TZ2Start%=TZ1End%
	IF FNFirst(TZ1Start%,TZ1End%) OSCLI("TIME UTC"+FNsigned(TZ2Hr)+":"+FNunsigned(TZ2Min))
	IF FNFirst(TZ2Start%,TZ2End%) OSCLI("TIME UTC"+FNsigned(TZ1Hr)+":"+FNunsigned(TZ1Min))
	END
	
	REM ------- FNsigned create string with sign and zero padding
	DEF FNsigned(X)
	LOCAL S$
	IF X<0 THEN S$="-" ELSE S$="+"
	=S$+FNunsigned(ABS(X))
	DEF FNunsigned(X)
	=MID$(STR$(100+X),2)

	REM ------- FNDtoUINT convert BCD to unsigned integer -------
	DEF FNDtoUINT(BCD%)
	=VAL(STR$~BCD%)
	
	REM ------- PROCOSword(A%,B%) send data in B% to OSWORD call A% -------
	DEF PROCOSword(A%,B%)
	X%=B%AND&FF:Y%=B%DIV&100:CALL(&FFF1)
	ENDPROC

	REM ------- FNNow read the time and return as a TRec -------
	DEF FNNow
	DIM OSBlock% 10:DIM Now% TRecSize
	?OSBlock%=1:PROCOSword(14,OSBlock%):OSBlock%?7=5:PROCOSword(14,OSBlock%+7)

	Now%!Year=FNDtoUINT(?OSBlock%+&100*OSBlock%?7)
	Now%!Month=FNDtoUINT(OSBlock%?1)
	Now%!Day=FNDtoUINT(OSBlock%?2)
	Now%!WkDay=FNDtoUINT(OSBlock%?3)
	Now%!Hour=FNDtoUINT(OSBlock%?4)
	Now%!Minute=FNDtoUINT(OSBlock%?5)
	Now%!Second=FNDtoUINT(OSBlock%?6)
	Now%!Ord=15
	=Now%

	REM ------- FNLeapYr check if it's a leap year --------
	DEF FNLeapYear(Year)
	=(Year MOD 400 = 0 OR Year MOD 100 <> 0 AND Year MOD 4 = 0)

	REM ------- FNMonthLength calculate the length of a month, even if greater than 12 --------
	DEF FNMonthLength(Month,Year)
	=MonthLength(Month MOD 12) - (Month=2 AND FNLeapYear(Year + (Month-1) DIV 12))
	
	REM ------- FNParseSpec convert an alarm specification string into a TRec
	DEF FNParseSpec(Spec$)
	DIM Alarm% TRecSize
	Alarm%!Year=-1
	Time$=RIGHT$(Spec$,12)
	Alarm%!Second=VAL(MID$(Time$,11,2))
	Alarm%!Minute=VAL(MID$(Time$,8,2))
	Alarm%!Hour=VAL(MID$(Time$,5,2))
	FOR I%=1TO12
		IF MonthName$(I%)=LEFT$(Time$,3) THEN Alarm%!Month=I%:I%=12
	NEXT I%
	IF LEN(Spec$)=15 THEN Alarm%!Day=VAL(LEFT$(Spec$,2)):Alarm%!Ord=15:Alarm%!WkDay=-1:=Alarm%
	Alarm%!Day=0
	FOR I%=1TO7
		IF DayName$(I%)=MID$(Spec$,5,3) THEN Alarm%!WkDay=I%:I%=7
	NEXT I%
	FOR I%=1TO8
		IF OrdName$(I%)=LEFT$(Spec$,3) THEN Alarm%!Ord=I%-4:I%=8
	NEXT I%
	=Alarm%
	

	REM ------- FNChangeTZ convert a TRec between timezones; assumes this will not change the date
	DEF FNChangeTZ(Spec%,TZ1Hr,TZ1Min,TZ2Hr,TZ2Min)
	DIM NewSpec% TRecSize
	NewSpec%!Second=Spec%!Second
	NewSpec%!Minute=Spec%!Minute-TZ1Min+TZ2Min
	NewSpec%!Hour=Spec%!Hour-TZ1Hr+TZ2Hr+INT(NewSpec%!Minute/60):NewSpec%!Minute=(NewSpec%!Minute+60) MOD 60
	NewSpec%!Day=Spec%!Day
	NewSpec%!WkDay=Spec%!WkDay
	NewSpec%!Ord=Spec%!Ord
	NewSpec%!Month=Spec%!Month
	NewSpec%!Year=Spec%!Year
	=NewSpec%
	
	
	REM ------- FNFirst check which of two timespecs will occur first; assumes Spec1%!Month<>Spec2%!Month-------
	DEF FNFirst(Spec1%,Spec2%)
	IF Now%!Month=Spec1%!Month THEN = FNDayNotPast(Spec1%)
	IF Now%!Month=Spec2%!Month THEN = NOT FNDayNotPast(Spec2%)
	= (Spec1%!Month-Now%!Month+12) MOD 12 < (Spec2%!Month-Now%!Month+12) MOD 12
	
	REM ------- FNDayNotPast check whether Spec% has passed yet, assuming Spec%!Month = Now%!Month -------
	DEF FNDayNotPast(Spec%)
	IF Spec%!Day<>0 THEN SD = Spec%!Day
	IF Spec%!Ord>=0 THEN SD = Spec%!Ord*7 + (Spec%!WkDay-Now%!WkDay-Now%!Day+36)MOD7 +1
	IF Spec%!Ord<0 THEN ML = FNMonthLength(Now%!Month,Now%!Year):SD = ML+Spec%!Ord*7 + (Spec%!WkDay-Now%!WkDay+Now%!Day-ML+35)MOD7 
	= SD>Now%!Day OR SD=Now%!Day AND (Spec%!Hour>Now%!Hour OR Spec%!Hour=Now%!Hour AND (Spec%!Minute>Now%!Minute OR Spec%!Minute=Now%!Minute AND Spec%!Second>=Now%!Second))

	REM ------- PROCTRecord define selectors for a time record
	DEF PROCTRecord
	Year=0:Month=4:Day=8:Ord=12:WkDay=16:Hour=20:Minute=24:Second=28
	TRecSize=32
	ENDPROC

	REM ------- PROCPrintTRec print a time record
	DEFPROCPrintTRec(TRec%)
	IF TRec%!Year<>-1 PRINT "year: ";TRec%!Year;
	PRINT ;" month: ";TRec%!Month;" day: ";TRec%!Day;" hour: ";TRec%!Hour;" minute: ";TRec%!Minute;" second: ";TRec%!Second
	IF TRec%!Ord<>15 PRINT "week: ";TRec%!Ord;
	PRINT ;" day: ";TRec%!WkDay
	ENDPROC
	
	REM ------- PROCTimeData read the basic calendar data into arrays
	DEFPROCTimeData
	RESTORE 1000
	DIM DayName$(7):DIM OrdName$(8):DIM MonthName$(12):DIM MonthLength(12)
	FOR I%=1 TO 7:READ DayName$(I%):NEXT
	FOR I%=1 TO 8:READ OrdName$(I%):NEXT
	FOR I%=1 TO 12:READ MonthName$(I%):NEXT
	FOR I%=1 TO 12:READ MonthLength(I%):NEXT
	ENDPROC
	
1000 DATA Sun,Mon,Tue,Wed,Thu,Fri,Sat
	 DATA apu,pen,lst,1st,2nd,3rd,4th,5th
	 DATA Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec
	 DATA 31,28,31,30,31,30,31,31,30,31,30,31
	 