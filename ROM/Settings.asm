EconetIDreg			= &FE18
KeyCodeR			= &B3
ScreenInit			= &C300

OSB_KbdScan			= &79
OSB_KbdScanAll		= &7A
OSB_WrCurKeys		= &78
OSB_KeyRptDelay		= &0B
OSB_KeyRtpRate		= &0C
OSB_CapsSetting		= &CA
OSB_CapsLEDs		= &76
OSB_BellVolume		= &D4
OSB_TVAdjust		= &90
OSB_LanguageRom		= &FC
OSB_EnterLanguage	= &8E
OSB_BASICRom		= &BB
OSB_RXBaudRate		= &07
OSB_TXBaudRate		= &08
OSB_PrinterDest		= &05
OSB_PrinterIgnore	= &06
OSB_TubePresence	= &EA
OSB_SerialFormat	= &9C
OSB_BreakType		= &FD
OSB_KbdStartOpt		= &FF

OSW_NetStationInfo	= &13

NVR_EconetStation	= 0
NVR_EconetServer	= 1
NVR_EconetServerNet	= 2
NVR_EconetPrint		= 3
NVR_EconetPrintNet	= 4
NVR_DefaultRoms		= 5
NVR_Roms07Status	= 6
NVR_Roms8FStatus	= 7
NVR_VDUSettings		= 10
NVR_CapsFDSettings	= 11
NVR_KeyRptDelay		= 12
NVR_KeyRptRate		= 13
NVR_PrinterIgnore	= 14
NVR_TubeSerialPrint	= 15
NVR_BellBSFormat	= 16
NVR_NVRSize			= 255

.SET_DefaultsTable
IF CONFIGFSPS
	EQUB &FE				\\ address 1: FS station
	EQUB 0					\\ address 2: FS network
	EQUB &EB				\\ address 3: PS station
	EQUB 0					\\ address 4: PS network
ENDIF
	EQUB %11111111			\\ address 5: FILE & LANG
	EQUB %11111111			\\ address 6: ROM 0-7
	EQUB %11111111			\\ address 7: ROM 8-F
	EQUB 0					\\ address 8: EDIT settings
	EQUB 0					\\ address 9: Telecom settings
	EQUB %00000000			\\ address 10: MODE & TV
	EQUB %11100000			\\ address 11: FDRIVE & CAPS
	EQUB 50					\\ address 12: DELAY
	EQUB 8					\\ address 13: REPEAT
	EQUB 10					\\ address 14: IGNORE
	EQUB %00111011			\\ address 15: TUBE, BAUD & PRINT
	EQUB %10100010			\\ address 16: LOUD, BOOT & DATA
\\	EQUB 0					\\ address 17: ANFS settings

SET_Defaults = P% - 17

.SET_Reset
{
	LDX #SET_DefaultsTable - SET_Defaults
	CLC
.resetLoop
	LDY SET_Defaults,X
	JSR FRAM_writeByte
	INX
	CPX #17
	BCC resetLoop
	LDY EconetIDreg						\\ read Econet ID from jumpers
	LDX #0
	CLC
	JSR FRAM_writeByte					\\ save in NVRAM 0
	LDY #&FF
	LDX #NVR_NVRSize
	CLC
	JSR FRAM_writeByte					\\ ensure *FX 161,255 returns 255
	JSR CON_ReadKeySwitches
	TAX
	AND #%00001000
	EOR #%00001000
	ASL A
	STA TempSpace						\\ save BOOT setting
	TXA
	AND #%00110000						\\ extract FDRIVE setting
	LSR A
	LSR A
	LSR A
	LSR A
	STA TempSpace+1						\\ save FDRIVE setting
	TXA
	AND #%00000111						\\ extract MODE setting
	STA TempSpace+2						\\ save MODE setting
	LDX #NVR_BellBSFormat
	CLC
	JSR FRAM_readByte
	TYA
	ORA TempSpace
	TAY
	JSR FRAM_writeByte
	LDX #NVR_CapsFDSettings
	CLC
	JSR FRAM_readByte
	TYA
	ORA TempSpace+1
	TAY
	JSR FRAM_writeByte
	LDX #NVR_VDUSettings
	CLC
	JSR FRAM_readByte
	TYA
	ORA TempSpace+2
	TAY
	JSR FRAM_writeByte
	RTS
}


\*******************************************************\
\														\
\				Service call 01: startup				\
\														\
\*******************************************************\

