import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class CroppedArtworkResult {
  final String croppedFilePath;
  final String label;
  final int width;
  final int height;

  CroppedArtworkResult({
    required this.croppedFilePath,
    required this.label,
    required this.width,
    required this.height,
  });
}

/// Pure Dart image processing service for artwork cropping and paper journal enhancements
class ImagePreprocessService {
  /// Crops a normalized bounding box [ymin, xmin, ymax, xmax] (0-1000 scale) from an image file
  static Future<CroppedArtworkResult?> cropBoundingBox({
    required String sourceImagePath,
    required List<int> box2d, // [ymin, xmin, ymax, xmax]
    required String outputDirectory,
    String? label,
    int? cropIndex,
  }) async {
    try {
      final file = File(sourceImagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      if (box2d.length < 4) return null;

      final yminNorm = box2d[0];
      final xminNorm = box2d[1];
      final ymaxNorm = box2d[2];
      final xmaxNorm = box2d[3];

      // Convert 0-1000 normalized grid to actual pixel coordinates
      final imgW = image.width;
      final imgH = image.height;

      var x = ((xminNorm / 1000.0) * imgW).round().clamp(0, imgW - 1);
      var y = ((yminNorm / 1000.0) * imgH).round().clamp(0, imgH - 1);
      var w = (((xmaxNorm - xminNorm) / 1000.0) * imgW).round().clamp(1, imgW - x);
      var h = (((ymaxNorm - yminNorm) / 1000.0) * imgH).round().clamp(1, imgH - y);

      // Crop artwork
      final cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      final outDir = Directory(outputDirectory);
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final sourceBase = p.basenameWithoutExtension(sourceImagePath);
      final indexSuffix = cropIndex != null ? '-crop$cropIndex' : '-crop';
      final outFileName = '$sourceBase$indexSuffix.png';
      final outPath = p.join(outputDirectory, outFileName);

      final pngBytes = img.encodePng(cropped);
      await File(outPath).writeAsBytes(pngBytes);

      return CroppedArtworkResult(
        croppedFilePath: outPath,
        label: label ?? 'Sketch',
        width: w,
        height: h,
      );
    } catch (_) {
      return null;
    }
  }

  /// Enhances paper journal photos by boosting contrast and reducing background paper grain
  static Future<String?> enhancePaperContrast({
    required String inputImagePath,
    required String outputImagePath,
  }) async {
    try {
      final file = File(inputImagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Enhance contrast so ink/pencil strokes pop over paper grain
      final enhanced = img.adjustColor(
        image,
        contrast: 1.35,
        brightness: 1.05,
      );

      final outDir = Directory(p.dirname(outputImagePath));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final pngBytes = img.encodePng(enhanced);
      await File(outputImagePath).writeAsBytes(pngBytes);

      return outputImagePath;
    } catch (_) {
      return null;
    }
  }
}
