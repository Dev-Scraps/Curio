import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../system/logger.dart';

part 'connectivity.g.dart';

@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) {
  return ConnectivityService();
}

class ConnectivityService {
  /// Simple check to see if we have internet access
  /// using a DNS lookup to google.com.
  Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch (_) {
      LogService.w(
        'ConnectivityService',
        'No internet connection (SocketException)',
      );
      return false;
    } catch (e) {
      LogService.e('ConnectivityService', 'Connectivity check failed', e);
      return false;
    }
  }
}
