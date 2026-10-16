import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scrip_master.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';
import 'log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedUnderlying;
  String? selectedExpiry;
  String? selectedType = 'CE';

  @override
  Widget build(BuildContext context) {
    final scrip = context.watch<ScripMasterService>();
    final hasData = scrip.rows.isNotEmpty;
    final isDemo = scrip.usedOfflineFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dhan Option OI Profile'),
        actions: [
          IconButton(
            tooltip: 'App Log',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status + Connect / Retry button
            _ConnectionCard(
              isLoading: scrip.isLoading,
              hasData: hasData,
              isDemo: scrip.usedOfflineFallback,
              error: scrip.error,
              instrumentCount: scrip.rows.length,
              onConnect: () => context.read<ScripMasterService>().load(),
            ),
            const SizedBox(height: 20),

            if (hasData) ...[
              const Text(
                'Select Option Contract',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedUnderlying,
                decoration: const InputDecoration(
                  labelText: 'Underlying',
                  border: OutlineInputBorder(),
                ),
                items: scrip
                    .getAvailableUnderlyings()
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    selectedUnderlying = v;
                    selectedExpiry = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              if (selectedUnderlying != null)
                DropdownButtonFormField<String>(
                  value: selectedExpiry,
                  decoration: const InputDecoration(
                    labelText: 'Expiry',
                    border: OutlineInputBorder(),
                  ),
                  items: scrip
                      .getExpiries(selectedUnderlying!)
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedExpiry = v),
                ),
              const SizedBox(height: 12),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'CE', label: Text('CALL')),
                  ButtonSegment(value: 'PE', label: Text('PUT')),
                ],
                selected: {selectedType!},
                onSelectionChanged: (s) =>
                    setState(() => selectedType = s.first),
              ),
              const SizedBox(height: 12),

              if (selectedUnderlying != null && selectedExpiry != null)
                Expanded(
                  child: _StrikeList(
                    underlying: selectedUnderlying!,
                    expiry: selectedExpiry!,
                    type: selectedType!,
                    onSelected: (contract) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChartScreen(contract: contract),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final bool isLoading;
  final bool hasData;
  final bool isDemo;
  final String? error;
  final int instrumentCount;
  final VoidCallback onConnect;

  const _ConnectionCard({
    required this.isLoading,
    required this.hasData,
    this.isDemo = false,
    required this.error,
    required this.instrumentCount,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isLoading) {
      statusColor = Colors.orange;
      statusText = 'Connecting to Dhan…';
      statusIcon = Icons.sync;
    } else if (hasData && isDemo) {
      statusColor = Colors.amber;
      statusText = 'Demo mode · $instrumentCount sample contracts';
      statusIcon = Icons.warning_amber;
    } else if (hasData) {
      statusColor = Colors.greenAccent;
      statusText = 'Connected · $instrumentCount instruments';
      statusIcon = Icons.check_circle;
    } else if (error != null) {
      statusColor = Colors.redAccent;
      statusText = 'Connection failed';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.grey;
      statusText = 'Not connected';
      statusIcon = Icons.cloud_off;
    }

    return Card(
      color: const Color(0xFF121826),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (error != null && !isLoading) ...[
              const SizedBox(height: 10),
              Text(
                _friendlyError(error!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onConnect,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasData ? Icons.refresh : Icons.play_arrow),
              label: Text(
                isLoading
                    ? 'Connecting…'
                    : hasData
                        ? 'Reconnect'
                        : 'Start Connection',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasData
                    ? Colors.blueGrey
                    : const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('Failed host lookup') ||
        raw.contains('SocketException') ||
        raw.contains('No address associated')) {
      return 'No internet / DNS error.\n'
          'Check Wi‑Fi or mobile data, then tap Start Connection again.\n'
          'Tip: open Chrome and try api.dhan.co';
    }
    if (raw.length > 180) return '${raw.substring(0, 180)}…';
    return raw;
  }
}

class _StrikeList extends StatelessWidget {
  final String underlying;
  final String expiry;
  final String type;
  final void Function(dynamic) onSelected;

  const _StrikeList({
    required this.underlying,
    required this.expiry,
    required this.type,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final contracts = context.read<ScripMasterService>().getIndexOptions(
          underlying: underlying,
          expiry: expiry,
          optionType: type,
        );

    contracts.sort((a, b) => a.strike.compareTo(b.strike));

    if (contracts.isEmpty) {
      return const Center(
        child: Text('No contracts found for this selection'),
      );
    }

    return ListView.builder(
      itemCount: contracts.length,
      itemBuilder: (ctx, i) {
        final c = contracts[i];
        return ListTile(
          title: Text('${c.strike} $type'),
          subtitle: Text(c.tradingSymbol),
          trailing: const Icon(Icons.candlestick_chart),
          onTap: () => onSelected(c),
        );
      },
    );
  }
}
