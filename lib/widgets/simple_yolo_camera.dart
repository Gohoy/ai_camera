// lib/widgets/simple_yolo_camera.dart
// 简化版YOLO11相机组件 - 专门用作组件集成
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'dart:async';
import 'dart:typed_data';

/// 简化版YOLO11相机组件
/// 专门设计用于集成到其他应用中
class SimpleYOLOCamera extends StatefulWidget {
  /// 模型路径 (yolo11n, yolo11s, yolo11m, yolo11l, yolo11x)
  final String modelPath;
  
  /// YOLO任务类型
  final YOLOTask task;
  
  /// 置信度阈值
  final double confidenceThreshold;
  
  /// 检测间隔（秒）
  final int detectionInterval;
  
  /// 是否显示性能统计
  final bool showStats;
  
  /// 是否显示控制按钮
  final bool showControls;
  
  /// 拍照回调
  final Function(Uint8List photoData)? onPhotoTaken;
  
  /// 检测结果回调
  final Function(List<YOLOResult> results)? onDetectionResult;
  
  /// 错误回调
  final Function(String error)? onError;

  const SimpleYOLOCamera({
    super.key,
    this.modelPath = 'yolo11n',
    this.task = YOLOTask.detect,
    this.confidenceThreshold = 0.5,
    this.detectionInterval = 1,
    this.showStats = true,
    this.showControls = true,
    this.onPhotoTaken,
    this.onDetectionResult,
    this.onError,
  });

  @override
  State<SimpleYOLOCamera> createState() => _SimpleYOLOCameraState();
}

