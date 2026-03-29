import 'dart:async';
import 'dart:ui';

class Debounce {
  final Duration duration;
  Timer? _timer;

  Debounce({required this.duration});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
