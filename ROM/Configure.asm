
.CON_DataTable
	EQUB 0:		EQUW CON_Baud-1				\\ BAUD
.bootIndex
	EQUB 16,	%11101111,	%00010000		\\ BOOT -- read keyboard switches for default
	EQUB 16,	%11101111,	%00000000		\\ NOBOOT
	EQUB 11,	%11000111,	%00100000		\\ CAPS
	EQUB 11,	%11000111,	%00010000		\\ NOCAPS
	EQUB 11,	%11000111,	%00001000		\\ SHCAPS
	EQUB 16,	%00011111,	%10100000		\\ DATA
	EQUB 12,	0,			50				\\ DELAY
.fdriveIndex
	EQUB 11+&80, %11111000,	%00110000		\\ FDRIVE -- read keyboard switches for default
	EQUB 5,		%11110000,	%00001111		\\ FILE
	EQUB 14,	0,			&0				\\ IGNORE
	EQUB 5,		%00001111,	%11110000		\\ LANG
	EQUB 16,	%11111101,	%00000010		\\ LOUD
	EQUB 16,	%11111101,	%00000000		\\ QUIET
.modeIndex
	EQUB 10+&80, %11111000,	%00000111		\\ MODE -- read keyboard switches for default         
	EQUB 15,	%11111110,	%00000001		\\ TUBE
	EQUB 15,	%11111110,	%00000000		\\ NOTUBE
	EQUB 15,	%00011111,	%00100000		\\ PRINT
	EQUB 13,	0,			8				\\ REPEAT
	EQUB 0:		EQUW CON_TV-1				\\ TV
	EQUB 0:		EQUW CON_Timezone-1			\\ TIMEZONE
IF CONFIGFSPS
	EQUB 0:		EQUW CON_FS-1				\\ FS
	EQUB 0:		EQUW CON_PS-1				\\ PS
ENDIF

.CON_Configure
{
	LDX #configTable - commandTable		\\ start searching for config term
	JSR CMD_matchCommand
	BEQ blankConfig						\\ no config term
	BPL passConfig						\\ unrecognised config term
	STY TempSpace						\\ save character pos
	STA TempSpace+3						\\ save parameter description
	LDA TempSpace+1						\\ load command index
	ASL A
	ADC TempSpace+1
	STA TempSpace+1						\\ multiply index by 3
	TAY
	LDX CON_DataTable,Y					\\ NVRAM address
	BEQ specialConfig					\\ jump to individual routine
	LDA TempSpace+3						\\ load parameter type
	CMP #helpAlt - helpBase
	BCC paramConfig						\\ config term with numeric parameter
.simpleConfig
	CLC
	JSR FRAM_readByte					\\ read NVRAM from address at X = configDataTable,Y
	TYA
	LDY TempSpace+1
	AND CON_DataTable+1,Y				\\ NVRAM mask relevant bits
	ORA CON_DataTable+2,Y				\\ setting
	TAY
	JSR FRAM_writeByte					\\ save new value
	LDA #0
	RTS
.blankConfig
	TYA
	PHA									\\ save character position
	LDX #configTable - commandTable
	JSR CMD_Help						\\ list all config terms + help text
	PLA
	TAY
.passConfig
	LDA #&28							\\ let the rest of the ROMs try
	RTS
.defaultConfig	
	TXA									\\ configDataTable,index
	BPL simpleConfig					\\ dont use keyboard switches
	JSR CON_ReadKeySwitches
	LDY TempSpace+1						\\ command index
	AND CON_DataTable+2,Y				\\ mask out unwanted bits
	STA TempSpace+2						\\ save it
	LDA CON_DataTable+2,Y				\\ load mask
.keyshiftLoop
	LSR A
	BCS doParam1
	LSR TempSpace+2
	BCC keyshiftLoop					\\ always
.specialConfig
	SEC
.^specialStatus
	LDA CON_DataTable+2,Y				\\ address high
	PHA
	LDA CON_DataTable+1,Y				\\ address low
	PHA
	RTS
.paramConfig
	LDY TempSpace						\\ get character pos
	JSR STR_ParseNum					\\ read numeric parameter
	BCS doParam							\\ numeric parameter in A
	BEQ defaultConfig					\\ no parameter, so use default
	BNE badParam
.doParam
	STA TempSpace+2					\\ save it
.doParam1
	LDY TempSpace+1					\\ command index
	LDA CON_DataTable+1,Y				\\ load mask
.shiftLoop
	LSR A
	BCC shiftLoopEnd
	ASL TempSpace+2
	BCC shiftLoop
	BCS badParam
.shiftLoopEnd
	LDA CON_DataTable+1,Y				\\ reload mask
	AND TempSpace+2					\\ check data size
	BNE badParam
	LDA CON_DataTable,Y
	AND #&7F
	TAX
	CLC
	JSR FRAM_readByte					\\ read NVRAM from address at X = configDataTable,Y
	TYA
	LDY TempSpace+1
	AND CON_DataTable+1,Y				\\ NVRAM mask relevant bits
	ORA TempSpace+2					\\ set value
	TAY
	JSR FRAM_writeByte					\\ save new value
	LDA #0
	RTS
.^badParam
	LDX TempSpace+3						\\ load parameter type
	JSR CMD_doError
	EQUS 252, "Bad parameter, expecting ", 0
}	

