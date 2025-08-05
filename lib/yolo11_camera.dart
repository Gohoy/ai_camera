// lib/yolo11_camera.dart
// YOLO11 相机组件导出文件
// 用于集成到其他Flutter项目中

/// YOLO11 相机组件库
/// 
/// 提供基于YOLO11的实时物体检测和相机功能
/// 
/// 使用方法:
/// ```dart
/// import 'package:your_package/yolo11_camera.dart';
/// 
/// // 在你的Widget中使用
/// SimpleYOLOCamera(
///   modelPath: 'yolo11n',
///   onDetectionResult: (results) {
///     print('检测到 ${results.length} 个对象');
///   },
///   onPhotoTaken: (photoData) {
///     // 处理拍照结果
///   },
/// )
/// ```
library yolo11_camera;

// 导出核心组件
export 'widgets/simple_yolo_camera.dart';
export 'widgets/yolo11_camera_widget.dart';

// 导出数据模型 (如果需要的话)
export 'models/detection_models.dart';

// 导出工具类
export 'utils/performance_monitor.dart';

// 导出服务类 (如果需要云端功能)
export 'services/cloud_service.dart';

// 重新导出 ultralytics_yolo 的主要类型，方便使用
export 'package:ultralytics_yolo/ultralytics_yolo.dart' show YOLOResult, YOLOTask;