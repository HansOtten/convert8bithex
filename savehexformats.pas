unit savehexformats;

{
  v2.5 convert hex formats

  Hans Otten

  Last update March 2025

V1 Initial KIM-1 Papertape to binary and vice versa conversion
V2 More file types added
V2.5 PRG filetype added
V2.6 1 december 2023 Bug multiple parts load + 1 fixed, TIM papertape added
V2.7 Cosmetic cleanup, filetypes on screen
V2.8 bug in file size multipart convert, fix load/save dialog init
V2.9 Apple 1 save format address one off error
V3.1 SREC to 16 bytes per line (not a bug, to check USURPATOR

  }
{
  save hex formatted file from buffer parts
  data in buffers databytes to be converted to hex file format

  expects:

  - buffers[buffer] array [0 .. $FFFF] of byte filled
  - bufferparts array of  bufferstart bufferend
  - buffers_inuse
}
{
 MIT License

 Copyright (c) 2019-2024 Hans Otten

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
  Classes, SysUtils;

procedure savehexfile ;

procedure saveBINfile ;

procedure saveIntelhexfile ;

procedure saveMOSpapertape ;

procedure saveTIMpapertape ;

procedure saveMotorolaSrec ;

procedure saveApple1Hex ;

procedure saveKIMtape(tapeID : byte) ;

procedure saveDefineType(definestring : string) ;

procedure SavePRGfile ;

implementation

uses hexglobals ;

type

  Tint4 = array[1..4] of byte ;


procedure OpenSaveFile(safefilename : string ) ;

begin

  if savefileopen
    then
      Closefile(savefile) ;
   SaveFileopen := false;
   try
     assignfile(savefile, safefilename) ;
     rewrite(savefile) ;
     savefileopen := true ;
   except
     on E: EInOutError do
       begin
         exit ;
       end;
   end;
end ;



function nibbletohex (data: byte) : byte ;

  begin

    if data < 10
      then
        nibbletohex := ord('0') + data
      else
        nibbletohex :=  ord('A') - 10 + data  ;

  end ; { hextochar }


procedure converttohex(var lownibble, highnibble : byte ; data : byte) ;

begin

  lownibble  := nibbletohex (data mod 16) ;
  highnibble := nibbletohex (data div 16) ;

end ; { converttohex }

procedure convertwordtohex(var int4: Tint4 ; dataword: integer) ;

var
  lownibble, highnibble : byte ;

begin
  lownibble := 0 ;
  highnibble := 0 ;
  dataword := dataword and $FFFF ;
  converttohex(lownibble, highnibble, dataword div 256) ;
  int4[1] := highnibble ;
  int4[2] := lownibble ;
  converttohex(lownibble, highnibble, dataword mod 256) ;
  int4[3] := highnibble ;
  int4[4] := lownibble ;
end ;

procedure writehexbyte(databyte : byte) ;

var
  lownibble, highnibble : byte ;

begin
  lownibble := 0 ;
  highnibble := 0 ;
  converttohex(lownibble,highnibble, databyte) ;
  write(savefile, highnibble) ;
  write(savefile, lownibble) ;
end ;

procedure writehexword(dataword : word) ;

var
  int4 : Tint4 ;
  i    : integer ;

begin
  int4[1] := 0 ;
  convertwordtohex(int4, dataword) ;
  for i := 1 to 4 do
     write(savefile,int4[i]) ;
end ;


procedure WriteCRLF ;

begin
  {$IFDEF UNIX}
  write(savefile, $0A) ;
  {$ENDIF}
  {$IFDEF Windows}
  write(savefile, $0D, $0A) ;
  {$ENDIF}
end ;

procedure SaveKIMtape(tapeID: byte) ;
var
  buffercnt : integer ;
  kimtapename : string ;
  startaddress,
  endaddress,
  checksum,
  cnt        : integer ;
  mbyte      : byte ;

begin
  saved := true ;
  for buffercnt := 1 to buffers_inuse do
    begin
      if buffers_inuse = 1
        then
          kimtapename  := SaveFilePath + FullSaveFilename
        else
          kimtapename :=  SaveFilePath +
                          SaveFileName +
                          inttohex(bufferparts[buffercnt].bufferstart,4) +
                          SaveFileExtension ;
      { open bin save file }
      OpenSaveFile(kimtapename) ;
      if SaveFileOpen
        then
          begin
            startaddress := bufferparts[buffercnt].bufferstart ;
            endaddress := bufferparts[buffercnt].bufferend ;
            checksum := 0 ;
            write(savefile, $2A) ;
            write(savefile, tapeID) ;
            inc(tapeID) ;
            checksum := checksum
                        + startaddress mod 256 + startaddress div 256
                        + endaddress mod 256 + endaddress div 256 ;
            write(savefile, startaddress mod 256) ;
            write(savefile, startaddress div 256) ;
            write(savefile, endaddress mod 256) ;
            write(savefile, endaddress div 256) ;
            for cnt := startaddress to endaddress do
              begin
                mbyte := buffer[cnt] ;
                write(savefile, mbyte) ;
                checksum := checksum + mbyte ;
              end ;
            write(savefile, $2F) ;
            { checksum low, high }
            checksum := checksum and $FFFF ;
            write(savefile, checksum mod 256 ) ;
            write(savefile, checksum div 256 ) ;
            { end of tape character }
            for cnt := 1 to 4 do
              write(savefile, $04) ;
          end
        else
          begin
            saved := false ;
            exitreason := 'Error writing KIM tape file ' + kimtapename ;
            exit
          end ;
   end ;
end;

procedure WriteBinaryfile(DoPRGheader : boolean) ;

var
  cnt : integer ;
  buffercnt : integer ;
  binname : string ;

begin
  {write out all buffer parts as separate files }
  saved := true ;
  for buffercnt := 1 to buffers_inuse do
     begin
       if buffers_inuse = 1
         then
           binname  := SaveFilePath + FullSaveFilename
         else
           binname :=  SaveFilePath +
                       SaveFileName +
                       inttohex(bufferparts[buffercnt].bufferstart,4) +
                       SaveFileExtension ;
       { open bin save file }
       OpenSaveFile(binname) ;
       if SaveFileOpen
         then
           begin
             if DoPRGHeader
               then
                 begin
                   { write startadress high byte and low byte }
                   write(savefile, bufferparts[buffercnt].bufferstart mod 256) ;
                   write(savefile, bufferparts[buffercnt].bufferstart div 256) ;
                 end;
             for cnt :=  bufferparts[buffercnt].bufferstart to bufferparts[buffercnt].bufferend do
               write(savefile, buffer[cnt])
           end
         else
           begin
             saved := false ;
             exitreason := 'Error writing bin file ' + binname ;
             exit
           end ;
     end ;
end ;

procedure saveBINfile ;
begin
  WriteBinaryFile(false) ;
end ;

procedure SavePRGfile ;
{ a PRG file is a BIN file with start adress a first two bytes, low, high }
begin
  WriteBinaryFile(true) ;
end ;


procedure savehexfile ;

const
  maxonline = 32 ;

var
  cnt : integer ;
  buffercnt : integer ;
  hexname : string ;
  online  : integer ;

begin
  for buffercnt := 1 to buffers_inuse do
     begin
       if buffers_inuse = 1
         then
           hexname := SaveFilePath + FullSaveFilename
         else
           hexname :=  SaveFilePath +
                       SaveFileName +
                       inttohex(bufferparts[buffercnt].bufferstart,4) +
                       SaveFileExtension ;
       { open bin save file }
       OpenSaveFile(hexname) ;
       if SaveFileOpen
         then
           begin
             online := 0 ;
             for cnt :=  bufferparts[buffercnt].bufferstart to
                         bufferparts[buffercnt].bufferend do
               begin
                  writehexbyte(buffer[cnt]) ;
                  online := online + 1 ;
                  if (online mod maxonline = 0)
                    then
                      begin
                        writeCRLF ;
                        online := 0 ;
                      end ;
                end
           end
         else
           begin
             saved := false ;
             exitreason := 'Error writing hex file ' + hexname ;
             exit
           end ;
       WriteCRLF ;

       saved := true ;
     end ;
end;


procedure saveIntelhexfile ;

var

    checksum : integer ;

procedure WriteIntelHexBufferpart(part : integer) ;

const
  NrdatabytesOnline = 32 ;

var
  recordaddress,
  totallines,
  inlinecnt,
  totalinline,
  binsize,
  checksum,
  buffercnt   : integer ;
  databyte,
  bchecksum : byte ;


begin
{ buffer is 0 based, so size of buffer is +1 }
 binsize    := bufferparts[part].bufferend - bufferparts[part].bufferstart + 1 ;
 totallines := 0 ;
 buffercnt  := bufferparts[part].bufferstart ;
 recordaddress := bufferparts[part].bufferstart ;
 { dump lines of NrdatabytesOnline bytes }
 totalinline := NrdatabytesOnline ;
 { loop all data records }
 { countdown binsize in records of totalinline size }
 while binsize > 0 do
   begin
     inc(totallines) ;
     checksum := 0 ;
     { determine nr of bytes in this line to convert, last may be smaller }
       inlinecnt := 0 ;
       if binsize > (NrdatabytesOnline - 1) { check if the last line is there }
         then
           begin
             binsize := binsize - NrdatabytesOnline ;
             totalinline := NrdatabytesOnline ;
           end
         else  { last line }
           begin
             totalinline := binsize ;
             binsize := 0 ;
           end ;
     { record mark }
      write(savefile, ord(':')) ;
       { write recordlenth = databytes in current record }
      writehexbyte(totalinline) ;
      checksum := checksum + totalinline ;
       { write current record address }
      writehexword(recordaddress) ;
      checksum := checksum
                   + (recordaddress mod 256)
                   + (recordaddress div 256) ;
      recordaddress := recordaddress + totalinline ;
       { write the record type }
      write(savefile, ord('0')) ;
      write(savefile, ord('0')) ;
       { now write the databytes in this line }
      for inlinecnt := 1 to totalinline do
        begin
          databyte := buffer[buffercnt] ;
          inc(buffercnt) ;
          checksum := checksum + databyte ;
          writehexbyte(databyte) ;
        end ;
      {write checksum }
     bchecksum := checksum and $FF ;
     bchecksum := $100 - bchecksum ;
     writehexbyte(bchecksum) ;
      { end of line }
     writeCRLF ;
   end;
end ;

procedure WriteTotalLineRecord ;

begin
  { finish with total line record }
  checksum := 0 ;
  write(savefile,ord(':') );
  write(savefile,ord('0')) ;
  write(savefile,ord('0')) ;
  { write dummy start address }
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  { write the record type }
  write(savefile, ord('0')) ;
  write(savefile, ord('1')) ;
  checksum := checksum + 1 ;
  {write checksum }
  write(savefile, ord('F')) ;
  write(savefile, ord('F')) ;
  writeCRLF ;
end ;

begin
 OpenSaveFile(SaveFilePath + FullSaveFileName) ;
 if SaveFileOpen
   then
     begin
       for buffercnt :=  1 to buffers_inuse do
         WriteIntelHexBufferpart(buffercnt) ;
       WriteTotalLineRecord ;
       saved := true ;
     end
   else
     begin
       saved := false ;
       exitreason := 'Error writing to Intel hex file ' + FullSaveFileName ;
       exit
      end ;
 if SavefileOpen
   then
     begin
       CloseFile(SaveFile) ;
       SaveFileOpen  := false ;
     end ;
end ;


procedure saveMOSpapertape ;


const
  NrdatabytesOnline = 24 ;

var
  recordaddress,
  totallines,
  inlinecnt,
  totalinline,
  binsize,
  checksum,
  currentbuf,
  buffercnt    : integer ;
  databyte : byte ;

begin
  saved := false ;
  OpenSaveFile(SaveFilePath + FullSaveFilename ) ;
  if not SaveFileOpen
    then
      begin
        exitreason := 'Error writing to MOS papertape file ' + FullSaveFileName ;
        exit
      end ;
  totallines := 0 ;
  { dump lines of NrdatabytesOnline bytes }
  totalinline := NrdatabytesOnline ;
  { loop all buffer parts }
  for currentbuf := 1 to buffers_inuse do
    begin
      { loop all data records }
      { countdown binsize in records of totalinline size }
      binsize    := bufferparts[currentbuf].bufferend
                    - bufferparts[currentbuf].bufferstart + 1;
      recordaddress := bufferparts[currentbuf].bufferstart ;
      buffercnt  := bufferparts[currentbuf].bufferstart;
       while binsize > 0 do
        begin
          inc(totallines) ;
          checksum := 0 ;
          { determine nr of bytes in this line to convert, last may be smaller }
           inlinecnt := 0 ;
          if binsize > (NrdatabytesOnline - 1)  { check if the last line is there }
            then
              begin
                binsize := binsize - NrdatabytesOnline ;
                totalinline := NrdatabytesOnline ;
              end
          else  { last line }
            begin
              totalinline := binsize ;
              binsize := 0 ;
            end ;
          { start of record }
           write(savefile, ord(';')) ;
          { write databytes in current record }
          writehexbyte(totalinline) ;
          checksum := checksum + totalinline ;
          { write current record address }
          writehexword(recordaddress) ;
          checksum := checksum
                   + (recordaddress mod 256)
                   + (recordaddress div 256) ;
           recordaddress := recordaddress + totalinline ;
          { now write the databytes in this line }
          for inlinecnt := 1 to totalinline do
            begin
              databyte := buffer[buffercnt] ;
              inc(buffercnt) ;
              checksum := checksum + databyte ;
              writehexbyte(databyte) ;
            end ;
          {write checksum }
          checksum := checksum and $FFFF ;
          writehexword(checksum) ;
          { end of line }
          writeCRLF ;
        end;
    end;
  checksum := 0 ;
  { now finish with total line record }
  write(savefile,ord(';') );
  write(savefile,ord('0')) ;
  write(savefile,ord('0')) ;
  { convert totallinecount to hex }
  writehexword(totallines) ;
  { checksum }
  checksum := checksum
                   + (totallines mod 256)
                   + (totallines div 256) ;
  writehexword(checksum) ;
  writeCRLF ;
  saved := true  ;
  CloseFile(SaveFile) ;
  SaveFileOpen  := false;


end ;


procedure saveTIMpapertape ;


const
  NrdatabytesOnline = 24 ;

var
  recordaddress,
  totallines,
  inlinecnt,
  totalinline,
  binsize,
  checksum,
  currentbuf,
  buffercnt    : integer ;
  databyte : byte ;

begin
  saved := false ;
  OpenSaveFile(SaveFilePath + FullSaveFilename ) ;
  if not SaveFileOpen
    then
      begin
        exitreason := 'Error writing to TIM papertape file ' + FullSaveFileName ;
        exit
      end ;
  totallines := 0 ;
  { dump lines of NrdatabytesOnline bytes }
  totalinline := NrdatabytesOnline ;
  for currentbuf := 1 to buffers_inuse do
    begin
      { loop all data records }
      { countdown binsize in records of totalinline size }
      binsize    := bufferparts[currentbuf].bufferend
                    - bufferparts[currentbuf].bufferstart + 1;
      recordaddress := bufferparts[currentbuf].bufferstart ;
      buffercnt  := bufferparts[currentbuf].bufferstart;
       while binsize > 0 do
        begin
          inc(totallines) ;
          checksum := 0 ;
          { determine nr of bytes in this line to convert, last may be smaller }
           inlinecnt := 0 ;
          if binsize > (NrdatabytesOnline - 1)  { check if the last line is there }
            then
              begin
                binsize := binsize - NrdatabytesOnline ;
                totalinline := NrdatabytesOnline ;
              end
          else  { last line }
            begin
              totalinline := binsize ;
              binsize := 0 ;
            end ;
          { start of record }
           write(savefile, ord(';')) ;
          { write databytes in current record }
          writehexbyte(totalinline) ;
          checksum := checksum + totalinline ;
          { write current record address }
          writehexword(recordaddress) ;
          checksum := checksum
                   + (recordaddress mod 256)
                   + (recordaddress div 256) ;
           recordaddress := recordaddress + totalinline ;
          { now write the databytes in this line }
          for inlinecnt := 1 to totalinline do
            begin
              databyte := buffer[buffercnt] ;
              inc(buffercnt) ;
              checksum := checksum + databyte ;
              writehexbyte(databyte) ;
            end ;
          {write checksum }
          checksum := checksum and $FFFF ;
          writehexword(checksum) ;
          { end of line }
          writeCRLF ;
        end;
    end;
  writeCRLF ;
  saved := true  ;
  CloseFile(SaveFile) ;
  SaveFileOpen  := false;

end ;


procedure saveMotorolaSrec ;


{
header S0  count[2] 0000 module name[20] ver[2] rev[2] description checksum[1]
       S0   06      0000 HDR 48 44 52  checksum (1B)
S1 count[2] load address[4] databytes[0..64] checksum[1]
S5
S7

count    = total length afer S1
checksum = the least significant byte of the ones
complement of the sum of the byte values represented by the pairs of characters
making up the count, the address, and the data fields

}

const
  NrdatabytesOnline = $10 ;

var
  recordaddress,
  totallines,
  inlinecnt,
  totalinline,
  binsize,
  checksum,
  currentbuf,
  buffercnt    : integer ;
  databyte,
  bchecksum : byte ;

begin
  saved := false ;
  OpenSaveFile(SaveFilePath + FullSaveFilename ) ;
  if not SaveFileOpen
    then
      begin
        exitreason := 'Error writing to S-record file ' + FullSaveFileName ;
        exit
      end ;
  totallines := 0 ;
  { write header }
  write(savefile, ord('S')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('6')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('0')) ;
  write(savefile, ord('4')) ; { HDR }
  write(savefile, ord('8')) ;
  write(savefile, ord('4')) ;
  write(savefile, ord('4')) ;
  write(savefile, ord('5')) ;
  write(savefile, ord('2')) ;
  write(savefile, ord('1')) ;
  write(savefile, ord('B')) ;
  writeCRLF ;
  { dump lines of NrdatabytesOnline bytes }
  totalinline := NrdatabytesOnline ;
  { loop all bufferparts }
  for currentbuf := 1 to buffers_inuse do
    begin
      binsize    := bufferparts[currentbuf].bufferend - bufferparts[currentbuf].bufferstart + 1 ;
      recordaddress := bufferparts[currentbuf].bufferstart ;
      buffercnt  := bufferparts[currentbuf].bufferstart;
      { loop all data records }
      { countdown binsize in records of totalinline size }
      while binsize > 0 do
        begin
          inc(totallines) ;
          checksum := 0 ;
          { determine nr of bytes in this line to convert, last may be smaller }
          inlinecnt := 0 ;
          if binsize > (NrdatabytesOnline - 1)  { check if the last line is there}
            then
              begin
                binsize := binsize - NrdatabytesOnline ;
                totalinline := NrdatabytesOnline ;
              end
            else  { last line }
              begin
                totalinline := binsize ;
                binsize := 0 ;
              end ;
          { record mark }
          write(savefile, ord('S')) ;
          write(savefile, ord('1')) ;
         { write recordlength = databytes in current record + 3 for
           overhead addres = 2 checksum 1 }
         writehexbyte(totalinline + 3) ;
         checksum := checksum + totalinline + 3 ;
          { write current record address }
         writehexword(recordaddress) ;
         checksum := checksum
                    + (recordaddress mod 256)
                    + (recordaddress div 256) ;
         recordaddress := recordaddress + totalinline ;
         { now write the databytes in this line }
         for inlinecnt := 1 to totalinline do
           begin
             databyte := buffer[buffercnt] ;
             inc(buffercnt) ;
             checksum := checksum + databyte ;
             writehexbyte(databyte) ;
           end ;
         {write checksum }
          bchecksum := checksum and $FF ;
          bchecksum := $FF - bchecksum ;
          writehexbyte(bchecksum) ;
          { end of line }
          writeCRLF ;
        end;
     end ;

  { write nr of lines S5 record }
  checksum := 0 ;
  write(savefile,ord('S') );
  write(savefile,ord('5')) ;
  write(savefile,ord('0')) ;
  write(savefile,ord('3')) ;
  { total lines }
  writehexword(totallines) ;
  checksum := checksum + 3 +
              + (totallines mod 256)
              + (totallines div 256) ;
  { write checksum }
  bchecksum := checksum and $FF ;
  bchecksum := $FF - bchecksum ;
  writehexbyte(bchecksum) ;
  writeCRLF ;

  { now finish with end of file reord S9  }
  checksum := 0 ;
  write(savefile,ord('S') );
  write(savefile,ord('9')) ;
  write(savefile,ord('0')) ;
  write(savefile,ord('3')) ;
  { convert totallinecount to hex }
  writehexword(startaddress) ;
  checksum := checksum + 3
              + (startaddress mod 256)
              + (startaddress div 256) ;

  {write checksum }
  bchecksum := checksum and $FF ;
  bchecksum := $FF- bchecksum ;
  writehexbyte(bchecksum) ;
  writeCRLF ;
  saved := true ;
  CloseFile(SaveFile) ;
  SaveFileOpen  := false;
end ;

procedure saveApple1Hex ;

const
  maxonline = 16 ;

var
  cnt : integer ;
  buffercnt : integer ;
  hexname : string ;
  online  : integer ;

procedure writeaddress(addr : integer) ;

var
  i : integer ;
  addrstr : string ;

begin
  online := 0 ;
  addrstr := inttohex(addr,4) + ':';
  for i := 1 to 5 do
    write(savefile, ord(addrstr[i])) ;
end ;

begin
  saved := false ;
  online := 0 ;
  for buffercnt := 1 to buffers_inuse do
     begin
       if buffers_inuse = 1
         then
           hexname := SaveFilePath + FullSaveFilename
         else
           hexname :=  SaveFilePath +
                       SaveFileName +
                       inttohex(bufferparts[buffercnt].bufferstart,4) +
                       SaveFileExtension ;
       { open bin save file }
       OpenSaveFile(hexname) ;
       if SaveFileOpen
         then
           begin
             writeaddress(bufferparts[buffercnt].bufferstart) ;
             for cnt :=  bufferparts[buffercnt].bufferstart to bufferparts[buffercnt].bufferend do
               begin
                  write(savefile, ord(' ')) ;
                  writehexbyte(buffer[cnt]) ;
                  online := online + 1 ;
                  if (online mod maxonline = 0) and (cnt < bufferparts[buffercnt].bufferend)
                    then
                      begin
                        write(savefile, ord(' ')) ;
                        write(savefile, ord(CR));
                        write(savefile, ord(LF));
                        writeaddress(cnt + 1) ;
                      end ;
                end
           end
         else
           begin
             saved := false ;
             exitreason := 'Error writing hex file ' + hexname ;
             exit
           end ;
       WriteCRLF ;
       CloseFile(SaveFile) ;
       SaveFileOpen := false ;
       saved := true ;
     end ;
end;

procedure saveDefineType(definestring : string) ;

var
  definename : string ;
  cnt    : integer ;
  defcnt : integer ;

begin
  saved := false ;
  definename := SaveFilePath + FullSaveFilename ;
  OpenSaveFile(definename) ;
  if SaveFileOpen
    then
      begin
        write(savefile,ord(';') );
        write(savefile,ord(' ') );
        writehexword(startaddress) ;
        write(savefile,ord('-') );
        writehexword(endaddress) ;
        WriteCRLF ;
        for cnt :=  bufferparts[1].bufferstart to bufferparts[1].bufferend do
          begin
           for defcnt := 1 to 8 do
             write(savefile,ord(' ') );
           for defcnt := 1 to length(definestring) do
             write(savefile,ord(definestring[defcnt]) );
           writehexbyte(buffer[cnt]) ;
            WriteCRLF ;
          end;
        CloseFile(SaveFile) ;
        SaveFileOpen := false ;
        saved := true
      end
    else
      begin
        saved := false ;
        exitreason := 'Error writing hex file ' + definename ;
        exit
      end ;
end;

end.

