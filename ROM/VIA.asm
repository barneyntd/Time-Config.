\ User VIA registers
VIA_iorb		= VIA_BASE
VIA_ddrb		= VIA_BASE + &02
VIA_t2cl		= VIA_BASE + &08
VIA_t2ch		= VIA_BASE + &09
VIA_sr  		= VIA_BASE + &0A
VIA_acr 		= VIA_BASE + &0B
VIA_pcr 		= VIA_BASE + &0C
VIA_ifr 		= VIA_BASE + &0D
VIA_ier 		= VIA_BASE + &0E

\ Port B control lines
PB_card 		= %00011111
PB_ramsel  		= %10000000
PB_alarm		= %01000000
PB_rtcsel		= %00100000
PB_sclk 		= %00000010

\IER control bits
IER_enable		= %10000000
IER_disable		= %00000000
IER_T1			= %01000000
IER_T2			= %00100000
IER_CB1			= %00010000
IER_CB2			= %00001000
IER_SR			= %00000100
IER_CA1			= %00000010
IER_CA2			= %00000001

\ PCR control bits
PCR_CB2_mask	= %00011111
PCR_CB1_mask	= %11101111

\ ACR control bits
ACR_T1_mask		= %00111111
ACR_T2_count	= %00100000
ACR_SR_mask		= %11100011
ACR_SR_off		= %00000000
ACR_SR_in		= %00001000
ACR_SR_out		= %00011000
ACR_BL_mask 	= %11111101

\ RTC registers
RTC_C1			= &00
RTC_C1_STOP		= %00100000
RTC_C1_RESET	= %01011000
RTC_C2			= &01
RTC_C2_SI		= %01000000
RTC_C2_TITP		= %00010000
RTC_C2_TIE		= %00000001
RTC_TD_sec		= &02
RTC_TD_min		= &03
RTC_TD_hr		= &04
RTC_TD_day		= &05
RTC_TD_wkdy		= &06
RTC_TD_mnth		= &07
RTC_TD_yr		= &08
RTC_AL_min		= &09
RTC_AL_hr		= &0A
RTC_AL_day		= &0B
RTC_AL_wkdy		= &0C
RTC_offset		= &0D
RTC_TI			= &0E
RTC_TI_4096		= %01111000
RTC_TI_OFF		= %01110011
RTC_TI_time 	= &0F
RTC_regmask		= &0F
RTC_read		= %10010000
RTC_write		= %00010000

\ FRAM commands
FRAM_WREN		= %00000110		\\ Set write enable latch
FRAM_WRDI		= %00000100		\\ Write disable
FRAM_RDSR		= %00000101		\\ Read Status Register
FRAM_WRSR		= %00000001		\\ Write Status Register
FRAM_READ		= %00000011		\\ Read memory data
FRAM_WRITE		= %00000010		\\ Write memory data
FRAM_HIADDR		= %00001000		\\ Use address &100 to &1FF


\*******************************************************\
\														\
\				Setup VIA								\
\														\
\*******************************************************\

 .VIA_setup					\\ set via registers to standby mode; X, Y preserved
	LDA VIA_pcr
	AND #PCR_CB2_mask AND PCR_CB1_mask
	STA VIA_pcr				\\ CB1 & CB2 input negative edge
	LDA VIA_acr
	AND #ACR_SR_mask AND ACR_BL_mask
	ORA #ACR_T2_count
	STA VIA_acr				\\ SR off, PB latch off, T2 countdown mode
	LDA #PB_ramsel OR PB_rtcsel OR PB_card
	STA VIA_iorb				\\ select lines high, in case they get set to output
	LDA #PB_card
	STA VIA_ddrb				\\ alarm & select lines to input, relying on pullups
	RTS

.VIA_setupComm					\\ setup shift register communication; LO(NOT(PB_ramsel)) or LO(NOT(PB_rtcmsel)) in A; X, Y preserved
	STA VIA_iorb				\\ select line low, others high
	EOR #LO(NOT(PB_card))
	PHA							\\ save for later
	STA VIA_ddrb				\\ select line to output
	LDA VIA_acr
	AND #ACR_SR_mask
	ORA #ACR_SR_out
	STA VIA_acr					\\ shift register output mode
	PLA
	AND #LO(NOT(PB_sclk))
	STA VIA_ddrb				\\ clock pullup to input
	RTS

.VIA_sendByte					\\ send shift register communication; first byte in A; X, Y preserved
{
	STA VIA_sr					\\ send byte
	LDA #IER_SR
.wait1
	BIT VIA_ifr					\\ check for shift complete
	BEQ wait1					\\ still waiting
	RTS
}

