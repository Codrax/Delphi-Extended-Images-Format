{***********************************************************}
{                Codruts Imaging Heif image                 }
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

unit Cod.Imaging.Heif;

interface
  uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Math,
  Types, UITypes, Vcl.Graphics, Vcl.Imaging.pngimage,
  Cod.Imaging.Utils,
  Cod.Imaging.Internal.Heif;

  type
    THeifImage = class(TGraphic)
    private
      const PIXEL_SIZE=3;
      const HEIF_CHANNEL=THeifChannel.channel_interleaved;
      var
      FImage: PHeifImage;
      FData: PByte;
      FDataStride: integer;
      FQuality: byte; // the save quality
      FLosslessQuality: boolean;

      {Free mem}
      procedure FreeData;
      procedure FreeImageMemory(AImage: PHeifImage);

      {Utils}
      function GetPixelStart(X, Y: Integer): cardinal;
      function ScanCreateBitmap: TBitMap;
      function ScanCreatePNG: TPNGImage;
      function ArraySize: cardinal;
      // Allocate new image
      procedure ReallocateNew(Width, Height: integer);  // this does NOT free previous existing memory

      {Properties}
      procedure SetQuality(const Value: byte);
      function GetPixels(const X, Y: Integer): TColor;
      procedure SetPixels(const X, Y: Integer; const Value: TColor);
      function GetWebPPixel(const X, Y: Integer): TRGBAPixel;
      procedure SetWebPPixel(const X, Y: Integer; const Value: TRGBAPixel);
      function GetScanline(const Index: Integer): Pointer;

      {Internal}
      class function DoWrite(ctx: PHeifContext; const data: Pointer; size: cardinal; userdata: Pointer): THeifError; static;

    protected
      {Empty}
      function GetEmpty: Boolean; override;

      {Internal assign}
      procedure AssignHeif(Source: THeifImage);

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

      property Handle: PHeifImage read FImage;

      {Save / Load}
      procedure LoadFromStream(Stream: TStream); override;
      procedure SaveToStream(Stream: TStream); override;

      procedure LoadFromFile(const Filename: string); override;
      procedure SaveToFile(const Filename: string); override;

      {Clipboard}
      procedure LoadFromClipboardFormat(AFormat: Word; AData: THandle;
        APalette: HPALETTE); override;
      procedure SaveToClipboardFormat(var AFormat: Word; var AData: THandle;
        var APalette: HPALETTE); override;

      {Save quality level}
      property Quality: byte read FQuality write SetQuality;
      property LosslessQuality: boolean read FLosslessQuality write FLosslessQuality;

      {Access to the png pixels}
      property Pixels[const X, Y: Integer]: TColor read GetPixels write SetPixels;
      property WebPPixels[const X, Y: Integer]: TRGBAPixel read GetWebPPixel write SetWebPPixel;   // no trasparency support

      constructor Create; override;
      constructor CreateBlank(Width, Height: integer);
      destructor Destroy; override;
    end;

implementation

procedure MoveFlipPixels(Source, Dest: PByte; Size: Integer);
var
  Divider: integer;
begin
  Divider := Size div 3;
  for var I := 0 to Divider-1 do begin
    Dest[I*3] := Source[I*3+2];
    Dest[I*3+1] := Source[I*3+1];
    Dest[I*3+2] := Source[I*3];
  end;
end;

{ THeifImage }

function THeifImage.ArraySize: cardinal;
begin
  Result := Height * FDataStride;
end;

procedure THeifImage.Assign(Source: TPersistent);
const
  RGB_SIZE = 3;
  RGBA_SIZE = 4;
var
  Y: integer;
  SrcPtr: PByte;
  DestPtr: PByte;
  BytesPerScanLine: Integer;
