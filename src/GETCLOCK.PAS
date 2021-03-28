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
  RTC_SEC1    = $2C0;
  RTC_SEC10   = $2C1;
  RTC_MIN1    = $2C2;
  RTC_MIN10   = $2C3;
  RTC_HOUR1   = $2C4;
  RTC_HOUR10  = $2C5;
  RTC_DAY1    = $2C6;
  RTC_DAY10   = $2C7;
  RTC_MONTH1  = $2C8;
  RTC_MONTH10 = $2C9;
  RTC_YEAR1   = $2CA;
  RTC_YEAR10  = $2CB;
  RTC_WEEKDAY = $2CC;
  RTC_CONTROL = $2CD;

  NIBBLE      = $0F;


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

procedure rtc_get_datetime;
var
  p: byte;
  hour, minute, second: byte;
  bad_time: boolean;
  year, month, day: word;
  bad_date: boolean;
begin
  bad_time := false;
  bad_date := false;

  p := port[RTC_SEC1];
  p := p and NIBBLE;
  if p > 9 then
    bad_time := true;
  second := p;

  p := port[RTC_SEC10];
  p := p and NIBBLE;
  if p > 5 then
    bad_time := true;
  second := p * 10 + second;

  p := port[RTC_MIN1];
  p := p and NIBBLE;
  if p > 9 then
    bad_time := true;
  minute := p;

  p := port[RTC_MIN10];
  p := p and NIBBLE;
  if p > 5 then
    bad_time := true;
  minute := p * 10 + minute;

  p := port[RTC_HOUR1];
  p := p and NIBBLE;
  if p > 9 then
    bad_time := true;
  hour := p;

  p := port[RTC_HOUR10];
  p := p and NIBBLE;
  if p > 2 then
    bad_time := true;
  hour := p * 10 + hour;

  if hour > 24 then
    bad_time := true;

  p := port[RTC_DAY1];
  p := p and NIBBLE;
  if p > 9 then
    bad_date := true;
  day := p;

  p := port[RTC_DAY10];
  p := p and NIBBLE;
  if p > 3 then
    bad_date := true;
  day := p * 10 + day;

  {
  TODO: Intel driver actually validates for errors like
  February 30 or April 31.
  I'll skip this for now, but will get back to it later.
  }

  p := port[RTC_MONTH1];
  p := p and NIBBLE;
  if p > 9 then
    bad_date := true;
  month := p;

  p := port[RTC_MONTH10];
  p := p and NIBBLE;
  if p > 1 then
    bad_date := true;
  month := p * 10 + month;

  if month > 12 then
    bad_date := true;

  p := port[RTC_YEAR1];
  p := p and NIBBLE;
  if p > 9 then
    bad_date := true;
  year := p;

  p := port[RTC_YEAR10];
  p := p and NIBBLE;
  if p > 9 then
    bad_date := true;
  year := p * 10 + year;

  if year > 99 then
    bad_date := true;

  rtc_init; { reset RTC i/o }

  WriteLn('Time: ', hour:2, ':', minute:2, ':', second:2);
  if bad_time then
  begin
    WriteLn('Invalid time');
    Halt(2);
  end;

  WriteLn('Date: ', year:2, ':', month:2, ':', day:2);
  if bad_date then
  begin
    WriteLn('Invalid date');
    Halt(3);
  end;

{
  SetDate(year, month, day);
  SetTime(hour, minute, second, 0);
}
  { TODO: read SEC100 from RTC }
end;

begin
  WriteLn('getclock - read date/time from Intel Above Board RTC');
  if rtc_detect then
    WriteLn('RTC found')
  else
  begin
    WriteLn('RTC not found');
    Halt(1);
  end;
  rtc_get_datetime;
end.
