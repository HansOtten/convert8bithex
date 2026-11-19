unit hexglobals;

{
  Shared state for the hex format load/save units, without any GUI.
  Replaces the variable/const part of the Lazarus unit mainconvert,
  so loadhexformats and savehexformats can be used by the command line
  program (and by the GUI, if mainconvert uses this unit).

  MIT License, Copyright (c) 2019-2026 Hans Otten
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  versiontext  = 'convert8bithex - convert 8 bit hex files, command line V1.0 (based on Convert 8 bit hex files V3.1) Hans Otten' ;

  maxbuf = 64 ; { maximum number of multiparts in file }
  CR = $0D ;
  LF = $0A ;

type
  Tbufferparts  = record
                   bufferstart : integer ;
                   bufferend   : integer ;
                 end;

  Tbufferpart   = array[1..maxbuf] of Tbufferparts ;

var
  { multipart buffering }
  buffer        : array[0 .. $FFFF] of byte ;
  bufferparts   : Tbufferpart ;
  buffers_inuse : integer ;  { buffers 1 .. buffers_inuse }
  currentbuf    : integer ;
  buffercnt     : integer ;
  loadfile,
  savefile      : file of byte ; { savefile reused for parts }
  SaveFilePath,
  SaveFileName,
  SaveFileExtension,
  FullSaveFileName : string ;   { multipart files get startaddress appended to name }

  LoadFileOpen : boolean ;
  SaveFileOpen : boolean ;
  hloaded,
  saved        : boolean ;
  exitreason   : string ;
  startaddress : integer ;
  endaddress   : integer ;
  tapeID       : byte ;

procedure Initbuffer(fillbyte : byte) ;
procedure SplitSaveFilename(const filename : string) ;

implementation

procedure Initbuffer(fillbyte : byte) ;
var
  cnt : integer ;
begin
  FillChar(buffer, SizeOf(buffer), fillbyte) ;
  buffers_inuse := 0 ;
  currentbuf := 1 ;
  for cnt := 1 to maxbuf do
    begin
      bufferparts[cnt].bufferstart := 0 ;
      bufferparts[cnt].bufferend := 0 ;
    end ;
end ;

procedure SplitSaveFilename(const filename : string) ;
{ split filename: path, name without extension, extension }
begin
  SaveFilePath      := ExtractFilePath(filename) ;
  FullSaveFileName  := ExtractFileName(filename) ;
  SaveFileExtension := ExtractFileExt(filename) ;
  SaveFileName      := ChangeFileExt(FullSaveFileName, '') ;
end ;

end.
