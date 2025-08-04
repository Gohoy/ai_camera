// lib/models/detection_models.dart
import 'dart:ui' as ui;

class DetectionResult {
  final String category;
  final double confidence;
  final ui.Image? segmentedImage;
  final int processingTime;
  final BoundingBox? bbox;
  final ui.Image? maskImage;

  const DetectionResult({
    required this.category,
    required this.confidence,
    this.segmentedImage,
    required this.processingTime,
    this.bbox,
    this.maskImage,
  });

  factory DetectionResult.empty() {
    return const DetectionResult(
      category: '',
      confidence: 0.0,
      processingTime: 0,
    );
  }

  bool get isEmpty => category.isEmpty;
}

class Detection {
  final BoundingBox bbox;
  final double confidence;
  final String label;

  const Detection({
    required this.bbox,
    required this.confidence,
    required this.label,
  });
}

class BoundingBox {
  final double x, y, width, height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get area => width * height;
  
  bool contains(double px, double py) {
    return px >= x && px <= x + width && py >= y && py <= y + height;
  }
}

class CloudAnalysisResult {
  final String description;
  final List<String> tags;
  final String? price;
  final String? wikiInfo;
  final List<String> relatedImages;
  final Map<String, dynamic>? additionalData;

  const CloudAnalysisResult({
    required this.description,
    required this.tags,
    this.price,
    this.wikiInfo,
    required this.relatedImages,
    this.additionalData,
  });
}

// 性能统计数据
class PerformanceStats {
  final Map<String, int> timings;
  final int memoryUsage;
  final int modelSize;

  const PerformanceStats({
    required this.timings,
    required this.memoryUsage,
    required this.modelSize,
  });
}
