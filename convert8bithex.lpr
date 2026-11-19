program convert8bithex;

{
  convert8bithex - command line version of "Convert 8 bit hex files"

  Converts between BIN, PRG, hex, Intel hex, MOS papertape, TIM papertape,
  Motorola S-record, Apple 1 hex, KIM-1 tape (and save as assembler defines).

  Uses the same load/save units as the Lazarus GUI program.

  MIT License, Copyright (c) 2019-2026 Hans Otten
}

{$mode objfpc}{$H+}

uses
  SysUtils, hexglobals, loadhexformats, savehexformats;

type
  TFormat = (fmtNone, fmtBIN, fmtPRG, fmtHEX, fmtIntel, fmtMOS, fmtTIM,
             fmtSrec, fmtApple1, fmtKIM, fmtDefine) ;

const
  FormatNames : array[TFormat] of string =
    ('', 'bin', 'prg', 'hex', 'ihex', 'mos', 'tim', 'srec', 'apple1', 'kim', 'define') ;
  FormatDescr : array[TFormat] of string =
    ('', 'binary, no address (use -s)',
     'binary, first two bytes load address (low, high)',
     'hex digits, two per byte, no address (use -s)',
     'Intel hex',
     'MOS / KIM-1 papertape',
     'TIM papertape',
     'Motorola S-record (S1/S5/S9)',
     'Apple 1 hex monitor format',
     'KIM-1 tape (.tap, binary with ID)',
     'assembler source with define bytes (output only, use -d)') ;
  { formats whose save procedure writes one file per buffer part }
  SplitFormats = [fmtBIN, fmtPRG, fmtHEX, fmtApple1, fmtKIM] ;

var
  infile, outfile   : string ;
  infmt, outfmt     : TFormat ;
  definestr         : string ;
  merge, force,
  quiet, startgiven : boolean ;
  fillbyte          : byte ;
  outtapeID         : byte ;
  outnames          : array of string ;

procedure Msg(const s : string) ;
begin
  if not quiet then
    writeln(s) ;
end ;

procedure Fail(const s : string ; code : integer) ;
begin
  writeln(stderr, 'convert8bithex: ', s) ;
  halt(code) ;
end ;

procedure Usage ;
var
  f : TFormat ;
begin
  writeln(versiontext) ;
  writeln ;
  writeln('Usage: convert8bithex [options] infile outfile') ;
  writeln ;
  writeln('Options:') ;
  writeln('  -i, --in FORMAT     input format  (default: from infile extension)') ;
  writeln('  -o, --out FORMAT    output format (default: from outfile extension)') ;
  writeln('  -s, --start ADDR    load address in hex for bin and hex input (default 0000)') ;
  writeln('  -m, --merge         write one output covering all parts, gaps filled') ;
  writeln('      --fill BYTE     hex fill byte for gaps with --merge (default FF)') ;
  writeln('  -k, --tapeid ID     hex KIM-1 tape ID for kim output (default 00)') ;
  writeln('  -d, --define TEXT   define directive for define output, e.g. ".byte $"') ;
  writeln('  -y, --yes           overwrite existing output files') ;
  writeln('  -q, --quiet         only report errors') ;
  writeln('  -h, --help          this text') ;
  writeln('  -V, --version       show version') ;
  writeln ;
  writeln('Formats:') ;
  for f := Succ(fmtNone) to High(TFormat) do
    writeln('  ', Format('%-8s', [FormatNames[f]]), ' ', FormatDescr[f]) ;
  writeln ;
  writeln('Extensions: .bin .prg .hex .ihex/.ihx .ptp/.pap .tim .srec/.s19 .ahex .tap .asm') ;
  writeln ;
  writeln('Input with several address ranges (Intel hex, papertape, S-record, Apple 1)') ;
  writeln('is loaded as separate parts. Output to bin, prg, hex, apple1 or kim then gives') ;
  writeln('one file per part, named <outfile name><start address><ext>,') ;
  writeln('e.g. prog0200.bin and prog1000.bin. Use -m for a single file instead.') ;
  writeln ;
  writeln('Examples:') ;
  writeln('  convert8bithex monitor.ptp monitor.bin') ;
  writeln('  convert8bithex -m --fill 00 basic.ihex basic.bin') ;
  writeln('  convert8bithex -s E000 rom.bin rom.srec') ;
  writeln('  convert8bithex -o define -d ".byte $" rom.bin rom.asm') ;
  halt(0) ;