.VIA_inputMode					\\ switch shift register from output to input mode
	LDA VIA_acr
	AND #ACR_SR_mask
	ORA #ACR_SR_in
	STA VIA_acr				\\ shift register input mode
	LDA VIA_sr				\\ start shifting
	RTS
	
.VIA_readByte
{
	LDA #IER_SR
.wait4
	BIT VIA_ifr				\\ check for shift complete
	BEQ wait4				\\ still waiting
	LDA VIA_sr					\\ read next byte
	RTS
}

.VIA_endComm				\\ set VIA back to normal state; X, Y, C preserved
	LDA VIA_acr
	AND #ACR_SR_mask
	STA VIA_acr				\\ SR off
	LDA #PB_rtcsel OR PB_card
	STA VIA_ddrb				\\ clock pullup to output
	LDA #LO(NOT(PB_rtcsel) AND NOT(PB_sclk))
	STA VIA_iorb				\\ pulse clock low
	LDA #LO(NOT(PB_rtcsel))
	STA VIA_iorb				\\ then high
	LDA #PB_ramsel OR PB_rtcsel OR PB_card
	STA VIA_iorb				\\ select lines high, in case they get set to output
	LDA #PB_card
	STA VIA_ddrb				\\ alarm & select lines to input, relying on pullups
	RTS


\*******************************************************\
\														\
\				Communicate with RTC					\
\														\
\*******************************************************\

.RTC_startComm				\\ start RTC register access; reg. no. in A; X, Y preserved
	PHA						\\ save RTC register no.
	LDA #LO(NOT(PB_rtcsel))
	JSR VIA_setupComm
	PLA
	JMP VIA_sendByte

.RTC_sendBytes				\\ send bytes to RTC registers in ascending order;
							\\ A=start register, X=no of bytes, data in TempSpace,Y
{
	PHP						\\ save interrupt mask
	SEI						\\ block interrupts
	ORA #RTC_write
	JSR RTC_startComm		\\ start register write
.sendBytesLoop
	LDA TempSpace,Y			\\ next data byte
	JSR VIA_sendByte		\\ send it
	INY						\\ count up through data
	DEX						\\ count down bytes
	BNE sendBytesLoop
	JSR VIA_endComm			\\ clean up
	PLP						\\ restore interrupt mask
	RTS
}
	
.RTC_sendByte				\\ send one byte to RTC register;
							\\ A=register, X=data
	PHP						\\ save interrupt mask
	SEI						\\ block interrupts
	ORA #RTC_write
	JSR RTC_startComm		\\ start register write
	TXA
	JSR VIA_sendByte		\\ send it
	JSR VIA_endComm			\\ clean up
	PLP						\\ restore interrupt mask
	RTS
	

.RTC_readBytes	   			\\ read RTC registers in ascending order;
							\\ A=start register, X=no of bytes, data in TempSpace,Y
{
	PHP						\\ save interrupt mask
	SEI						\\ block interrupts
	ORA #RTC_read
	JSR RTC_startComm		\\ start register read
	JSR VIA_inputMode
.readBytesLoop
	JSR VIA_readByte
	STA TempSpace,Y			\\ save it
	INY						\\ count up through data
	DEX						\\ count down bytes
	BNE readBytesLoop
	JSR VIA_endComm			\\ clean up
	PLP						\\ restore interrupt mask
	RTS
}

.RTC_readByte	   			\\ read one RTC register;
							\\ A=register, X=data
	PHP						\\ save interrupt mask
	SEI						\\ block interrupts
	ORA #RTC_read
	JSR RTC_startComm		\\ start register read
	JSR VIA_inputMode
	JSR VIA_readByte
	TAX
	JSR VIA_endComm			\\ clean up
	PLP						\\ restore interrupt mask
	RTS

.RTC_Synchronise			\\ wait for the seconds to tick over
{
	LDA #IER_disable OR IER_T2
	STA VIA_ier				\\ disable T2 interrupt
	LDX #RTC_C2_SI
	LDA #RTC_C2
	JSR RTC_sendByte		\\ turn on seconds alarm
	LDA #PB_alarm
.syncLoop
	BIT VIA_iorb			\\ check alarm pin
	BNE syncLoop			\\ wait for alarm
	LDX #0
	LDA #RTC_C2
	JMP RTC_sendByte		\\ turn off seconds alarm and return
}