.CON_Status
{
	LDX #configTable - commandTable		\\ start searching for config term
	JSR CMD_matchCommand
	BEQ blankStatus						\\ no config term
	BPL passStatus						\\ unrecognised config term
	STA TempSpace+3						\\ save parameter description
	LDA TempSpace+1						\\ load command index
	ASL A
	ADC TempSpace+1						\\ multiply index by 3
	TAY
.termStatus
	STY TempSpace+1
	LDA CON_DataTable,Y					\\ NVRAM address
	AND #&7F
	TAX
	CLC
	BEQ specialStatus					\\ jump to individual routine
	JSR FRAM_readByte					\\ read NVRAM from address at X = configDataTable,Y
	TYA									\\ result
	LDY TempSpace+1						\\ index * 3
	ORA CON_DataTable+1,Y				\\ NVRAM mask relevant bits
	EOR CON_DataTable+1,Y				\\ NVRAM flip irrelevant bits
	STA TempSpace						\\ relevant bits from NVRAM
	LDX TempSpace+2						\\ start of this term
	LDA TempSpace+3						\\ load parameter type
	CMP #helpAlt - helpBase
	BCC paramStatus						\\ config term with numeric parameter
.checkNext
	LDA TempSpace						\\ load setting value
	CMP CON_DataTable+2,Y				\\ check setting
	BNE notThisOne
	JSR CMD_printTerm
	JMP endLine
.notThisOne
	LDA TempSpace+3						\\ load parameter type
	CMP #helpAlt - helpBase				\\ check for alternative
	PHP
.skipLoop
	INX
	LDA commandTable-1,X
	BPL	skipLoop						\\ skip over term
	STA TempSpace+3
	PLP
	BNE nothing							\\ no alternative matches setting
	INY
	INY
	INY									\\ next index
	BNE checkNext						\\ always true
.paramStatus
	JSR CMD_printTerm
	LDA CON_DataTable+1,Y
.shiftLoop
	LSR A
	BCC shifted
	LSR TempSpace						\\ convert data bits to number
	BCC shiftLoop						\\ should be always true
.^shifted
	LDA #' '
	JSR OSWRCH
	LDA TempSpace						\\ numeric parameter value
	STY TempSpace+1
	JSR STR_PrintNum
	LDY TempSpace+1
.^endLine
	JSR OSNEWL
.nothing
	LDA #0
	RTS
.notFSPS
	PLA
	TAY
.passStatus
	LDA #&29							\\ let the rest of the ROMs try
	RTS

.blankStatus
	TYA
	PHA									\\ save character position
	LDX #configTable - commandTable
	LDY #0
.termLoop1
	STX TempSpace+2						\\ start of term
.termLoop
	INX
	LDA commandTable-1,X
	BEQ termDone
	BPL termLoop
	STA TempSpace+3
	JSR termStatus						\\ print term & status
	INY
	INY
	INY
	BNE termLoop1						\\ always
.termDone
IF CONFIGFSPS
	CPX #fspsTable-commandTable
	BNE notFSPS
	LDX OS_ROMNum
	LDA OS_RomBytes,X
	AND #&40
	BEQ notFSPS
	LDX #fspsTable-commandTable
	BNE termLoop1						\\ always
ENDIF
}

