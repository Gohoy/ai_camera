// lib/main_yolo11.dart
// YOLO11 相机应用 - 跨平台相机
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets/simple_yolo_camera.dart';
import 'widgets/web_compatible_camera.dart';

void main() {
  runApp(const YOLO11CameraApp());
}

class YOLO11CameraApp extends StatelessWidget {
  const YOLO11CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLO11 AI相机',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _buildCameraWidget(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  /// 根据平台构建相机组件
  Widget _buildCameraWidget() {
    if (kIsWeb) {
      // Web平台使用兼容版本
      return WebCompatibleCamera(
        modelPath: 'yolo11n',
        detectionInterval: 1,
        onDetectionResult: (results) {
          if (results.isNotEmpty) {
            print('检测到 ${results.length} 个对象');
          }
        },
        onPhotoTaken: (photoData) {
          print('照片已保存，大小: ${photoData.length} bytes');
        },
        onError: (error) {
          print('错误: $error');
        },
      );
    } else {
      // 移动平台使用YOLO11原生版本
      return SimpleYOLOCamera(
        modelPath: 'yolo11n',
        detectionInterval: 1,
        onDetectionResult: (results) {
          if (results.isNotEmpty) {
            print('检测到 ${results.length} 个对象');
          }
        },
        onPhotoTaken: (photoData) {
          print('照片已保存，大小: ${photoData.length} bytes');
        },
        onError: (error) {
          print('错误: $error');
        },
      );
    }
  }
}