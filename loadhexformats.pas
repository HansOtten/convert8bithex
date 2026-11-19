unit loadhexformats;

{
  v2.5 convert hex formats

  Hans Otten

  Last update December 2023
  }

{
  Load hex formatted file into buffers
  data converted to databytes

  procedures load* expects:

  - fileload file of byte opened
  - buffers array [0 .. $FFFF] of byte written with databytes
  - bufferparts
  - buffer_inuse
  - currentbuffer
  - exitreason contains reasonfor premature exit if loaded false
}
{
 MIT License

Copyright (c) 2019-2023 Hans Otten

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils ;

procedure loadBINfile ;

procedure loadhexfile ;

procedure loadIntelhexfile ;

procedure loadMOSpapertape ;

procedure loadTIMpapertape ;

procedure loadMotorolaSrec ;

procedure loadApple1hex ;

procedure loadKIMtape ;

procedure LoadPRGfile ;


implementation

uses hexglobals ;

var
  expectedset      : set of byte ;
  { debug
  linebuf : array[0.. 65535] of byte ;
  linepos : integer ;
   debug }
function convertfromhex (hexchar : byte) : byte ;

{ expects hexchar to be hex char }

begin
  if hexchar in [ord('A')..ord('Z')]
    then
      convertfromhex := hexchar - ord('A') + 10
    else
      convertfromhex := hexchar - ord('0') ;
end ; { converthex }

function packhex (highnibble, lownibble: byte) : byte ;

  { convert 2 hex chars to binary byte }

begin
  packhex := 16*convertfromhex(highnibble) + convertfromhex(lownibble)
end ; { packhex }

function getbyte(var databyte : byte) : boolean ;
{
   get byte from input, skip all bytes not in expected set
   which is hex file dependent. skips also CR LF etc
   status returned in loadfile and exitreason
   only to be called if hex format requires this.
}

begin
  repeat
    if eof(loadfile)
      then
        begin
          exitreason := 'Error reading input file, past eof?' ;
          getbyte := false ;
          exit
        end;
    try
      read(loadfile, databyte) ;
    except
      begin
        exitreason := 'Error reading input file, past eof?' ;
        getbyte := false ;
        exit
      end;
    end;
  until (databyte in expectedset) ;
  { debug
  linebuf[linepos] := databyte ;
  inc(linepos) ;
  debug }
  getbyte := true ;
end;

function gethexbyte(var databyte : byte): boolean ;

{ read hex char skip all if not expected }

begin
  if getbyte(databyte)
    then
      gethexbyte := databyte in [ord('0')..ord('9'), ord('A')..ord('Z')]
    else
      gethexbyte := false ;
end;



function GetHexByteNumber(var databyte : byte) : boolean ;

 { read two bytes and combine into number }

var
  lownibble,
  highnibble  : byte ;

begin
   lownibble := 0 ;
   highnibble := 0 ;
   if not GethexByte(databyte)
     then
       begin
         GetHexByteNumber := false ;
         exit
       end
     else
       highnibble := databyte ;
   if not GethexByte(databyte)
     then
       begin
         GetHexByteNumber := false ;
         exit
       end
   else
     lownibble := databyte ;
   databyte :=  convertfromhex(lownibble) + 16 *  convertfromhex(highnibble) ;
   GetHexByteNumber  := true ;

end ; { GetHexByteNumber }

function GetHexWord(var dataword: integer) : boolean ;

{ read 4 hex chars into number }

var
  lowbyte, highbyte : byte ;
begin
   lowbyte := 0 ;
   highbyte := 0 ;
   if not GetHexByteNumber(highbyte)
     then
       begin
         GetHexWord := false ;
         exit
       end  ;
   if not GetHexByteNumber(lowbyte)
     then
       begin
         GetHexWord := false ;
         exit
       end  ;
      dataword  := 256 * highbyte + lowbyte ;
   GetHexWord := true ;

end ; { GetHexWord }

function GetHexAddress(var dataword: integer) : boolean ;

{ read low byte, high byte address  }

var
  lowbyte, highbyte : byte ;
begin
   lowbyte := 0 ;
   highbyte := 0 ;
   if not GetHexByteNumber(lowbyte)
     then
       begin
         GetHexAddress := false ;
         exit
       end  ;
   if not GetHexByteNumber(highbyte)
     then
       begin
         GetHexAddress := false ;
         exit
       end  ;
      dataword  := 256 * highbyte + lowbyte ;
   GetHexAddress := true ;

end ; { GetHexAddress }

procedure loadKIMtape ;
var
  databyte          : byte ;
  startaddresstape,
  endaddresstape,
  bufferpos, cnt    : integer ;
  chktape,
  checksum          : integer ;
begin
  hloaded := false ;
  checksum := 0 ;
  read(loadfile, databyte) ;
  if databyte <> $2A
    then
      begin
        exitreason := 'Not the start of a KIM-1 tape file' ;
        exit ;
      end ;
  read(loadfile, databyte) ;
  tapeID := databyte ;
  read(loadfile, databyte) ;
  startaddresstape := databyte ;
  checksum := checksum + databyte ;
  read(loadfile, databyte) ;
  startaddresstape := startaddresstape + 256 * databyte ;
  checksum := checksum + databyte ;
  read(loadfile, databyte) ;
  endaddresstape :=  databyte ;
  checksum := checksum + databyte ;
  read(loadfile, databyte) ;
  endaddresstape := endaddresstape + 256*databyte ;
  checksum := checksum + databyte ;
  databyte := 0 ;
  bufferpos := startaddresstape - 1 ;
  cnt := 0 ;
  while cnt < (endaddresstape - startaddresstape + 1) do
    begin
      read(loadfile, databyte) ;
      checksum := checksum + databyte ;
      inc(bufferpos) ;
      inc(cnt) ;
      buffer[bufferpos] := databyte ;
    end ;
  read(loadfile, databyte) ;
  if databyte <> $2F
    then
      begin
        exitreason := 'Not a KIM-1 tape file' ;
        exit ;
      end ;
  read(loadfile, databyte) ;
  chktape := databyte  ;
  read(loadfile, databyte) ;
  chktape := chktape + databyte * 256 ;
  chktape := chktape and $FFFF ;
  checksum := checksum and $FFFF ;
  if checksum <> chktape
    then
      begin
        exitreason := 'Error in checksum' ;
        exit ;
      end ;
  bufferparts [1].bufferstart := startaddresstape ;
  bufferparts[1].bufferend :=  bufferpos ;
  buffers_inuse := 1 ;
  hloaded := true  ;
end;

procedure LoadBINPRGfile(DoPRGfile : boolean) ;
{ a BIN file is just a collection of bits, no meta info }
{ loads binary file into bufferpart 1 as databytes
  starting at starteaddress
  bufferpos is position of last databyte entered }
var
  databyte : byte ;
  bufferpos : integer ;
begin
  hloaded := false ;
  if DOPRGfile
    then
      begin
        { read startaddress }
        if filesize(loadfile) < 2
          then
            begin
              hloaded := false ;
              exitreason := 'Error reading start address in PRG file' ;
              exit ;
          end ;
        read(loadfile, databyte) ;
        startaddress := databyte ;
        read(loadfile, databyte) ;
        startaddress := startaddress + databyte * 256 ;
      end;
   bufferpos := startaddress ;
  while not eof(loadfile) do
    begin
      read(loadfile, databyte) ;
      buffer[bufferpos] := databyte ;
      inc(bufferpos) ;
      if bufferpos > $FFFF + 1
        then
          begin
            hloaded := false ;
            exitreason := 'Input file too big, size is maximum $FFFF' ;
            exit ;
          end;
    end;
  dec(bufferpos) ;  { correct one too far }
  bufferparts [1].bufferstart := startaddress ;
  bufferparts[1].bufferend :=  bufferpos ;
  buffers_inuse := 1 ;
  hloaded := true ;
end ;


procedure loadBINfile ;
{ a BIN file is just a collection of bits without an meta info such as startaddress }

begin
  LoadBINPRGfile(false) ;
end ;
procedure loadPRGfile ;
{ a PRG file is a BIN file preceeded with the start address (low, high) }

begin
  LoadBINPRGfile(true) ;
end ;

procedure loadhexfile ;

{ hex file consists of databytes in ascii format, one databyte in two hex chars}

var
  lownibble, highnibble: byte ;
  databyte : byte ;
  bufferpos : integer ;

begin
  hloaded := false ;
  bufferpos := startaddress ;
  lownibble := 0 ;
  highnibble := 0 ;
  expectedset := [ord('A')..ord('F'), ord('0')..ord('9')] ;
  while not eof(loadfile) do
    begin
      if gethexbyte(highnibble)
        then
          begin
            if not eof(loadfile)
              then
                if gethexbyte(lownibble)
                  then
                    begin
                      databyte := packhex(highnibble,lownibble) ;
                      buffer[bufferpos] := databyte ;
                      inc(bufferpos) ;
                   end;
            end ;
      if bufferpos > $FFFF + 1
        then
          begin
            exitreason := 'Input file too big, size is maximum $FFFF' ;
            exit ;
          end;
     end ;
  dec(bufferpos) ;
  bufferparts [1].bufferstart := startaddress ;
  bufferparts[1].bufferend :=  bufferpos ;
  buffers_inuse := 1 ;
  hloaded := true ;
end ;


procedure loadIntelhexfile ;

var
  morerecords : boolean ;
  bchecksum,
  checksum,
  rchecksum   : byte ;
  databyte    : byte ;
  recordtype  : byte ;
  inlinecnt,
  totalinline : byte ;
  totallines  : integer ;
  lstartaddr,
  cstartaddr  : integer ;

begin

{
  bufferpart[1] init
  while records to read do
    search for begin of record
    read ; record
    if end of file record type = 01
      check if all read ok
      set no more records
    else if datarecord type 00 read databytes into bufferpart
    if load address read <> loadaddress current
      then
        new bufferpart
}

    hloaded := false ;
    morerecords := true ;
    totallines := 0 ;
    buffers_inuse := 1 ;
    cstartaddr := 0 ;
    while morerecords do { read all records until closing record }
      begin
        checksum := 0 ;
        databyte := 0 ;
        { read record header ;, skip everything in front  }
        expectedset := [ord(':')] ;
        if not getbyte(databyte)
          then
            begin
              exitreason := 'Record start : expected in Intel hex file' ;
              exit ;
            end ;
         { read totalinline count and add to checksum }
        expectedset := [ord('A') .. ord('F'),ord('0') .. ord('9')] ;
        totalinline := 0 ;
         if not GetHexByteNumber(totalinline)
           then
             begin
               exitreason := 'Invalid count field in Intel hex' ;
               exit
             end ;
         checksum := checksum + totalinline ;
        { read startaddress }
        lstartaddr := 0 ;
        if not GetHexWord(lstartaddr)
          then
            begin
              exitreason := 'Error reading startaddress in datarecord' ;
              exit
            end ;
        checksum := checksum
                    + (lstartaddr mod 256)
                    + (lstartaddr div 256) ;

        recordtype := 0 ;
        if not GetHexByteNumber(recordtype)
          then
            begin
               exitreason := 'Error reading record type' ;
               exit
             end ;
        { end of file record }
        if recordtype = 1
          then
            begin
              { count must be 00 }
              if totalinline <> 0
                then
                  begin
                    exitreason := 'Invalid end of file record linecount' ;
                    exit
                  end  ;
              { address has to be 0000 }
              if lstartaddr <> 0
                then
                  begin
                    exitreason := 'Invalid end of file record startaddress' ;
                    exit
                  end  ;
              { checksum has to be $FF }
              morerecords := false ;
              rchecksum := 0 ;
              if GetHexByteNumber(rchecksum)
                then
                  if (rchecksum <> $FF)
                    then
                      begin
                        exitreason := 'Invalid end of file record' ;
                        exit
                      end  ;
             end
        { data record }
        else if recordtype = 0
          then
            begin
              { for all databytes in line do }
              if totallines = 0  { first record contains startaddress }
                then
                  begin
                     cstartaddr := lstartaddr ;
                     bufferparts[buffers_inuse].bufferstart := cstartaddr ;
                   end
                 else
                   begin
                     if cstartaddr <> lstartaddr
                       then
                         begin
                           { new bufferpart }
                           bufferparts[buffers_inuse].bufferend := cstartaddr - 1;
                           inc(buffers_inuse) ;
                           if buffers_inuse > maxbuf
                             then
                               begin
                                 exitreason := 'Too many parts in Intel hex file' ;
                                 exit
                               end  ;
                          bufferparts[buffers_inuse].bufferstart := lstartaddr;
                          cstartaddr := lstartaddr ;
                         end
                   end ;
              { read data bytes from line into buffer }
              for inlinecnt := 1 to totalinline do
                begin
                  { read two hex data bytes and add to checksum }
                  if not GetHexByteNumber(databyte)
                    then
                      begin
                        Exitreason := 'Error in reading databytes' ;
                        exit
                      end ;
                  { write to buffer}
                  buffer[cstartaddr] := databyte ;
                  inc(cstartaddr) ;
                  checksum := checksum + databyte ;
                end ;
              { read checksum }
              rchecksum := 0 ;
              if not GetHexByteNumber(rchecksum)
                 then
                   begin
                     exitreason := 'Error reading checksum data records' ;
                     exit ;
                   end ;
              bchecksum := checksum and $FF ;
              bchecksum := $100 - bchecksum ;
              { if read checksum <> calculated checksum fatal error }
              if bchecksum <> rchecksum
                then
                  begin
                    exitreason := 'Checksum error in data reords' ;
                    exit
                  end ;
              inc(totallines)  ;
            end
        else if recordtype = 2
           then
             begin
                { ignore for now }
             end
        else
          begin
            exitreason := 'Invalid record type' ;
            exit ;
          end ;
      end ;
    hloaded := true ;
    dec(cstartaddr) ;
    bufferparts[buffers_inuse].bufferend := cstartaddr ;

end ;


procedure loadMOSpapertape ;

var
  morerecords : boolean ;
  checksum,
  rchecksum   : integer ;
  databyte    : byte ;
  inlinecnt,
  totalinline : byte ;
  readlines,
  totallines  : integer ;
  lstartaddr,
  cstartaddr  : integer ;

begin
  {
  while records to read do
    search for begin of record
    read ; record
  if datarecord read databytes into buffer
  else if end of file record (count = 0)
    check if all read ok
    set no more records
}
    cstartaddr := 0 ;
    rchecksum := 0 ;
    hloaded := false ;
    morerecords := true ;
    buffers_inuse := 1 ;
    totallines := 0 ;
    while morerecords do { read all records until closing record }
       begin
         checksum := 0 ;
         databyte := 0 ;
         { read record header ;, skip everything in front  }
         expectedset := [ord(';')] ;
         if not getbyte(databyte)
           then
             begin
               exitreason := 'Record start ; expected in papertape' ;
               exit ;
             end ;
          { read totalinline count and add to checksum }
         expectedset := [ord('A') .. ord('F'),ord('0') .. ord('9'),
                         ord(';'), $0D, $0A] ;
         totalinline := 0 ;
         if not GetHexByteNumber(totalinline)
           then
             begin
               exitreason := 'Not a MOS papertape?' ;
               exit
             end ;
         checksum := checksum + totalinline ;
         if totalinline = 0 { last record }
           then
             { some utils do not store the linecount, so just be happy at eof }
             begin
               { read total lines and add to checksum}
               readlines := 0 ;
               if GetHexWord(readlines)
                 then
                   begin
                     { if read total lines <> total lines then fatal error }
                     if totallines <> readlines
                       then
                         begin
                           exitreason := 'Error in number of records in papertape' ;
                           exit ;
                         end ;
                     checksum := (readlines mod 256) +( readlines div 256) ;
                     { read checksum }
                     rchecksum := 0 ;
                     if not GetHexWord(rchecksum)
                       then
                         begin
                           Exitreason := 'Error reading checksum eof record' ;
                           exit ;
                         end ;
                     { if read checksum <> calculated checksum fatal error }
                     if checksum <> rchecksum
                       then
                         begin
                           exitreason := 'Error in checksum eof record' ;
                          exit
                         end ;
                   end ;
               morerecords := false ;
             end
           else  { data record }
             begin
               { read startaddress }
               lstartaddr := 0 ;
               if not GetHexWord(lstartaddr)
                 then
                   begin
                     exitreason := 'error reading in MOS startaddress ' ;
                     exit
                   end ;
               checksum := checksum
                               + (lstartaddr mod 256)
                               + (lstartaddr div 256) ;
               if totallines = 0  { first record contains startaddress }
                 then
                   begin
                      cstartaddr := lstartaddr ;
                      bufferparts[buffers_inuse].bufferstart := cstartaddr ;
                   end
                 else
                   begin
                     if cstartaddr <> lstartaddr
                       then
                         begin
                           { new bufferpart }
                           bufferparts[buffers_inuse].bufferend := cstartaddr - 1;
                           inc(buffers_inuse) ;
                           if buffers_inuse > maxbuf
                             then
                               begin
                                 exitreason := 'Too many parts in Intel hex file' ;
                                 exit
                               end  ;
                          bufferparts[buffers_inuse].bufferstart := lstartaddr;
                          cstartaddr := lstartaddr ;
                         end
                   end ;
               { read data bytes from line }
               for inlinecnt := 1 to totalinline do
                 begin
                   { read two hex data bytes and add to checksum }
                   if not GetHexByteNumber(databyte)
                     then
                       begin
                         Exitreason := 'Error in reading databytes' ;
                         exit
                       end ;
                   { write to buffer}
                   buffer[cstartaddr] := databyte ;
                   inc(cstartaddr) ;
                   checksum := checksum + databyte ;
                 end ;
               { read checksum }
               if not GetHexWord(rchecksum)
                 then
                   begin
                     exitreason := 'Error reading checksum data records' ;
                     exit ;
                   end ;

               { if read checksum <> calculated checksum fatal error }
               if (checksum and $FFFF) <> rchecksum
                 then
                   begin
                     exitreason := 'Checksum error in data reords' ;
                     exit
                   end ;
               inc(totallines)  ;
             end

       end ;
    hloaded := true ;
    dec(cstartaddr) ;
    bufferparts[buffers_inuse].bufferend := cstartaddr ;

end ;


procedure loadTIMpapertape ;

var
  morerecords : boolean ;
  checksum,
  rchecksum   : integer ;
  databyte    : byte ;
  inlinecnt,
  totalinline : byte ;
  readlines,
  totallines  : integer ;
  lstartaddr,
  cstartaddr  : integer ;

begin
  {
  while records to read do
    search for begin of record
    read ; record
  if datarecord read databytes into buffer
  else if end of file record (count = 0)
    check if all read ok
    set no more records
}
    cstartaddr := 0 ;
    rchecksum := 0 ;
    hloaded := false ;
    morerecords := true ;
    buffers_inuse := 1 ;
    totallines := 0 ;
    while morerecords do { read all records until closing record }
       begin
         checksum := 0 ;
         databyte := 0 ;
         { read record header ;, skip everything in front  }
         expectedset := [ord(';')] ;
         if not getbyte(databyte)
           then
             begin
                 hloaded := true ;
                 dec(cstartaddr) ;
                 bufferparts[buffers_inuse].bufferend := cstartaddr ;
                exit
              end ;
          { read totalinline count and add to checksum }
         expectedset := [ord('A') .. ord('F'),ord('0') .. ord('9'),
                         ord(';'), $0D, $0A] ;
         totalinline := 0 ;
         if not GetHexByteNumber(totalinline)
           then
             begin
               exitreason := 'Not a MOS papertape?' ;
               exit
             end ;
         checksum := checksum + totalinline ;
         if totalinline = 0 { last record }
           then
             { some utils do not store the linecount, so just be happy at eof }
             begin
               { read total lines and add to checksum}
               readlines := 0 ;
               if GetHexWord(readlines)
                 then
                   begin
                     { if read total lines <> total lines then fatal error }
                     if totallines <> readlines
                       then
                         begin
                           exitreason := 'Error in number of records in papertape' ;
                           exit ;
                         end ;
                     checksum := (readlines mod 256) +( readlines div 256) ;
                     { read checksum }
                     rchecksum := 0 ;
                     if not GetHexWord(rchecksum)
                       then
                         begin
                           Exitreason := 'Error reading checksum eof record' ;
                           exit ;
                         end ;
                     { if read checksum <> calculated checksum fatal error }
                     if checksum <> rchecksum
                       then
                         begin
                           exitreason := 'Error in checksum eof record' ;
                          exit
                         end ;
                   end ;
               morerecords := false ;
             end
           else  { data record }
             begin
               { read startaddress }
               lstartaddr := 0 ;
               if not GetHexWord(lstartaddr)
                 then
                   begin
                     exitreason := 'error reading in MOS startaddress ' ;
                     exit
                   end ;
               checksum := checksum
                               + (lstartaddr mod 256)
                               + (lstartaddr div 256) ;
               if totallines = 0  { first record contains startaddress }
                 then
                   begin
                      cstartaddr := lstartaddr ;
                      bufferparts[buffers_inuse].bufferstart := cstartaddr ;
                   end
                 else
                   begin
                     if cstartaddr <> lstartaddr
                       then
                         begin
                           { new bufferpart }
                           bufferparts[buffers_inuse].bufferend := cstartaddr -1;
                           inc(buffers_inuse) ;
                           if buffers_inuse > maxbuf
                             then
                               begin
                                 exitreason := 'Too many parts in Intel hex file' ;
                                 exit
                               end  ;
                          bufferparts[buffers_inuse].bufferstart := lstartaddr;
                          cstartaddr := lstartaddr ;
                         end
                   end ;
               { read data bytes from line }
               for inlinecnt := 1 to totalinline do
                 begin
                   { read two hex data bytes and add to checksum }
                   if not GetHexByteNumber(databyte)
                     then
                       begin
                         Exitreason := 'Error in reading databytes' ;
                         exit
                       end ;
                   { write to buffer}
                   buffer[cstartaddr] := databyte ;
                   inc(cstartaddr) ;
                   checksum := checksum + databyte ;
                 end ;
               { read checksum }
               if not GetHexWord(rchecksum)
                 then
                   begin
                     exitreason := 'Error reading checksum data records' ;
                     exit ;
                   end ;

               { if read checksum <> calculated checksum fatal error }
               if (checksum and $FFFF) <> rchecksum
                 then
                   begin
                     exitreason := 'Checksum error in data reords' ;
                     exit
                   end ;
               inc(totallines)  ;
             end

       end ;
    hloaded := true ;
    dec(cstartaddr) ;
    bufferparts[buffers_inuse].bufferend := cstartaddr ;

end ;

procedure loadMotorolaSrec ;

{
header S0  count[2] 0000 module name[20] ver[2] rev[2] description checksum[1]
       S0   06      0000 HDR 48 44 52  checksum (1B)
S1 count[2] load address[4] databytes[0..64] checksum[1]
S5  03 [total linecount[2] checksum
S9   startaaddress[2] checksum[1]

count    = total length afer S1
checksum = the least significant byte of the ones
complement of the sum of the byte values represented by the pairs of characters
making up the count, the address, and the data fields

}


  var
    moredata,
    morerecords : boolean ;
    checksum,
    rchecksum   : byte ;
    bchecksum,
    recordtype,
    databyte    : byte ;
    inlinecnt,
    totalinline : byte ;
    bufferpos,
    readlines,
    totallines  : integer ;
    startaddr,
    lstartaddr  : integer ;

  begin

    {
    while records to read do
      search for begin of record
      read ; record
    if datarecord read databytes into buffer
    else if end of file record S9(count = 0)
      check if all read ok
      set no more records
    else if S5 record nr of datarecords
      check if valid record
      do not accept datarecords
  }
      hloaded := false ;
      moredata := true ;
      morerecords := true ;
      bufferpos := 0 ;
      totallines := 0 ;
      buffers_inuse := 1 ;
      rchecksum := 0 ;
      while morerecords do { read all records until closing record }
         begin
           checksum := 0 ;
           databyte := 0 ;
           { read record header S, skip everything in front  }
           expectedset := [ord('S')] ;
           if not getbyte(databyte)
             then
               begin
                 exitreason := 'Record start : expected in intel hex' ;
                 exit ;
               end ;
           { read record type  }
           expectedset := [ord('0') .. ord('9'), ord('A') ..ord('Z')] ;
           recordtype := 0  ;
           getbyte(recordtype) ;
           totalinline := 0 ;
           if not GetHexByteNumber(totalinline)
             then
               begin
                 exitreason := 'Invalid count in srec' ;
                 exit
               end ;
           checksum := checksum + totalinline ;
           totalinline := totalinline - 3 ;
           case recordtype of
             ord('0') : { slip start record } ;
             ord('1') : { S1 count[2] loadaddress[4] databytes[2] checksum[1]}
                        begin
                        if not moredata
                          then
                            begin
                              exitreason := 'Data records following S5 record' ;
                              exit
                           end ;
                        { read startaddress }
                        lstartaddr := 0 ;
                        if not GetHexWord(lstartaddr)
                          then
                            begin
                              exitreason := 'error reading startaddres in S1 record' ;
                              exit
                            end ;
                         checksum := checksum
                                             + (lstartaddr mod 256)
                                             + (lstartaddr div 256) ;
                        if totallines = 0  { first record contains startaddress }
                          then
                            begin
                              bufferpos := lstartaddr ;
                              bufferparts[buffers_inuse].bufferstart := lstartaddr ;
                             end
                            else
                              begin
                                if bufferpos <> lstartaddr
                                  then
                                    begin
                                      { new part }
                                      bufferparts[buffers_inuse].bufferend := bufferpos -1 ;
                                      inc(buffers_inuse) ;
                                      if buffers_inuse > maxbuf
                                        then
                                          begin
                                            exitreason := 'Too many parts in S record file' ;
                                            exit
                                          end  ;
                                      bufferparts[buffers_inuse].bufferstart := lstartaddr ;
                                      bufferpos := lstartaddr ;
                                    end
                              end ;
                        for inlinecnt := 1 to totalinline do
                          begin
                            { read two hex data bytes and add to checksum }
                            if not GetHexByteNumber(databyte)
                              then
                                begin
                                  Exitreason := 'Error in reading databytes' ;
                                  exit
                                end ;
                             { write to buffer}
                            buffer[bufferpos] := databyte ;
                            inc(bufferpos) ;
                            checksum := checksum + databyte ;
                          end ;
                        {read checksum }
                        rchecksum := 0 ;
                        if not GetHexByteNumber(rchecksum)
                          then
                            begin
                              exitreason := 'Error reading checksum' ;
                              exit ;
                            end ;
                        bchecksum := checksum and $FF ;
                        bchecksum := $FF - bchecksum ;
                      { if read checksum <> calculated checksum fatal error }
                        { if read checksum <> calculated checksum fatal error }
                        if bchecksum  <> rchecksum
                          then
                            begin
                              exitreason := 'Checksum error in data record' ;
                              exit
                            end ;
                        inc(totallines)  ;
                        end;
             ord('5') : begin
                          { S5  count[2]=03 totallinecount[4] checksum[1] }
                          if totalinline <> 0
                            then
                              begin
                                exitreason := 'Error line count S5 record' ;
                                exit ;
                              end ;
                          moredata := false ;
                          readlines := 0 ;
                          if not GetHexWord(readlines)
                            then
                              begin
                                exitreason := 'Error in nr of lines S5 record' ;
                                exit ;
                              end ;
                       { if read total lines <> total lines then fatal error }
                       if totallines <> readlines
                         then
                           begin
                             exitreason := 'Error in number of records in S record' ;
                             exit ;
                           end ;
                       checksum := checksum
                                  + (totallines mod 256)
                                  + (totallines div 256) ;
                        { read checksum }
                       if not GetHexByteNumber(rchecksum)
                         then
                           begin
                             exitreason := 'Error reading checksum' ;
                             exit ;
                           end ;
                         bchecksum := checksum and $FF ;
                         bchecksum := $FF - bchecksum ;
                       { if read checksum <> calculated checksum fatal error }
                       if bchecksum  <> rchecksum
                         then
                           begin
                             exitreason := 'Checksum error in S5 record' ;
                             exit
                           end ;
                        end ;
             ord('9') : begin
                        { S9 count[2]=03 startaddres[4]  checksum[1] }
                          morerecords := false ;
                          if totalinline <> 0
                            then
                              begin
                                exitreason := 'Error line count S5 record' ;
                                exit ;
                              end ;
                          startaddr := 0 ;
                          if not GetHexWord(startaddr)
                            then
                              begin
                                exitreason := 'Error in start address S9 record' ;
                                exit ;
                              end ;
                        checksum := checksum
                                    + (startaddr mod 256)
                                    + (startaddr div 256) ;
                       { read checksum }
                       if not GetHexByteNumber(rchecksum)
                         then
                           begin
                             exitreason := 'Error reading checksum S9 record' ;
                             exit ;
                           end ;
                         bchecksum := checksum and $FF ;
                         bchecksum := $FF - bchecksum ;
                       { if read checksum <> calculated checksum fatal error }
                       if bchecksum  <> rchecksum
                         then
                           begin
                             exitreason := 'Checksum error in S9 record' ;
                             exit
                           end ;
                        end ;
                       end
           end ;
      hloaded := true ;
      dec(bufferpos) ;
      bufferparts[buffers_inuse].bufferend := bufferpos ;
      hloaded := true ;

end ;


procedure loadApple1hex ;

var
  databyte    : byte ;
  bufferpos,
  lstartaddr  : integer ;
  thisline    : boolean ;

{
  Apple 1 format:
  repeated
    loadaddress: 4 hex
    :
    <space><hex high nibble><hex low nibble><space>
    eol (CRLF or LF)
  until eof

  load address may change (new bufferpart) in a new line
  or be added the previous nr of databytes (same aprt)
}

begin

  { debug
  linepos := 0 ;
   debug }

  hloaded := false ;
  buffers_inuse := 0 ;
  thisline := true ;
  bufferpos := 0 ;
  expectedset := [ord('A')..ord('F'), ord('0')..ord('9'),
                  LF, ord(':')] ;
  exitreason:= 'Unknown Apple 1 load file' ;
  { loop until last line  }
  while not eof(loadfile) do
    begin
      { loop records }
      { read load address }
      lstartaddr := 0 ;
      if not GetHexWord(lstartaddr) then
        begin
          exitreason := 'Error reading Apple 1 hex file start adress' ;
          exit
        end ;
      { first bufferpart, store first load address }
      if buffers_inuse = 0
        then
          begin
            bufferpos := lstartaddr ;
            inc(buffers_inuse) ;
            bufferparts[buffers_inuse].bufferstart := lstartaddr ;
          end  ;
      { skip : }
      databyte := 0 ;
      if not getbyte(databyte)
        then
          begin
            exitreason := 'Error reading Apple 1 hex file colon' ;
            exit ;
          end ;
      if databyte <> ord(':')
        then
          begin
            exitreason := 'Error reading Apple 1 hex file , no colon' ;
            exit ;
          end ;
      { loop load databytes till end of line, count them }
      thisline := true ;
      while thisline do
        begin
          { get high nibble and lownibble and combine in databyte}
          if not GetHexByteNumber(databyte)
            then
              begin
                if databyte = LF
                  then
                    thisline := false
                  else
                    begin
                      exitreason := 'Error reading Apple 1 hex file , invalid data' ;
                      exit ;
                    end
                end
            else
              begin
                {put databyte in buffer }
                buffer[bufferpos] := databyte ;
                inc(bufferpos) ;
              end  ;
        end;
    end ;

  { end last bufferpart }
  dec(bufferpos) ;
  bufferparts[buffers_inuse].bufferend := bufferpos ;
  hloaded := true ;
end ;

end.