begin
  // Load
  if Source is THeifImage then
    AssignHeif(Source as THeifImage)
  else begin
    const Bit = TBitMap.Create;
    try
      // Create
      Bit.Assign(Source);

      // Free previous
      FreeData;

      // Allocate new image
      ReallocateNew(Bit.Width, Bit.Height);

      // Read
      DestPtr := FData;
      BytesPerScanLine := Bit.Width * RGB_SIZE;

      // Pixel format
      case Bit.PixelFormat of
        pf24bit: begin
          // Copy picture lines
          for Y := 0 to Bit.Height - 1 do begin
            SrcPtr := Bit.ScanLine[Y];

            // Copy
            MoveFlipPixels(SrcPtr, DestPtr, BytesPerScanLine);

            // Inc pos
            Inc(DestPtr, BytesPerScanLine);
          end;
        end;
        pf32bit: begin
          Bit.SaveToFile('C:\Users\Codrut\Downloads\what.heif');

          // Copy picture lines
          for Y := 0 to Bit.Height - 1 do begin
            SrcPtr := Bit.ScanLine[Y];

            // Copy
            for var X := 0 to Bit.Width do begin
              DestPtr[X*RGB_SIZE] := SrcPtr[2];
              DestPtr[X*RGB_SIZE+1] := SrcPtr[1];
              DestPtr[X*RGB_SIZE+2] := SrcPtr[0];

              Inc(SrcPtr, RGBA_SIZE);
            end;

            // Inc pos
            Inc(DestPtr, FDataStride);
          end;
        end;

        else raise Exception.Create('Pixel format not supported.');
      end;
    finally
      Bit.Free;
    end;
  end;
end;

procedure THeifImage.AssignTo(Dest: TPersistent);
begin
  if Dest is THeifImage then
    (Dest as THeifImage).AssignHeif( Self )
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

procedure THeifImage.AssignHeif(Source: THeifImage);
begin
  // Free memory
  FreeData;

  if not Source.Empty then begin
    // Read settings
    ReallocateNew(Source.Width, Source.Height);

    // Copy memory
    Move(Source.FData^, FData^, ArraySize);
  end;
end;

constructor THeifImage.Create;
begin
  inherited;
  FImage := nil;
  FData := nil;
  FQuality := DEFAULT_QUALITY;
end;

constructor THeifImage.CreateBlank(Width, Height: integer);
begin
  FreeData;

  ReallocateNew(Width, Height);
end;

destructor THeifImage.Destroy;
begin
  FreeData;

  inherited;
end;

class function THeifImage.DoWrite(ctx: PHeifContext; const data: Pointer; size: cardinal;
  userdata: Pointer): THeifError;
var
  Stream: TStream;
begin
  Stream := TStream(userdata);

  // Write
  try
    Stream.Write(Data^, Size);
  except
    // Success
    Result := THeifError.Create(THeifErrorNum.heif_error_Decoder_plugin_error,
      THeifSuberrorCode.heif_suberror_Unspecified);
    Exit;
  end;

  // Success
  Result := THeifError.Create(THeifErrorNum.heif_error_Ok);
end;

procedure THeifImage.Draw(ACanvas: TCanvas; const Rect: TRect);
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

procedure THeifImage.FreeData;
begin
  if not GetEmpty then
    FreeImageMemory(FImage);

  FData := nil;
  FImage := nil;
end;

procedure THeifImage.FreeImageMemory(AImage: PHeifImage);
begin
  heif_image_release(AImage);
end;

function THeifImage.GetEmpty: Boolean;
begin
  Result := (FImage = nil) and (FData = nil);
end;

function THeifImage.GetHeight: Integer;
begin
  if GetEmpty then
    Exit(0);
  Result := heif_image_get_height(FImage, HEIF_CHANNEL);
end;

function THeifImage.GetPixels(const X, Y: Integer): TColor;
begin
  Result := GetWebPPixel(X, Y).ToColor;
end;

function THeifImage.GetPixelStart(X, Y: Integer): cardinal;
begin
  Result := Y*FDataStride + X*PIXEL_SIZE;
end;

function THeifImage.GetScanline(const Index: Integer): Pointer;
begin
  Result := @FData[GetWidth*Index*PIXEL_SIZE];
end;

function THeifImage.GetWebPPixel(const X, Y: Integer): TRGBAPixel;
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);
  Result := TRGBAPixel.Create(FData[Start], FData[Start+1], FData[Start+2]);
end;

function THeifImage.GetWidth: Integer;
begin
  if GetEmpty then
    Exit(0);
  Result := heif_image_get_width(FImage, HEIF_CHANNEL);
end;

procedure THeifImage.LoadFromClipboardFormat(AFormat: Word; AData: THandle;
  APalette: HPALETTE);
begin
  inherited;
  raise Exception.Create('Not supported.');
end;

procedure THeifImage.LoadFromFile(const Filename: string);
var
  ctx: PHeifContext;
  imageHandle: PHeifImageHandle;
