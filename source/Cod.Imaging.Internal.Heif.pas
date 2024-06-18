// Lib HEIF

unit Cod.Imaging.Internal.Heif;

interface

uses
  Windows,
  SysUtils;

  type
    // Types
    THeifItemID = UInt32;
    PHeifItemID = ^THeifItemID;
    THeifPropertyID = UInt32;
    THeifString = PAnsiChar;
    THeifChannel = type integer;
    THeifChroma = type integer;
    THeifColorspace = type integer;
    THeifReadingOptions = type Pointer; // should be set to null for now
    THeifEncodingOptions = type Pointer; // also null
    THeifCompressionFormat = type integer;

    // Helper
    THeifChannelHelper = record helper for THeifChannel
      const
      channel_Y = 0;
      channel_Cb = 1;
      channel_Cr = 2;
      channel_R = 3;
      channel_G = 4;
      channel_B = 5;
      channel_Alpha = 6;
      channel_interleaved = 10;
    end;
    THeifChromaHelper = record helper for THeifChroma
      const
      // SDR
      chroma_444=3;
      chroma_interleaved_RGB =10;
      chroma_interleaved_RGBA=11;
      // HDR
      chroma_interleaved_RRGGBB_BE=12;
      chroma_interleaved_RRGGBBAA_BE=13;
      chroma_interleaved_RRGGBB_LE=14;
      chroma_interleaved_RRGGBBAA_LE=15;
    end;
    THeifColorspaceHelper = record helper for THeifColorspace
      const
      colorspace_undefined=99;
      colorspace_YCbCr=0;
      colorspace_RGB=1;
      colorspace_monochrome=2;
    end;
    THeifCompressionFormatHelper = record helper for THeifCompressionFormat
      const
      // No format selected
      compression_undefined = 0;

      // HEVC used for HEIC images, equivalent to H.256
      compression_HEVC = 1;
      // AVC compression (unused)
      compression_AVC = 2;
      // Joint Photographs Experts Group encoding
      compression_JPEG = 3;
      // Used for AVIF Images
      compression_AV1 = 4;
      // VVC compression (unused)
      compression_VVC = 5;
      // EVC encoding (unused)
      compression_EVC = 6;
      // JPEG 2000 encoding
      compression_JPEG2000 = 7;
      // Uncompressed image encoding
      compression_uncompressed = 8;
      // Mask image encoding (ISO/IEC 23008-12:2022 Section 6.10.2)
      compression_mask = 0;
    end;

    // Error
    THeifErrorNum = (
    // Everything ok, no error occurred
    heif_error_Ok,
    // Input file does not exist.
    heif_error_Input_does_not_exist,
    // Error in input file. Corrupted or invalid content.
    heif_error_Invalid_input,
    // Input file type is not supported.
    heif_error_Unsupported_filetype,
    // Image requires an unsupported decoder feature.
    heif_error_Unsupported_feature,
    // Library API has been used in an invalid way.
    heif_error_Usage_error,
    // Could not allocate enough memory.
    heif_error_Memory_allocation_error,
    // The decoder plugin generated an error
    heif_error_Decoder_plugin_error,
    // The encoder plugin generated an error
    heif_error_Encoder_plugin_error,
    // Error during encoding or when writing to the output
    heif_error_Encoding_error,
    // Application has asked for a color profile type that does not exist
    heif_error_Color_profile_does_not_exist,
    // Error loading a dynamic plugin
    heif_error_Plugin_loading_error);

    heif_filetype_result = (
    heif_filetype_no,
    heif_filetype_yes_supported,   // it is heif and can be read by libheif
    heif_filetype_yes_unsupported, // it is heif, but cannot be read by libheif
    heif_filetype_maybe); // not sure whether it is an heif, try detection with more input data

    THeifError = record
      code: THeifErrorNum;
      subcode: cardinal;

      emessage: THeifString;

      procedure ErrRaise;
    end;

    // Base classes
    THeifContextClass = TObject;
    THeifImageClass = TObject;
    THeifPixelImageClass = TObject;

    // Heif context
    THeifContext = record
      context: THeifContextClass;
    end;
    PHeifContext = ^THeifContext;

    // Heif image
    THeifImage = record
      image: THeifPixelImageClass;
    end;
    PHeifImage = ^THeifImage;

    // Heif image handle
    THeifImageHandle = record
      image: THeifImage;
      context: THeifContext;
    end;
    PHeifImageHandle = ^THeifImageHandle;
    PPHeifImageHandle = ^PHeifImageHandle;

    // Encoder
    PHeifEncoder = Pointer;

    // Procs
    THeifWriteFunc = function(ctx: PHeifContext; const data: Pointer; size: Cardinal; userdata: Pointer): THeifError of object;
    PHeifWriteFunc = ^THeifWriteFunc;

    // Writer
    THeifWriter = record
      writer_api_version: integer;
      write: THeifWriteFunc;
    end;
    PHeifWriter = ^THeifWriter;

  const
    (* DLL Name *)
    HeifDLL = 'libheif.dll';

  // Lib-HEIF Procedures
  //procedure heif_check_filetype; stdcall; external HeifDLL;

