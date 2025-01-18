Time & Config.
==============

Time & Config. is a project to add a real-time clock and a configuration memory to a BBC microcomputer model B, giving
it some of the features of the BBC master. It has three main parts:
1.  A PCB containing a PCF2123 RTC, an FM25040B FRAM and an LTC4054 Li charger.
	This is designed to share a user port with a turbo-MMC card, but can also be used alone.
2.  A sideways ROM which implements:
	- OSBYTE 161 & 162: read and write NVRAM
	- OSWORD 14 & 15: read and set real-time clock
	- ROM service calls 40 & 41: extendable CONFIGURE & STATUS
	- \*-commands: TIME, CONFIGURE, STATUS, UNPLUG, INSERT & ROMS
	- configure terms: BAUD, BOOT, NOBOOT, CAPS, NOCAPS, SHCAPS, DATA, DELAY, FDRIVE, FILE, IGNORE, LANG, LOUD, QUIET, MODE, TUBE, NOTUBE, PRINT, REPEAT, TV
 	- help terms: T&C and TIME
3.  A version of SNTP over serial which allows you to synchronise the clock to internet time, to a precision of a few centiseconds.

#### Project folders
- **kicad** This holds the schematic and pcb design, as a kicad project;
- **ROM** This holds the source for the ROM code, in beebasm format;
- **sntp** This holds the SNTPoS client program in BASIC (without line numbers) and the sntpos\_server program in POSIX C.

#### Licence
This project is licensed under creative commons licence [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
This means that you are free to use it for any noncommercial purpose, provided you credit the copyright holder, and pass on the same conditions.
If you want to create a commercial product based on Time & Config., you must obtain a seperate licence from the copyright holder.

