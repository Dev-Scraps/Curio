import 'dart:io';
import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/yt_dlp/metadata_platform.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/account.dart';

class GoogleLoginScreen extends ConsumerStatefulWidget {
  const GoogleLoginScreen({
    super.key,
    this.onLoginSuccess,
    this.forceFreshLogin = false,
  });
  final VoidCallback? onLoginSuccess;
  final bool forceFreshLogin;

  @override
  ConsumerState<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends ConsumerState<GoogleLoginScreen> {
  late final WebViewController _controller;
  bool _handled = false; // prevent multiple triggers
  bool _showFetchingScreen = false; // show fetching screen instead of YouTube
  bool _loggedOut = false; // track if logout was done for fresh login

  @override
  void initState() {
    super.initState();

    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: _onPageFinished),
      );

    // Clear cookies and cache only if forcing fresh login
    if (widget.forceFreshLogin) {
      debugPrint('[GoogleLoginScreen] Forcing logout for fresh login...');
      _controller.clearCache();

      // Clear cookies using JavaScript
      await _controller.runJavaScript('''
        document.cookie.split(";").forEach(function(c) { 
          document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/");
        });
      ''');

      // Load logout URL first
      _controller.loadRequest(Uri.parse('https://accounts.google.com/Logout'));
    } else {
      // Load login URL directly
      _controller.loadRequest(
        Uri.parse(
          'https://accounts.google.com/ServiceLogin'
          '?service=youtube&continue=https://www.youtube.com',
        ),
      );
    }
  }

  void _onPageFinished(String url) {
    if (_handled) return;

    // If forcing fresh login and logout hasn't been done, check if logout page loaded
    if (widget.forceFreshLogin && !_loggedOut) {
      _loggedOut = true;
      debugPrint(
        '[GoogleLoginScreen] Logout complete, now loading login page...',
      );
      _controller.loadRequest(
        Uri.parse(
          'https://accounts.google.com/ServiceLogin'
          '?service=youtube&continue=https://www.youtube.com',
        ),
      );
      return;
    }

    final isYoutube =
        url.contains('youtube.com') && !url.contains('accounts.google.com');

    if (isYoutube) {
      _handled = true;
      debugPrint('[GoogleLoginScreen] Detected YouTube page: $url');

      // Show fetching screen instead of YouTube
      setState(() {
        _showFetchingScreen = true;
      });

      _handleSuccessfulLogin();
    }
  }

  Future<void> _handleSuccessfulLogin() async {
    try {
      debugPrint('[GoogleLoginScreen] Starting cookie extraction...');

      // Wait longer for cookies to be stored (3 seconds)
      await Future.delayed(const Duration(seconds: 3));
      debugPrint(
        '[GoogleLoginScreen] After 3s delay, attempting to extract cookies...',
      );

      final ytDlp = YtDlpMetadataPlatformService();

      // Try multiple times to get cookies
      String cookies = '';
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('[GoogleLoginScreen] Attempt $attempt to get cookies...');
        cookies = await ytDlp.getCookies('https://www.youtube.com');

        if (cookies.isNotEmpty) {
          debugPrint(
            '[GoogleLoginScreen] ✓ Got cookies on attempt $attempt: ${cookies.length} bytes',
          );
          break;
        }

        debugPrint(
          '[GoogleLoginScreen] No cookies on attempt $attempt, waiting 2s...',
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      if (cookies.isEmpty) {
        debugPrint(
          '[GoogleLoginScreen] ✗ FAILED: No cookies extracted after 3 attempts!',
        );
        debugPrint('[GoogleLoginScreen] Returning to login page...');
        _handled = false;
        return;
      }

      debugPrint(
        '[GoogleLoginScreen] ✓ Cookies extracted: ${cookies.length} bytes',
      );

      // Save cookies to file
      final appDir = await getApplicationSupportDirectory();
      final cookiesDir = Directory(p.join(appDir.path, 'cookies'));
      await cookiesDir.create(recursive: true);

      final id = 'account_${DateTime.now().millisecondsSinceEpoch}';
      final cookiePath = p.join(cookiesDir.path, '$id.txt');

      final formatted = _formatCookiesForYtDlp(cookies);
      await File(cookiePath).writeAsString(formatted);
      debugPrint('[GoogleLoginScreen] Cookies saved to: $cookiePath');

      // Create account
      final account = Account(
        id: id,
        name: 'Connecting...',
        email: '',
        avatarUrl: '',
        cookiePath: cookiePath,
      );

      debugPrint('[GoogleLoginScreen] Adding account...');
      await ref.read(syncServiceProvider.notifier).addAccount(account);

      debugPrint('[GoogleLoginScreen] Starting profile update...');
      ref.read(syncServiceProvider.notifier).updateUserProfile();

      widget.onLoginSuccess?.call();
      if (mounted) {
        debugPrint('[GoogleLoginScreen] Closing login screen...');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[GoogleLoginScreen] ✗ Login error: $e');
      _handled = false;
    }
  }

  String _formatCookiesForYtDlp(String raw) {
    final lines = ['# Netscape HTTP Cookie File'];
    for (final c in raw.split(';')) {
      final p = c.trim().split('=');
      if (p.length == 2) {
        lines.add('.youtube.com\tTRUE\t/\tFALSE\t0\t${p[0]}\t${p[1]}');
      }
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showFetchingScreen ? 'Fetching Cookies...' : 'Sign in to Google',
        ),
        centerTitle: true,
      ),
      body: _showFetchingScreen
          ? _buildFetchingScreen()
          : SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }

  Widget _buildFetchingScreen() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      color: isLight ? Colors.white : Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            M3CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 24),
            Text(
              'Please wait',
              style: TextStyle(
                color: isLight ? Colors.black : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
