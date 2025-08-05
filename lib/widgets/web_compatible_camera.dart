import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

class MockDetection {
  final String className;
  final double confidence;
  final double x, y, width, height;

  MockDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class WebCompatibleCamera extends StatefulWidget {
  final int detectionInterval;
  final bool showControls;
  final Function(List<MockDetection>)? onDetectionResult;
  final Function(Uint8List)? onPhotoTaken;
  final Function(String)? onError;

  const WebCompatibleCamera({
    super.key,
    this.detectionInterval = 1,
    this.showControls = true,
    this.onDetectionResult,
    this.onPhotoTaken,
    this.onError,
  });

  @override
  State<WebCompatibleCamera> createState() => _WebCompatibleCameraState();
}

class _WebCompatibleCameraState extends State<WebCompatibleCamera> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;
  bool _isCameraInitialized = false;
  bool _isDetecting = true;
  Timer? _detectionTimer;
  List<MockDetection> _detections = [];

  final List<String> _classes = [
    'person', 'car', 'bicycle', 'dog', 'cat', 'bird', 'bottle', 'chair', 'table', 'laptop'
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        widget.onError?.call('没有可用的相机');
        return;
      }

      _controller = CameraController(
        _cameras![_selectedCameraIdx],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      _startDetection();
    } catch (e) {
      widget.onError?.call('相机初始化失败: $e');
    }
  }

  void _startDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(Duration(seconds: widget.detectionInterval), (timer) {
      if (_isDetecting && mounted) {
        _simulateDetection();
      }
    });
  }

  void _simulateDetection() {
    final random = Random();
    final numDetections = random.nextInt(3) + 1;
    List<MockDetection> results = [];

    for (int i = 0; i < numDetections; i++) {
      results.add(MockDetection(
        className: _classes[random.nextInt(_classes.length)],
        confidence: random.nextDouble() * 0.5 + 0.5,
        x: random.nextDouble() * 0.6,
        y: random.nextDouble() * 0.6,
        width: random.nextDouble() * 0.3 + 0.1,
        height: random.nextDouble() * 0.3 + 0.1,
      ));
    }

    setState(() {
      _detections = results;
    });
    
    widget.onDetectionResult?.call(results);
  }

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

  Future<void> _takePhoto() async {
    if (!_isCameraInitialized || _controller == null) return;
    
    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      widget.onPhotoTaken?.call(bytes);
    } catch (e) {
      widget.onError?.call('拍照失败: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
      _isCameraInitialized = false;
    });
    
    await _controller?.dispose();
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: DetectionPainter(_detections),
          ),
        ),
        if (widget.showControls) _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildButton(
              icon: _isDetecting ? Icons.pause : Icons.play_arrow,
              color: _isDetecting ? Colors.green : Colors.orange,
              onTap: _toggleDetection,
              size: 45,
            ),
            _buildButton(
              icon: Icons.camera_alt,
              color: Colors.white,
              size: 60,
              iconColor: Colors.black,
              onTap: _takePhoto,
            ),
            _buildButton(
              icon: Icons.flip_camera_android,
              color: Colors.blue,
              onTap: _switchCamera,
              size: 45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 50,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<MockDetection> detections;

  DetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var detection in detections) {
      final rect = Rect.fromLTWH(
        detection.x * size.width,
        detection.y * size.height,
        detection.width * size.width,
        detection.height * size.height,
      );
      
      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.className} ${(detection.confidence * 100).toInt()}%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}