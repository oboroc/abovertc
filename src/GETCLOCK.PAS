{
  getclock - read date/time from Intel Above Board RTC

  version 0.0.1-pre0

  Copyright (c) 2021 Adrian Oboroc

  GPLv3 license

  Compile with Turbo Pascal 6.0 for now
}

program GetClock;

uses
  Dos;

const
  RTC_CONTROL = $2CD;

procedure rtc_init;
var
  p: byte;
begin
  p := port[RTC_CONTROL];
  p := p and $0E;
  port[RTC_CONTROL] := p;
end;

function rtc_detect: boolean;
var
  p, i, tries: byte;
  rtc_found: boolean;
label
  rtc_ok;
begin
  rtc_found := false;
  for tries := 1 to 2 do
  begin
    rtc_init;
    asm
      nop
      nop
      nop
    end;
    p := port[RTC_CONTROL];
    p := p and 1;
    port[RTC_CONTROL] := p;
    for i := 1 to 100 do
    begin
      p := port[RTC_CONTROL];
      if p and 2 = 0 then
      begin
        rtc_found := true;
        goto rtc_ok;
      end;
    end; { i }
  end; { tries }
rtc_ok:
  rtc_detect := rtc_found;
end;

procedure rtc_get_time;
begin
  {
  SetDate(Year, Month, Day: Word);
  SetTime(Hour, Minute, Second, Sec100: Word);
  }
end;

begin
  WriteLn('getclock - read date/time from Intel Above Board RTC');
  if rtc_detect then
    WriteLn('RTC found')
  else
    WriteLn('RTC not found');
end.
