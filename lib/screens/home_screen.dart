import 'package:flutter/material.dart';
import '../models/scheme.dart';
import '../services/mf_api_service.dart';
import '../state/app_state.dart';
import 'scheme_detail_screen.dart';
import 'comparison_screen.dart';
import 'category_browse_screen.dart';
import 'goal_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _service = MFApiService();
  final _appState = AppState();

  List<Scheme> _allSchemes = [];
  bool _loadingAmfi = true;
  String? _amfiError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _appState.addListener(_onStateChanged);
    _loadAmfiData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  Future<void> _loadAmfiData() async {
    setState(() {
      _loadingAmfi = true;
      _amfiError = null;
    });
    try {
      final schemes = await _service.loadAmfiSchemes();
      setState(() => _allSchemes = schemes);
    } catch (_) {
      setState(
          () => _amfiError = 'Could not load fund list. Check your connection.');
    } finally {
      setState(() => _loadingAmfi = false);
    }
  }

  List<Scheme> _localSearch(String query) {
    if (query.trim().isEmpty) return [];
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return _allSchemes
        .where((s) {
          final name = s.schemeName.toLowerCase();
          return terms.every((t) => name.contains(t));
        })
        .take(10)
        .toList();
  }

  void _openScheme(Scheme scheme) {
    _appState.addRecentlyViewed(scheme);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SchemeDetailScreen(schemeCode: scheme.schemeCode)),
    ).then((_) => setState(() {}));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final compareCount = _appState.comparison.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MF Explorer'),
        centerTitle: true,
        actions: [
          if (compareCount > 0)
            Badge(
              label: Text('$compareCount'),
              child: IconButton(
                icon: const Icon(Icons.compare_arrows),
                tooltip: 'Compare',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ComparisonScreen(schemes: _appState.comparison),
                  ),
                ).then((_) => setState(() {})),
              ),
            ),
          IconButton(
            icon: Icon(
              _appState.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: _appState.isDarkMode ? 'Light mode' : 'Dark mode',
            onPressed: () => _appState.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Goal Planner',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalPlannerScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Categories'),
            Tab(icon: Icon(Icons.star_outline), text: 'Watchlist'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSearchTab(),
          _buildCategoryTab(),
          _buildWatchlistTab(),
        ],
      ),
    );
  }

  // ── Search tab ───────────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingAmfi
              ? const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Loading fund list…',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                )
              : Autocomplete<Scheme>(
                  displayStringForOption: (s) => s.schemeName,
                  optionsBuilder: (TextEditingValue value) {
                    if (value.text.trim().isEmpty) return const [];
                    return _localSearch(value.text);
                  },
                  onSelected: _openScheme,
                  fieldViewBuilder:
                      (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        hintText: 'Search funds (e.g. SBI gold direct)',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final scheme = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  leading:
                                      const Icon(Icons.show_chart, size: 18),
                                  title: Text(
                                    scheme.schemeName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => onSelected(scheme),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Expanded(child: _buildSearchBody()),
      ],
    );
  }

  Widget _buildSearchBody() {
    if (_amfiError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_amfiError!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _loadAmfiData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final recent = _appState.recentlyViewed;
    if (recent.isEmpty) {
      return const Center(child: Text('Search for a mutual fund to begin.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Recently Viewed',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...recent.map((s) => _schemeTile(s)),
      ],
    );
  }

  // ── Category tab ─────────────────────────────────────────────────────────

  Widget _buildCategoryTab() {
    if (_loadingAmfi) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_amfiError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_amfiError!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _loadAmfiData, child: const Text('Retry')),
          ],
        ),
      );
    }
    return CategoryBrowseScreen(allSchemes: _allSchemes);
  }

  // ── Watchlist tab ─────────────────────────────────────────────────────────

  Widget _buildWatchlistTab() {
    final watchlist = _appState.watchlist;
    if (watchlist.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No favourites yet.\nOpen a fund and tap the ★ to add it here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Favourites',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...watchlist.map((s) => _schemeTile(s, showStar: true)),
      ],
    );
  }

  // ── Shared tile ───────────────────────────────────────────────────────────

  Widget _schemeTile(Scheme s, {bool showStar = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.show_chart, size: 18),
        title: Text(s.schemeName,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        subtitle: s.fundHouse != null
            ? Text(s.fundHouse!, style: const TextStyle(fontSize: 11))
            : null,
        trailing: showStar
            ? IconButton(
                icon: const Icon(Icons.star, color: Colors.amber, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _appState.toggleFavourite(s)),
              )
            : const Icon(Icons.chevron_right, size: 18),
        onTap: () => _openScheme(s),
      ),
    );
  }
}