begin
  // Allocate context
  ctx := heif_context_alloc();
  try
    // Make new memory instance
    heif_context_read_from_file(ctx, @AnsiString(Filename)[1], nil).ErrRaise;

    heif_context_get_primary_image_handle(ctx, imageHandle).ErrRaise;
    try
      heif_decode_image(imageHandle, FImage, THeifColorspace.colorspace_RGB, THeifChroma.chroma_interleaved_RGB, nil).ErrRaise;

      FData := heif_image_get_plane(FImage, THeifChannel.channel_interleaved, FDataStride);
    finally
      heif_image_handle_release(imageHandle);
    end;

  finally
    heif_context_free( ctx );
  end;
end;

procedure THeifImage.LoadFromStream(Stream: TStream);
var
  ctx: PHeifContext;
  imageHandle: PHeifImageHandle;
  Buffer: TBytes;
begin
  // Get bytes
  Stream.Position := 0;
  SetLength(Buffer, Stream.Size);
  Stream.ReadBuffer(Buffer, Stream.size);

  // Decode
  try
    // Allocate context
    ctx := heif_context_alloc();
    try
      // Make new memory instance
      heif_context_read_from_memory(ctx, @Buffer[0], Stream.Size, nil);

      heif_context_get_primary_image_handle(ctx, imageHandle).ErrRaise;
      try
        heif_decode_image(imageHandle, FImage, THeifColorspace.colorspace_RGB, THeifChroma.chroma_interleaved_RGB, nil).ErrRaise;

        FData := heif_image_get_plane(FImage, THeifChannel.channel_interleaved, FDataStride);
      finally
        heif_image_handle_release(imageHandle);
      end;

    finally
      heif_context_free( ctx );
    end;
  finally
    SetLength(Buffer, 0);
  end;
end;

procedure THeifImage.ReallocateNew(Width, Height: integer);
begin
  // Create image
  heif_image_create(Width, Height, THeifColorspace.colorspace_RGB, THeifChroma.chroma_interleaved_RGB, FImage).ErrRaise;

  // Create new plane
  heif_image_add_plane(FImage, THeifChannel.channel_interleaved, Width, Height, 24).ErrRaise;

  // Get Interleaved plane
  FData := heif_image_get_plane(FImage, THeifChannel.channel_interleaved, FDataStride);
end;

procedure THeifImage.SaveToClipboardFormat(var AFormat: Word;
  var AData: THandle; var APalette: HPALETTE);
begin
  inherited;
  raise Exception.Create('Not supported.');
end;

procedure THeifImage.SaveToFile(const Filename: string);
var
  ctx: PHeifContext;
  encoder: PHeifEncoder;
begin
  // Save
  ctx := heif_context_alloc();
  try
    heif_context_get_encoder_for_format(ctx, THeifCompressionFormat.compression_HEVC, encoder).ErrRaise;
    try
      heif_encoder_set_lossy_quality(encoder, 85).ErrRaise;

      heif_context_encode_image(ctx, FImage, encoder, nil, nil).ErrRaise;
    finally
      heif_encoder_release(encoder);
    end;

    heif_context_write_to_file(ctx, @AnsiString(Filename)[1]);
  finally
    heif_context_free(ctx);
  end;
end;

procedure THeifImage.SaveToStream(Stream: TStream);
var
  ctx: PHeifContext;
  encoder: PHeifEncoder;
  writer: THeifWriter;
begin
  // Allocate context
  ctx := heif_context_alloc();
  try
    // Create encoder
    heif_context_get_encoder_for_format(ctx, THeifCompressionFormat.compression_HEVC, encoder).ErrRaise;
    try
      if LosslessQuality then
        heif_encoder_set_lossless(encoder, true)
      else
        heif_encoder_set_lossy_quality(encoder, Quality).ErrRaise;

      // Encode
      heif_context_encode_image(ctx, FImage, encoder, nil, nil).ErrRaise;
    finally
      heif_encoder_release(encoder);
    end;

    // Start writing process
    writer.writer_api_version := 1;
    writer.write := DoWrite;
    heif_context_write(ctx, writer, Stream).ErrRaise;
  finally
    heif_context_free( ctx );
  end;
end;

function THeifImage.ScanCreateBitmap: TBitMap;
var
  Y: Integer;
  SrcPtr: PByte;
  DestPtr: PByte;
  BytesPerScanLine: Integer;
