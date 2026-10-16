import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/option_contract.dart';
import '../services/market_feed.dart';
import '../services/oi_profile_service.dart';
import '../widgets/candle_chart.dart';

class ChartScreen extends StatefulWidget {
  final OptionContract contract;

  const ChartScreen({super.key, required this.contract});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _connectFeed();
  }

  Future<void> _connectFeed() async {
    setState(() => _connecting = true);
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('clientId') ?? '';
    final token = prefs.getString('accessToken') ?? '';

    if (clientId.isEmpty || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set Client ID & Token in Settings')),
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

    await feed.connect(
      clientId: clientId,
      accessToken: token,
      securityId: widget.contract.securityId,
      exchangeSegment: widget.contract.exchangeSegment,
    );

    setState(() => _connecting = false);
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
        title: Text(widget.contract.displayName),
        actions: [
          if (_connecting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(
              feed.isConnected ? Icons.circle : Icons.circle_outlined,
              color: feed.isConnected ? Colors.greenAccent : Colors.redAccent,
              size: 14,
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Live ticker strip
          Container(
            color: const Color(0xFF121826),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // Chart + OI Profile
          Expanded(
            child: CandleChartWithOiProfile(
              contract: widget.contract,
              profile: oi.profile,
            ),
          ),

          // HOIN / LOIN chips
          if (oi.profile.highOiNodes.isNotEmpty || oi.profile.lowOiNodes.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...oi.profile.highOiNodes.map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text('HOIN ${p.toStringAsFixed(0)}'),
                          backgroundColor: Colors.red.withOpacity(0.3),
                        ),
                      )),
                  ...oi.profile.lowOiNodes.map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text('LOIN ${p.toStringAsFixed(0)}'),
                          backgroundColor: Colors.blue.withOpacity(0.3),
                        ),
                      )),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