.SET_Startup
{
	TYA
	PHA
	LDX #NVR_NVRSize
	CLC
	JSR FRAM_readByte		\\ check for blank NVRAM
	TYA
	BEQ resetEverything
	LDX #KeyCodeR
	LDA #OSB_KbdScan
	JSR OSBYTE				\\ check for R key pressed
	TXA
	BPL notRKey
	LDA #OSB_WrCurKeys
	JSR OSBYTE				\\ write current keys pressed info
	JMP resetSettings
.notRKey
	LDX #NVR_Roms07Status	\\ rom unplugging happens even on soft breaks
	LDA #0
	JSR unplugRoms				\\ unplug roms 0-7
	LDX #NVR_Roms8FStatus
	LDA #8
	JSR unplugRoms				\\ unplug roms 8-F	

	LDA #OSB_BreakType
	LDX #0
	LDY #&FF
	JSR OSBYTE				\\ look up break type
	TXA
	BNE hardBreak
.done
	PLA
	TAY
	LDA #1
	RTS
.resetEverything
	JSR RTC_resetClock		\\ reset clock chip & variables
	JSR RTC_resetTZN		\\ reset timezone names
.resetSettings
	JSR SET_Reset
.hardBreak
IF CONFIGFSPS
	LDX OS_ROMNum
	LDA #&80
	STA OS_RomBytes,X		\\ set hard break flag
ENDIF
	LDX #NVR_VDUSettings
	CLC
	JSR FRAM_readByte
	TYA
	AND #7
	STA TempSpace
	LDX #NVR_BellBSFormat
	CLC
	JSR FRAM_readByte
	TYA
	AND #%00010000
	EOR #%00010000
	LSR A
	ORA TempSpace
	STA TempSpace
	LDX #NVR_CapsFDSettings
	CLC
	JSR FRAM_readByte
	TYA
	AND #3
	ASL A
	ASL A
	ASL A
	ASL A
	ORA TempSpace
	STA TempSpace
	TAX
	LDY #%11000000
	LDA #OSB_KbdStartOpt		\\ change keyboard startup byte to match settings
	JSR OSBYTE

	LDX #NVR_VDUSettings
	CLC
	JSR FRAM_readByte
	TYA
	LSR A
	LSR A
	LSR A
	LSR A
	TAY
	LSR A
	CMP #%00000100
	BCC notNeg
	ORA #%11111000
.notNeg
	TAX
	TYA
	AND #1
	TAY
	LDA #OSB_TVAdjust			\\ set *TV
	JSR OSBYTE
	LDA TempSpace				\\ get screen mode (other bits ignored)
	JSR ScreenInit				\\ reset video with new settings

	LDX #NVR_CapsFDSettings
	CLC
	JSR FRAM_readByte
	TYA
	LSR A
	LSR A
	LSR A
	LSR A
	BCS shCaps
	LSR A
	BCC caps
	LDX #%00110000
	BCS doCaps
.shCaps
	LDX #%10100000
.doCaps
	LDY #%01001000
	LDA #OSB_CapsSetting		\\ set caps lock setting
	JSR OSBYTE
	LDA #OSB_CapsLEDs			\\ set caps lock LEDs
	JSR OSBYTE
.caps
	
	LDX #NVR_KeyRptDelay
	CLC
	JSR FRAM_readByte
	TYA
	TAX
	LDA #OSB_KeyRptDelay		\\ set keyboard repeat delay
	JSR OSBYTE

	LDX #NVR_KeyRptRate
	CLC
	JSR FRAM_readByte
	TYA
	TAX
	LDA #OSB_KeyRtpRate			\\ set keyboard repeat period
	JSR OSBYTE
	
	LDX #NVR_PrinterIgnore
	CLC
	JSR FRAM_readByte
	TYA
	TAX
	LDA #OSB_PrinterIgnore		\\ set printer ignore character
	JSR OSBYTE
	
	LDX #NVR_TubeSerialPrint
	CLC
	JSR FRAM_readByte
	TYA
	LSR A
	LSR A
	PHA
	AND #7
	CLC
	ADC #1
	PHA
	TAX
	LDA #OSB_RXBaudRate			\\ set serial receive baud rate
	JSR OSBYTE
	PLA							\\ baud rate
	TAX
	LDA #OSB_TXBaudRate			\\ set serial transmit baud rate
	JSR OSBYTE
	PLA							\\ NVRAM byte, shifted twice
	LSR A
	LSR A
	LSR A
	TAX
	LDA #OSB_PrinterDest		\\ set printer destination
	JSR OSBYTE
	
	LDX #NVR_BellBSFormat
	CLC
	JSR FRAM_readByte
	TYA
	LSR A
	PHA
	AND #1
	BNE loud
	LDY #0
	LDX #192
	LDA #OSB_BellVolume			\\ set bell volume quiet
	JSR OSBYTE
.loud
	PLA
	LSR A
	LSR A
	AND #%00011100
	TAX
	LDY #%11100011
	LDA #OSB_SerialFormat		\\ set serial data format
	JSR OSBYTE
	JMP done

.unplugRoms
	PHA
	CLC
	JSR FRAM_readByte
	STY TempSpace
	PLA
	TAY
.plugLoop
	LSR TempSpace
	BCS plugged
	LDA OS_RomTable,Y
	AND #%01111111
	STA OS_RomTable,Y
.plugged
	INY
	CPY #8
	BEQ plugDone
	CPY #16
	BNE plugLoop
.plugDone
	RTS
	}

