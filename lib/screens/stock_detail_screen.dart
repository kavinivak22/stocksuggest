// lib/screens/stock_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../utils/constants.dart';
import '../widgets/analysis_gauge.dart';
import 'news_webview_screen.dart';

// Helper classes
class ChartData {
  ChartData(this.x, this.open, this.high, this.low, this.close, this.volume);
  final DateTime x;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
}

class NewsArticle {
  final String title;
  final String url;
  NewsArticle({required this.title, required this.url});
}

class AnalysisFactor {
  final String text;
  final String type; // 'buy', 'sell', 'neutral'
  AnalysisFactor({required this.text, required this.type});
}

class StockDetailScreen extends StatefulWidget {
  final String stockSymbol;
  const StockDetailScreen({super.key, required this.stockSymbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  // State variables
  List<ChartData>? _chartData;
  List<AnalysisFactor> _analysisFactors = [];
  double _finalScore = 0;
  ChartData? _latestOhlcv;
  List<NewsArticle> _newsArticles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeData();
  }
  
  // Calculation methods
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

  List<double> _calculateSma(List<double> prices, int period) {
    List<double> sma = [];
    if (prices.length < period) return sma;
    double sum = prices.sublist(0, period).reduce((a, b) => a + b);
    sma.add(sum / period);
    for (int i = period; i < prices.length; i++) {
      sum += prices[i] - prices[i - period];
      sma.add(sum / period);
    }
    return sma;
  }
  
  Map<String, List<double>> _calculateBollingerBands(List<double> prices, int period, int stdDevFactor) {
    if (prices.length < period) return {'middle': [], 'upper': [], 'lower': []};
    final middleBand = _calculateSma(prices, period);
    List<double> upperBand = [];
    List<double> lowerBand = [];
    List<double> alignedSma = List.filled(period - 1, 0.0, growable: true)..addAll(middleBand);
    for (int i = period - 1; i < prices.length; i++) {
      final slice = prices.sublist(i - period + 1, i + 1);
      final mean = alignedSma[i];
      final sumOfSquares = slice.map((price) => (price - mean) * (price - mean)).reduce((a,b) => a+b);
      final stdDev = (sumOfSquares / period);
      upperBand.add(mean + (stdDevFactor * stdDev));
      lowerBand.add(mean - (stdDevFactor * stdDev));
    }
    return {'middle': middleBand, 'upper': upperBand, 'lower': lowerBand};
  }

  Future<void> _fetchAndAnalyzeData() async {
    try {
      const newsApiKey = 'f679f4146df84dc49b0c379a7bbefdf5';

      // Fetch stock data and news data at the same time
      final responses = await Future.wait([
        http.get(Uri.parse('/.netlify/functions/yahoo?ticker=${widget.stockSymbol}.NS')), // <-- CORRECTED THIS LINE
        http.get(Uri.parse('https://newsapi.org/v2/everything?q=${widget.stockSymbol}&sortBy=publishedAt&language=en&pageSize=5&apiKey=$newsApiKey'))
      ]);
      
      final stockResponse = responses[0];
      if (stockResponse.statusCode != 200) throw Exception('Failed to load stock data.');
      final stockData = json.decode(stockResponse.body);
      if (stockData['chart']['result'] == null) throw Exception('No stock data found.');
      
      final timestamps = (stockData['chart']['result'][0]['timestamp'] as List<dynamic>).cast<int>();
      final quotes = stockData['chart']['result'][0]['indicators']['quote'][0];
      final List<double> closes = (quotes['close'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
      final List<double> opens = (quotes['open'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
      final List<double> highs = (quotes['high'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
      final List<double> lows = (quotes['low'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
      final List<double> volumes = (quotes['volume'] as List<dynamic>).map((p) => p == null ? 0.0 : (p as num).toDouble()).toList();
      
      final List<ChartData> tempChartData = [];
      for (int i = 0; i < timestamps.length; i++) {
        tempChartData.add(ChartData(DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000), opens[i], highs[i], lows[i], closes[i], volumes[i]));
      }
      
      if (closes.length < 34) throw Exception('Insufficient data for analysis.');
      
      final newsResponse = responses[1];
      List<NewsArticle> tempNews = [];
      if (newsResponse.statusCode == 200) {
        final newsData = json.decode(newsResponse.body);
        tempNews = (newsData['articles'] as List).map((article) => NewsArticle(title: article['title'], url: article['url'])).toList();
      }

      double buyScore = 0, sellScore = 0;
      List<AnalysisFactor> factors = [];
      final macdValues = _getLatestMacd(closes, 12, 26, 9);
      if (macdValues['prev_macd']! < macdValues['prev_signal']! && macdValues['macd']! > macdValues['signal']!) {
        buyScore += 1.5;
        factors.add(AnalysisFactor(text: "MACD crossover suggests positive momentum.", type: 'buy'));
      }
      if (macdValues['prev_macd']! > macdValues['prev_signal']! && macdValues['macd']! < macdValues['signal']!) {
        sellScore += 1.5;
        factors.add(AnalysisFactor(text: "MACD crossover suggests negative momentum.", type: 'sell'));
      }
      final latestRsi = _calculateRsi(closes, 14);
      if (latestRsi < 35) { buyScore += 1; factors.add(AnalysisFactor(text: "RSI is low (${latestRsi.toStringAsFixed(1)}), suggesting the stock may be oversold.", type: 'buy')); }
      if (latestRsi > 65) { sellScore += 1; factors.add(AnalysisFactor(text: "RSI is high (${latestRsi.toStringAsFixed(1)}), suggesting the stock may be overbought.", type: 'sell')); }
      final bb = _calculateBollingerBands(closes, 20, 2);
      final lastClose = closes.last;
      if(bb['lower']!.isNotEmpty && lastClose <= bb['lower']!.last) {
        buyScore += 1;
        factors.add(AnalysisFactor(text: "Price is touching the lower Bollinger Band.", type: 'buy'));
      }
      if(bb['upper']!.isNotEmpty && lastClose >= bb['upper']!.last) {
        sellScore += 1;
        factors.add(AnalysisFactor(text: "Price is touching the upper Bollinger Band.", type: 'sell'));
      }
      final avgVolume = volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20;
      if (volumes.last > avgVolume * 1.5) {
        factors.add(AnalysisFactor(text: "Trading volume is significantly higher than average.", type: 'neutral'));
      }
      if (factors.isEmpty) factors.add(AnalysisFactor(text: "Indicators are currently neutral.", type: 'neutral'));

      setState(() {
        _chartData = tempChartData;
        _newsArticles = tempNews;
        _finalScore = buyScore - sellScore;
        _analysisFactors = factors;
        _latestOhlcv = tempChartData.last;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.stockSymbol), backgroundColor: AppColors.background, elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text))))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        AnalysisGauge(score: _finalScore),
                        const SizedBox(height: 16),
                        _buildKeyMetricsCard(_latestOhlcv!),
                        const SizedBox(height: 16),
                        _buildAnalysisFactorsCard(),
                        const SizedBox(height: 16),
                        _buildStockChart(),
                        if(_newsArticles.isNotEmpty) const SizedBox(height: 16),
                        if(_newsArticles.isNotEmpty) _buildRecentNewsCard(),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  Widget _buildKeyMetricsCard(ChartData data) {
    final format = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    final numberFormat = NumberFormat.compact();
    final change = data.close - data.open;
    final changePercent = (data.open == 0) ? 0.0 : (change / data.open) * 100;
    final changeColor = change >= 0 ? AppColors.buy : AppColors.sell;

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: changeColor.withOpacity(0.5), width: 1.5)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.stockSymbol, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(format.format(data.close), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)', style: TextStyle(color: changeColor, fontSize: 16)),
            ]),
          ]),
          const Divider(height: 24, color: Colors.white24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _metricItem('Open', format.format(data.open)),
            _metricItem('High', format.format(data.high)),
            _metricItem('Low', format.format(data.low)),
            _metricItem('Volume', numberFormat.format(data.volume)),
          ]),
        ]),
      ),
    );
  }

  Widget _metricItem(String title, String value) {
    return Column(children: [
      Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  Widget _buildAnalysisFactorsCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Analysis Factors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 16, color: Colors.white24),
          ..._analysisFactors.map((factor) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  factor.type == 'buy' ? Icons.check_circle : (factor.type == 'sell' ? Icons.remove_circle : Icons.info_outline),
                  color: factor.type == 'buy' ? AppColors.buy : (factor.type == 'sell' ? AppColors.sell : AppColors.hold),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(factor.text, style: TextStyle(color: Colors.grey[300]))),
              ],
            ),
          )).toList(),
        ]),
      ),
    );
  }

  Widget _buildStockChart() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: const DateTimeAxis(majorGridLines: MajorGridLines(width: 0)),
          primaryYAxis: const NumericAxis(isVisible: false),
          axes: <ChartAxis>[
            NumericAxis(
              name: 'yAxis', opposedPosition: true,
              majorGridLines: const MajorGridLines(width: 0.2, color: Colors.white30),
              numberFormat: NumberFormat.compact(),
            ),
          ],
          series: <CartesianSeries>[
            CandleSeries<ChartData, DateTime>(
              name: 'Price',
              dataSource: _chartData!,
              xValueMapper: (d, _) => d.x, lowValueMapper: (d, _) => d.low, highValueMapper: (d, _) => d.high,
              openValueMapper: (d, _) => d.open, closeValueMapper: (d, _) => d.close,
              yAxisName: 'yAxis',
            ),
          ],
          indicators: <TechnicalIndicator<ChartData, DateTime>>[
            BollingerBandIndicator<ChartData, DateTime>(
              seriesName: 'Price',
              yAxisName: 'yAxis',
              period: 20,
              standardDeviation: 2,
            ),
          ],
          trackballBehavior: TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap, tooltipDisplayMode: TrackballDisplayMode.groupAllPoints),
        ),
      ),
    );
  }

  Widget _buildRecentNewsCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent News', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 16, color: Colors.white24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _newsArticles.length,
            separatorBuilder: (ctx, idx) => const Divider(color: Colors.white12),
            itemBuilder: (ctx, index) {
              final article = _newsArticles[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NewsWebviewScreen(url: article.url),
                    ),
                  );
                },
              );
            },
          )
        ]),
      ),
    );
  }
}