end ;

function FormatFromName(const s : string) : TFormat ;
var
  f : TFormat ;
begin
  Result := fmtNone ;
  for f := Succ(fmtNone) to High(TFormat) do
    if LowerCase(s) = FormatNames[f] then
      exit(f) ;
  { some aliases }
  case LowerCase(s) of
    'intel', 'ihx'          : Result := fmtIntel ;
    'pap', 'ptp', 'papertape': Result := fmtMOS ;
    's19', 's-record', 'motorola': Result := fmtSrec ;
    'ahex', 'apple'         : Result := fmtApple1 ;
    'tap', 'kimtape'        : Result := fmtKIM ;
    'asm'                   : Result := fmtDefine ;
  end ;
end ;

function FormatFromExt(const filename : string) : TFormat ;
var
  ext : string ;
begin
  ext := LowerCase(ExtractFileExt(filename)) ;
  case ext of
    '.bin', '.rom'  : Result := fmtBIN ;
    '.prg'          : Result := fmtPRG ;
    '.hex'          : Result := fmtHEX ;
    '.ihex', '.ihx' : Result := fmtIntel ;
    '.ptp', '.pap'  : Result := fmtMOS ;
    '.tim'          : Result := fmtTIM ;
    '.srec', '.s19', '.mot' : Result := fmtSrec ;
    '.ahex'         : Result := fmtApple1 ;
    '.tap'          : Result := fmtKIM ;
    '.asm'          : Result := fmtDefine ;
  else
    Result := fmtNone ;
  end ;
end ;

function ParseHex(const s : string ; maxval : integer ; out value : integer) : boolean ;
var
  t : string ;
begin
  t := s ;
  if (t <> '') and (t[1] = '$') then
    Delete(t, 1, 1) ;
  if (Length(t) > 2) and (LowerCase(Copy(t, 1, 2)) = '0x') then
    Delete(t, 1, 2) ;
  Result := (t <> '') and TryStrToInt('$' + t, value)
            and (value >= 0) and (value <= maxval) ;
end ;

procedure ParseArgs ;
var
  i, v : integer ;
  a    : string ;
  files : array of string ;

  function NextArg : string ;
  begin
    inc(i) ;
    if i > ParamCount then
      Fail('missing value for option ' + a, 1) ;
    Result := ParamStr(i) ;
  end ;

