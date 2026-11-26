import 'dart:typed_data';

class ImageModel {
  Uint8List imageByte;
  String name;
  String docType;

  /// Original bytes at first ingest (CamScanner crop source). Never replaced by
  /// crop/filter/size — only [imageByte] is the display/PDF page.
  Uint8List? rawBytes;

  ImageModel({
    required this.imageByte,
    required this.name,
    required this.docType,
    this.rawBytes,
  });

  /// Crop canvas source: frozen raw, else current display.
  Uint8List get cropSource => rawBytes ?? imageByte;

  ImageModel copyWith({
    Uint8List? imageByte,
    String? name,
    String? docType,
    Uint8List? rawBytes,
    bool clearRawBytes = false,
  }) {
    return ImageModel(
      imageByte: imageByte ?? this.imageByte,
      name: name ?? this.name,
      docType: docType ?? this.docType,
      rawBytes: clearRawBytes ? null : (rawBytes ?? this.rawBytes),
    );
  }

  /// Update display bytes while keeping the original crop source.
  ImageModel withDisplayBytes(Uint8List display) {
    return copyWith(imageByte: display);
  }
}
