import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scrip_master.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedUnderlying;
  String? selectedExpiry;
  String? selectedType = 'CE';
  double? selectedStrike;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScripMasterService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrip = context.watch<ScripMasterService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dhan Option OI Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: scrip.isLoading
          ? const Center(child: CircularProgressIndicator())
          : scrip.error != null
              ? Center(child: Text('Error: ${scrip.error}'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Option Contract',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Underlying
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
                            selectedStrike = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Expiry
                      if (selectedUnderlying != null)
                        DropdownButtonFormField<String>(
                          value: selectedExpiry,
                          decoration: const InputDecoration(
                            labelText: 'Expiry',
                            border: OutlineInputBorder(),
                          ),
                          items: scrip
                              .getExpiries(selectedUnderlying!)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedExpiry = v),
                        ),
                      const SizedBox(height: 12),

                      // CE / PE
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

                      // Strike list
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
                  ),
                ),
    );
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

    // Sort by strike
    contracts.sort((a, b) => a.strike.compareTo(b.strike));

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
