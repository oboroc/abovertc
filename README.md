# Intel Above Board PS/PC real-time clock support

I aim to create typical getclock/setclock DOS programs for RTC in Intel Above Board PS/PC card.

![Intel Above Board PS/PC card photo](Intel Above Board PS-PC.jpg)

Intel Above Board PS/PC is a very cool multi-function ISA card from 1985 for XT class computers:
- RTC clock;
- serial port, DB-9 connector;
- parallel port, DB-25 connector;
- up to 1.5MB memory if populating all memory banks with 41256 DRAM chips;
- it can backfill the base memory to 640KB from arbitrary 64K boundary;
- all memory that wasn't used to backfill base memory can be used as EMS 4.0;
- works reliably at 8MHz with 150ns DRAM chips.

The only problem I had with it is that all the drivers I could find online didn't include support for RTC.
I finally found a [driver](3rdparty/clock.sys) distribution that did have RTC driver in it.
It was available in file intel_above_board_v40a.zip available
[here](https://vetusware.com/download/Intel%20Above%20Board%204/?id=6149).
I shared the good news with fellow enthusiasts
[here](http://www.vcfed.org/forum/showthread.php?76141-Need-help-with-RTC-on-Intel-Above-Board-PS-PC&p=631392#post631392).

Intel's driver works well, but it takes 1280 bytes of base memory, and on XT that is a lot.

So far I successfully dissassembled Intel's driver. See the source here: [clock.asm](src/clock.asm).
I use DosBox and Microsoft Macro Assembler 5.1 to build it.
Assembled binary matches the original driver exactly.
I'll massage disassembled code a bit more to make it more readable.
After that I plan to write getclock/setclock DOS programs.


## Note on licensing

clock.sys driver and clock.asm disassembly are copyright (c) 1985 Intel Corporation. The rest of the code is my and is GPLv3.
