// lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'widgets/portfolio_list.dart';
import 'widgets/suggestions_list.dart';
import 'screens/stock_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const InsightFolioApp());
}

class InsightFolioApp extends StatelessWidget {
  const InsightFolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InsightFolio',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (userSnapshot.hasData) {
            return const PortfolioScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Map<String, dynamic>> _topPicks = [];
  bool _isLoadingPicks = true;

  final List<String> NIFTY_50_STOCKS = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'ICICIBANK', 'INFY', 'HINDUNILVR', 'BHARTIARTL',
    'ITC', 'SBIN', 'LICI', 'BAJFINANCE', 'HCLTECH', 'KOTAKBANK', 'LT', 'ASIANPAINT',
    'AXISBANK', 'MARUTI', 'SUNPHARMA', 'TITAN', 'ADANIENT', 'ONGC', 'ULTRACEMCO',
    'TATAMOTORS', 'NTPC', 'TATASTEEL', 'WIPRO', 'POWERGRID', 'M&M', 'COALINDIA'
  ];

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
    _fetchTopPicks();
  }

  // --- ANALYSIS LOGIC (moved here from detail screen) ---
  List<double> _calculateEma(List<double> prices, int period) {
    final multiplier = 2 / (period + 1);
    List<double> ema = [prices[0]];
    for (int i = 1; i < prices.length; i++) {
      ema.add((prices[i] - ema.last) * multiplier + ema.last);
    }
    return ema;
  }

  double _calculateRsi(List<double> prices, int period) {
    if (prices.length <= period) return 50.0;
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final change = prices[i] - prices[i-1];
      if (change > 0) avgGain += change;
      else avgLoss += change.abs();
    }
    avgGain /= period;
    avgLoss /= period;
    for (int i = period + 1; i < prices.length; i++) {
      final change = prices[i] - prices[i-1];
      if (change > 0) {
        avgGain = (avgGain * (period - 1) + change) / period;
        avgLoss = (avgLoss * (period - 1)) / period;
      } else {
        avgGain = (avgGain * (period - 1)) / period;
        avgLoss = (avgLoss * (period - 1) + change.abs()) / period;
      }
    }
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  Map<String, double> _getLatestMacd(List<double> prices, int fast, int slow, int signal) {
      if (prices.length < slow) return {'macd': 0, 'signal': 0, 'prev_macd': 0, 'prev_signal': 0};
      final emaFast = _calculateEma(prices, fast);
      final emaSlow = _calculateEma(prices, slow);
      final macdLine = List.generate(prices.length, (i) => emaFast[i] - emaSlow[i]);
      final signalLine = _calculateEma(macdLine, signal);
      return {'macd': macdLine.last, 'signal': signalLine.last, 'prev_macd': macdLine[macdLine.length-2], 'prev_signal': signalLine[signalLine.length-2]};
  }

  Future<Map<String, dynamic>> getAdvancedAnalysis(List<double> closes, List<double> opens) async {
      double buyScore = 0, sellScore = 0;
      List<String> reasons = [];
      // (Analysis logic is the same as before)
      final macdValues = _getLatestMacd(closes, 12, 26, 9);
      if (macdValues['prev_macd']! < macdValues['prev_signal']! && macdValues['macd']! > macdValues['signal']!) {
          buyScore += 1.5;
          reasons.add("MACD crossover suggests positive momentum.");
      }
      if (macdValues['prev_macd']! > macdValues['prev_signal']! && macdValues['macd']! < macdValues['signal']!) {
          sellScore += 1.5;
          reasons.add("MACD crossover suggests negative momentum.");
      }
      final latestRsi = _calculateRsi(closes, 14);
      if (latestRsi < 35) { buyScore += 1; reasons.add("RSI is low, suggesting it may be oversold."); }
      if (latestRsi > 65) { sellScore += 1; reasons.add("RSI is high, suggesting it may be overbought."); }
      
      String finalSignal = "HOLD";
      if (buyScore >= 1.5 && buyScore > sellScore) finalSignal = "BUY";
      if (sellScore >= 1.5 && sellScore > buyScore) finalSignal = "SELL";

      return {'signal': finalSignal, 'score': buyScore, 'reason': reasons.isNotEmpty ? reasons.first : "Indicators are currently neutral."};
  }
  // -----------------------------------------------------------

  Future<void> _fetchTopPicks() async {
  final List<Map<String, dynamic>> picks = [];
  final shuffledList = List<String>.from(NIFTY_50_STOCKS)..shuffle();
  final stocksToScan = shuffledList.take(15);

  for (String ticker in stocksToScan) {
      try {
          final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$ticker.NS?range=100d&interval=1d');
          final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
          if (response.statusCode != 200) continue;
          
          final data = json.decode(response.body);
          if (data['chart']['result'] == null || data['chart']['result'][0]['timestamp'] == null) continue;

          final quotes = data['chart']['result'][0]['indicators']['quote'][0];
          final closes = (quotes['close'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
          final opens = (quotes['open'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();

          if (closes.length < 34) continue;

          final analysis = await getAdvancedAnalysis(closes, opens);

          // --- THIS IS THE CHANGED LOGIC ---
          // Instead of only looking for "BUY", we'll consider any stock
          // with a positive score, making it more likely to find suggestions.
          if (analysis['score'] > 0.5) { 
            picks.add({'ticker': ticker, 'score': analysis['score'], 'reason': analysis['reason']});
          }
          // ------------------------------------

      } catch (e) {
          print("Could not analyze $ticker: $e");
      }
  }

  picks.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  if (mounted) {
    setState(() {
      _topPicks = picks.take(5).toList();
      _isLoadingPicks = false;
    });
  }
}

  void _setupPushNotifications() async { /* ... same as before ... */ }
  void _showAddStockDialog() { /* ... same as before ... */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InsightFolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () { FirebaseAuth.instance.signOut(); },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLoadingPicks
              ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Scanning for top picks...')))
              : SuggestionsList(picks: _topPicks, lastUpdated: DateTime.now()),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('My Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: const PortfolioList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStockDialog,
        tooltip: 'Add Stock',
        child: const Icon(Icons.add),
      ),
    );
  }
}