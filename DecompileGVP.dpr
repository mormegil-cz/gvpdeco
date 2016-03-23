// Copyright (C) 2002, Petr Kadlec <mormegil@centrum.cz>
//
// --------------------------- cesky -----------------------------
//
// Pro informace o autorskych prave viz soubor gnu_licence_cz.txt, ktery
// je soucasti distribuce tohoto programu.
//
// Tento program je volne programove vybaveni; muzete jej sirit a modifikovat
// podle ustanoveni Obecne verejne licence GNU pro Ceskou republiku, vydavane
// Free Software Foundation a obcanským sdruzením zastudena.cz a to bud verze
// 2.CZE teto licence anebo (podle vaseho uvazeni) kterekoli pozdejsi verze.
//
// Tento program je rozsirovan v nadeji, ze bude uzitecny, avsak BEZ JAKEKOLI
// ZARUKY; neposkytuji se ani odvozene zaruky PRODEJNOSTI anebo VHODNOSTI PRO
// URCITY UCEL. Dalsi podrobnosti hledejte v Obecne verejne licenci GNU pro
// Ceskou republiku.
//
// Kopii Obecne verejne licence GNU pro Ceskou republiku jste mel obdrzet spolu
// s timto programem; pokud se tak nestalo, ziskáte ji na www.zastudena.cz.
//
// ------------------------- english -----------------------------
//
// For copyright information, see the file gnu_license.txt included
// with this source code distribution.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

program DecompileGVP;
{$APPTYPE CONSOLE}
uses
  Windows,
  CommDlg,
  Classes,
  SysUtils,
  CmdLine;

{
  Restrictions, bugs, etc:
     * All voices always share the phrases file, and only the first voice's message is used. (The messages from the rest of voices are ignored.)
       It is assumed they have all the same phrases.
     * Similarily, when the first voice does have a sound attached, it is assumed all other do have a sound as well.
     * The phrase is always quoted in the phrase file, although it is not always required.
}

{$R *.RES}

type
  THeader = packed record      // GVP file header structure
                       Magic:      array[0..3] of Char;
                       Version1,
                       Version2:   Cardinal;
                       TitleSize1: Cardinal;
                       TitleOffs1: Cardinal;
                       TitleSize2: Cardinal;
                       TitleOffs2: Cardinal;
                       VarCount:   Cardinal;   
                       VarSize:    Cardinal;
                       VarOffs:    Cardinal;
                       IdCount:    Cardinal;
                       CatRelOffs: Cardinal;
                       IdentOffs:  Cardinal;
                       VoiceCount: Cardinal;
                       IndexCount: Cardinal;
                       IndexSize:  Cardinal;
                       IndexOffs:  Cardinal;
                       PhraseCount:Cardinal;
                       PhraseSize: Cardinal;
                       PhraseOffs: Cardinal;
                       WavCount:   Cardinal;
                       WavSize:    Cardinal;
                       WavOffs:    Cardinal;
                       VoiceSize:  Cardinal;
                       VoiceOffs:  Cardinal;
  end;
  PHeader = ^THeader;
  EInvalidFormat = class(Exception);
  PCardinal = ^Cardinal;

  TSound = record
                 IdNum:        Cardinal;
                 Category:     PWideChar;
                 ID:           PWideChar;
                 Phrase:       PWideChar;
                 Variation:    Byte;
                 HasVariation: Boolean;
                 HasSound:     Boolean;
           end;

  TVoice = record
                 Title: string;
                 Ident: string;
           end;

// configurable by command line
var WAVDirName: string = 'WAV';
    OutputDir:  string = 'Output';
    DontExtractWaves: Boolean = False;
    DontOverwrite:    Boolean = False;