.CON_ReadKeySwitches
{
	LDX #&09							\\ start scanning at switch 8/bit 0
.keyScanLoop
	LDY #&03    						;stop Auto scan
	STY &FE40   						;by writing to system VIA
	LDY #&7F    						;set port A to input on bit 7, output on bits 0 to 6
	STY &FE43   						;
	STX &FE4F   						;write X to Port A system VIA
	LDX &FE4F   						;read back &80 if key pressed (M set)
	LDY #&0B    						;select auto scan of keyboard
	STY &FE40   						;tell VIA
	CPX #&80							\\ set C to keyboard switch
	ROR A
	DEX
	CPX #&1
	BEQ doKeySw
	CPX #&81
	BNE keyScanLoop
.doKeySw
	EOR #&FF							\\ switch off means bit = 1
	RTS
}

.CON_Baud
{
	BCC baudStatus
	LDY TempSpace						\\ get character pos
	JSR STR_ParseDec					\\ read numeric parameter
	BNE notDefault						\\ not zero or blank
	LDA #7								\\ defaul value
	SEC
.notDefault
	BCC badParam1
	CMP #9
	BCS badParam1
	SBC #0								\\ actually 1, but C is clear
	ASL A
	ASL A
	STA TempSpace+2
	LDX #NVR_TubeSerialPrint
	CLC
	JSR FRAM_readByte					\\ read NVRAM from address 15
	TYA
	AND #%11100011						\\ NVRAM mask relevant bits
	ORA TempSpace+2						\\ set value
	TAY
	JSR FRAM_writeByte					\\ save new value
	LDA #0
	RTS

.baudStatus
	LDX #NVR_TubeSerialPrint
	CLC
	JSR FRAM_readByte					\\ read NVRAM from address 15
	TYA									\\ result
	LSR A
	LSR A
	AND #7
	CLC
	ADC #1
	STA TempSpace						\\ relevant bits from NVRAM
	LDX TempSpace+2						\\ start of this term
	JSR CMD_printTerm
	LDY TempSpace+1
	JMP shifted
.^badParam1
	JMP badParam
}	

.CON_TV
{
	BCC tvStatus
	LDY TempSpace						\\ get character pos
	JSR STR_ParseDec					\\ read numeric parameter
	BCS doVertical
	BNE badParam1
	LDA #0								\\ default vertical offset
.doVertical
	CMP #4
	BCC vertOK
	CMP #252
	BCC badParam1
.vertOK
	ASL A
	STA TempSpace+1
	CLC
	JSR GSINIT						\\ skip spaces
	BEQ noInterlace					\\ nothing here
	CMP #','						\\ check for comma
	BNE noComma
	INY
.noComma
	JSR STR_ParseDec				\\ read numeric parameter
	BCS doInterlace
	BNE badParam1
.noInterlace
	LDA #0							\\ default interlace
.doInterlace
	CMP #2
	BCS badParam1
	ORA TempSpace+1
	ASL A
	ASL A
	ASL A
	ASL A
	STA TempSpace+1
	LDX #NVR_VDUSettings
	CLC
	JSR FRAM_readByte				\\ read NVRAM from address 10
	TYA
	AND #%00001111					\\ NVRAM mask relevant bits
	ORA TempSpace+1					\\ set value
	TAY
	JSR FRAM_writeByte				\\ save new value
	LDA #0
	RTS

.tvStatus
	LDX #NVR_VDUSettings
	CLC
	JSR FRAM_readByte				\\ read NVRAM from address 10
	TYA								\\ result
	LSR A
	LSR A
	LSR A
	LSR A
	STA TempSpace					\\ relevant bits from NVRAM
	LDX TempSpace+2					\\ start of this term
	JSR CMD_printTerm
	LDA #' '
	JSR OSWRCH
	LDA TempSpace					\\ load value
	LSR A
	CMP #4
	BCC notNeg
	ORA #%11111100
.notNeg
	JSR STR_PrintNum
	LDA #','
	JSR OSWRCH
	LDA TempSpace					\\ load value
	AND #1
	JSR STR_printDigit
	LDY TempSpace+1
	JMP endLine
}

