# Intel Above Board/PS configuration

[stason.org](https://stason.org/TULARC/pc/io-cards/I-L/INTEL-CORPORATION-Multi-I-O-card-ABOVE-BOARD-PS.html)
has information on Intel Above Board/PS switch settings.
They switched the names of switch blocks.
I'll mirror it here:


                                                           __
    +-----------------------------------------------------|
    | *** *** *** *** *** ***         ******  **********  |-+
    | *b* *b* *b* *b* *b* *b*         *SW1 *  *  SW2   *  | | serial
    | *a* *a* *a* *a* *a* *a*         ******  **********  |-+
    | *n* *n* *n* *n* *n* *n*                             |-+
    | *k* *k* *k* *k* *k* *k*                             | |
    | * * * * * * * * * * * *                             | | parallel
    | *5* *4* *3* *2* *1* *0*                             | |
    | * * * * * * * * * * * *                             | |
    | *** *** *** *** *** ***                             |-+
    +---------------------------+--------------------+----|	
                                |____________________|    |


**bold** - factory default setting


| Parallel port   | SW1-1 | SW1-2 |
|:----------------|:------|:------|
| **LPT1 (378h)** | off   | on    |
| LPT2 (278h)     | on    | off   |
| disabled        | off   | off   |


| Serial port     | SW1-3 | SW1-4 |
|:----------------|:------|:------|
| **COM1 (3F8h)** | off   | on    |
| COM2 (2F8h)     | on    | off   |
| disabled        | off   | off   |


| Real-time clock | SW2-1 |
|:----------------|:------|
| **RTC enabled** | on    |
| RTC disabled    | off   |


| Base memory backfill start address | SW2-2 | SW2-3 |
|:-----------------------------------|:------|:------|
| **256K**                           | off   | on    |
| 512K                               | on    | off   |
| none                               | on    | on    |


| I/O port address | SW2-4 | SW2-5 | SW2-6 |
|:-----------------|:------|:------|:------|
| none             | off   | off   | off   |
| 208h - 20Fh      | off   | off   | on    |
| 218h - 21Fh      | off   | on    | off   |
| **258h - 25Fh**  | off   | on    | on    |
| 268h - 26Fh      | on    | off   | off   |
| 2A8h - 2AFh      | on    | off   | on    |
| 2B8h - 2BFh      | on    | on    | off   |
| 2E8h - 2EFh      | on    | on    | on    |


| DRAM chip type | SW2-7 |
|:---------------|:------|
| 64K (4164)     | off   |
| 256K (41256)   | on    |


SW2-8 is factory configured. Don't change.
