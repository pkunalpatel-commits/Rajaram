# Dhan Option OI Profile Chart (Open Source)

Live candlestick chart for **Option Contracts** powered by **DhanHQ v2 APIs**.

### Unique Features
- **Option Premium OI Profile** (horizontal histogram on Y-axis)
  - Bins option premium into ticks (₹2 / ₹5)
  - Maps Open Interest / ΔOI to each premium level
  - Shows **OI-POC** (Point of Control)
  - Highlights **High OI Nodes (HOIN)** and **Low OI Nodes (LOIN)**
- Multi-timeframe **VWAP** (Session + Daily + Weekly)
- Previous Day OHLC levels
- Weekly High / Low
- Monthly High / Low
- Live WebSocket feed (Full packet → LTP + OI + Depth)
- Uses official scrip master:  
  `https://images.dhan.co/api-data/api-scrip-master-detailed.csv`

### Screenshots (concept)
- Candlestick of Option Premium
- Horizontal OI bars on the right of price scale
- Price lines for VWAP / PDH / PDL / Weekly / Monthly

---

## Prerequisites

1. **Dhan Account** with **Data APIs** enabled (₹399–499/month)
2. Generate **Client ID** + **Access Token** from  
   https://web.dhan.co → Profile → Access DhanHQ APIs
3. Flutter SDK ≥ 3.16 (https://docs.flutter.dev/get-started/install)
4. Android Studio / VS Code

---

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/dhan_option_oi_chart.git
cd dhan_option_oi_chart
flutter pub get
```

### Configure Credentials

Create a file `lib/config/secrets.dart` (already git-ignored):

```dart
class Secrets {
  static const String clientId = 'YOUR_CLIENT_ID';
  static const String accessToken = 'YOUR_ACCESS_TOKEN';
}
```

Or set them at runtime in the Settings screen (stored in SharedPreferences).

### Run

```bash
flutter run
# or build release APK
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## Project Structure

```
lib/
├── main.dart
├── config/
│   └── secrets.dart          # (git-ignored) put your tokens here
├── models/
│   ├── candle.dart
│   ├── option_contract.dart
│   └── oi_profile.dart
├── services/
│   ├── dhan_api.dart         # REST (historical, option chain, quotes)
│   ├── market_feed.dart      # WebSocket Full packet parser
│   ├── scrip_master.dart     # downloads & parses detailed CSV
│   └── oi_profile_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── chart_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── candle_chart.dart     # fl_chart + custom OI histogram
│   └── level_lines.dart
└── utils/
    └── vwap.dart
```

---

## How the OI Profile Works

1. Every live tick (or every 1–5 s) the current Option LTP is binned:
   ```dart
   double bin = (ltp / binSize).floor() * binSize;
   ```
2. Current OI (or ΔOI) is added to that bin.
3. POC = bin with maximum OI.
4. HOIN = bins significantly above average OI (strong support/resistance for the premium itself).
5. LOIN = low-OI zones (price tends to slice through quickly).

The horizontal histogram is drawn on the right side of the price scale using `fl_chart` CustomPaint / extra BarChart.

---

## GitHub Setup (one-time)

```bash
# after cloning or creating the folder
git init
git add .
git commit -m "Initial commit: Dhan Option OI Profile Chart"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/dhan_option_oi_chart.git
git push -u origin main
```

Add this to `.gitignore` (already included):

```
lib/config/secrets.dart
*.jks
key.properties
.dart_tool/
build/
```

---

## Roadmap / Next Steps

- [ ] Full binary WebSocket parser for all packet types
- [ ] Option Chain side panel (all strikes OI)
- [ ] Drawing tools (trendlines, Fibonacci)
- [ ] Alert on HOIN / POC touch
- [ ] Dark / Light theme toggle
- [ ] Export chart as PNG

---

## License

MIT – free for personal & commercial use.  
DhanHQ APIs remain under Dhan’s terms.

---

**Made for Indian options traders who want institutional-grade OI profiling on the option premium itself.**
