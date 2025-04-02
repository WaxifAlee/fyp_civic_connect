import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageCompression {
  static const String _apiKey = 'zTBrdn8jL1GjPwlWQjfdHjrPt23fQzc7';

  static Future<File> compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final response = await http.post(
      Uri.parse('https://api.tinify.com/shrink'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('api:$_apiKey'))}',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode == 201) {
      final compressedImageUrl = jsonDecode(response.body)['output']['url'];
      final compressedImageResponse =
          await http.get(Uri.parse(compressedImageUrl));
      final compressedImageBytes = compressedImageResponse.bodyBytes;
      final compressedImageFile = File(imageFile.path)
        ..writeAsBytesSync(compressedImageBytes);
      return compressedImageFile;
    } else {
      throw Exception('Failed to compress image');
    }
  }
}
