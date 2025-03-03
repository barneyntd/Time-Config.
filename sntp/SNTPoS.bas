	*FX2,2
	*FX21,1
	PROCdimspace:PROCcode
	PROCReadTimes:PROCsend
	PROCrecv
	IF Error$<>"" THEN PRINT Error$:END
	PROConwire
	@%=&02030A
	IF LI%<>0 PRINT"Warning: leap second due in the last minute of this month!"
	PRINT"Time is ";ABS(theta);" seconds ";:IF theta>0 PRINT"behind server" ELSE PRINT"ahead of server"
	PRINT"(roundtrip time ";delta;" seconds)"
	@%=&90A
	IF ABS(theta) < 0.015 END
	PRINT"Last clock correction ";TI%-TS%;" seconds ago"
	IF TI%-TS%>3600 PRINT"(Approximate drift ";-theta/(TI%-TS%)*86400;" seconds per day)"
	PRINT"Press","0 to quit"'" ","1 to correct time"
	W% = TI%-TS%>7000 AND ABS(theta)>2.17E-6*(TI%-TS%):IF W% PRINT" ","2 to correct time and recalibrate clock"'"(Don't recalibrate after leap seconds)"
	REPEAT:G$=GET$:UNTIL "0"<=G$ AND G$<="2"
	IF G$="0" END
	IF W% AND G$="2" PROCcalibrate
	PROCcorrect
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
	
	REM ------- FNDtoSINT convert BCD to signed integer -------
	DEF FNDtoSINT(BCD%)
	LOCAL I%:I%=VAL(STR$~BCD%):IF I%>=50THEN I%=I%-100
	=I%
	
	REM ------- FNABCDtoSEC convert Acorn BCD block to seconds since 1900-1-1 00:00:00 UTC ------
	DEF FNABCDtoSEC(B%)
	LOCAL TZ%,Yr%,Mon%,Day%,Hr%,Min%,Sec%,ML%,TI1%
	Yr%=FNDtoUINT(?B%)+(FNDtoUINT(B%?7)-19)*100
	Mon%=FNDtoUINT(B%?1)
	Day%=FNDtoUINT(B%?2)-1
	RESTORE
	FOR I%=1TO Mon%:READ ML%
		IF ML%=28 AND Yr%MOD4=0 AND (Yr%MOD100<>0 OR Yr%MOD400=1) THEN ML%=29
		Day%=Day%+ML%
	NEXT:Day%=Day%-ML%
	Day%=Day%+(Yr%-1)DIV4
	Hr%=FNDtoUINT(B%?4)-FNDtoSINT(B%?8)
	Min%=FNDtoUINT(B%?5)-FNDtoUINT(B%?9)
	Sec%=FNDtoUINT(B%?6)
	TI1%=Sec%+Min%*60+Hr%*3600+Day%*86400
	IF Yr%<=(&7FFFFFFF-TI1%)/31536000 THEN =TI1%+Yr%*31536000 ELSE =(TI1%+(Yr%-68)*31536000-1075259648)-1075259648
	DATA 31,28,31,30,31,30,31,31,30,31,30,31

	REM ------- PROCosword(A%,B%) send data in B% to OSWORD call A% -------
	DEF PROCosword(A%,B%)
	X%=B%AND&FF:Y%=B%DIV&100:CALL(&FFF1)
	ENDPROC

	REM ------- PROCReadTimes sync OS clock and set TI% = time now, TS% = last set time, TZ% = timeZone
	REM							all in seconds since 1900-1-1 00:00:00 UTC ------
	DEF PROCReadTimes
	CALL(Synchronise)
	?OSblock%=1:PROCosword(14,OSblock%):OSblock%?7=5:PROCosword(14,OSblock%+7)
	Yr%=?OSblock%
	TI%=FNABCDtoSEC(OSblock%):TZ%=FNDtoSINT(OSblock%?8)*3600+FNDtoUINT(OSblock%?9)*60
	?OSblock%=6:OSblock%?1=&FF:PROCosword(14,OSblock%)
	IF Yr%<&25 AND ?OSblock%>&75 THEN OSBlock%?7=OSBlock%?7-1:IF (OSBlock%?7 AND&F)=&F THEN OSblock%?7=OSblock%?7-6
	OSblock%?8=0:OSblock%?9=0:TS%=FNABCDtoSEC(OSblock%)
	ENDPROC
	


	REM ------- PROCdimspace reserve memory space for buffers and define byte offsets
	REM
	DEF PROCdimspace
	DIM OSblock% 32, NTPblock% 56
	LIVN%=47:Stratum%=46:Poll%=45:Prec%=44:RootDelay%=40:RootDisp%=36:RefID%=32
	TIref%=28:TIFref%=24:TIorg%=20:TIForg%=16:TIrec%=12:TIFrec%=8:TIxmt%=4:TIFxmt%=0
	TIdst%=52:TIFdst%=48
	ENDPROC

	REM ------- PROCsend create and send SNTP block over serial port
	DEF PROCsend
	NTPblock%?LIVN%=4*8 OR 3
	NTPblock%?Stratum%=0:NTPblock%?Poll%=0:NTPblock%?Prec%=0
	NTPblock%!RootDelay%=0:NTPblock%!RootDisp%=0:NTPblock%!RefID%=0
	NTPblock%!TIref%=0:NTPblock%!TIFref%=0
	NTPblock%!TIorg%=0:NTPblock%!TIForg%=0
	NTPblock%!TIrec%=0:NTPblock%!TIFrec%=0
	NTPblock%!TIxmt%=TI%
	CALL(StampNSend)
	TIF%=NTPblock%!TIFxmt%
	ENDPROC

	REM ------- PROCrecv read SNTP block from serial, and check for errors
	DEF PROCrecv
	CALL(RecvNStamp)
	NTPblock%!TIdst%=TI%+NTPblock%?TIdst%
	LI%=(NTPblock%?LIVN%)DIV&40:IF LI%=3 THEN Error$="Unsynchronised server":ENDPROC
	IF (NTPblock%?LIVN% AND 7)<>4 THEN Error$="Bad server mode "+STR$(?NTPblock% AND 7):ENDPROC
	IF NTPblock%?Stratum%=0 THEN Error$="KoD code "+CHR$(NTPblock%?(RefID%+3))+CHR$(NTPblock%?(RefID%+2))+CHR$(NTPblock%?(RefID%+1))+CHR$(NTPblock%?RefID%):ENDPROC
	IF NTPblock%!RootDelay%>&10000 OR NTPblock%!RootDelay%<-655 THEN Error$="Bad root delay "+STR$(NTPblock%!RootDelay%):ENDPROC
	IF NTPblock%!RootDisp%>&10000 OR NTPblock%!RootDisp%<0 THEN Error$="Bad root dispersion "+STR$(NTPblock%!RootDisp%):ENDPROC
	IF NTPblock%!TIxmt%-NTPblock%!TIref%>86400 THEN Error$="Server time not set for "+STR$(NTPblock%!TIxmt%-NTPblock%!TIref%)+" seconds":ENDPROC
	IF NTPblock%!TIorg%<>TI% OR NTPblock%!TIForg%<>TIF% THEN Error$="Wrong packet":ENDPROC
	Error$="":ENDPROC

	REM ------- PROConwire calculate theta & delta according to SNTP
	DEF PROConwire
	LOCAL TIForg,TIFrec,TIFxmt,TIFdst,deltaX,deltaR
	TIForg=NTPblock%!TIForg%/4.2949673E9:IF TIForg<0 THEN TIForg=TIForg+1
	TIFrec=NTPblock%!TIFrec%/4.2949673E9:IF TIFrec<0 THEN TIFrec=TIFrec+1
	TIFxmt=NTPblock%!TIFxmt%/4.2949673E9:IF TIFxmt<0 THEN TIFxmt=TIFxmt+1
	TIFdst=NTPblock%!TIFdst%/4.2949673E9:IF TIFdst<0 THEN TIFdst=TIFdst+1
	deltaX=(NTPblock%!TIrec%-NTPblock%!TIorg%)+(TIFrec-TIForg)
	deltaR=(NTPblock%!TIdst%-NTPblock%!TIxmt%)+(TIFdst-TIFxmt)
	theta=(deltaX-deltaR)/2
	delta=deltaX+deltaR
	ENDPROC

	REM ------- PROCcorrect adjust the clock by theta seconds
	DEF PROCcorrect
	LOCAL @%
	IF ABS(theta)<99 THEN @%=&01020205:OSCLI("TIME S"+FNsigned(theta)):ENDPROC
	?OSblock%=1:PROCosword(14,OSblock%)
	Hr%=FNDtoUINT(OSblock%?4)+theta DIV3600
	Min%=FNDtoUINT(OSblock%?5)+theta MOD3600DIV60
	Sec%=FNDtoUINT(OSblock%?6)+theta MOD60
	IF Sec%>=60 THEN Sec%=Sec%-60:Min%=Min%+1
	IF Sec%<0 THEN Sec%=Sec%+60:Min%=Min%-1
	IF Min%>=60 THEN Min%=Min%-60:Hr%=Hr%+1
	IF Min%<0 THEN Min%=Min%+60:Hr%=Hr%-1
	IF Hr%>23 OR Hr%<0 PRINT"Please set the date correctly, and run again.":ENDPROC
	OSCLI("TIME "+FNunsigned(Hr%)+":"+FNunsigned(Min%)+":"+FNunsigned(Sec%))
	PRINT"Please run again for more precise correction."
	ENDPROC

	REM ------- PROCcalibrate calculate the clock drift and adjust the offset register
	DEF PROCcalibrate
	LOCAL C%
	C%=INT(theta*460800/(TI%-TS%)+0.5)
	IF ABS(C%)>63 OR C%=0 ENDPROC
	OSCLI("TIME T"+FNsigned(-C%))
	ENDPROC


	REM--------------------------------
	REM PROCcode Time-critical routines in assembly code
	REM
	DEF PROCcode
	DIM Codespace% 300:Counter=&70:Result=&72
	FOR O%=0TO2STEP2:P%=Codespace%:[OPT O%
	  .Synchronise
		LDA #1
		STA OSblock%
		LDA #ASC("S")
		STA OSblock%+1
		LDA #15
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JSR &FFF1
		LDA #0
		STA OSblock%
		STA OSblock%+1
		STA OSblock%+2
		STA OSblock%+3
		STA OSblock%+4
		LDA #2
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JMP &FFF1
	  .StampNSend
		LDA #1
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JSR &FFF1
		LDA OSblock%
		JSR Div100
		LDA Result
		STA NTPblock%+TIFxmt%
		LDA Result+1
		STA NTPblock%+TIFxmt%+1
		LDA Result+2
		STA NTPblock%+TIFxmt%+2
		LDA Result+3
		STA NTPblock%+TIFxmt%+3
		LDA Result+4
		BNE timeout
		LDX #47
	  .sendLoop
		STX Counter
	  .sendRetry
		LDY NTPblock%,X
		LDA #138
		LDX #2
		JSR &FFF4
		BCC sentOK
		LDA #1
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JSR &FFF1
		LDA OSblock%+1
		BNE timeout
		LDX Counter
		JMP sendRetry
	  .sentOK
		LDX Counter
		DEX
		BPL sendLoop
		RTS
	  .timeout
		BRK
		EQUB 64
		EQUS "Timeout waiting for serial communication"
		EQUB 0
	  .RecvNStamp
		LDX #47
	  .recvLoop
		STX Counter
	  .recvRetry
		LDA #145
		LDX #1
		JSR &FFF4
		BCC recdOK
		LDA #1
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JSR &FFF1
		LDA OSblock%+1
		BNE timeout
		JMP recvRetry
	  .recdOK
		LDX Counter
		TYA
		STA NTPblock%,X
		DEX
		BPL recvLoop
		LDA #1
		LDX #OSblock%AND&FF
		LDY #OSblock%DIV&100
		JSR &FFF1
		LDA OSblock%
		JSR Div100
		LDA Result
		STA NTPblock%+TIFdst%
		LDA Result+1
		STA NTPblock%+TIFdst%+1
		LDA Result+2
		STA NTPblock%+TIFdst%+2
		LDA Result+3
		STA NTPblock%+TIFdst%+3
		LDA Result+4
		STA NTPblock%+TIdst%
		RTS
	  .Div100
		LDY #0
		STY Result
		LDY #33
		SEC 
		SBC #200
		BCS subok1 
		ADC #200
		CLC
	  .subok1 
		ROL Result
	  .divloop 
		SEC
		SBC #100
		BCS subok
		ADC #100 
		CLC
	  .subok
		ROL Result
		ROL Result+1
		ROL Result+2
		ROL Result+3
		ROL Result+4
		ASL A
		DEY
		BNE divloop
		RTS
	  ]
	  IF P%-Codespace%>=300 THEN PRINT"Not enough code space!":END
	  NEXT
	ENDPROC






