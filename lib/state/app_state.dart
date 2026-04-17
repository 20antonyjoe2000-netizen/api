import 'package:flutter/foundation.dart';
import '../models/scheme.dart';

/// Simple in-memory app state (singleton ChangeNotifier).
/// Screens call setState() after mutations, or use ListenableBuilder.
class AppState extends ChangeNotifier {
  static final AppState _i = AppState._();
  factory AppState() => _i;
  AppState._();

  // ── Recently viewed ────────────────────────────────────────────────────────
  final List<Scheme> _recent = [];
  List<Scheme> get recentlyViewed => List.unmodifiable(_recent);

  void addRecentlyViewed(Scheme scheme) {
    _recent.removeWhere((s) => s.schemeCode == scheme.schemeCode);
    _recent.insert(0, scheme);
    if (_recent.length > 15) _recent.removeLast();
    notifyListeners();
  }

  // ── Watchlist / Favourites ─────────────────────────────────────────────────
  final Map<int, Scheme> _favs = {};
  List<Scheme> get watchlist => _favs.values.toList();

  void toggleFavourite(Scheme scheme) {
    if (_favs.containsKey(scheme.schemeCode)) {
      _favs.remove(scheme.schemeCode);
    } else {
      _favs[scheme.schemeCode] = scheme;
    }
    notifyListeners();
  }

  bool isFavourite(int schemeCode) => _favs.containsKey(schemeCode);

  // ── Comparison basket (max 3) ──────────────────────────────────────────────
  final List<Scheme> _comparison = [];
  List<Scheme> get comparison => List.unmodifiable(_comparison);

  bool inComparison(int schemeCode) =>
      _comparison.any((s) => s.schemeCode == schemeCode);

  /// Returns false if already full (3 funds).
  bool addToComparison(Scheme scheme) {
    if (_comparison.length >= 3 || inComparison(scheme.schemeCode)) {
      return false;
    }
    _comparison.add(scheme);
    notifyListeners();
    return true;
  }

  void removeFromComparison(int schemeCode) {
    _comparison.removeWhere((s) => s.schemeCode == schemeCode);
    notifyListeners();
  }

  void clearComparison() {
    _comparison.clear();
    notifyListeners();
  }
}
