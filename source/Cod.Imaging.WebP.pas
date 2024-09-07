{***********************************************************}
{                Codruts Imaging WebP image                 }
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

{$DEFINE UseDelphi}              //Disable fat vcl units(perfect for small apps)
{$DEFINE RegisterGraphic}        //Registers TPNGObject to use with TPicture

unit Cod.Imaging.WebP;

interface
  uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Math,
  Types, UITypes, Vcl.Graphics, Vcl.Imaging.pngimage,
  Cod.Imaging.Utils,
  Cod.Imaging.Internal.libwebp,
  Cod.Imaging.Internal.WebPHelpers;

  type
    TWebPImage = class(TGraphic)
    private
      FData: PByte;
      FWidth,
      FHeight: integer;
      FQuality: single; // the save quality
      FChannelNumber: byte;
      FLibMem: boolean;

      {Free mem}
      procedure FreeData;
      procedure FreeByteMemory(Data: PByte; LibraryMemory: boolean);

      {Utils}
      function GetPixelStart(X, Y: Integer): cardinal;
      function ScanCreateBitmap: TBitMap;
      function ScanCreatePNG: TPNGImage;
      function ArraySize: cardinal;
      // Alloce application memory, return new size
      function ReallocateMemory: cardinal; // this does NOT free previous existing memory

      {Properties}
      procedure SetQuality(const Value: single);
      function GetPixels(const X, Y: Integer): TColor;
      procedure SetPixels(const X, Y: Integer; const Value: TColor);
      function GetWebPPixel(const X, Y: Integer): TRGBAPixel;
      procedure SetWebPPixel(const X, Y: Integer; const Value: TRGBAPixel);
      function GetScanline(const Index: Integer): Pointer;

    protected
      {Empty}
      function GetEmpty: Boolean; override;

      {Internal assign}
      procedure AssignWebp(Source: TWebPImage);

      {Draw to canvas}
      procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;

      {Sizing}
      function GetWidth: Integer; override;
      function GetHeight: Integer; override;
      procedure SetHeight(Value: Integer); override;
      procedure SetWidth(Value: Integer); override;

    public
      {Returns a scanline from png}
      property Scanline[const Index: Integer]: Pointer read GetScanline;

      {Assigns from another object}
      procedure Assign(Source: TPersistent); override;
      {Assigns to another object}
      procedure AssignTo(Dest: TPersistent); override;

      {Save / Load}
      procedure LoadFromStream(Stream: TStream); override;
      procedure SaveToStream(Stream: TStream); override;

      {Save quality level}
      property Quality: single read FQuality write SetQuality;

      {Access to the png pixels}
      property Pixels[const X, Y: Integer]: TColor read GetPixels write SetPixels;
      property WebPPixels[const X, Y: Integer]: TRGBAPixel read GetWebPPixel write SetWebPPixel;

      constructor Create; override;
      constructor CreateBlank(Width, Height: integer);
      destructor Destroy; override;
    end;

  function GetLibraryVersion: string;

implementation

function GetLibraryVersion: string;
begin
  Result := GetWebpVersionString(WebPGetEncoderVersion);
end;

{ TWebPImage }

function TWebPImage.ArraySize: cardinal;
begin
  Result := FWidth * FHeight * FChannelNumber;
end;

procedure TWebPImage.Assign(Source: TPersistent);
var
  Y: integer;
  SrcPtr: PByte;
  DestPtr: PByte;
  BytesPerScanLine: Integer;
begin
  // Load
  if Source is TWebPImage then
    AssignWebp(Source as TWebPImage)
  else begin
    const Bit = TBitMap.Create;
    try
      // Create
      Bit.Assign(Source);
      Bit.PixelFormat := pf32bit;
      Bit.Transparent := true;
      Bit.TransparentMode := tmAuto;

      // Allocate
      FreeData;
      FWidth := Bit.Width;
      FHeight := Bit.Height;
      ReallocateMemory;

      // Read
      DestPtr := FData;
      BytesPerScanLine := Bit.Width * 4;

      // Copy picture lines
      for Y := 0 to Bit.Height - 1 do begin
        SrcPtr := Bit.ScanLine[Y];

        Move(SrcPtr^, DestPtr^, BytesPerScanLine); // Copy the entire scanline
        Inc(DestPtr, BytesPerScanLine); // Move to the next scanline in the source data
      end;
    finally
      Bit.Free;
    end;
  end;
end;

