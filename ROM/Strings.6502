.STR_PrintString
{
	PLA
	STA TempSpace2
	PLA
	STA TempSpace2+1
	LDY #1
.printLoop
	LDA (TempSpace2),Y
	BEQ doneLoop
	JSR OSASCI
	INY
	BNE printLoop
.doneLoop
	TYA
	CLC
	ADC TempSpace2
	TAY
	LDA TempSpace2+1
	ADC #0
	PHA
	TYA
	PHA
	RTS
}

.STR_PrintNum
{
	PHA
	LDA TempSpace+3
	CMP #helpRom - helpBase
	BEQ printDigit1
	PLA
	CMP #10
	BCC STR_printDigit
	CMP #100
	BCC print2Digits
	LDY #0
	SEC
.loop100
	INY
	SBC #100
	BCS loop100
	ADC #100
	DEY
	PHA
	TYA
	JSR STR_printDigit
	PLA
.print2Digits
	LDY #0
	SEC
.loop10
	INY
	SBC #10
	BCS loop10
	ADC #10
	PHA
	DEY
	TYA
	JSR STR_printDigit
.printDigit1
	PLA
.*STR_printDigit
	CMP #10
	BCS letters
	ADC #'0'
	JMP OSWRCH
.letters
	ADC #'A'-11
	JMP OSWRCH
}

.STR_PrintBCD
{
	PHA
	LSR A
	LSR A
	LSR A
	LSR A
	JSR	STR_printDigit
	PLA
	AND #&F
	JMP STR_printDigit
}

.STR_ParseNum
{
	CMP #helpRom - helpBase
	BEQ STR_ParseHex
.*STR_ParseDec
	CLC
	JSR GSINIT						\\ skip spaces
	BEQ blankNum					\\ nothing here
	LDA #0
.numLoop
	STA TempSpace+2				\\ value so far
	JSR GSREAD						\\ read digit
	BCS endNum2
	CMP #'9'+1
	BCS endNum
	SBC #'0'-1						\\ convert to number
	BCC endNum
	TAX								\\ save for later
	ASL TempSpace+2				\\ multiply previous result by 2
	BCS badNum
	LDA TempSpace+2
	ASL A							\\ result times 4
	BCS badNum
	ASL A							\\ result times 8
	BCS badNum
	ADC TempSpace+2				\\ result times 10
	BCS badNum
	STA TempSpace+2
	TXA								\\ new digit value
	ADC TempSpace+2				\\ new total value
	BCC numLoop
.badNum
	LDA #&FF
.blankNum
	CLC
	RTS								\\ C is clear, Z set for blank, NZ for error
.endNum
	DEY								\\ reread non-digit
	SEC
.endNum2
	LDA TempSpace+2
	RTS
.*STR_ParseHex
	CLC
	JSR GSINIT						\\ skip spaces
	BEQ blankNum					\\ nothing here
	JSR GSREAD						\\ read digit
	SEC
	SBC #'0'
	BCC badNum
	CMP #10
	BCC goodNum
	SBC #'A'-'0'-10
	CMP #10
	BCC badNum
	CMP #16
	BCS badNum
.goodNum
	TAX
	JSR GSREAD						\\ C is clear if more characters
	TXA
	RTS
}


