import 'package:flutter/material.dart';
import '../models/scheme.dart';
import '../state/app_state.dart';
import 'scheme_detail_screen.dart';

/// Groups the AMFI scheme list by category and lets users drill in.
class CategoryBrowseScreen extends StatefulWidget {
  final List<Scheme> allSchemes;
  const CategoryBrowseScreen({super.key, required this.allSchemes});

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  late final Map<String, List<Scheme>> _byCategory;
  late final List<String> _categories;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _byCategory = {};
    for (final s in widget.allSchemes) {
      final cat = s.category ?? 'Other';
      (_byCategory[cat] ??= []).add(s);
    }
    _categories = _byCategory.keys.toList()..sort();
  }

  List<String> get _filteredCategories {
    if (_search.trim().isEmpty) return _categories;
    final q = _search.toLowerCase();
    return _categories
        .where((c) => c.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _filteredCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Browse by Category')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filter categories…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cats.length,
              itemBuilder: (ctx, i) {
                final cat = cats[i];
                final count = _byCategory[cat]!.length;
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(cat),
                  subtitle: Text('$count funds'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FundListScreen(
                        category: cat,
                        schemes: _byCategory[cat]!,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FundListScreen extends StatefulWidget {
  final String category;
  final List<Scheme> schemes;
  const _FundListScreen({required this.category, required this.schemes});

  @override
  State<_FundListScreen> createState() => _FundListScreenState();
}

class _FundListScreenState extends State<_FundListScreen> {
  final _appState = AppState();
  String _search = '';

  List<Scheme> get _filtered {
    if (_search.trim().isEmpty) return widget.schemes;
    final terms = _search.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return widget.schemes.where((s) {
      final name = s.schemeName.toLowerCase();
      return terms.every((t) => name.contains(t));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final schemes = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search in category…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: schemes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = schemes[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.show_chart, size: 18),
                  title: Text(s.schemeName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: s.fundHouse != null
                      ? Text(s.fundHouse!,
                          style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: _appState.isFavourite(s.schemeCode)
                      ? const Icon(Icons.star, size: 16, color: Colors.amber)
                      : null,
                  onTap: () {
                    _appState.addRecentlyViewed(s);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SchemeDetailScreen(schemeCode: s.schemeCode),
                      ),
                    ).then((_) => setState(() {}));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
