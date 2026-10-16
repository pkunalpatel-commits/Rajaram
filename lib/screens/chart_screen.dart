import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/option_contract.dart';
import '../services/market_feed.dart';
import '../services/oi_profile_service.dart';
import '../widgets/candle_chart.dart';
import 'log_screen.dart';
import '../utils/app_log.dart';

class ChartScreen extends StatefulWidget {
  final OptionContract contract;

  const ChartScreen({super.key, required this.contract});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  bool _connecting = false;

  Future<void> _connectFeed() async {
    setState(() => _connecting = true);
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('clientId') ?? '';
    final token = prefs.getString('accessToken') ?? '';

    if (clientId.isEmpty || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set Client ID & Access Token in Settings first'),
          ),
        );
      }
      setState(() => _connecting = false);
      return;
    }

    final feed = context.read<MarketFeedService>();
    final oiService = context.read<OiProfileService>();

    feed.onTick = (ltp, oi) {
      oiService.onLiveTick(ltp, oi);
    };

    AppLog.i('Chart Start Live for ${widget.contract.securityId}');
    await feed.connect(
      clientId: clientId,
      accessToken: token,
      securityId: widget.contract.securityId,
      exchangeSegment: widget.contract.exchangeSegment,
    );

    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _disconnectFeed() async {
    await context.read<MarketFeedService>().disconnect();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    context.read<MarketFeedService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<MarketFeedService>();
    final oi = context.watch<OiProfileService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contract.displayName,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            tooltip: 'Log',
            icon: const Icon(Icons.article_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogScreen()),
            ),
          ),
          Icon(
            feed.isConnected ? Icons.circle : Icons.circle_outlined,
            color: feed.isConnected ? Colors.greenAccent : Colors.redAccent,
            size: 12,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Live ticker strip
          Container(
            color: const Color(0xFF121826),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('LTP', feed.ltp?.toStringAsFixed(2) ?? '--'),
                _metric('OI', feed.oi?.toString() ?? '--'),
                _metric('POC', oi.profile.poc?.toStringAsFixed(1) ?? '--'),
                _metric('Bins', oi.profile.bins.length.toString()),
              ],
            ),
          ),

          // Connect / Disconnect button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connecting
                    ? null
                    : (feed.isConnected ? _disconnectFeed : _connectFeed),
                icon: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        feed.isConnected ? Icons.stop : Icons.play_arrow,
                      ),
                label: Text(
                  _connecting
                      ? 'Connecting…'
                      : feed.isConnected
                          ? 'Disconnect Live Feed'
                          : 'Start Live Connection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: feed.isConnected
                      ? Colors.red.shade700
                      : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          if (feed.lastError != null && !feed.isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                feed.lastError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Chart + OI Profile
          Expanded(
            child: CandleChartWithOiProfile(
              contract: widget.contract,
              profile: oi.profile,
            ),
          ),

          // HOIN / LOIN chips
          if (oi.profile.highOiNodes.isNotEmpty ||
              oi.profile.lowOiNodes.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...oi.profile.highOiNodes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('HOIN ${p.toStringAsFixed(0)}'),
                        backgroundColor: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  ...oi.profile.lowOiNodes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('LOIN ${p.toStringAsFixed(0)}'),
                        backgroundColor: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
