// lib/services/cloud_service.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:ui' as ui;
import '../utils/performance_monitor.dart';
import '../models/detection_models.dart';

class CloudAnalysisService {
  static const String BASE_URL = 'https://your-gpu-server.com/api';
  static const String LLAVA_ENDPOINT = '/llava-analyze';
  static const String WEB_SEARCH_ENDPOINT = '/web-search';
  static const String PRICE_CHECK_ENDPOINT = '/price-check';
  
  final Dio _dio = Dio();

  CloudAnalysisService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    
    // 添加请求拦截器用于日志
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print("🌐 $obj"),
    ));
  }

  // 上传图片到云端分析 - LLaVA + Web Search
  Future<CloudAnalysisResult> analyzeWithLLaVA({
    required ui.Image segmentedImage,
    required String category,
    required double confidence,
    String? userPrompt,
  }) async {
    try {
      print("🚀 开始云端分析...");
      PerformanceMonitor.startTimer('cloud_analysis');
      
      // 1. 转换图片为bytes
      final imageBytes = await _imageToBytes(segmentedImage);
      
      // 2. 构建分析提示词
      final analysisPrompt = _buildAnalysisPrompt(category, userPrompt);
      
      // 3. 调用LLaVA分析
      PerformanceMonitor.startTimer('llava_analysis');
      final llavaResult = await _callLLaVA(imageBytes, analysisPrompt);
      PerformanceMonitor.endTimer('llava_analysis');
      
      // 4. 并行执行Web搜索
      PerformanceMonitor.startTimer('web_search');
      final webSearchResult = await _performWebSearch(category, llavaResult['description'] ?? '');
      PerformanceMonitor.endTimer('web_search');
      
      // 5. 价格查询
      PerformanceMonitor.startTimer('price_check');
      final priceResult = await _checkPrice(category, llavaResult['description'] ?? '');
      PerformanceMonitor.endTimer('price_check');
      
      PerformanceMonitor.endTimer('cloud_analysis');
      
      final totalTime = PerformanceMonitor.getTimer('cloud_analysis');
      print("✅ 云端分析完成，总耗时: ${totalTime}ms");
      print("  LLaVA分析: ${PerformanceMonitor.getTimer('llava_analysis')}ms");
      print("  Web搜索: ${PerformanceMonitor.getTimer('web_search')}ms");
      print("  价格查询: ${PerformanceMonitor.getTimer('price_check')}ms");

      // 6. 合并结果
      return CloudAnalysisResult(
        description: llavaResult['description'] ?? '',
        tags: List<String>.from(llavaResult['tags'] ?? []),
        price: priceResult['price'],
        wikiInfo: webSearchResult['wiki_info'],
        relatedImages: List<String>.from(llavaResult['related_images'] ?? []),
        additionalData: {
          'web_search': webSearchResult,
          'price_info': priceResult,
          'llava_raw': llavaResult,
        },
      );
    } on DioException catch (e) {
      print("❌ 云端分析失败: ${e.message}");
      throw Exception('网络请求失败: ${e.message}');
    } catch (e) {
      print("❌ 未知错误: $e");
      throw Exception('分析失败: $e');
    }
  }

  // 调用LLaVA模型分析
  Future<Map<String, dynamic>> _callLLaVA(
    Uint8List imageBytes,
    String prompt,
  ) async {
    final formData = FormData.fromMap({
              'image': MultipartFile.fromBytes(
          imageBytes,
          filename: 'subject.png',
        ),
      'prompt': prompt,
      'model': 'llava-1.6-7b',
      'max_tokens': 512,
      'temperature': 0.7,
    });

    final response = await _dio.post(
      '$BASE_URL$LLAVA_ENDPOINT',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
      ),
    );

    return response.data;
  }

  // 执行Web搜索
  Future<Map<String, dynamic>> _performWebSearch(
    String category,
    String description,
  ) async {
    final searchQuery = '$category $description';
    
    final response = await _dio.post(
      '$BASE_URL$WEB_SEARCH_ENDPOINT',
      data: {
        'query': searchQuery,
        'max_results': 5,
        'include_wiki': true,
        'include_news': true,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer YOUR_API_KEY',
        },
      ),
    );

    return response.data;
  }

  // 价格查询
  Future<Map<String, dynamic>> _checkPrice(
    String category,
    String description,
  ) async {
    final response = await _dio.post(
      '$BASE_URL$PRICE_CHECK_ENDPOINT',
      data: {
        'category': category,
        'description': description,
        'sources': ['amazon', 'ebay', 'taobao'],
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer YOUR_API_KEY',
        },
      ),
    );

    return response.data;
  }

  // 构建分析提示词
  String _buildAnalysisPrompt(String category, String? userPrompt) {
    final basePrompt = '''
请详细分析这个$category物体，包括：

1. 详细描述：外观、材质、颜色、尺寸等特征
2. 功能用途：主要用途、适用场景
3. 品牌信息：如果是知名品牌产品
4. 技术规格：如果是电子产品
5. 市场定位：价格区间、目标用户
6. 相关推荐：类似产品或配件

请用中文回答，信息要准确详细。
''';

    if (userPrompt != null && userPrompt.isNotEmpty) {
      return '$basePrompt\n\n用户特别关注：$userPrompt';
    }
    
    return basePrompt;
  }

  // 批量分析（用于性能测试）
  Future<List<CloudAnalysisResult>> batchAnalyze(
    List<Map<String, dynamic>> requests,
  ) async {
    final results = <CloudAnalysisResult>[];
    
    for (final request in requests) {
      try {
        final result = await analyzeWithLLaVA(
          segmentedImage: request['image'],
          category: request['category'],
          confidence: request['confidence'],
          userPrompt: request['prompt'],
        );
        results.add(result);
      } catch (e) {
        print("批量分析中单个请求失败: $e");
        // 继续处理其他请求
      }
    }
    
    return results;
  }

  // 获取分析历史
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    final response = await _dio.get(
      '$BASE_URL/analysis-history',
      options: Options(
        headers: {
          'Authorization': 'Bearer YOUR_API_KEY',
        },
      ),
    );

    return List<Map<String, dynamic>>.from(response.data);
  }

  // 获取性能统计
  Map<String, int> getPerformanceStats() {
    return PerformanceMonitor.getAllTimers();
  }

  Future<Uint8List> _imageToBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
