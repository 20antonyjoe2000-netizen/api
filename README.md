# MF Explorer — Indian Mutual Fund App

A clean, feature-rich Flutter Android app for exploring Indian mutual fund data powered by the free [mfapi.in](https://mfapi.in) API. No login required — just install and start exploring.

---

## Download

> **[Download latest APK](https://github.com/20antonyjoe2000-netizen/api/releases/latest/download/mf-explorer.apk)**

Install directly on any Android device (Android 5.0+). You may need to enable *"Install from unknown sources"* in your device settings.

---

## Features

| Feature | Description |
|---|---|
| **Smart Search** | Instant autocomplete search across 40,000+ mutual fund schemes loaded from AMFI |
| **Fund Details** | Fund house, scheme type, category, ISIN, and current NAV at a glance |
| **NAV History Chart** | Interactive line chart with 1M / 3M / 6M / 1Y / All range filters |
| **Fund Comparison** | Compare up to 3 funds side-by-side, normalized to 100 for fair comparison |
| **SIP Calculator** | Simulate monthly SIP returns against real historical NAV data |
| **Goal Planner** | Enter a target corpus and get the required monthly SIP amount |
| **Browse by Category** | Browse all funds grouped by SEBI category (Equity, Debt, Hybrid, etc.) |
| **Watchlist** | Star any fund to save it to your personal favourites tab |
| **Recently Viewed** | Quick access to funds you've browsed recently |
| **Share Chart** | Share a snapshot of any fund's NAV chart |

---

## Screenshots

> *(Install the APK to see the app in action)*

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Android) |
| Language | Dart |
| HTTP | [`http`](https://pub.dev/packages/http) |
| Charts | [`fl_chart`](https://pub.dev/packages/fl_chart) |
| Date formatting | [`intl`](https://pub.dev/packages/intl) |
| Share | [`share_plus`](https://pub.dev/packages/share_plus) |
| Data source | [mfapi.in](https://mfapi.in) + [AMFI NAVAll.txt](https://portal.amfiindia.com/spages/NAVAll.txt) |

---

## API

All data is fetched live from two public, free APIs — no API key required:

| Source | Used for |
|---|---|
| `https://api.mfapi.in/mf/{code}` | NAV history, fund metadata |
| `https://api.mfapi.in/mf/{code}/latest` | Latest NAV |
| `https://portal.amfiindia.com/spages/NAVAll.txt` | Full scheme list with categories |

---

## Build from Source

### Prerequisites

- Flutter SDK 3.x ([install guide](https://docs.flutter.dev/get-started/install))
- Android SDK with build tools (via Android Studio or command line)
- Java 17+

### Steps

```bash
# Clone the repo
git clone https://github.com/20antonyjoe2000-netizen/api.git
cd api

# Install dependencies
flutter pub get

# Run on a connected device / emulator
flutter run

# Build a release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
lib/
  main.dart                        # App entry point, MaterialApp setup
  screens/
    home_screen.dart               # Search, Categories, Watchlist tabs
    scheme_detail_screen.dart      # Fund metadata + NAV chart + share
    comparison_screen.dart         # Side-by-side fund comparison chart
    sip_calculator_screen.dart     # Historical SIP simulator
    goal_planner_screen.dart       # Target corpus → monthly SIP
    category_browse_screen.dart    # SEBI category drill-down
  services/
    mf_api_service.dart            # All HTTP calls (AMFI + mfapi.in)
  models/
    scheme.dart                    # schemeCode, schemeName, category, fundHouse
    scheme_detail.dart             # meta + navHistory
    nav_entry.dart                 # date (DateTime) + nav (double)
  state/
    app_state.dart                 # Singleton ChangeNotifier: watchlist, recents, comparison
```

---

## Notes

- Fund list is loaded once from AMFI at startup and cached in memory.
- NAV history from the API is in reverse-chronological order; the app reverses it before plotting.
- All dates from the API are in `DD-MM-YYYY` format.
- No local database — all data is fetched fresh each session.
- The app is read-only. It does not support transactions, portfolio tracking, or any form of account access.

---

## License

MIT — free to use, modify, and distribute.