var
  (* Context *)
  heif_context_alloc: function: PHeifContext; stdcall;
  heif_context_read_from_file: function (context: PHeifContext; filename: THeifString; const readoptions: THeifReadingOptions): THeifError; stdcall;
  heif_context_write_to_file: function (context: PHeifContext; filename: THeifString): THeifError; stdcall;
  heif_context_read_from_memory: function (context: PHeifContext; mem: PByte; size: cardinal; const readoptions: THeifReadingOptions): THeifError; stdcall;
  heif_context_read_from_memory_without_copy: function (context: PHeifContext; mem: PByte; size: cardinal; const readoptions: THeifReadingOptions): THeifError; stdcall;
  heif_context_write: function (context: PHeifContext; var writer: THeifWriter; userdata: Pointer): THeifError; stdcall;
  heif_context_get_number_of_top_level_images: function (context: PHeifContext): cardinal;
  heif_context_get_primary_image_handle: function (context: PHeifContext; var Handle: PHeifImageHandle): THeifError; stdcall;
  heif_context_get_primary_image_ID: function (context: PHeifContext; var id: THeifItemID): THeifError; stdcall;
  heif_context_set_primary_image: function (context: PHeifContext; Handle: PHeifImageHandle): THeifError; stdcall;
  heif_context_get_encoder_for_format: function (context: PHeifContext; format: THeifCompressionFormat; var Encoder: PHeifEncoder): THeifError;
  heif_context_encode_image: function (context: PHeifContext; image: PHeifImage; Encoder: PHeifEncoder; options: THeifEncodingOptions; out_image_handle: PPHeifImageHandle): THeifError; stdcall;
  heif_context_add_exif_metadata: function (context: PHeifContext; imageHandle: PHeifImageHandle; data: Pointer; size: integer): THeifError; stdcall;
  heif_context_free: function (context: PHeifContext): BOOL; stdcall;

  (* Encoder *)
  heif_encoder_get_name: function (encoder: PHeifEncoder): THeifString; stdcall;
  heif_encoder_set_lossless: function (encoder: PHeifEncoder; enable: bool): THeifString; stdcall;
  // Quality ranges from 0-100
  heif_encoder_set_lossy_quality: function (encoder: PHeifEncoder; quality: integer): THeifError; stdcall;
  heif_encoder_release: function (encoder: PHeifEncoder): THeifString; stdcall;

  (* Heif image handle *)
  heif_image_handle_get_height: function (handle: PHeifImageHandle): integer; stdcall;
  heif_image_handle_get_width: function (handle: PHeifImageHandle): integer; stdcall;
  heif_image_handle_has_alpha_channel: function (handle: PHeifImageHandle): bool; stdcall;
  heif_image_handle_get_thumbnail: function (MainImageHandle: PHeifImageHandle; id: THeifItemID; Handle: PHeifImageHandle): BOOL; stdcall;
  heif_image_handle_get_chroma_bits_per_pixel: function (handle: PHeifImageHandle): integer; stdcall;
  heif_image_handle_release: function (handle: PHeifImageHandle): BOOL; stdcall;

  (* Heif image *)
  heif_image_create: function (width: integer; height: integer; colorspace: THeifColorspace; chroma: THeifChroma; var image: PHeifImage): THeifError; stdcall;
  heif_decode_image: function (in_handle: PHeifImageHandle; var out_img: PHeifImage; colorspace: THeifColorspace; chroma: THeifChroma; other: pointer): THeifError; stdcall;
  heif_image_get_width: function (image: PHeifImage; channel: THeifChannel): integer; stdcall;
  heif_image_get_height: function (image: PHeifImage; channel: THeifChannel): integer; stdcall;
  heif_image_get_plane: function (image: PHeifImage; channel: THeifChannel; var stride: Integer): PByte; stdcall;
  heif_image_get_plane_readonly: function (image: PHeifImage; channel: THeifChannel; stride: PInteger): PByte; stdcall;
  heif_image_get_colorspace: function (image: PHeifImage): cardinal; stdcall;
  heif_image_get_bits_per_pixel: function (image: PHeifImage; channel: THeifChannel  ): integer; stdcall;
  heif_image_get_chroma_format: function (image: PHeifImage): THeifChroma; stdcall;
  heif_image_add_plane: function (image: PHeifImage; channel: THeifChannel; width: integer; height: integer; bitDepth: integer): THeifError; stdcall;
  heif_image_release: procedure (image: PHeifImage); stdcall;

  (* Utils *)
  heif_get_version: function: THeifString; stdcall;
  heif_get_version_number: function: integer; stdcall;
  heif_get_version_number_major: function: integer; stdcall;
  heif_get_version_number_minor: function: integer; stdcall;
  heif_get_version_number_maintenance: function: integer; stdcall;

  var
    FHeifDLL: THandle = 0;