class _SimpleYOLOCameraState extends State<SimpleYOLOCamera> {
  List<YOLOResult> _detectionResults = [];
  bool _isDetecting = true;
  int _detectionCount = 0;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _startDetection();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    super.dispose();
  }

  void _startDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      Duration(seconds: widget.detectionInterval), 
      (timer) {
        if (_isDetecting && mounted) {
          // 触发检测（由YOLOView自动处理）
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // YOLO11 相机视图
          YOLOView(
            modelPath: widget.modelPath,
            task: widget.task,
            confidenceThreshold: widget.confidenceThreshold,
            onResult: _handleDetection,
          ),
          
          // 顶部统计信息
          if (widget.showStats) _buildStatsOverlay(),
          
          // 底部控制按钮
          if (widget.showControls) _buildControlsOverlay(),
          
          // 检测结果信息
          if (_detectionResults.isNotEmpty) _buildResultsOverlay(),
        ],
      ),
    );
  }

  /// 处理检测结果
  void _handleDetection(List<YOLOResult> results) {
    if (!_isDetecting) return;
    
    setState(() {
      _detectionResults = results;
      _detectionCount++;
    });
    
    // 调用外部回调
    widget.onDetectionResult?.call(results);
    
    // 输出检测日志
    if (results.isNotEmpty) {
      final topResult = results.first;
      print('🎯 [${widget.modelPath}] 检测到: ${topResult.className} (${(topResult.confidence * 100).toStringAsFixed(1)}%)');
    }
  }

  /// 统计信息覆盖层
  Widget _buildStatsOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 检测状态指示灯
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isDetecting ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            
            // 统计文本
            Text(
              '${widget.modelPath.toUpperCase()} | $_detectionCount次',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 检测结果覆盖层
  Widget _buildResultsOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '检测到 ${_detectionResults.length} 个对象',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < _detectionResults.length && i < 3; i++)
              Text(
                '${_detectionResults[i].className}: ${(_detectionResults[i].confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            if (_detectionResults.length > 3)
              Text(
                '...还有${_detectionResults.length - 3}个',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 控制按钮覆盖层
  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 检测开关
            _buildCircleButton(
              icon: _isDetecting ? Icons.pause : Icons.play_arrow,
              color: _isDetecting ? Colors.green : Colors.orange,
              onTap: _toggleDetection,
            ),
            
            // 拍照按钮
            _buildCircleButton(
              icon: Icons.camera_alt,
              color: Colors.white,
              size: 60,
              iconColor: Colors.black,
              onTap: _takePhoto,
            ),
            
            // 设置按钮
            _buildCircleButton(
              icon: Icons.settings,
              color: Colors.blue,
              onTap: _showSettings,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建圆形按钮
  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 50,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  /// 切换检测状态
  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
    });
    
    if (_isDetecting) {
      _startDetection();
    } else {
      _detectionTimer?.cancel();
    }
  }

  /// 拍照功能
  void _takePhoto() async {
    try {
      print('📸 拍照中...');
      
      // TODO: 实现真实的拍照功能
      // 这里应该从YOLOView或Camera中捕获图像
      
      // 模拟拍照
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 创建模拟照片数据
      final photoData = Uint8List.fromList([]);
      
      // 调用回调
      widget.onPhotoTaken?.call(photoData);
      
      // 显示拍照反馈
      _showPhotoFeedback();
      
    } catch (e) {
      final errorMsg = '拍照失败: $e';
      print('❌ $errorMsg');
      widget.onError?.call(errorMsg);
    }
  }

  /// 显示拍照反馈
  void _showPhotoFeedback() {
    // 简单的视觉反馈
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const Center(
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
      ),
    );
    
    // 自动关闭
    Timer(const Duration(milliseconds: 800), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  /// 显示设置
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YOLO11 设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.memory, color: Colors.green),
              title: Text(
                '模型: ${widget.modelPath.toUpperCase()}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '轻触查看模型信息',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => _showModelInfo(),
            ),
            
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.orange),
              title: Text(
                '检测间隔: ${widget.detectionInterval}秒',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '检测频率设置',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.blue),
              title: Text(
                '置信度阈值: ${(widget.confidenceThreshold * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '检测灵敏度',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示模型信息
  void _showModelInfo() {
    const modelInfo = {
      'yolo11n': '最快 - 2.6M参数，56ms推理',
      'yolo11s': '平衡 - 9.4M参数，90ms推理',
      'yolo11m': '准确 - 20.1M参数，183ms推理',
      'yolo11l': '高精度 - 25.3M参数，238ms推理',
      'yolo11x': '最佳 - 56.9M参数，462ms推理',
    };
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(
          widget.modelPath.toUpperCase(),
          style: const TextStyle(color: Colors.green),
        ),
        content: Text(
          modelInfo[widget.modelPath] ?? '未知模型',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}/// YOLO11相机组件的静态工厂方法
class YOLOCameraFactory {
  /// 创建标准检测相机
  static Widget createDetectionCamera({
    String modelPath = 'yolo11n',
    double confidenceThreshold = 0.5,
    Function(List<YOLOResult>)? onDetection,
    Function(Uint8List)? onPhoto,
  }) {
    return SimpleYOLOCamera(
      modelPath: modelPath,
      task: YOLOTask.detect,
      confidenceThreshold: confidenceThreshold,
      onDetectionResult: onDetection,
      onPhotoTaken: onPhoto,
    );
  }
  
  /// 创建分割相机
  static Widget createSegmentationCamera({
    String modelPath = 'yolo11n-seg',
    double confidenceThreshold = 0.5,
    Function(List<YOLOResult>)? onDetection,
    Function(Uint8List)? onPhoto,
  }) {
    return SimpleYOLOCamera(
      modelPath: modelPath,
      task: YOLOTask.segment,
      confidenceThreshold: confidenceThreshold,
      onDetectionResult: onDetection,
      onPhotoTaken: onPhoto,
    );
  }
  
  /// 创建最小化相机（无UI）
  static Widget createMinimalCamera({
    String modelPath = 'yolo11n',
    Function(List<YOLOResult>)? onDetection,
  }) {
    return SimpleYOLOCamera(
      modelPath: modelPath,
      showStats: false,
      showControls: false,
      onDetectionResult: onDetection,
    );
  }
}