begin
  infmt := fmtNone ;
  outfmt := fmtNone ;
  definestr := '.byte $' ;
  merge := false ;
  force := false ;
  quiet := false ;
  startgiven := false ;
  fillbyte := $FF ;
  outtapeID := 0 ;
  startaddress := 0 ;
  files := nil ;
  if ParamCount = 0 then
    Usage ;
  i := 0 ;
  while i < ParamCount do
    begin
      inc(i) ;
      a := ParamStr(i) ;
      if (a = '-h') or (a = '--help') or (a = '-?') or (a = '/?') then
        Usage
      else if (a = '-V') or (a = '--version') then
        begin
          writeln(versiontext) ;
          halt(0) ;
        end
      else if (a = '-i') or (a = '--in') then
        begin
          infmt := FormatFromName(NextArg) ;
          if infmt = fmtNone then
            Fail('unknown input format ' + ParamStr(i) + ' (see convert8bithex -h)', 1) ;
          if infmt = fmtDefine then
            Fail('define is an output format only', 1) ;
        end
      else if (a = '-o') or (a = '--out') then
        begin
          outfmt := FormatFromName(NextArg) ;
          if outfmt = fmtNone then
            Fail('unknown output format ' + ParamStr(i) + ' (see convert8bithex -h)', 1) ;
        end
      else if (a = '-s') or (a = '--start') then
        begin
          if not ParseHex(NextArg, $FFFF, v) then
            Fail('start address must be hex 0000 .. FFFF', 1) ;
          startaddress := v ;
          startgiven := true ;
        end
      else if (a = '-k') or (a = '--tapeid') then
        begin
          if not ParseHex(NextArg, $FF, v) then
            Fail('tape ID must be hex 00 .. FF', 1) ;
          outtapeID := v ;
        end
      else if a = '--fill' then
        begin
          if not ParseHex(NextArg, $FF, v) then
            Fail('fill byte must be hex 00 .. FF', 1) ;
          fillbyte := v ;
        end
      else if (a = '-d') or (a = '--define') then
        definestr := NextArg
      else if (a = '-m') or (a = '--merge') then
        merge := true
      else if (a = '-y') or (a = '--yes') then
        force := true
      else if (a = '-q') or (a = '--quiet') then
        quiet := true
      else if (Length(a) > 1) and (a[1] = '-') then
        Fail('unknown option ' + a + ' (see convert8bithex -h)', 1)
      else
        begin
          SetLength(files, Length(files) + 1) ;
          files[High(files)] := a ;
        end ;
    end ;
  if Length(files) <> 2 then
    Fail('need exactly one input file and one output file (see convert8bithex -h)', 1) ;
  infile := files[0] ;
  outfile := files[1] ;
  if infmt = fmtNone then
    infmt := FormatFromExt(infile) ;
  if infmt = fmtNone then
    Fail('cannot tell input format from extension, use -i', 1) ;
  if infmt = fmtDefine then
    Fail('define (.asm) is an output format only, use -i', 1) ;
  if outfmt = fmtNone then
    outfmt := FormatFromExt(outfile) ;
  if outfmt = fmtNone then
    Fail('cannot tell output format from extension, use -o', 1) ;
  if startgiven and not (infmt in [fmtBIN, fmtHEX]) then
    Msg('Note: -s is only used for bin and hex input, ignored') ;
end ;

procedure LoadInput ;
begin
  if not FileExists(infile) then
    Fail('input file not found: ' + infile, 2) ;
  Initbuffer(fillbyte) ;
  hloaded := false ;
  exitreason := '' ;
  try
    AssignFile(loadfile, infile) ;
    Reset(loadfile) ;
    LoadFileOpen := true ;
  except
    on E: Exception do
      Fail('error opening ' + infile + ': ' + E.Message, 2) ;
  end ;
  try
    case infmt of
      fmtBIN    : loadBINfile ;
      fmtPRG    : loadPRGfile ;
      fmtHEX    : loadhexfile ;
      fmtIntel  : loadIntelhexfile ;
      fmtMOS    : loadMOSpapertape ;
      fmtTIM    : loadTIMpapertape ;
      fmtSrec   : loadMotorolaSrec ;
      fmtApple1 : loadApple1hex ;
      fmtKIM    : loadKIMtape ;
    end ;
  except
    on E: Exception do
      begin
        hloaded := false ;
        exitreason := 'unexpected end of file or read error (' + E.Message + ')' ;
      end ;
  end ;
  CloseFile(loadfile) ;
  LoadFileOpen := false ;
  if not hloaded then
    Fail('not a valid ' + FormatNames[infmt] + ' file: ' + exitreason, 2) ;
  if buffers_inuse = 0 then
    Fail('empty input file, nothing to convert', 2) ;
end ;

procedure ReportParts(const title : string) ;
var
  i, n, total : integer ;