implementation

function GetProc(Name: string): FARPROC;
begin
  Result := GetProcAddress(FHeifDLL, PChar(Name));
end;

procedure LoadHeifDLL;
begin
  FHeifDLL := LoadLibrary(PChar(HeifDLL));

  if FHeifDLL = 0 then
    Exit;

  // Load function memory
  heif_context_alloc := GetProc('heif_context_alloc');
  heif_context_read_from_file := GetProc('heif_context_read_from_file');
  heif_context_write_to_file := GetProc('heif_context_write_to_file');
  heif_context_read_from_memory := GetProc('heif_context_read_from_memory');
  heif_context_read_from_memory_without_copy := GetProc('heif_context_read_from_memory_without_copy');
  heif_context_write := GetProc('heif_context_write');
  heif_context_get_number_of_top_level_images := GetProc('heif_context_get_number_of_top_level_images');
  heif_context_get_primary_image_handle := GetProc('heif_context_get_primary_image_handle');
  heif_context_get_primary_image_ID := GetProc('heif_context_get_primary_image_ID');
  heif_context_set_primary_image := GetProc('heif_context_set_primary_image');
  heif_context_get_encoder_for_format := GetProc('heif_context_get_encoder_for_format');
  heif_context_encode_image := GetProc('heif_context_encode_image');
  heif_context_add_exif_metadata := GetProc('heif_context_add_exif_metadata');
  heif_context_free := GetProc('heif_context_free');

  heif_encoder_get_name := GetProc('heif_encoder_get_name');
  heif_encoder_set_lossless := GetProc('heif_encoder_set_lossless');
  heif_encoder_set_lossy_quality := GetProc('heif_encoder_set_lossy_quality');
  heif_encoder_release := GetProc('heif_encoder_release');

  heif_image_handle_get_height := GetProc('heif_image_handle_get_height');
  heif_image_handle_get_width := GetProc('heif_image_handle_get_width');
  heif_image_handle_has_alpha_channel := GetProc('heif_image_handle_has_alpha_channel');
  heif_image_handle_get_thumbnail := GetProc('heif_image_handle_get_thumbnail');
  heif_image_handle_get_chroma_bits_per_pixel := GetProc('heif_image_handle_get_chroma_bits_per_pixel');
  heif_image_handle_release := GetProc('heif_image_handle_release');

  heif_image_create := GetProc('heif_image_create');
  heif_decode_image := GetProc('heif_decode_image');
  heif_image_get_width := GetProc('heif_image_get_width');
  heif_image_get_height := GetProc('heif_image_get_height');
  heif_image_get_plane := GetProc('heif_image_get_plane');
  heif_image_get_plane_readonly := GetProc('heif_image_get_plane_readonly');
  heif_image_get_colorspace := GetProc('heif_image_get_colorspace');
  heif_image_get_bits_per_pixel := GetProc('heif_image_get_bits_per_pixel');
  heif_image_get_chroma_format := GetProc('heif_image_get_chroma_format');
  heif_image_add_plane := GetProc('heif_image_add_plane');
  heif_image_release := GetProc('heif_image_release');

  heif_get_version := GetProc('heif_get_version');
  heif_get_version_number := GetProc('heif_get_version_number');
  heif_get_version_number_major := GetProc('heif_get_version_number_major');
  heif_get_version_number_minor := GetProc('heif_get_version_number_minor');
  heif_get_version_number_maintenance := GetProc('heif_get_version_number_maintenance');
end;

procedure UnloadHeifDLL;
begin
  FreeLibrary(FHeifDLL);
end;

{ THeifError }

procedure THeifError.ErrRaise;
begin
  if code <> heif_error_Ok then
    raise Exception.Create(Format('Error "%S"'#13'Code: %D @(%D)', [emessage, integer(code), subcode]));
end;

initialization
  LoadHeifDLL;
finalization
  UnloadHeifDLL;
end.
