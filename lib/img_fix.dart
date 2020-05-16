import 'dart:io';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';

Future<List<int>> fixExifRotation(String imagePath, bool invert) async {
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
  int xcrop = 0;
  int ycrop = 0;
    // rotate
  print(exifData['Image Orientation']);
  if (exifData['Image Orientation'].printable.contains('Horizontal')) {
    fixedImage = img.copyRotate(originalImage, 90);
  } else if (exifData['Image Orientation'].printable.contains('180')) {
    fixedImage = img.copyRotate(originalImage, -90);
    ycrop = width - height;
  } else if (exifData['Image Orientation'].printable.contains(invert ? '90 CW' : '90 CCW')) {
    fixedImage = img.copyRotate(originalImage, 180);
    if (!invert) {
      xcrop = width - height;
    }
  } else {
    fixedImage = img.copyRotate(originalImage, 0);
    if (invert) {
      xcrop = width - height;
    }
  }

  if (invert) {
    fixedImage = img.flipVertical(fixedImage);
  }
  fixedImage = img.copyCrop(fixedImage, xcrop, ycrop, height, height);

  return img.encodeJpg(fixedImage);
}

Future<dynamic> saveToPath (String imagePath, Future<List<int>> fixedImage) async {
  final out = File(imagePath);
  return fixedImage.then((outimg) {
    return out.writeAsBytes(outimg).then ( (arg) {
      return ImageGallerySaver.saveFile(imagePath);});
  });
}