\*******************************************************\
\														\
\				Service call FF: tube					\
\														\
\*******************************************************\

.SET_TubeControl
{
	LDX #NVR_TubeSerialPrint
	CLC
	JSR FRAM_readByte
	TYA
	AND #%00000001
	BNE notKillTube
	SEI						\\ should be already set!
	STA OS_ROMNum			\\ A is zero; skip other roms
.notKillTube
	LDA #&FF
	RTS						\\ restore I flag & return without gap
}

\*******************************************************\
\														\
\				Service call 03: filing system			\
\														\
\*******************************************************\

.SET_defaultFS
{
	TYA
	PHA
IF CONFIGFSPS
	LDA #OSB_BreakType
	LDX #0
	LDY #&FF
	JSR OSBYTE				\\ look up break type
	TXA
	BEQ noNet				\\ not hard break, so don't do anything
	LDA #0
	PHA
	LDA #8					\\ osword &13 subcall: read station number
	PHA
	TSX
	INX
	LDY #&01
	LDA #OSW_NetStationInfo
	JSR OSWORD
	PLA
	PLA
	BEQ noNet				\\ no station number, so no net
	LDX OS_ROMNum
	LDA OS_RomBytes,X
	ORA #&40
	STA OS_RomBytes,X		\\ set net exists flag
	CLC
	LDX #NVR_EconetPrintNet
	JSR FRAM_readByte		\\ read default print server network
	TYA
	PHA
	LDX #NVR_EconetPrint
	JSR FRAM_readByte		\\ read default print server address
	TYA
	PHA
	LDA #3					\\ osword &13 subcall: set print server
	PHA
	TSX
	INX
	LDY #&01
	LDA #OSW_NetStationInfo
	JSR OSWORD
	PLA
	PLA
	PLA
.noNet
ENDIF
	LDA #OSB_KbdScanAll
	JSR OSBYTE
	CPX #&FF
	BNE noDefaultFS			\\ key pressed, so ignore default
	CLC
	LDX #NVR_DefaultRoms
	JSR FRAM_readByte		\\ read default roms
	TYA
	AND #&0F				\\ default file system rom
	CMP OS_ROMNum			\\ compare with this
	BCS noDefaultFS			\\ bigger numbers are already tried; don't try again
	ADC #1					\\ it's about to be decremented
	SEI						\\ should be already set!
	STA OS_ROMNum			\\ skip to default rom
.noDefaultFS
	PLA
	TAY
	LDA #3
	RTS
}

\*******************************************************\
\														\
\				Service call 0F: vectors claimed		\
\														\
\*******************************************************\

IF CONFIGFSPS
.SET_fileServer
{
	TYA
	PHA
	LDA OS_RomBytes,X		\\ check hard break flag
	BPL notFileServer
	LDA #0
	TAY
	JSR OSARGS				\\ get filing system number
	CMP #5
	BNE notFileServer
	LDX OS_ROMNum
	LDA #&40
	STA OS_RomBytes,X		\\ clear hard break, set net present
	CLC
	LDX #NVR_EconetServerNet
	JSR FRAM_readByte		\\ read default file server network
	TYA
	PHA
	LDX #NVR_EconetServer
	JSR FRAM_readByte		\\ read default file server address
	TYA
	PHA
	LDA #1					\\ osword &13 subcall 
	PHA
	TSX
	INX
	LDY #&01
	LDA #OSW_NetStationInfo
	JSR OSWORD
	PLA
	PLA
	PLA
.notFileServer
	PLA
	TAY
	LDA #&F
	RTS
}
ENDIF

\*******************************************************\
\														\
\				Language entry point					\
\														\
\*******************************************************\

.SET_defaultLang
{
	LDX #NVR_DefaultRoms
	CLC
	JSR FRAM_readByte		\\ read default roms
	TYA
	LSR A
	LSR A
	LSR A
	LSR A					\\ default language rom
	TAX
	CMP OS_ROMNum			\\ compare with this
	BCC foundLang			\\ default is smaller than this
	LDX OS_ROMNum			\\ this <= default; try this-1
	DEX
.langLoop
	LDA OS_RomTable,X
	AND #%01000000
	BNE foundLang
	DEX
	BPL langLoop
	LDX #0
	LDY #&FF
	LDA #OSB_BASICRom		\\ look up BASIC rom id
	JSR OSBYTE
	CPX #&FF
	BNE foundLang
	BRK						\\ run out of possibilities
	EQUS &F9,"Language?",0
.foundLang
	LDA #OSB_EnterLanguage
	JMP OSBYTE
}



