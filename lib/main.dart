import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const YellowPagesApp());

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Contact {
  final String name;
  final String category;
  final String phone;
  final String address;

  /// Pre-computed lowercase text used for instant searching.
  final String _haystack;

  Contact({
    required this.name,
    required this.category,
    required this.phone,
    required this.address,
  }) : _haystack = [
          name,
          category,
          phone,
          phone.replaceAll(RegExp(r'\D'), ''), // lets "5550101" match "555-0101"
          address,
        ].join('\n').toLowerCase();

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: (json['name'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
      );

  /// Every whitespace-separated term must appear somewhere in the record.
  bool matches(List<String> terms) {
    for (final t in terms) {
      if (!_haystack.contains(t)) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class YellowPagesApp extends StatelessWidget {
  const YellowPagesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFF2B705); // directory yellow
    return MaterialApp(
      title: 'Yellow Pages',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F5F1),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const DirectoryPage(),
    );
  }
}

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final _controller = TextEditingController();
  List<Contact> _all = [];
  List<Contact> _visible = [];
  List<String> _terms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/contacts.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _all = list;
        _visible = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load contacts.json\n$e';
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    setState(() {
      _terms = terms;
      _visible =
          terms.isEmpty ? _all : _all.where((c) => c.matches(terms)).toList();
    });
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copied'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              controller: _controller,
              onChanged: _onQueryChanged,
              onClear: _clear,
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_visible.length} of ${_all.length} listings',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            Expanded(child: _buildBody(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: cs.outline),
            const SizedBox(height: 12),
            Text('No listings found',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Try a different name, category, phone or address.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _visible.length,
      itemBuilder: (context, i) {
        final c = _visible[i];
        return ContactCard(
          contact: c,
          terms: _terms,
          onCopyPhone: () => _copy(c.phone, 'Phone number'),
          onCopyAddress: () => _copy(c.address, 'Address'),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header with search bar
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Header({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'Yellow Pages',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Search name, category, phone or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: onClear,
                        ),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class ContactCard extends StatelessWidget {
  final Contact contact;
  final List<String> terms;
  final VoidCallback onCopyPhone;
  final VoidCallback onCopyAddress;

  const ContactCard({
    super.key,
    required this.contact,
    required this.terms,
    required this.onCopyPhone,
    required this.onCopyAddress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    contact.name.isEmpty
                        ? '?'
                        : contact.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Highlight(
                        text: contact.name,
                        terms: terms,
                        style: text.titleMedium!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _Highlight(
                          text: contact.category,
                          terms: terms,
                          style: text.labelMedium!
                              .copyWith(color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.phone_rounded,
              text: contact.phone,
              terms: terms,
              onTap: onCopyPhone,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.place_rounded,
              text: contact.address,
              terms: terms,
              onTap: onCopyAddress,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final List<String> terms;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.terms,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: _Highlight(
                text: text,
                terms: terms,
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search-term highlighting
// ---------------------------------------------------------------------------

class _Highlight extends StatelessWidget {
  final String text;
  final List<String> terms;
  final TextStyle style;

  const _Highlight({
    required this.text,
    required this.terms,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty || text.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    // Collect [start, end) ranges for every term occurrence.
    final ranges = <List<int>>[];
    for (final t in terms) {
      var from = 0;
      while (true) {
        final i = lower.indexOf(t, from);
        if (i < 0) break;
        ranges.add([i, i + t.length]);
        from = i + t.length;
      }
    }
    if (ranges.isEmpty) return Text(text, style: style);

    // Merge overlaps.
    ranges.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[ranges.first];
    for (final r in ranges.skip(1)) {
      if (r[0] <= merged.last[1]) {
        if (r[1] > merged.last[1]) merged.last[1] = r[1];
      } else {
        merged.add(r);
      }
    }

    final hl = style.copyWith(
      backgroundColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in merged) {
      if (r[0] > cursor) spans.add(TextSpan(text: text.substring(cursor, r[0])));
      spans.add(TextSpan(text: text.substring(r[0], r[1]), style: hl));
      cursor = r[1];
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return Text.rich(TextSpan(style: style, children: spans));
  }
}