IF CONFIGFSPS
.CON_FSPS
{
	LDY TempSpace					\\ get character pos
	JSR STR_ParseDec				\\ read numeric parameter
	BCS doNetwork
	BNE badParam2
	LDA #0							\\ default network 0
	STA TempSpace+1
	BEQ defaultFS
.doNetwork
	STA TempSpace+1
	JSR GSREAD
	BCC dot
	LDA TempSpace+1					\\ no dot, so last value was server ID
	LDX #0
	STX TempSpace+1					\\ default network 0
	BCS writeFS
.dot
	CMP #'.'						\\ check for full stop
	BNE badParam2
	JSR STR_ParseDec				\\ read numeric parameter
	BCS writeFS
	BNE badParam2
.defaultFS
	CLC								\\ use default ID
.writeFS
	BIT TempSpace+1					\\ check network <= 127
	BMI badParam2
	RTS
.badParam2
	JMP badParam
}

.CON_FS
{
	BCC fsStatus
	JSR CON_FSPS
	BCS notDefault
	LDA #&FE						\\ default file server ID 254
.notDefault
	TAY
	CLC
	LDX #NVR_EconetServer
	JSR FRAM_writeByte
	LDX #NVR_EconetServerNet
	LDY TempSpace+1
	JSR FRAM_writeByte
	LDA #0
	RTS

.fsStatus
	LDX #NVR_EconetServer
	CLC
	JSR FRAM_readByte				\\ read NVRAM from address 1
	STY TempSpace
	LDX #NVR_EconetServerNet
.^fspsStatus
	JSR FRAM_readByte
	TYA
	PHA
	LDX TempSpace+2					\\ start of this term
	JSR CMD_printTerm
	LDA #' '
	JSR OSWRCH
	PLA
	JSR STR_PrintNum
	LDA #'.'
	JSR OSWRCH
	LDA TempSpace
	JSR STR_PrintNum
	LDY TempSpace+1
	JMP endLine
}

.CON_PS
{
	BCC psStatus
	JSR CON_FSPS
	BCS notDefault
	LDA #&EB						\\ default print server ID 235
.notDefault
	TAY
	CLC
	LDX #NVR_EconetPrint
	JSR FRAM_writeByte
	LDX #NVR_EconetPrintNet
	LDY TempSpace+1
	JSR FRAM_writeByte
	LDA #0
	RTS
	
.psStatus
	LDX #NVR_EconetPrint
	CLC
	JSR FRAM_readByte				\\ read NVRAM from address 3
	STY TempSpace
	LDX #NVR_EconetPrintNet
	JMP fspsStatus
}
ENDIF

.timezoneStatus
	LDX TempSpace+2					\\ start of this term
	LDA TempSpace+1
	PHA
	JSR CMD_printTerm
	JSR OSNEWL
	TXA
	PHA
	JSR RTC_ListZones				\\ print list of timezones
	PLA
	TAX
	PLA
	TAY
	LDA #0
	RTS

.CON_Timezone
{
	BCC timezoneStatus
	LDY TempSpace					\\ get character pos
	CLC
	JSR GSINIT						\\ skip spaces
	BEQ blankZone					\\ nothing here
	LDA TextPointer
	STA OSWORDPtr
	LDA TextPointer+1
	STA OSWORDPtr+1
	JSR RTC_ParseTZN				\\ check if it exists
	BCS foundIt
	LDX #NVR_TZDefs
.searchLoop
	SEC
	JSR FRAM_readByte
	CPY #0
	BEQ foundSpace
	TXA
	ADC #4							\\ C is set from CPY
	TAX
	CPX #NVR_TZDefs+NVR_TZDefsSpace
	BCC searchLoop
	LDX #&FF
	JSR CMD_doError
	EQUS 190, "Timezones full", 0
.foundSpace
	LDY TempSpace2					\\ character pos saved in RTC_ParseTZN
	JSR GSREAD
	BCS	badName 
	TAY
	SEC
	JSR FRAM_writeByte
	INX
	LDY TempSpace2
	INY
	JSR GSREAD
	BCS	badName 
	TAY
	SEC
	JSR FRAM_writeByte
	INX
	LDY TempSpace2
	INY
	INY
	JSR GSREAD
	BCS	badName
	TAY
	SEC
	JSR FRAM_writeByte
	DEX
	DEX
	LDY TempSpace2
	INY
	INY
	INY
.foundIt
	JSR RTC_rewriteTZN
	LDA #0
	RTS
.blankZone
	JSR RTC_resetTZN
	LDA #0
	RTS
.badName
	LDX #&FF
	JSR CMD_doError
	EQUS 204, "Bad timezone name", 0
}

