@echo off
del *.SYS
del *.LST
del *.ref
del *.err
"C:\Program Files (x86)\DOSBox-0.74-3\DOSBox.exe" indos.bat -noautoexec -exit
fc /b ..\3rdparty\CLOCK.SYS MASM51.SYS > compare.err
