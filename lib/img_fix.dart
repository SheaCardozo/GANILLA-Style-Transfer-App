import 'dart:io';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

Future<List<int>> fixExifRotation(String imagePath) async {
  final originalFile = File(imagePath);
  List<int> imageBytes = await originalFile.readAsBytes();

  final originalImage = img.decodeImage(imageBytes);

  final height = originalImage.height;
  final width = originalImage.width;

  // Let's check for the image size
  if (height >= width) {
    // I'm interested in portrait photos so
    // I'll just return here
    return imageBytes;
  }

  // We'll use the exif package to read exif data
  // This is map of several exif properties
  // Let's check 'Image Orientation'
  final exifData = await readExifFromBytes(imageBytes);

  img.Image fixedImage;

  if (height < width) {
    // rotate
    if (exifData['Image Orientation'].printable.contains('Horizontal')) {
      fixedImage = img.copyRotate(originalImage, 90);
    } else if (exifData['Image Orientation'].printable.contains('180')) {
      fixedImage = img.copyRotate(originalImage, -90);
    } else {
      fixedImage = img.copyRotate(originalImage, 0);
    }
  }

  // Here you can select whether you'd like to save it as png
  // or jpg with some compression
  // I choose jpg with 100% quality

  return img.encodeJpg(fixedImage);
}