\***************************************************************************************\
\																						\
\										Time & Config.									\
\																						\
\***************************************************************************************\

\\	Set the constants in this file, then assemble with
\\		beebasm -i TnC.asm -do TnC.ssd
\\


VIA_BASE 	= &FCB0		\\ set this to &FE60 for standard BBC userport

OSWORDE8	= 0			\\ 1 = implement OSWRD 14,9 & OSWRD 14,10: like 14,1 & 14,2, but with century
CONFIGFSPS	= 1			\\ 1 = implement CONFIGURE FS and PS



ORG &8000
.codeStart
INCLUDE "Header.asm"
INCLUDE "Settings.asm"
INCLUDE "VIA.asm"
INCLUDE "Time.asm"
INCLUDE "TimeStrings.asm"
INCLUDE "Commands.asm"
INCLUDE "Configure.asm"
INCLUDE "Strings.asm"
INCLUDE "Roms.asm"
INCLUDE "OswordEF.asm"
INCLUDE "SaveTimes.asm"
.codeEnd


PRINT "Code size ", codeEnd - codeStart, "bytes"
SAVE "TnC", codeStart, codeEnd, VIA_setup
PUTBASIC "../sntp/SNTPoS.bas", "SNTPoS"
PUTTEXT "../Timezones/Africa.txt", "Africa", &0000
PUTTEXT "../Timezones/Australasia.txt", "Austral", &0000
PUTTEXT "../Timezones/Europe.txt", "Europe", &0000
PUTTEXT "../Timezones/Far East.txt", "FarEast", &0000
PUTTEXT "../Timezones/Subcontinent.txt", "Subcont", &0000
PUTTEXT "../Timezones/USA.txt", "USA", &0000

PUTBASIC "../Examples/DST.bas", "DST"
