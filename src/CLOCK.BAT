set PATH=d:\dosbox\MASM51
if exist masm.err del masm.err
if exist link.err del link.err
if exist clock.asm masm /DTWEAK /DTWEAK2 /V /Z /ZI clock,,,; 2> masm.err
rem if exist clock.asm masm /V /Z /ZI clock,,,; 2> masm.err
if exist clock.crf cref clock;
if exist clock.obj link clock,,,; 2> link.err
if exist clock.exe exe2bin clock.exe clock.sys
if exist clock.obj del clock.obj
if exist clock.exe del clock.exe
if exist clock.crf del clock.crf
