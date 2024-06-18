{***********************************************************}
{             Codruts Imaging Global Utilities               }
{                                                           }
{                        version 1.0                        }
{                                                           }
{                                                           }
{                                                           }
{         This library is licensed under a MIT license      }
{              Copyright 2024 Codrut Software               }
{                  All rights reserved.                     }
{                                                           }
{***********************************************************}

unit Cod.Imaging.Utils;

interface
  uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Math,
  Types, UITypes, Vcl.Graphics;

  type
    TRGBAPixel = $00000000..$FFFFFFFF;

    // FXColor Helper
    TRGBAPixelHelper = record helper for TRGBAPixel
      class function Create(R, G, B: Byte; A: Byte = 255): TRGBAPixel; overload; static;
      class function Create(AColor: TColor; A: Byte = 255): TRGBAPixel; overload; static;
      class function Create(AString: string): TRGBAPixel; overload; static;

    public
      // Change value
      function GetAlpha: byte;
      function GetR: byte;
      function GetG: byte;
      function GetB: byte;

      procedure SetA(Value: byte);
      procedure SetR(Value: byte);
      procedure SetG(Value: byte);
      procedure SetB(Value: byte);

      // Convert
      function ToColor: TColor;
      function ToString: string;
    end;

const
  DEFAULT_QUALITY = 85;

implementation

{ TRGBAPixel }

class function TRGBAPixelHelper.Create(R, G, B, A: Byte): TRGBAPixel;
begin
  Result := (B or (G shl 8) or (R shl 16) or (A shl 24));
end;

class function TRGBAPixelHelper.Create(AColor: TColor; A: Byte): TRGBAPixel;
begin
  {$R-}
  Result := (GetBValue(AColor) or (GetGValue(AColor) shl 8) or (GetRValue(AColor) shl 16) or (A shl 24));
  {$R+}
end;

class function TRGBAPixelHelper.Create(AString: string): TRGBAPixel;
begin
  if AString[1] = '#' then
    Result := StrToInt('$' + Copy(AString, 2, 8))
  else
    Exit( AString.ToInteger );
end;

function TRGBAPixelHelper.GetAlpha: byte;
begin
  Result := (Self and $FF000000) shr 24;
end;

function TRGBAPixelHelper.GetB: byte;
begin
  Result := (Self and $000000FF);
end;

function TRGBAPixelHelper.GetG: byte;
begin
  Result := (Self and $0000FF00) shr 8;
end;

function TRGBAPixelHelper.GetR: byte;
begin
  Result := (Self and $00FF0000) shr 16;
end;

procedure TRGBAPixelHelper.SetA(Value: byte);
begin
  Self := (Self and $00FFFFFF) or (TRGBAPixel(Value) shl 24);
end;

procedure TRGBAPixelHelper.SetB(Value: byte);
begin
  Self := (Self and $FFFFFF00) or (Value);
end;

procedure TRGBAPixelHelper.SetG(Value: byte);
begin
  Self := (Self and $FFFF00FF) or (TRGBAPixel(Value) shl 8);
end;

procedure TRGBAPixelHelper.SetR(Value: byte);
begin
  Self := (Self and $FF00FFFF) or (TRGBAPixel(Value) shl 16);
end;

function TRGBAPixelHelper.ToColor: TColor;
begin
  Result := RGB(GetR, GetG, GetB);
end;

function TRGBAPixelHelper.ToString: string;
begin
  Result := '#' + IntToHex(Self, 8);
end;

end.