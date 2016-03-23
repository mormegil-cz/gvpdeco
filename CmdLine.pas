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
unit CmdLine;

{
  General command-line utility library.
}  

interface
uses SysUtils;

procedure CmdLine_RegProc(const Name: string; Proc: TProcedure; const Required: Boolean = False);
procedure CmdLine_RegSwitch(const Name: string; var Value: Boolean; const Required: Boolean = False);
procedure CmdLine_RegToggle(const Name: string; var Value: Boolean; const Required: Boolean = False);
procedure CmdLine_RegIntOption(const Name: string; var Value: Integer; const Required: Boolean = False);
procedure CmdLine_RegFloatOption(const Name: string; var Value: Real; const Required: Boolean = False);
procedure CmdLine_RegStrOption(const Name: string; var Value: string; const Required: Boolean = False);

procedure CmdLine_RegPositional(var Value: string; const Required: Boolean = False);

procedure CmdLine_Parse(const IgnoreCase: Boolean = True);

type ECmdLine = class(Exception);

{ ---------------------------------------------------------------------------- }

implementation

{$TYPEINFO OFF}

resourcestring
  SValueExpected = 'Value expected';

{ ---------------------------------------------------------------------------- }

type TParam = class
                   Required,
                   Used: Boolean;
                   
                   Value: Pointer;
                   function Accepted(var Index: Integer): Boolean; virtual; abstract;
              end;

     TOption = class(TParam)
                    Name: string;
                    function Accepted(var Index: Integer): Boolean; override;
               private
                    procedure DoAccept(var Index: Integer); virtual; abstract;
               end;

     TProcOption = class(TOption)
                   private
                       procedure DoAccept(var Index: Integer); override;
                   end;

     TSwitchOption = class(TOption)
                   private
                       procedure DoAccept(var Index: Integer); override;
                   end;

     TToggleOption = class(TOption)
                   private
                       procedure DoAccept(var Index: Integer); override;
                   end;

     TIntOption = class(TOption)
                  private
                      procedure DoAccept(var Index: Integer); override;
                  end;

     TFltOption = class(TOption)
                  private
                      procedure DoAccept(var Index: Integer); override;
                  end;

     TStrOption = class(TOption)
                  private
                      procedure DoAccept(var Index: Integer); override;
                  end;

     TPositional = class(TParam)
                        function Accepted(var Index: Integer): Boolean; override;
                   end;

{ ---------------------------------------------------------------------------- }

var ParamArray: array of string;
    IgnoreCase: Boolean;

    Params:     array of TParam = nil;
    ParamLen:   Integer = 0;

{ ---------------------------------------------------------------------------- }

{ TOption }

function TOption.Accepted(var Index: Integer): Boolean;
begin
     if IgnoreCase then
        Result := AnsiSameText(ParamArray[Index], Name)
     else
        Result := AnsiSameStr(ParamArray[Index], Name);

     if Result then
     begin
          Used := True;
          Inc(Index);
          DoAccept(Index);
     end;
end;

{ TSwitchOption }

procedure TSwitchOption.DoAccept(var Index: Integer);
begin
     Boolean(Value^) := True;
end;

{ TProcOption }

procedure TProcOption.DoAccept(var Index: Integer);
begin
     TProcedure(Value)();
end;

{ TToggleOption }

procedure TToggleOption.DoAccept(var Index: Integer);
begin
     Boolean(Value^) := not Boolean(Value^);
end;

{ TIntOption }

procedure TIntOption.DoAccept(var Index: Integer);
begin
     if Index >= Length(ParamArray) then raise ECmdLine.Create(SValueExpected);

     Integer(Value^) := StrToInt(ParamArray[Index]);
     Inc(Index);
end;

{ TFltOption }

procedure TFltOption.DoAccept(var Index: Integer);
begin
     if Index >= Length(ParamArray) then raise ECmdLine.Create(SValueExpected);

     Real(Value^) := StrToFloat(ParamArray[Index]);
     Inc(Index);
end;

{ TStrOption }

procedure TStrOption.DoAccept(var Index: Integer);
begin
     if Index >= Length(ParamArray) then raise ECmdLine.Create(SValueExpected);

     string(Value^) := ParamArray[Index];
     Inc(Index);
end;

{ TPositional }

function TPositional.Accepted(var Index: Integer): Boolean;
begin
     if Used then
     begin
          Result := False;
          Exit;
     end;

     string(Value^) := ParamArray[Index];
     Inc(Index);

     Used := True;

     Result := True;
end;

{ ---------------------------------------------------------------------------- }

procedure Add(const P: TParam);
begin
     Assert(Length(Params) >= ParamLen);
     if Length(Params) = ParamLen then SetLength(Params, ParamLen+16);

     Params[ParamLen] := P;
     Inc(ParamLen);
end;

{ ---------------------------------------------------------------------------- }

procedure CmdLine_RegProc(const Name: string; Proc: TProcedure; const Required: Boolean = False);
var P: TProcOption;
begin
     P := TProcOption.Create();
     P.Name := Name;
     P.Value := @Proc;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegSwitch(const Name: string; var Value: Boolean; const Required: Boolean = False);
var P: TSwitchOption;
begin
     P := TSwitchOption.Create();
     P.Name := Name;
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegToggle(const Name: string; var Value: Boolean; const Required: Boolean = False);
var P: TToggleOption;
begin
     P := TToggleOption.Create();
     P.Name := Name;
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegIntOption(const Name: string; var Value: Integer; const Required: Boolean = False);
var P: TIntOption;
begin
     P := TIntOption.Create();
     P.Name := Name;
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegFloatOption(const Name: string; var Value: Real; const Required: Boolean = False);
var P: TFltOption;
begin
     P := TFltOption.Create();
     P.Name := Name;
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegStrOption(const Name: string; var Value: string; const Required: Boolean = False);
var P: TStrOption;
begin
     P := TStrOption.Create();
     P.Name := Name;
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

procedure CmdLine_RegPositional(var Value: string; const Required: Boolean = False);
var P: TPositional;
begin
     P := TPositional.Create();
     P.Value := @Value;
     P.Required := Required;
     Add(P);
end;

{ ---------------------------------------------------------------------------- }

procedure CmdLine_Parse(const IgnoreCase: Boolean = True);
var I, J: Integer;
    Acc:  Boolean;
begin
     CmdLine.IgnoreCase := IgnoreCase;

     SetLength(ParamArray, ParamCount);
     for I := 1 to ParamCount do
         ParamArray[I-1] := ParamStr(I);

     I := 0;
     try
       while I < ParamCount do
       begin
            Acc := False;
            for J := 0 to ParamLen-1 do
                if Params[J].Accepted(I) then
                begin
                     Acc := True;
                     Break;
                end;

            if not Acc then
               raise ECmdLine.Create('Unknown argument');
       end;

       for I:=0 to ParamLen-1 do
           with Params[I] do
                if Required and not Used then
                   raise ECmdLine.Create('Required argument missing');
     except
       on EConvertError do
          raise ECmdLine.Create('Invalid value');
     end;

     for I:=0 to ParamLen-1 do
         Params[I].Free;

     ParamLen := 0;
     Params := nil;
end;

end.
