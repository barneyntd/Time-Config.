   10 *FX2,2
   20 *FX7,8
   30 *FX8,8
   40 *FX21,1
   50 *FX21,2
  100 PROCdimspace:PROCcode
  140 PROCTIsetup:PRINT"Time: ";TI$;" UTC";FNsigned(TZ%)
  150 PROCsend
  160 PROCrecv
  170 IF Error$<>"" THEN PRINT Error$:END
  180 PROConwire
  185 @%=&30A
  190 IF LI%<>0 PRINT"Warning: leap second due in the last minute of this month!"
  200 PRINT"Time is ";ABS(theta);" seconds ";:IF theta>0 PRINT"behind server" ELSE PRINT"ahead of server"
  210 PRINT"(roundtrip time ";delta;" seconds)"
  215 @%=&90A
  220 IF ABS(theta) < 0.015 END
  230 PRINT"Last clock correction ";TI%-TS%;" seconds ago."
  240 PRINT"Press","0 to quit"'" ","1 to correct time"
  250 IF TI%-TS%>7000 AND ABS(theta)>2.17E-6*(TI%-TS%) PRINT" ","2 to correct time and recalibrate clock"'"(Don't recalibrate after leap seconds)"
  260 REPEAT:G$=GET$:UNTIL "0"<=G$ AND G$<="2"
  270 IF G$="0" END
  280 IF G$="2" PROCcalibrate
  290 PROCcorrect
  990 END
 1000 REM--------------------------------------------------------
 1010 REM PROCosword(A%) send data in OSblock% to OSWORD call A%
 1020 REM
 1030 DEF PROCosword(A%)
 1040 X%=OSblock%AND&FF:Y%=OSblock%DIV&100:CALL(&FFF1)
 1050 ENDPROC
 1300 REM--------------------------------------------------
 1310 REM FNsigned(X) create string with sign and zero padding
 1320 REM
 1330 DEF FNsigned(X)
 1340 LOCAL S$
 1350 IF X<0 THEN S$="-" ELSE S$="+"
 1360 =S$+FNunsigned(ABS(X))
 1370 DEF FNunsigned(X)
 1380 =MID$(STR$(100+X),2)
 1400 REM----------------------------------------------------------------
 1410 REM PROCdimspace reserve memory space for buffers
 1420 REM
 1430 DEF PROCdimspace
 1440 DIM OSblock% 32, NTPblock% 56
 1450 LIVN%=47:Stratum%=46:Poll%=45:Prec%=44:RootDelay%=40:RootDisp%=36:RefID%=32
 1460 TIref%=28:TIFref%=24:TIorg%=20:TIForg%=16:TIrec%=12:TIFrec%=8:TIxmt%=4:TIFxmt%=0
 1470 TIdst%=52:TIFdst%=48
 1480 ENDPROC
 2000 REM----------------------------------------------------------------
 2010 REM PROCTIsetup read time TI% & timezone TZ%, and sync OS clock to seconds
 2020 REM
 2030 DEF PROCTIsetup
 2040 CALL(Synchronise)
 2060 ?OSblock%=0:PROCosword(14):TI$=$OSblock%
 2070 ?OSblock%=7:PROCosword(14):TZ%=VAL(STR$~(?OSblock%)):IF TZ%>=50THEN TZ%=TZ%-100
 2080 TI%=FNutc(TI$,TZ%)
 2090 ?OSblock%=5:OSblock%?1=&FF:PROCosword(14):TS$=$OSblock%:TS%=FNutc(TS$,0)
 2100 ENDPROC
 3000 REM------------------------------------------------------
 3010 REM PROCsend create and send SNTP block over serial port
 3020 REM
 3030 DEF PROCsend
 3040 NTPblock%?LIVN%=4*8 OR 3
 3050 NTPblock%?Stratum%=0:NTPblock%?Poll%=0:NTPblock%?Prec%=0
 3060 NTPblock%!RootDelay%=0:NTPblock%!RootDisp%=0:NTPblock%!RefID%=0
 3080 NTPblock%!TIref%=0:NTPblock%!TIFref%=0
 3090 NTPblock%!TIorg%=0:NTPblock%!TIForg%=0
 3100 NTPblock%!TIrec%=0:NTPblock%!TIFrec%=0
 3110 NTPblock%!TIxmt%=TI%
 3140 CALL(StampNSend)
 3150 TIF%=NTPblock%!TIMxmt%
 3160 ENDPROC
 4000 REM------------------------------------------------------------
 4010 REM PROCrecv read SNTP block from serial, and check for errors
 4020 REM
 4030 DEF PROCrecv
 4070 CALL(RecvNStamp)
 4090 NTPblock%!TIdst%=TI%+NTPblock%?TIdst%
 4110 LI%=(NTPblock%?LIVN%)DIV&40:IF LI%=3 THEN Error$="Unsynchronised server":ENDPROC
 4120 IF (NTPblock%?LIVN% AND 7)<>4 THEN Error$="Bad server mode "+STR$(?NTPblock% AND 7):ENDPROC
 4130 IF NTPblock%?Stratum%=0 THEN Error$="KoD code "+CHR$(NTPblock%?(RefID%+3))+CHR$(NTPblock%?(RefID%+2))+CHR$(NTPblock%?(RefID%+1))+CHR$(NTPblock%?RefID%):ENDPROC
 4140 IF NTPblock%!RootDelay%>1 OR NTPblock%!RootDelay%<0 THEN Error$="Bad root delay "+STR$(NTPblock%!RootDelay%):ENDPROC
 4150 IF NTPblock%!RootDisp%>1 OR NTPblock%!RootDisp%<0 THEN Error$="Bad root dispersion "+STR$(NTPblock%!RootDisp%):ENDPROC
 4200 IF NTPblock%!TIxmt%-NTPblock%!TIref%>86400 THEN Error$="Server time not set for "+STR$(NTPblock%!TIxmt%-NTPblock%!TIref%)+" seconds":ENDPROC
 4210 IF NTPblock%!TIorg%<>TI% OR NTPblock%!TIForg%<>TIF% THEN Error$="Wrong packet":ENDPROC
 4220 Error$="":ENDPROC
 5000 REM--------------------------------------------------------
 5010 REM PROConwire calculate theta & delta according to SNTP
 5020 REM
 5030 DEF PROConwire
 5040 LOCAL TIForg,TIFrec,TIFxmt,TIFdst,deltaX,deltaR
 5050 TIForg=NTPblock%!TIForg%/4.2949673E9:IF TIForg<0 THEN TIForg=TIForg+1
 5060 TIFrec=NTPblock%!TIFrec%/4.2949673E9:IF TIFrec<0 THEN TIFrec=TIFrec+1
 5070 TIFxmt=NTPblock%!TIFxmt%/4.2949673E9:IF TIFxmt<0 THEN TIFxmt=TIFxmt+1
 5080 TIFdst=NTPblock%!TIFdst%/4.2949673E9:IF TIFdst<0 THEN TIFdst=TIFdst+1
 5090 deltaX=(NTPblock%!TIrec%-NTPblock%!TIorg%)+(TIFrec-TIForg)
 5100 deltaR=(NTPblock%!TIdst%-NTPblock%!TIxmt%)+(TIFdst-TIFxmt)
 5110 theta=(deltaX-deltaR)/2
 5120 delta=deltaX+deltaR
 5130 ENDPROC
 6000 REM---------------------------------------------------------------------
 6010 REM FNutc(TI$,TZ%) calculate UTC time from acorn time string & time zone
 6020 REM
 6030 DEF FNutc(TI$,TZ%)
 6040 LOCAL Yr%,Mon$,Day%,Hr%,Min%,Sec%,ML%,TI1%
 6050 Yr%=VAL(MID$(TI$,12,4))-1900
 6060 Day%=VAL(MID$(TI$,5,2))-1
 6070 RESTORE 10000
 6080 REPEAT:READ Mon$,ML%
 6090   IF ML%=28 AND Yr%MOD4=0 AND (Yr%MOD100<>0 OR Yr%MOD400=1) THEN ML%=29
 6100   Day%=Day%+ML%:UNTIL Mon$=MID$(TI$,8,3):Day%=Day%-ML%
 6110 Day%=Day%+(Yr%-1)DIV4
 6120 Hr%=VAL(MID$(TI$,17,2))-TZ%
 6130 Min%=VAL(MID$(TI$,20,2))
 6140 Sec%=VAL(MID$(TI$,23,2))
 6150 TI1%=Sec%+Min%*60+Hr%*3600+Day%*86400
 6160 IF Yr%<=(&7FFFFFFF-TI1%)/31536000 THEN =TI1%+Yr%*31536000 ELSE =(TI1%+(Yr%-68)*31536000-1075259648)-1075259648
 7000 REM---------------------------------------------------------------------
 7010 REM PROCcorrect adjust the clock by theta seconds
 7020 REM
 7030 DEF PROCcorrect
 7040 LOCAL @%
 7050 IF ABS(theta)>=20 GOTO7100
 7060 @%=&01020205:OSCLI("TIME S"+FNsigned(theta))
 7070 ENDPROC
 7100 ?OSblock%=0:PROCosword(14):TI$=$OSblock%
 7110 Hr%=VAL(MID$(TI$,17,2))+theta DIV3600
 7120 Min%=VAL(MID$(TI$,20,2))+theta MOD3600DIV60
 7130 Sec%=VAL(MID$(TI$,23,2))+theta MOD60
 7140 IF Sec%>=60 THEN Sec%=Sec%-60:Min%=Min%+1
 7150 IF Sec%<0 THEN Sec%=Sec%+60:Min%=Min%-1
 7160 IF Min%>=60 THEN Min%=Min%-60:Hr%=Hr%+1
 7170 IF Min%<0 THEN Min%=Min%+60:Hr%=Hr%-1
 7180 IF Hr%>=24 OR Hr%<0 PRINT"Please set the date correctly, and run again.":ENDPROC
 7190 OSCLI("TIME "+FNunsigned(Hr%)+":"+FNunsigned(Min%)+":"+FNunsigned(Sec%))
 7200 PRINT"Please run again for more precise correction."
 7210 ENDPROC
 8000 REM---------------------------------------------------------------------
 8010 REM PROCcalibrate calculate the clock drift and adjust the offset register
 8020 REM
 8025 DEF PROCcalibrate
 8030 LOCAL C%
 8040 C%=INT(theta*460800/(TI%-TS%)+0.5)
 8050 IF ABS(C%)>63 OR C%=0 ENDPROC
 8055 PRINT"*TIME C"+FNsigned(C%)
 8060 REM OSCLI("TIME C"+FNsigned(C%))
 8070 ENDPROC
 9000 REM--------------------------------
 9010 REM DATA month names & lengths
 9020 REM
 9030 DATA Jan,31,Feb,28,Mar,31,Apr,30,May,31,Jun,30,Jul,31,Aug,31,Sep,30,Oct,31,Nov,30,Dec,31