begin
  Msg(title) ;
  total := 0 ;
  for i := 1 to buffers_inuse do
    begin
      n := bufferparts[i].bufferend - bufferparts[i].bufferstart + 1 ;
      total := total + n ;
      Msg(Format('  part %d: %s - %s  %6d bytes',
                 [i, IntToHex(bufferparts[i].bufferstart, 4),
                  IntToHex(bufferparts[i].bufferend, 4), n])) ;
    end ;
  Msg(Format('  total : %d bytes in %d part(s)', [total, buffers_inuse])) ;
end ;

procedure MergeParts ;
{ one part from lowest to highest address; gaps keep the fill byte
  that Initbuffer put in the buffer before loading }
var
  i, lo, hi : integer ;
begin
  lo := bufferparts[1].bufferstart ;
  hi := bufferparts[1].bufferend ;
  for i := 2 to buffers_inuse do
    begin
      if bufferparts[i].bufferstart < lo then lo := bufferparts[i].bufferstart ;
      if bufferparts[i].bufferend > hi then hi := bufferparts[i].bufferend ;
    end ;
  bufferparts[1].bufferstart := lo ;
  bufferparts[1].bufferend := hi ;
  buffers_inuse := 1 ;
  Msg(Format('Merged into one part %s - %s, gaps filled with %s',
             [IntToHex(lo, 4), IntToHex(hi, 4), IntToHex(fillbyte, 2)])) ;
end ;

procedure MakeOutputNames ;
var
  i : integer ;
begin
  SplitSaveFilename(outfile) ;
  if (outfmt in SplitFormats) and (buffers_inuse > 1) then
    begin
      SetLength(outnames, buffers_inuse) ;
      for i := 1 to buffers_inuse do
        outnames[i - 1] := SaveFilePath + SaveFileName
                           + IntToHex(bufferparts[i].bufferstart, 4)
                           + SaveFileExtension ;
    end
  else
    begin
      SetLength(outnames, 1) ;
      outnames[0] := outfile ;
    end ;
end ;

procedure SaveOutput ;
var
  s : string ;
begin
  if not force then
    for s in outnames do
      if FileExists(s) then
        Fail('output file exists: ' + s + ' (use -y to overwrite)', 3) ;
  if (outfmt = fmtDefine) and (buffers_inuse > 1) then
    Msg('Note: define output only writes part 1, use -m to include all parts') ;
  saved := false ;
  exitreason := '' ;
  try
    case outfmt of
      fmtBIN    : saveBINfile ;
      fmtPRG    : savePRGfile ;
      fmtHEX    : savehexfile ;
      fmtIntel  : saveIntelhexfile ;
      fmtMOS    : saveMOSpapertape ;
      fmtTIM    : saveTIMpapertape ;
      fmtSrec   : saveMotorolaSrec ;
      fmtApple1 : saveApple1Hex ;
      fmtKIM    : saveKIMtape(outtapeID) ;
      fmtDefine : saveDefineType(definestr) ;
    end ;
  except
    on E: Exception do
      begin
        saved := false ;
        exitreason := E.Message ;
      end ;
  end ;
  if SaveFileOpen then
    begin
      CloseFile(savefile) ;
      SaveFileOpen := false ;
    end ;
  if not saved then
    Fail('conversion failed: ' + exitreason, 3) ;
end ;

var
  s : string ;

begin
  LoadFileOpen := false ;
  SaveFileOpen := false ;
  tapeID := 0 ;
  ParseArgs ;
  LoadInput ;
  Msg('Loaded ' + infile + ' as ' + FormatNames[infmt]) ;
  if infmt = fmtKIM then
    Msg('  KIM tape ID = ' + IntToHex(tapeID, 2)) ;
  ReportParts('Parts:') ;
  if merge and (buffers_inuse > 1) then
    MergeParts ;
  { addresses used by prg header, S9 record and define header }
  startaddress := bufferparts[1].bufferstart ;
  endaddress := bufferparts[buffers_inuse].bufferend ;
  MakeOutputNames ;
  SaveOutput ;
  Msg('Saved as ' + FormatNames[outfmt] + ':') ;
  for s in outnames do
    Msg('  ' + s) ;
end.