begin
  Result := TBitmap.Create;

  Result.PixelFormat := pf24bit;
  Result.Width := Width;
  Result.Height := Height;
  Result.Transparent := false;

  SrcPtr := FData;
  BytesPerScanLine := Width * PIXEL_SIZE;

  const ImageHeight = Height;
  for Y := 0 to ImageHeight - 1 do
  begin
    // Get line start
    DestPtr := Result.ScanLine[Y];

    // Read
    MoveFlipPixels(@SrcPtr^, @DestPtr^, BytesPerScanLine);

    // Next row
    Inc(SrcPtr, FDataStride);  // move by FDataStride, as some other data is contained!!
  end;
end;

function THeifImage.ScanCreatePNG: TPNGImage;
var
  Y: Integer;
  SrcPtr,
  DestPtr: PByte;
  BytesPerSourceLine: integer;
begin
  if (Width = 0) or (Height = 0) then
    Exit( TPNGImage.Create );

  Result := TPNGImage.CreateBlank(COLOR_RGB, 8, Width, Height);
  Result.Transparent := false;

  // Calcualte byte size
  SrcPtr := FData;
  BytesPerSourceLine := Width * PIXEL_SIZE;

  const ImageHeight = Height;
  for Y := 0 to ImageHeight - 1 do
  begin
    DestPtr := Result.ScanLine[Y];

    // Read
    MoveFlipPixels(@SrcPtr^, @DestPtr^, BytesPerSourceLine);

    ///  Since the PNG image is COLOR_RGB, not COLOR_BRGALPHA, the Alpha
    ///  channel does not exist, and so It does not need to be set to 255.
    ///  Also, they are in reverse order, so this function is needed

    // Move
    Inc(SrcPtr, FDataStride);  // move by FDataStride, as some other data is contained!!
  end;
end;

procedure THeifImage.SetHeight(Value: Integer);
var
  PreviousImage: PHeifImage;
  PreviousData: PByte;
  PreviousSize: cardinal;
  DataCopy: cardinal;
begin
  // Prev
  PreviousImage := FImage;
  PreviousData := FData;
  PreviousSize := ArraySize;

  // Allocate new
  ReallocateNew(Width, Value);

  // Transfer data
  DataCopy := Min(PreviousSize, ArraySize);
  Move(PreviousData^, FData^, DataCopy);

  // Free previous
  FreeImageMemory(PreviousImage);
end;

procedure THeifImage.SetPixels(const X, Y: Integer; const Value: TColor);
begin
  SetWebPPixel(X, Y, TRGBAPixel.Create(Value));
end;

procedure THeifImage.SetQuality(const Value: byte);
begin
  FQuality := EnsureRange(Value, 0, 100);
end;

procedure THeifImage.SetWebPPixel(const X, Y: Integer; const Value: TRGBAPixel);
var
  Start: integer;
begin
  Start := GetPixelStart(X, Y);

  FData[Start] := Value.GetR;
  FData[Start+1] := Value.GetG;
  FData[Start+2] := Value.GetB;
end;

procedure THeifImage.SetWidth(Value: Integer);
var
  PreviousImage: PHeifImage;
  PreviousData: PByte;
  PreviousRowByteSize: integer;
  DataCopy: cardinal;
  ImageHeight,
  RowByteSize: integer;
begin
  // Prev
  PreviousImage := FImage;
  PreviousData := FData;
  PreviousRowByteSize := Width*PIXEL_SIZE;

  // Allocate new
  ReallocateNew(Value, Height);

  // Transfer data
  RowByteSize := Width*PIXEL_SIZE;
  DataCopy := Min(PreviousRowByteSize, RowByteSize);
  ImageHeight := Height; // Assign the value here

  for var Y := 0 to ImageHeight - 1 do
    Move(PreviousData[Y*PreviousRowByteSize], FData[Y*RowByteSize], DataCopy);

  // Free previous
  FreeImageMemory(PreviousImage);
end;

initialization
  // Don't register DLL
  if not HeifDLLLoaded then
    Exit;

  {Registers THeifImage to use with TPicture}
  {$IFDEF UseDelphi}{$IFDEF RegisterGraphic}
    TPicture.RegisterFileFormat('heic', 'High Efficiency Image Codec', THeifImage);
    TPicture.RegisterFileFormat('heif', 'High Efficiency Image Format', THeifImage);
  {$ENDIF}{$ENDIF}
finalization
  // Don't unregister DLL
  if not HeifDLLLoaded then
    Exit;

  {$IFDEF UseDelphi}{$IFDEF RegisterGraphic}
    TPicture.UnregisterGraphicClass(THeifImage);
  {$ENDIF}{$ENDIF}
end.
