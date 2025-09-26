// lib/screens/news_webview_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/constants.dart';

class NewsWebviewScreen extends StatefulWidget {
  final String url;
  const NewsWebviewScreen({super.key, required this.url});

  @override
  State<NewsWebviewScreen> createState() => _NewsWebviewScreenState();
}

class _NewsWebviewScreenState extends State<NewsWebviewScreen> {
  late final WebViewController _controller;
  var _loadingPercentage = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() { _loadingPercentage = 0; });
          },
          onProgress: (progress) {
            setState(() { _loadingPercentage = progress; });
          },
          onPageFinished: (url) {
            setState(() { _loadingPercentage = 100; });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Article'),
        backgroundColor: AppColors.card,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadingPercentage < 100)
            LinearProgressIndicator(
              value: _loadingPercentage / 100.0,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.buy),
            ),
        ],
      ),
    );
  }
}