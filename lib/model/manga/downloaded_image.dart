import 'dart:convert';
import 'dart:typed_data';

class DownloadedImage {
  final Uint8List imagePath;

  DownloadedImage({
    required this.imagePath,
  });

  factory DownloadedImage.fromJson(Map<String, dynamic> json) {
    return DownloadedImage(
      imagePath: base64.decode(json['uint8list_base64']),
    );
  }
  
}