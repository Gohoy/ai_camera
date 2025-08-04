// lib/utils/performance_monitor.dart

class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, int> _results = {};

  static void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  static void endTimer(String name) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      _results[name] = timer.elapsedMilliseconds;
      _timers.remove(name);
    }
  }

  static int getTimer(String name) {
    return _results[name] ?? 0;
  }

  static Map<String, int> getAllTimers() {
    return Map.from(_results);
  }

  static void clear() {
    _timers.clear();
    _results.clear();
  }

  static void printStats() {
    print("📊 性能统计:");
    _results.forEach((name, time) {
      print("  $name: ${time}ms");
    });
  }
} 