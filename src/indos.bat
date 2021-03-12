@echo off
set PATH=c:\masm51;%PATH%
if exist masm.err del masm.err
if exist link.err del link.err
rem if exist clock.asm masm clock; 2> masm.err
if exist clock.asm masm /V /Z /ZI clock,,,; 2> masm.err
if exist clock.crf cref clock;
if exist clock.obj link clock; 2> link.err
if exist clock.exe exe2bin clock.exe masm51.sys
if exist clock.obj del clock.obj
if exist clock.exe del clock.exe
if exist clock.crf del clock.crf
rem pause
