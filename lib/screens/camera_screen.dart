// lib/screens/camera_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;
import '../services/ai_detector.dart';
import '../services/cloud_service.dart';
import '../models/detection_models.dart';


class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  final AIDetector _aiDetector = AIDetector();
  final CloudAnalysisService _cloudService = CloudAnalysisService();

  bool _isProcessing = false;
  bool _isCloudAnalyzing = false;
  DetectionResult? _currentResult;
  CloudAnalysisResult? _cloudResult;
  
  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // 性能统计
  Map<String, int> _performanceStats = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
    _initializeAI();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showError('没有找到相机设备');
      return;
    }

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _showError('相机初始化失败: $e');
    }
  }

  Future<void> _initializeAI() async {
    try {
      await _aiDetector.initializeModels();
    } catch (e) {
      _showError('AI模型初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller?.value.isInitialized != true) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化相机...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 相机预览
          Positioned.fill(child: CameraPreview(_controller!)),

          // 检测框覆盖层
          if (_currentResult?.bbox != null) _buildDetectionOverlay(),

          // 顶部状态栏
          _buildTopBar(),

          // 底部控制栏
          _buildBottomControls(),

          // 结果显示面板
          if (_currentResult != null) _buildResultPanel(),

          // 加载指示器
          if (_isProcessing || _isCloudAnalyzing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 性能统计
            if (_performanceStats.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_performanceStats['total_detection'] ?? 0}ms',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            // 标题
            const Text(
              'AI识物',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            // 设置按钮
            IconButton(
              onPressed: _showSettings,
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    final bbox = _currentResult!.bbox!;
    final screenSize = MediaQuery.of(context).size;
    
    // 转换bbox坐标到屏幕坐标
    final left = bbox.x * screenSize.width;
    final top = bbox.y * screenSize.height;
    final width = bbox.width * screenSize.width;
    final height = bbox.height * screenSize.height;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // 检测标签
            Positioned(
              top: -30,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentResult!.category} ${(_currentResult!.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 相册按钮
            _buildControlButton(
              icon: Icons.photo_library,
              onTap: _pickFromGallery,
            ),
            
            // 拍照按钮
            _buildCaptureButton(),
            
            // 切换相机按钮
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              onTap: _switchCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isProcessing ? null : _captureAndAnalyze,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isProcessing ? 1.0 : _pulseAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isProcessing ? Colors.grey : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                size: 40,
                color: _isProcessing ? Colors.white : Colors.black87,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _isCloudAnalyzing ? '☁️ 云端分析中...' : '🤖 AI正在分析...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_performanceStats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '本地: ${_performanceStats['total_detection'] ?? 0}ms',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    return SlideTransition(
      position: _slideAnimation,
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 结果内容
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildLocalResult(),
                      if (_cloudResult != null) ...[
                        const SizedBox(height: 20),
                        _buildCloudResult(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocalResult() {
    final result = _currentResult!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smartphone, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '📱 本地识别',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(result.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              '类别: ${result.category}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '处理时间: ${result.processingTime}ms',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 12),
            if (result.segmentedImage != null)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RawImage(
                    image: result.segmentedImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudResult() {
    final result = _cloudResult!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '☁️ 云端分析',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (result.description.isNotEmpty) ...[
              const Text(
                '详细描述:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                result.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],

            if (result.tags.isNotEmpty) ...[
              const Text('标签:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: result.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue[50],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            if (result.price != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '参考价格: ${result.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (result.wikiInfo != null) ...[
              const Text(
                '百科信息:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                result.wikiInfo!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentResult = null;
      _cloudResult = null;
    });

    try {
      // 1. 拍照
      final imageFile = await _controller!.takePicture();
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 2. 本地AI识别
      final result = await _aiDetector.detectAndSegment(image, "object");

      setState(() {
        _currentResult = result;
        _performanceStats = _aiDetector.getPerformanceStats();
      });

      if (!result.isEmpty && result.segmentedImage != null) {
        // 3. 云端分析
        setState(() {
          _isCloudAnalyzing = true;
        });

        try {
          final cloudResult = await _cloudService.analyzeWithLLaVA(
            segmentedImage: result.segmentedImage!,
            category: result.category,
            confidence: result.confidence,
          );

          setState(() {
            _cloudResult = cloudResult;
          });
        } catch (e) {
          print("云端分析失败，仅显示本地结果: $e");
        } finally {
          setState(() {
            _isCloudAnalyzing = false;
          });
        }
      }
    } catch (e) {
      _showError('分析失败: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    // TODO: 实现从相册选择图片
    _showError('相册功能开发中...');
  }

  Future<void> _switchCamera() async {
    if (_controller == null) return;
    
    final cameras = await availableCameras();
    final currentIndex = cameras.indexOf(_controller!.description);
    final nextIndex = (currentIndex + 1) % cameras.length;
    
    await _controller!.dispose();
    _controller = CameraController(
      cameras[nextIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _controller!.initialize();
    setState(() {});
  }

  void _showSettings() {
    // TODO: 实现设置页面
    _showError('设置功能开发中...');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _aiDetector.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
