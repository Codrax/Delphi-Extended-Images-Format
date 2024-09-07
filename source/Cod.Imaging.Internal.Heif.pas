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
    THeifSuberrorCode = type integer;

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
    THeifSuberrorCodeHelper = record helper for THeifSuberrorCode
      const
      // no further information available
      heif_suberror_Unspecified = 0;

      // --- Invalid_input ---
      // End of data reached unexpectedly.
      heif_suberror_End_of_data = 100;

      // Size of box (defined in header) is wrong
      heif_suberror_Invalid_box_size = 101;

      // Mandatory 'ftyp' box is missing
      heif_suberror_No_ftyp_box = 102;
      heif_suberror_No_idat_box = 103;
      heif_suberror_No_meta_box = 104;
      heif_suberror_No_hdlr_box = 105;
      heif_suberror_No_hvcC_box = 106;
      heif_suberror_No_pitm_box = 107;
      heif_suberror_No_ipco_box = 108;
      heif_suberror_No_ipma_box = 109;
      heif_suberror_No_iloc_box = 110;
      heif_suberror_No_iinf_box = 111;
      heif_suberror_No_iprp_box = 112;
      heif_suberror_No_iref_box = 113;
      heif_suberror_No_pict_handler = 114;

      // An item property referenced in the 'ipma' box is not existing in the 'ipco' container.
      heif_suberror_Ipma_box_references_nonexisting_property = 115;

      // No properties have been assigned to an item.
      heif_suberror_No_properties_assigned_to_item = 116;

      // Image has no (compressed) data
      heif_suberror_No_item_data = 117;

      // Invalid specification of image grid (tiled image)
      heif_suberror_Invalid_grid_data = 118;

      // Tile-images in a grid image are missing
      heif_suberror_Missing_grid_images = 119;
      heif_suberror_Invalid_clean_aperture = 120;

      // Invalid specification of overlay image
      heif_suberror_Invalid_overlay_data = 121;

      // Overlay image completely outside of visible canvas area
      heif_suberror_Overlay_image_outside_of_canvas = 122;
      heif_suberror_Auxiliary_image_type_unspecified = 123;
      heif_suberror_No_or_invalid_primary_item = 124;
      heif_suberror_No_infe_box = 125;
      heif_suberror_Unknown_color_profile_type = 126;
      heif_suberror_Wrong_tile_image_chroma_format = 127;
      heif_suberror_Invalid_fractional_number = 128;
      heif_suberror_Invalid_image_size = 129;
      heif_suberror_Invalid_pixi_box = 130;
      heif_suberror_No_av1C_box = 131;
      heif_suberror_Wrong_tile_image_pixel_depth = 132;
      heif_suberror_Unknown_NCLX_color_primaries = 133;
      heif_suberror_Unknown_NCLX_transfer_characteristics = 134;
      heif_suberror_Unknown_NCLX_matrix_coefficients = 135;

      // Invalid specification of region item
      heif_suberror_Invalid_region_data = 136;

      // Image has no ispe property
      heif_suberror_No_ispe_property = 137;
      heif_suberror_Camera_intrinsic_matrix_undefined = 138;
      heif_suberror_Camera_extrinsic_matrix_undefined = 139;

      // Invalid JPEG 2000 codestream - usually a missing marker
      heif_suberror_Invalid_J2K_codestream = 140;
      heif_suberror_No_vvcC_box = 141;

      // icbr is only needed in some situations; this error is for those cases
      heif_suberror_No_icbr_box = 142;
      heif_suberror_No_avcC_box = 143;

      // Decompressing generic compression or header compression data failed (e.g. bitstream corruption)
      heif_suberror_Decompression_invalid_data = 150;

      // --- Memory_allocation_error ---

      // A security limit preventing unreasonable memory allocations was exceeded by the input file.
      // Please check whether the file is valid. If it is; contact us so that we could increase the
      // security limits further.
      heif_suberror_Security_limit_exceeded = 1000;

      // There was an error from the underlying compression / decompression library.
      // One possibility is lack of resources (e.g. memory).
      heif_suberror_Compression_initialisation_error = 1001;

      // --- Usage_error ---
      // An item ID was used that is not present in the file.
      heif_suberror_Nonexisting_item_referenced = 2000; // also used for Invalid_input

      // An API argument was given a NULL pointer; which is not allowed for that function.
      heif_suberror_Null_pointer_argument = 2001;

      // Image channel referenced that does not exist in the image
      heif_suberror_Nonexisting_image_channel_referenced = 2002;

      // The version of the passed plugin is not supported.
      heif_suberror_Unsupported_plugin_version = 2003;

      // The version of the passed writer is not supported.
      heif_suberror_Unsupported_writer_version = 2004;

      // The given (encoder) parameter name does not exist.
      heif_suberror_Unsupported_parameter = 2005;

      // The value for the given parameter is not in the valid range.
      heif_suberror_Invalid_parameter_value = 2006;

      // Error in property specification
      heif_suberror_Invalid_property = 2007;

      // Image reference cycle found in iref
      heif_suberror_Item_reference_cycle = 2008;

      // --- Unsupported_feature ---
      // Image was coded with an unsupported compression method.
      heif_suberror_Unsupported_codec = 3000;

      // Image is specified in an unknown way; e.g. as tiled grid image (which is supported)
      heif_suberror_Unsupported_image_type = 3001;
      heif_suberror_Unsupported_data_version = 3002;

      // The conversion of the source image to the requested chroma / colorspace is not supported.
      heif_suberror_Unsupported_color_conversion = 3003;
      heif_suberror_Unsupported_item_construction_method = 3004;
      heif_suberror_Unsupported_header_compression_method = 3005;

      // Generically compressed data used an unsupported compression method
      heif_suberror_Unsupported_generic_compression_method = 3006;
      heif_suberror_Unsupported_essential_property = 3007;

      // --- Encoder_plugin_error ---
      heif_suberror_Unsupported_bit_depth = 4000;

      // --- Encoding_error ---
      heif_suberror_Cannot_write_output_data = 5000;
      heif_suberror_Encoder_initialization = 5001;
      heif_suberror_Encoder_encoding = 5002;
      heif_suberror_Encoder_cleanup = 5003;
      heif_suberror_Too_many_regions = 5004;

      // --- Plugin loading error ---
      heif_suberror_Plugin_loading_error = 6000;         // a specific plugin file cannot be loaded
      heif_suberror_Plugin_is_not_loaded = 6001;         // trying to remove a plugin that is not loaded
      heif_suberror_Cannot_read_plugin_directory = 6002; // error while scanning the directory for plugins
      heif_suberror_No_matching_decoder_installed = 6003; // no decoder found for that compression format
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
      heif_error_Plugin_loading_error
    );

    heif_filetype_result = (
      heif_filetype_no,
      heif_filetype_yes_supported,   // it is heif and can be read by libheif
      heif_filetype_yes_unsupported, // it is heif, but cannot be read by libheif
      heif_filetype_maybe
    ); // not sure whether it is an heif, try detection with more input data

    THeifError = record
      code: THeifErrorNum;
      subcode: THeifSuberrorCode;

      emessage: THeifString;

      procedure ErrRaise;

      class function Create(ACode: THeifErrorNum; ASubcode: THeifSuberrorCode=THeifSuberrorCode.heif_suberror_Unspecified; AMessage: THeifString=nil): THeifError; static;
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
    THeifWriteFunc = function(const data: Pointer; size: cardinal; userdata: Pointer): THeifError of object;
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
  heif_encoder_set_lossless: function (encoder: PHeifEncoder; enable: bool): THeifError; stdcall;
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

  function HeifDLLLoaded: boolean;

implementation

var
  FHeifDLL: THandle = 0;

function HeifDLLLoaded: boolean;
begin
  Result := FHeifDLL <> 0;
end;

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

class function THeifError.Create(ACode: THeifErrorNum; ASubcode: THeifSuberrorCode;
  AMessage: THeifString): THeifError;
begin
  with Result do begin
    code := ACode;
    subcode := ASubCode;
    emessage := AMessage;
  end;
end;

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
