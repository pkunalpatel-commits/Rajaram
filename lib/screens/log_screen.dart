import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_log.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Log'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = AppLog.lines.join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied')),
              );
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => AppLog.clear(),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppLog.version,
        builder: (context, _, __) {
          final lines = AppLog.lines;
          if (lines.isEmpty) {
            return const Center(
              child: Text(
                'No log yet.\nTap Reconnect or Start Live Connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lines.length,
            itemBuilder: (ctx, i) {
              final line = lines[i];
              final isErr = line.contains(' E  ') ||
                  line.toLowerCase().contains('error') ||
                  line.toLowerCase().contains('fail');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: isErr ? Colors.redAccent : Colors.greenAccent.shade100,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
