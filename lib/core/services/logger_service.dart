import 'package:logger/logger.dart';

class LoggerService {
  final Logger _logger = Logger();

  void d(String message) => _logger.d(message);
  void e(String message) => _logger.e(message);
  void i(String message) => _logger.i(message);
  void w(String message) => _logger.w(message);
}