10000 REM--------------------------------
10010 REM PROCcode Time-critical routines in assembly code
10020 REM
10030 DEF PROCcode
10040 DIM Codespace% 200:Counter=&70
10050 FOR O%=0TO2STEP2:P%=Codespace%:[OPT O%
10060   .Synchronise
10070     LDA #1
10080     STA OSblock%
10090     LDA #ASC("S")
10100     STA OSblock%+1
10110     LDA #15
10120     LDX #OSblock%AND&FF
10130     LDY #OSblock%DIV&100
10140     JSR &FFF1
10150     LDA #0
10160     STA OSblock%
10170     STA OSblock%+1
10180     STA OSblock%+2
10190     STA OSblock%+3
10200     STA OSblock%+4
10210     LDA #2
10220     LDX #OSblock%AND&FF
10230     LDY #OSblock%DIV&100
10240     JMP &FFF1
10260   .StampNSend
10270     LDA #1
10280     LDX #OSblock%AND&FF
10290     LDY #OSblock%DIV&100
10300     JSR &FFF1
10310     LDA OSblock%
10320     JSR Div100
10330     LDA Result
10340     STA NTPblock%+TIFxmt%
10350     LDA Result+1
10360     STA NTPblock%+TIFxmt%+1
10370     LDA Result+2
10380     STA NTPblock%+TIFxmt%+2
10390     LDA Result+3
10400     STA NTPblock%+TIFxmt%+3
10410     LDA Result+4
10420     BNE timeout
10430     LDX #47
10440   .sendLoop
10450     STX Counter
10460   .sendRetry
10470     LDY NTPblock%,X
10480     LDA #138
10490     LDX #2
10500     JSR &FFF4
10510     BCC sentOK
10520     LDA #1
10530     LDX #OSblock%AND&FF
10540     LDY #OSblock%DIV&100
10550     JSR &FFF1
10560     LDA OSblock%+1
10570     BNE timeout
10580     LDX Counter
10590     JMP sendRetry
10600   .sentOK
10610     LDX Counter
10620     DEX
10630     BPL sendLoop
10640     RTS
10660   .RecvNStamp
10670     LDX #47
10680   .recvLoop
10690     STX Counter
10700   .recvRetry
10710     LDA #145
10720     LDX #2
10730     JSR &FFF4
10740     BCC recdOK
10750     LDA #1
10760     LDX #OSblock%AND&FF
10770     LDY #OSblock%DIV&100
10780     JSR &FFF1
10790     LDA OSblock%+1
10800     BNE timeout
10810     JMP recvRetry
10820   .recdOK
10830     LDX Counter
10835     TYA
10840     STA NTPblock%,X
10850     DEX
10860     BPL recvLoop
10870     LDA #1
10880     LDX #OSblock%AND&FF
10890     LDY #OSblock%DIV&100
10900     JSR &FFF1
10910     LDA OSblock%
10920     JSR Div100
10930     LDA Result
10940     STA NTPblock%+TIFdst%
10950     LDA Result+1
10960     STA NTPblock%+TIFdst%+1
10970     LDA Result+2
10980     STA NTPblock%+TIFdst%+2
10990     LDA Result+3
11000     STA NTPblock%+TIFdst%+3
11010     LDA Result+4
11020     STA NTPblock%+TIdst%
11030     RTS
11050   .Div100
11060     LDY #0
11070     STY Result
11080     LDY #33
11090     SEC 
11100     SBC #200
11110     BCS subok1 
11120     ADC #200
11130     CLC
11140   .subok1 
11150     ROL Result
11160   .divloop 
11170     SEC
11180     SBC #100
11190     BCS subok
11200     ADC #100 
11210     CLC
11220   .subok
11230     ROL Result
11240     ROL Result+1
11250     ROL Result+2
11260     ROL Result+3
11270     ROL Result+4
11280     ASL A
11290     DEY
11300     BNE divloop
11310     RTS
11330   .timeout
11340     BRK
11350     EQUB 64
11360     EQUS "Timeout waiting for serial communication"
11370     EQUB 0
11380   ]:NEXT
11390 ENDPROC






