# Delphi-Extended-Images-Format
Support in Delphi for WebP and Heif image codecs with a wrapper for the DLLs.

These units add two new `TGraphic` class types called `THeifImage` and `TWebPImage` respectively. They work as any other TGraphic with support for editing images, assigning to other image types and you can edit the pixels individually by any of the avalabile channels with the `TRGBAPixel` helper provided in `Cod.Imaging.Utils`.

### Planned features
- Ability to save Heif image to TStream (currently not avalabile due to dll callback complications)

## Examples
```
  var Image: THeifImage;
  Image := THeifImage.Create;
  try
    Image.LoadFromFile('sample.heic');

    Image1.Stretch := true;
    Image1.Picture.Graphic := Image;
  finally
    Image.Free;
  end;
```
```
  var Image: TWebPImage;
  Image := TWebPImage.Create;
  try
    Image.LoadFromFile('sample.webp');

    Image1.Stretch := true;
    Image1.Picture.Graphic := Image;
  finally
    Image.Free;
  end;****
```
Cross conversion example
```
  var WebImage: TWebPImage;
  var HeifImage: THeifImage;
  WebImage := TWebPImage.Create;
  HeifImage := THeifImage.Create;
  try
    // Load WebP
    WebImage.LoadFromFile('sample.webp');

    // Assign to Heif
    HeifImage.Assign(WebImage);

    // Display
    Image1.Stretch := true;
    Image1.Picture.Graphic := HeifImage;

    // Save heif
    HeifImage.SaveToFile('out.heif');
  finally
    WebImage.Free;
    HeifImage.Free;
  end;
```

## Image
![image](https://github.com/Codrax/Delphi-Extended-Images-Format/assets/68193064/1550559a-4639-4833-ac55-68d6e9b49cb7)