procedure TWebPImage.AssignTo(Dest: TPersistent);
begin
  if Dest is TWebPImage then
    (Dest as TWebPImage).AssignWebp( Self )
  else
  if Dest is TPngImage then
    begin
      const PNG = ScanCreatePNG;
      Dest.Assign( PNG );
    end
  else
    begin
      const Bit = ScanCreateBitmap;
      try
        Dest.Assign( Bit );
      finally
        Bit.Free;
      end;
    end;
end;

procedure TWebPImage.AssignWebp(Source: TWebPImage);
var
  MemSize: integer;
begin
  // Free memory
  FreeData;

  if not Source.Empty then begin
    // Read settings
    FWidth := Source.FWidth;
    FHeight := Source.FHeight;
    FChannelNumber := Source.FChannelNumber;
    FQuality := Source.FQuality;

    // Clone memory
    MemSize := Source.ArraySize;
    FData := AllocMem( MemSize );
    Move(Source.FData^, FData^, MemSize);
    FLibMem := false;
  end;
end;

constructor TWebPImage.Create;
begin
  inherited;
  FData := nil;
  FQuality := DEFAULT_QUALITY;
  FChannelNumber := 4; {B G R A}
end;

constructor TWebPImage.CreateBlank(Width, Height: integer);
begin
  // Free
  FreeData;

  // Size
  FWidth := Width;
  FHeight := Height;

  // Allocate
  ReallocateMemory;
end;

destructor TWebPImage.Destroy;
begin
  FreeData;

  inherited;
end;

procedure TWebPImage.Draw(ACanvas: TCanvas; const Rect: TRect);
var
  Cache: TPNGImage;
begin
  if Empty then
    Exit;
  Cache := ScanCreatePNG;
  try
    // Draw buffer
    ACanvas.StretchDraw(Rect, Cache);
  finally
    Cache.Free;
  end;
end;

procedure TWebPImage.FreeByteMemory(Data: PByte; LibraryMemory: boolean);
begin
  if LibraryMemory then
    // Library allocated memory pool, free via calls
    WebPFree(Data)
  else
    // Application memory, free via FreeMem
    FreeMem(Data);
end;

procedure TWebPImage.FreeData;
begin
  if not GetEmpty then
    FreeByteMemory(FData, FLibMem);
  FData := nil;
  FWidth := 0;
  FHeight := 0;
  FLibMem := false;
end;

function TWebPImage.GetEmpty: Boolean;
begin
  Result := FData = nil;
end;

function TWebPImage.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TWebPImage.GetPixels(const X, Y: Integer): TColor;
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);
  Result := RGB(FData[Start+2], FData[Start+1], FData[Start]);
end;

function TWebPImage.GetPixelStart(X, Y: Integer): cardinal;
begin
  Result := (X+FWidth*Y)*FChannelNumber;
end;

function TWebPImage.GetScanline(const Index: Integer): Pointer;
begin
  Result := @FData[FWidth*Index*FChannelNumber];
end;

function TWebPImage.GetWebPPixel(const X, Y: Integer): TRGBAPixel;
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);
  Result := TRGBAPixel.Create(FData[Start+2], FData[Start+1], FData[Start], FData[Start+3]);
end;

function TWebPImage.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TWebPImage.LoadFromStream(Stream: TStream);
var
  Buffer: TBytes;
begin
  // Get bytes
  Stream.Position := 0;
  SetLength(Buffer, Stream.Size);
  Stream.ReadBuffer(Buffer, Stream.size);

  try
    // Decode
    FData := WebPDecodeBGRA(@Buffer[0], Stream.Size, @FWidth, @FHeight);
    FLibMem := true;
  finally
    SetLength(Buffer, 0);
  end;
end;

function TWebPImage.ReallocateMemory: cardinal;
begin
  Result := ArraySize;
  FData := AllocMem(Result);
  FLibMem := false;
end;

procedure TWebPImage.SaveToStream(Stream: TStream);
var
  Output: PByte;
  Size: cardinal;
begin
  Size := WebPEncodeBGRA(FData, FWidth, FHeight, FWidth*FChannelNumber, Quality, Output);

  Stream.Write( Output^, Size );
end;

function TWebPImage.ScanCreateBitmap: TBitMap;
var
  Y: Integer;
  SrcPtr: PByte;
  DestPtr: PByte;
  BytesPerScanLine: Integer;