// Get length of Unicode zero-terminated string, including the termination #0
function UnicodeLen(Str: Pointer): Cardinal; assembler; register;
// --> EAX = Str
// <-- EAX = length
asm
   PUSH EDI
   MOV  EDI, Str
   XOR  ECX, ECX
   DEC  ECX
   XOR  EAX, EAX
   CLD
   REPNE SCASW
   NEG  ECX
   DEC  ECX
   XCHG EAX, ECX
   POP  EDI
end;

procedure ProgressDisplay;
const Position: Integer = 0;
      DisplayChars: array[0..3] of char = '|/-\';
begin
     Write(DisplayChars[Position], #8);
     Position := (Position + 1) and 3;
end;

procedure ProgressPercent(Percent: Single);
begin
     Write(Percent:5:1,'%', #8#8#8#8#8#8);
end;

// create voicepack identifier
function GetVoicepackIdent(FName: string): string;
const
  UniqueNum: Integer = 0;
var I: Integer;
begin
     Result := ExtractFileName(FName);
     I := Pos('.', Result);
     if I <> 0 then
        Delete(Result, I, Length(Result) - I + 1);
     for I:=1 to Length(Result) do
     begin
          if not (Result[I] in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) then
          begin
               Inc(UniqueNum);
               Result := 'Voicepack' + IntToStr(UniqueNum);
               Exit;
          end;
     end;
end;

// create voice identifier
function GetVoiceIdent(Voice: string): string;
const UniqueVoiceNum: Integer = 0;
var I: Integer;
begin
     Result := ExtractFileName(Voice);
     I := Pos('.', Result);
     if I <> 0 then
        Delete(Result, I, Length(Result) - I + 1);
     for I:=1 to Length(Result) do
     begin
          if not (Result[I] in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) then
          begin
               if UniqueVoiceNum <= 26 then
                  Result := 'Pilot' + Char(UniqueVoiceNum + Byte('A'))
               else
                  Result := 'Pilot' + IntToStr(UniqueVoiceNum - 26);

               Inc(UniqueVoiceNum);
               Exit;
          end;
     end;
end;

// create sound filename from the sound identifier
function GetSoundFName(SoundID: WideString; HasVariation: Boolean; Variation: Byte): WideString;
var I: Integer;
    C: WideChar;
begin
     Result := SoundID;
     for I:=1 to Length(Result) do
     begin
          C := Result[I];
          if not (((C >= '0') and (C <= '9')) or
                  ((C >= 'A') and (C <= 'Z')) or
                  ((C >= 'a') and (C <= 'z'))) then Result[I] := '_';
     end;

     if HasVariation then
        Result := Result + IntToStr(Variation);

     Result := WAVDirName + '\' + Result + '.WAV';
end;

var F:        TFileStream = nil;
    WAV:      TFileStream = nil;
    TXT:      TFileStream = nil;
    XML:      TextFile;
    Mapping:  THandle     = 0;
    Head:     PHeader     = nil;
    FileBase: Cardinal    = 0;

    SrcFName: string = '';
    XMLFName: string = '';
    TXTFName: string = '';

    Voices:   array of TVoice = nil;
    Sounds:   array of TSound = nil;

    FileTitle: AnsiString;

    Start:    TDateTime;

procedure ShowHelp;
begin
     Writeln('Usage: ', ExtractFileName(ParamStr(0)), ' [-o directory] [-f directory] [-n] [-w]');
     Writeln('          [srcfile[.gvp] [configfile[.xml] [phrasefile[.txt]]]]');
     Writeln;
     Writeln('Options:');
     Writeln('   -o directory   "Output" directory used in the XML config file');
     Writeln('   -f directory   Directory for the wave files');
     Writeln('   -n             Do not extract wave files');
     Writeln('   -w             Do not overwrite existing wave files');
     Halt(2);
end;

procedure ShowLicense;
begin
     Writeln('For copyright information, see the file gnu_license.txt included');
     Writeln('with this source code distribution.');
     Writeln;
     Writeln('This program is free software; you can redistribute it and/or modify');
     Writeln('it under the terms of the GNU General Public License as published by');
     Writeln('the Free Software Foundation; either version 2 of the License, or');
     Writeln('(at your option) any later version.');
     Writeln;
     Writeln('This program is distributed in the hope that it will be useful,');
     Writeln('but WITHOUT ANY WARRANTY; without even the implied warranty of');
     Writeln('MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the');
     Writeln('GNU General Public License for more details.');
     Writeln;
     Writeln('You should have received a copy of the GNU General Public License');
     Writeln('along with this program; if not, write to the Free Software');
     Writeln('Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.');

     Halt(0);
end;

procedure ShowLicence;
begin
  Writeln('Pro informace o autorskych prave viz soubor gnu_licence_cz.txt, ktery');
  Writeln('je soucasti distribuce tohoto programu.');
  Writeln;
  Writeln('Tento program je volne programove vybaveni; muzete jej sirit a modifikovat');
  Writeln('podle ustanoveni Obecne verejne licence GNU pro Ceskou republiku, vydavane');
  Writeln('Free Software Foundation a obcanským sdruzením zastudena.cz a to bud verze');
  Writeln('2.CZE teto licence anebo (podle vaseho uvazeni) kterekoli pozdejsi verze.');
  Writeln;
  Writeln('Tento program je rozsirovan v nadeji, ze bude uzitecny, avsak BEZ JAKEKOLI');
  Writeln('ZARUKY; neposkytuji se ani odvozene zaruky PRODEJNOSTI anebo VHODNOSTI PRO');
  Writeln('URCITY UCEL. Dalsi podrobnosti hledejte v Obecne verejne licenci GNU pro');
  Writeln('Ceskou republiku.');
  Writeln;
  Writeln('Kopii Obecne verejne licence GNU pro Ceskou republiku jste mel obdrzet spolu');
  Writeln('s timto programem; pokud se tak nestalo, ziskáte ji na www.zastudena.cz.');

  Halt(0);
end;

const
    BOMMark: Word     = $FEFF;                    // Unicode Byte Order Mark
    TAB:     WideChar = #9;                       // TAB character in Unicode
    CRLF:    array[0..1] of WideChar = (#13,#10); // CR+LF in Unicode
    Quote:   WideChar = '"';                      // Double quote character in Unicode

var I, J:     Integer;
    IdentCnt: Cardinal;
    RIFFSize: Cardinal;

    Str:      string;
    WAVFN:    string;
    WStr:     WideString;

    P: Pointer;

    IdTable:     Pointer;
    SoundsIndex: PCardinal;
    CatIndex:    PCardinal;
    WaveIndex:   PCardinal;

    OpenFile:    TOpenFilename;
    DlgFileName: array[0..MAX_PATH] of Char;

begin
  try
     Writeln('GVPUnpack  v1.1  Copyright (C) 2002 Petr Kadlec <mormegil@centrum.cz>');
     Writeln;

     // Process command line
     CmdLine_RegProc('--license', ShowLicense);
     CmdLine_RegProc('--licence', ShowLicence);
     CmdLine_RegProc('-h', ShowHelp);
     CmdLine_RegProc('-?', ShowHelp);
     CmdLine_RegProc('--help', ShowHelp);

     CmdLine_RegStrOption('-o', OutputDir);
     CmdLine_RegStrOption('-f', WAVDirName);
     CmdLine_RegSwitch('-n', DontExtractWaves);
     CmdLine_RegSwitch('-w', DontOverwrite);

     CmdLine_RegPositional(SrcFName);
     CmdLine_RegPositional(XMLFName);
     CmdLine_RegPositional(TXTFName);

     CmdLine_Parse();

     if SrcFName = '' then
     begin
          DlgFileName[0] := #0;
          FillChar(OpenFile, SizeOf(OpenFile), 0);
          with OpenFile do
          begin
               lStructSize := SizeOf(OpenFile);
               lpstrFilter := 'GVP voicepacks (*.gvp)'#0'*.gvp'#0'All files (*.*)'#0'*.*'#0#0;
               lpstrFile   := @DlgFileName;
               nMaxFile    := SizeOf(DlgFileName);
               lpstrTitle  := 'Select a GVP voicepack to decompile';
               Flags       := OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_LONGNAMES or OFN_NOTESTFILECREATE;
               lpstrDefExt := 'gvp';
          end;
          if not GetOpenFileName(OpenFile) then
          begin
               Writeln('Cancel, exiting...');
               Halt(1);
          end;
          SrcFName := DlgFileName;
     end else if ExtractFileExt(SrcFName)='' then SrcFName := SrcFName + '.gvp';

     if XMLFName = '' then
     begin
          DlgFileName[0] := #0;
          FillChar(OpenFile, SizeOf(OpenFile), 0);
          with OpenFile do
          begin
               lStructSize := SizeOf(OpenFile);
               lpstrFilter := 'XML files (*.xml)'#0'*.xml'#0'All files (*.*)'#0'*.*'#0#0;
               lpstrFile   := @DlgFileName;
               nMaxFile    := SizeOf(DlgFileName);
               lpstrTitle  := 'Select a filename for the created XML project';
               Flags       := OFN_NOREADONLYRETURN or OFN_HIDEREADONLY or OFN_LONGNAMES or OFN_OVERWRITEPROMPT or OFN_PATHMUSTEXIST;
               lpstrDefExt := 'xml';
          end;
          if not GetSaveFileName(OpenFile) then
          begin
               Writeln('Cancel, exiting...');
               Halt(1);
          end;
          XMLFName := DlgFileName;
     end else if ExtractFileExt(XMLFName)='' then XMLFName := XMLFName + '.xml';

     if TXTFName = '' then
     begin
          DlgFileName[0] := #0;
          FillChar(OpenFile, SizeOf(OpenFile), 0);
          with OpenFile do
          begin
               lStructSize := SizeOf(OpenFile);
               lpstrFilter := 'TXT files (*.txt)'#0'*.txt'#0'All files (*.*)'#0'*.*'#0#0;
               lpstrFile   := @DlgFileName;
               nMaxFile    := SizeOf(DlgFileName);
               lpstrTitle  := 'Select a filename for the created TXT phrase file';
               Flags       := OFN_NOREADONLYRETURN or OFN_HIDEREADONLY or OFN_LONGNAMES or OFN_OVERWRITEPROMPT or OFN_PATHMUSTEXIST;
               lpstrDefExt := 'txt';
          end;
          if not GetSaveFileName(OpenFile) then
          begin
               Writeln('Cancel, exiting...');
               Halt(1);
          end;
          TXTFName := DlgFileName;
     end else if ExtractFileExt(TXTFName)='' then TXTFName := TXTFName + '.txt';

     try
       Start := Now();

       // Open the voicepack
       F := TFileStream.Create(SrcFName, fmOpenRead or fmShareDenyWrite);
       Mapping := CreateFileMapping(F.Handle, nil, PAGE_READONLY, 0, 0, nil);
       if Mapping = 0 then RaiseLastWin32Error;
       FileBase := Cardinal(MapViewOfFile(Mapping, FILE_MAP_READ, 0, 0, 0));
       if FileBase = 0 then RaiseLastWin32Error;

       Head := Pointer(FileBase);

       // Read and analyse the voicepack tables/indexes
       Write('Analysing voicepack ... ');

       if Head^.Magic <> 'GVP ' then
          raise EInvalidFormat.Create('Not a GVP file (invalid magic)');

       // - create list of voices
       FileTitle := WideCharToString(PWideChar(Cardinal(FileBase) + Head^.TitleOffs1));
       SetLength(Voices, Head^.VoiceCount);
       P := Pointer(Cardinal(FileBase) + Head^.VoiceOffs);
       for I:=0 to Head^.VoiceCount-1 do
         with Voices[I] do
         begin
            Title := WideCharToString(P);
            Ident := GetVoiceIdent(Title);
            P := Pointer(Cardinal(P) + 2*UnicodeLen(P));
         end;

       // - create list of sounds
       SetLength(Sounds, Head^.IndexCount);

       SoundsIndex := Pointer(Cardinal(FileBase)    + Head^.IndexOffs);
       CatIndex    := Pointer(Cardinal(SoundsIndex) + Head^.IndexCount shl 2);
       WaveIndex   := Pointer(Cardinal(CatIndex)    + Head^.IndexCount shl 2);

       for I:=0 to Head^.IndexCount-1 do
         with Sounds[I] do
         begin
            if I and 31 = 0 then
               ProgressPercent(I/Head^.IndexCount * 100.0);

            IdNum := SoundsIndex^ shr 4;

            IdentCnt := 0;
            IdTable  := Pointer(Cardinal(FileBase) + Head^.IdentOffs);
            while (Cardinal(IdTable^) <> IdNum) do
            begin
                 Inc(PCardinal(IdTable));
                 Inc(PWideChar(IdTable), UnicodeLen(IdTable));
                 Inc(IdentCnt);
                 if IdentCnt >= Head^.IdCount then
                    raise EInvalidFormat.Create('GVP file corrupt (sound identifier not found');
            end;

            Category  := PWideChar(CatIndex^ + FileBase);
            ID        := PWideChar(Cardinal(IdTable) + 4);
            Variation := Byte(SoundsIndex^) and $F;
            if WaveIndex^ = 0 then
               Phrase    := nil
            else
               Phrase    := PWideChar(WaveIndex^ + FileBase);
            HasVariation := Variation <> 0;
            HasSound  := PCardinal(Cardinal(WaveIndex) + 4)^ <> 0;

            Inc(SoundsIndex);
            Inc(CatIndex);
            Inc(WaveIndex, Head^.VoiceCount shl 1);
         end;

       // - find out variations
       Write('      '#8#8#8#8#8#8);
       for I:=0 to Head^.IndexCount-1 do
       begin
            if I and 31 = 0 then
               ProgressDisplay;
            if not Sounds[I].HasVariation then
               for J:=0 to Head^.IndexCount-1 do
                   if (I <> J) and (Sounds[I].ID = Sounds[J].ID) then
                   begin
                        Sounds[I].HasVariation := True;
                        Break;
                   end;
       end;
       Writeln('OK');

       // Create the XML configuration file
       Write('Creating configuration file ... ');
       AssignFile(XML, XMLFName);
       FileMode := 1;
       Rewrite(XML);
       try
         Str := GetVoicepackIdent(SrcFName);
         Writeln(XML, '<Voicepacks>');
         Writeln(XML, '   <', Str, ' OutputPath="\',OutputDir, '">');
         Writeln(XML, '      <Voices>');

         for I := 0 to Length(Voices)-1 do
           with Voices[I] do
             Writeln(XML,
                      '         <', Ident, ' PhrasesFile="\', TXTFName, '" WAVDir="\', Ident, '" Name="', Title, '"/>'
             );

         Writeln(XML, '      </Voices>');
         Writeln(XML, '   </', Str, '>');
         Writeln(XML, '</Voicepacks>');
       finally
         CloseFile(XML);
       end;
       Writeln('OK');

       // Create the TXT phrases file
       Write('Creating phrases file ... ');
       TXT := TFileStream.Create(TXTFName, fmCreate or fmShareExclusive);
       try
         TXT.WriteBuffer(BOMMark, SizeOf(BOMMark));
         for I:=0 to Length(Sounds)-1 do
           with Sounds[I] do
           begin
                TXT.WriteBuffer(Category^, (UnicodeLen(Category)-1) shl 1);
                TXT.WriteBuffer(TAB, SizeOf(TAB));
                TXT.WriteBuffer(ID^, (UnicodeLen(ID)-1) shl 1);
                TXT.WriteBuffer(TAB, SizeOf(TAB));
                WStr := IntToStr(Variation);
                TXT.WriteBuffer(WStr[1], Length(WStr) shl 1);
                TXT.WriteBuffer(TAB, SizeOf(TAB));
                if Phrase <> nil then
                begin
                     TXT.WriteBuffer(Quote, SizeOf(Quote));
                     TXT.WriteBuffer(Phrase^, (UnicodeLen(Phrase)-1) shl 1);
                     TXT.WriteBuffer(Quote, SizeOf(Quote));
                end;
                TXT.WriteBuffer(TAB, SizeOf(TAB));
                if HasSound then
                begin
                     WStr := GetSoundFName(ID, HasVariation, Variation);
                     TXT.WriteBuffer(WStr[1], Length(WStr) shl 1);
                end;
                TXT.WriteBuffer(CRLF, SizeOf(CRLF));
           end;
       finally
         FreeAndNil(TXT);
       end;
       Writeln('OK');

       // Extract waves, if required
       if not DontExtractWaves then
       begin
         Write('Extracting wave files ... ');

         // Create the voices' directories
         for I:=0 to Length(Voices)-1 do
         begin
              Str := Voices[I].Ident;
              if not FileExists(Str+'\NUL') then MkDir(Str);   // FileExists(DirName+'\NUL') === DirExists
              Str := Str + '\' + WAVDirName;
              if not FileExists(Str+'\NUL') then MkDir(Str);
         end;

         try
           WaveIndex := Pointer(FileBase + Head^.IndexOffs + Head^.IndexCount shl 3 + 4);

           for I:=0 to Head^.IndexCount-1 do
           begin
                ProgressPercent(I/Head^.IndexCount*100.0);

                if not Sounds[I].HasSound then
                begin
                     Inc(WaveIndex, Head^.VoiceCount shl 1);
                     Continue;
                end;

                with Sounds[I] do
                     Str := GetSoundFName(ID, HasVariation, Variation);

                for J:=0 to Head^.VoiceCount-1 do
                begin
                     P := Pointer(WaveIndex^ + FileBase);
                     WAVFN := Voices[J].Ident + '\' + Str;
                     if DontOverwrite and FileExists(WAVFN) then
                     begin
                          Writeln;
                          Writeln('File "', WAVFN, '" already exists.');
                          Halt(2);
                     end;
                     WAV := TFileStream.Create(WAVFN, fmCreate or fmShareExclusive);

                     if Cardinal(P^) <> $46464952 then            // "RIFF" magic
                        raise EInvalidFormat.Create('GVP contains a non-RIFF file');
                     RIFFSize := PCardinal(Cardinal(P) + 4)^ + 8; // size of the RIFF file
                     WAV.WriteBuffer(P^, RIFFSize);
                     FreeAndNil(WAV);
                     Inc(WaveIndex, 2);
                end;
           end;
         finally
           FreeAndNil(WAV);
         end;
         Writeln('OK    ');
       end;

       Writeln('GVP file decompiled in ', (86400 * (Now - Start)):0:1, ' s');
     finally
       // close the voicepack
       if FileBase <> 0 then UnmapViewOfFile(Pointer(FileBase));
       if Mapping <> 0 then CloseHandle(Mapping);
       FreeAndNil(F);
     end;
  except
     on E: ECmdLine do
     begin
          ShowHelp;
          Write('Press ENTER...');
          Readln;
          Halt(1);
     end;
     on E: Exception do
     begin
          Writeln;
          Writeln('Error: [', E.ClassName, '] ', E.Message);
          Write('Press ENTER...');
          Readln;
          Halt(3);
     end;
  end;
end.