.RTC_setupDelay				\\ set up clock & via for delay of X centiseconds
{
	BEQ noDelay
	DEX						\\ T2 counts n+1
	LDA VIA_acr
	ORA #ACR_T2_count
	STA VIA_acr				\\ timer 2 countdown mode
	STX VIA_t2cl			\\ set count
	LDX #RTC_TI_4096		\\ 4096 Hz
	LDA #RTC_TI
	JSR RTC_sendByte
	LDX #41					\\ 4096/41 = 100Hz
	LDA #RTC_TI_time
	JSR RTC_sendByte		\\ start pulses
	LDA #0
	STA VIA_t2ch			\\ start counting
	LDX #RTC_C2_TITP OR RTC_C2_TIE
	LDA #RTC_C2
	JMP RTC_sendByte		\\ turn on countdown alarm and return
.noDelay
	LDA VIA_acr
	AND #LO(NOT(ACR_T2_count))
	STA VIA_acr				\\ timer 2 timer mode
	LDA #0
	STA VIA_t2cl
	STA VIA_t2ch			\\ count one microsecond, then set ifr
	RTS
}
	
.RTC_delay					\\ wait for T2 to countdown past zero
{
	LDA #IER_T2
.waitT2loop
	BIT VIA_ifr				\\ check T2 flag
	BEQ waitT2loop
	LDA #RTC_TI
	LDX #RTC_TI_OFF
	JMP RTC_sendByte		\\ turn off timer and return
}

.RTC_stopClock
	LDX #RTC_C1_STOP
	LDA #RTC_C1
	JMP RTC_sendByte		\\ stop clock and return

.RTC_startClock
	LDX #0
	LDA #RTC_C1
	JSR RTC_sendByte		\\ start clock
	LDA #RTC_C2
	JMP RTC_sendByte		\\ turn off interrupts and return

\*******************************************************\
\														\
\				Communicate with FRAM					\
\														\
\*******************************************************\

.FRAM_startComm					\\ start FRAM access; opcode in A; X, Y, C preserved
	PHA							\\ save FRAM opcode.
	LDA #LO(NOT(PB_ramsel))
	JSR VIA_setupComm
	PLA
	JMP VIA_sendByte

.FRAM_writeByte					\\ save byte in FRAM X=address, Y=value, C=address high bit
{
	PHP							\\ save interrupt mask
	SEI							\\ block interrupts
	LDA #FRAM_WREN
	JSR FRAM_startComm			\\ enable write
	JSR VIA_endComm
	LDA #FRAM_WRITE
	BCC lowaddr
	ORA #FRAM_HIADDR			\\ set high address bit
.lowaddr
	JSR FRAM_startComm			\\ start memory write
	TXA
	JSR VIA_sendByte
	TYA							\\ send data
	JSR VIA_sendByte
	JSR VIA_endComm				\\ clean up
	LDA #FRAM_WRDI
	JSR FRAM_startComm			\\ workround fram bug
	JSR VIA_endComm
	PLP							\\ restore interrupt mask
	RTS
}

.FRAM_readByte					\\ read byte from FRAM X=address, Y=value, C=address high bit
{
	PHP							\\ save interrupt mask
	SEI							\\ block interrupts
	LDA #FRAM_READ
	BCC lowaddr1
	ORA #FRAM_HIADDR			\\ set high address bit
.lowaddr1
	JSR FRAM_startComm			\\ start memory read
	TXA
	JSR VIA_sendByte
	JSR VIA_inputMode
	JSR VIA_readByte
	TAY
	JSR VIA_endComm				\\ clean up
	PLP							\\ restore interrupt mask
	RTS
}

.FRAM_writeBytes				\\ write Y bytes to FRAM start address = X + 256 from TempSpace
{
	PHP							\\ save interrupt mask
	SEI							\\ block interrupts
	LDA #FRAM_WREN
	JSR FRAM_startComm			\\ enable write
	JSR VIA_endComm
	LDA #FRAM_WRITE OR FRAM_HIADDR
	JSR FRAM_startComm			\\ start memory write
	TXA
	JSR VIA_sendByte			\\ send address
	LDX #0
.writeFramLoop
	LDA TempSpace,X				\\ get byte
	JSR VIA_sendByte			\\ send byte to FRAM
	INX
	DEY
	BNE writeFramLoop
	JSR VIA_endComm				\\ clean up
	PLP							\\ restore interrupt mask
	RTS
}

.FRAM_readBytes					\\ read Y bytes from FRAM start address = X + 256 to TempSpace
{
	PHP							\\ save interrupt mask
	SEI							\\ block interrupts
	LDA #FRAM_READ OR FRAM_HIADDR
	JSR FRAM_startComm			\\ start memory read
	TXA
	JSR VIA_sendByte			\\ send address
	JSR VIA_inputMode
	LDX #0
.readFramLoop
	JSR VIA_readByte			\\ read byte from FRAM
	STA TempSpace,X				\\ save it
	INX
	DEY
	BNE readFramLoop
	JSR VIA_endComm				\\ clean up
	PLP							\\ restore interrupt mask
	RTS
}

