import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/scrip_master.dart';
import 'services/market_feed.dart';
import 'services/oi_profile_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DhanOptionApp());
}

class DhanOptionApp extends StatelessWidget {
  const DhanOptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScripMasterService()),
        ChangeNotifierProvider(create: (_) => MarketFeedService()),
        ChangeNotifierProvider(create: (_) => OiProfileService()),
      ],
      child: MaterialApp(
        title: 'Dhan Option OI Profile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0A0E17),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
