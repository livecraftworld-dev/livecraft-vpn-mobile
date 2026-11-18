import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';

class AppExclusionsScreen extends StatefulWidget {
  final List<String> initialExcluded;

  const AppExclusionsScreen({
    super.key,
    required this.initialExcluded,
  });

  @override
  State<AppExclusionsScreen> createState() => _AppExclusionsScreenState();
}

class _AppExclusionsScreenState extends State<AppExclusionsScreen> {
  List<AppInfo> _apps = [];
  bool _isLoading = true;
  String? _error;

  late Set<String> _selectedPackages;
  String _searchQuery = "";
  bool _showOnlySelected = false;

  static const List<String> _bankKeywords = [
    "sber", "vtb", "tinkoff", "tbank", "alfa", "gosuslugi", "gazprombank",
    "raiffeisen", "ozon", "wildberries", "yandex", "dzen", "avito", "nalog",
    "mirpay", "sbp", "pochta", "mos.ru"
  ];

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set<String>.from(widget.initialExcluded);
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        withIcon: true,
      );

      // Sort alphabetically by app name
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _apps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<AppInfo> get _filteredApps {
    return _apps.where((app) {
      final matchesSearch = _searchQuery.isEmpty ||
          app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = !_showOnlySelected || _selectedPackages.contains(app.packageName);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _selectBankPresets() {
    setState(() {
      for (final app in _apps) {
        final pkg = app.packageName.toLowerCase();
        final name = app.name.toLowerCase();
        final isBankOrRu = _bankKeywords.any((kw) => pkg.contains(kw) || name.contains(kw));
        if (isBankOrRu) {
          _selectedPackages.add(app.packageName);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Выбрано ${_selectedPackages.length} приложений (Банки, Госуслуги, Сервисы)'),
        backgroundColor: LiveCraftTheme.activeGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        for (final app in _filteredApps) {
          _selectedPackages.add(app.packageName);
        }
      } else {
        if (_searchQuery.isEmpty && !_showOnlySelected) {
          _selectedPackages.clear();
        } else {
          for (final app in _filteredApps) {
            _selectedPackages.remove(app.packageName);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredApps;

    return Scaffold(
      backgroundColor: LiveCraftTheme.background,
      appBar: AppBar(
        backgroundColor: LiveCraftTheme.surface,
        elevation: 0,
        title: const Text(
          "Исключения приложений",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: LiveCraftTheme.text,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedPackages.toList()),
            child: const Text(
              "ГОТОВО",
              style: TextStyle(
                color: LiveCraftTheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                style: const TextStyle(color: LiveCraftTheme.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Поиск приложения...",
                  hintStyle: const TextStyle(color: LiveCraftTheme.subtext, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: LiveCraftTheme.subtext, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: LiveCraftTheme.subtext, size: 18),
                          onPressed: () => setState(() => _searchQuery = ""),
                        )
                      : null,
                  filled: true,
                  fillColor: LiveCraftTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: LiveCraftTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: LiveCraftTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: LiveCraftTheme.primary),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            // 2. Action Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ActionChip(
                    backgroundColor: LiveCraftTheme.surface,
                    side: const BorderSide(color: LiveCraftTheme.border),
                    avatar: const Icon(Icons.account_balance_rounded, size: 14, color: LiveCraftTheme.gold),
                    label: const Text("Банки и сервисы", style: TextStyle(fontSize: 11, color: LiveCraftTheme.text)),
                    onPressed: _selectBankPresets,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _showOnlySelected,
                    backgroundColor: LiveCraftTheme.surface,
                    selectedColor: LiveCraftTheme.card,
                    side: BorderSide(
                      color: _showOnlySelected ? LiveCraftTheme.primary : LiveCraftTheme.border,
                    ),
                    label: Text(
                      "Выбранные (${_selectedPackages.length})",
                      style: TextStyle(
                        fontSize: 11,
                        color: _showOnlySelected ? LiveCraftTheme.primary : LiveCraftTheme.text,
                        fontWeight: _showOnlySelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onSelected: (val) => setState(() => _showOnlySelected = val),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedPackages.isNotEmpty)
                    ActionChip(
                      backgroundColor: LiveCraftTheme.surface,
                      side: const BorderSide(color: LiveCraftTheme.border),
                      label: const Text("Сбросить", style: TextStyle(fontSize: 11, color: LiveCraftTheme.error)),
                      onPressed: () => _toggleAll(false),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Info banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: LiveCraftTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LiveCraftTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: LiveCraftTheme.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPackages.isEmpty
                          ? "Все приложения используют защищённый туннель"
                          : "Отмеченные приложения (${_selectedPackages.length}) идут напрямую мимо VPN",
                      style: const TextStyle(fontSize: 11, color: LiveCraftTheme.subtext),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 3. Main App List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: LiveCraftTheme.primary),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: LiveCraftTheme.error),
                                const SizedBox(height: 12),
                                Text(
                                  "Не удалось получить список приложений:\n$_error",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: LiveCraftTheme.subtext, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: LiveCraftTheme.primary),
                                  onPressed: _loadInstalledApps,
                                  child: const Text("Повторить", style: TextStyle(color: LiveCraftTheme.background)),
                                )
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                "Приложения не найдены",
                                style: TextStyle(color: LiveCraftTheme.subtext, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final app = filtered[index];
                                final isSelected = _selectedPackages.contains(app.packageName);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  child: TvFocusable(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedPackages.remove(app.packageName);
                                        } else {
                                          _selectedPackages.add(app.packageName);
                                        }
                                      });
                                    },
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      leading: app.icon != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.memory(
                                                app.icon!,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: LiveCraftTheme.border,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.android_rounded,
                                                color: LiveCraftTheme.primary,
                                                size: 20,
                                              ),
                                            ),
                                      title: Text(
                                        app.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? LiveCraftTheme.text : LiveCraftTheme.text.withOpacity(0.9),
                                        ),
                                      ),
                                      subtitle: Text(
                                        app.packageName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: LiveCraftTheme.subtext),
                                      ),
                                      trailing: Switch(
                                        value: isSelected,
                                        activeColor: LiveCraftTheme.primary,
                                        activeTrackColor: LiveCraftTheme.border,
                                        inactiveThumbColor: LiveCraftTheme.subtext,
                                        inactiveTrackColor: LiveCraftTheme.surface,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val) {
                                              _selectedPackages.add(app.packageName);
                                            } else {
                                              _selectedPackages.remove(app.packageName);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // 4. Bottom Save Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: LiveCraftTheme.surface,
                border: Border(top: BorderSide(color: LiveCraftTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiveCraftTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context, _selectedPackages.toList()),
                  child: Text(
                    "СОХРАНИТЬ (${_selectedPackages.length})",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: LiveCraftTheme.background,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