begin
  Result := TBitmap.Create;

  Result.PixelFormat := pf32bit;
  Result.Width := FWidth;
  Result.Height := FHeight;
  Result.Transparent := true;
  Result.TransparentMode := tmAuto;

  SrcPtr := FData;
  BytesPerScanLine := FWidth * FChannelNumber;

  for Y := 0 to FHeight - 1 do
  begin
    DestPtr := Result.ScanLine[Y]; // Get the pointer to the start of the scanline
    Move(SrcPtr^, DestPtr^, BytesPerScanLine); // Copy the entire scanline
    Inc(SrcPtr, BytesPerScanLine); // Move to the next scanline in the source data
  end;
end;

function TWebPImage.ScanCreatePNG: TPNGImage;
const
  RGB_SIZE = 3;
var
  RGBA_SIZE: integer;
  X, Y: Integer;
  AlphPtr: PByteArray;
  SrcPtr,
  DestPtr,
  Cursor: PByte;
  BytesPerSourceLine: integer;
begin
  // Initialize byte size
  RGBA_SIZE := FChannelNumber;

  // Create
  Result := TPNGImage.CreateBlank(COLOR_RGBALPHA, RGBA_SIZE * 2, FWidth, FHeight);

  // Calcualte byte size
  SrcPtr := FData;
  BytesPerSourceLine := FWidth * RGBA_SIZE;

  for Y := 0 to FHeight - 1 do
  begin
    DestPtr := Result.ScanLine[Y];
    AlphPtr := Result.AlphaScanline[Y];

    // Read
    Cursor := SrcPtr;
    for X := 0 to FWidth-1 do begin
      // Read alpha
      Move(Cursor^, DestPtr^, 3);

      AlphPtr[X] := Cursor[3];

      // Move
      Inc(Cursor, RGBA_SIZE);
      Inc(DestPtr, RGB_SIZE);
    end;

    // Move
    Inc(SrcPtr, BytesPerSourceLine);
  end;
end;

procedure TWebPImage.SetHeight(Value: Integer);
var
  Previous: PByte;
  PreviousSize,
  NewSize: cardinal;
  PreviousLibMem: boolean;
begin
  // Prev
  Previous := FData;
  PreviousSize := ArraySize;
  PreviousLibMem := FLibMem;

  // Set height
  FHeight := Value;

  // Allocate memory
  NewSize := ReallocateMemory;

  // Transfer bytes
  Move(Previous^, FData^, Min(PreviousSize, NewSize));

  // Free previous
  FreeByteMemory(Previous, PreviousLibMem);
end;

procedure TWebPImage.SetPixels(const X, Y: Integer; const Value: TColor);
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);

  FData[Start+3] := 255;

  FData[Start+2] := GetRValue(Value);
  FData[Start+1] := GetGValue(Value);
  FData[Start] := GetBValue(Value);
end;

procedure TWebPImage.SetQuality(const Value: single);
begin
  FQuality := EnsureRange(Value, 0, 100);
end;

procedure TWebPImage.SetWebPPixel(const X, Y: Integer; const Value: TRGBAPixel);
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);

  FData[Start+2] := Value.GetR;
  FData[Start+1] := Value.GetG;
  FData[Start] := Value.GetB;
  FData[Start+3] := Value.GetAlpha;
end;

procedure TWebPImage.SetWidth(Value: Integer);
var
  Previous: PByte;
  PreviousLibMem: boolean;

  PreviousWidth: integer;
begin
  // Prev
  Previous := FData;
  PreviousLibMem := FLibMem;

  PreviousWidth := FWidth;

  // Set height
  FWidth := Value;

  // Allocate memory
  ReallocateMemory;

  // Transfer bytes
  const MemoryRead = Min(PreviousWidth, FWidth) * FChannelNumber;
  for var I := 0 to FHeight-1 do begin
    Move(Previous[I * PreviousWidth * FChannelNumber],
         FData[I * FWidth * FChannelNumber],
         MemoryRead);
  end;

  // Free previous
  FreeByteMemory(Previous, PreviousLibMem);
end;

initialization
  // Don't register DLL
  if not WebPDLLLoaded then
    Exit;

  {Registers THeifImage to use with TPicture}
  {$IFDEF UseDelphi}{$IFDEF RegisterGraphic}
    TPicture.RegisterFileFormat('webp', 'Web Picture', TWebPImage);
  {$ENDIF}{$ENDIF}
finalization
  // Don't unregister DLL
  if not WebPDLLLoaded then
    Exit;

  {$IFDEF UseDelphi}{$IFDEF RegisterGraphic}
    TPicture.UnregisterGraphicClass(TWebPImage);
  {$ENDIF}{$ENDIF}
end.