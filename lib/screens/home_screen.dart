import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';
import '../theme/app_theme.dart';
import '../services/config_builder.dart';
import '../widgets/tv_focusable.dart';
import 'app_exclusions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SingboxClient _client = SingboxClient();
  
  ServerConfig _selectedServer = ServerConfig.availableServers[0]; // Amsterdam default
  bool _bypassRussian = true;
  List<String> _excludedPackages = [];
  bool _isConnected = false;
  bool _isConnecting = false;

  Timer? _timer;
  int _elapsedSeconds = 0;

  String _uploadSpeed = "0 KB/s";
  String _downloadSpeed = "0 KB/s";

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPulseAnimation();
    _loadPreferences();
    _initVpnEngine();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _bypassRussian = prefs.getBool('bypassRussian') ?? true;
        _excludedPackages = prefs.getStringList('excludedPackages') ?? [];
      });
    } catch (e) {
      debugPrint("Prefs error: $e");
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bypassRussian', _bypassRussian);
      await prefs.setStringList('excludedPackages', _excludedPackages);
    } catch (e) {
      debugPrint("Save prefs error: $e");
    }
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initVpnEngine() async {
    try {
      await _client.initialize();

      _client.faultStream.listen((fault) {
        debugPrint("Fault from sing-box core: $fault");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сбой ядра VPN: $fault'),
            backgroundColor: LiveCraftTheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      });

      _client.coreLogStream.listen((logs) {
        for (final log in logs) {
          debugPrint("[sing-box core] ${log.message}");
        }
      });

      _client.serviceStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          if (state == ServiceState.started) {
            _isConnected = true;
            _isConnecting = false;
            _startTimer();
          } else if (state == ServiceState.stopped) {
            _isConnected = false;
            _isConnecting = false;
            _stopTimer();
          } else if (state == ServiceState.starting || state == ServiceState.stopping) {
            _isConnecting = true;
          }
        });
      });

      _client.trafficStatsStream.listen((stats) {
        if (!mounted || !_isConnected) return;
        setState(() {
          _uploadSpeed = _formatBps(stats.uplinkBps);
          _downloadSpeed = _formatBps(stats.downlinkBps);
        });
      });
    } catch (e) {
      debugPrint("Init error: $e");
    }
  }

  String _formatBps(int bps) {
    final bytesPerSec = bps ~/ 8;
    if (bytesPerSec < 1024) return "$bytesPerSec B/s";
    if (bytesPerSec < 1024 * 1024) return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
    _uploadSpeed = "0 KB/s";
    _downloadSpeed = "0 KB/s";
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  Future<void> _toggleConnection() async {
    if (_isConnecting) return;

    if (_isConnected) {
      setState(() => _isConnecting = true);
      try {
        await _client.disconnect();
      } catch (e) {
        debugPrint("Disconnect error: $e");
      } finally {
        if (mounted) setState(() => _isConnecting = false);
      }
    } else {
      setState(() => _isConnecting = true);
      try {
        final hasPermission = await _client.requestVPNPermission();
        if (!hasPermission) {
          if (mounted) {
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Требуется разрешение на подключение VPN')),
            );
          }
          return;
        }

        final configJson = ConfigBuilder.buildJson(
          _selectedServer,
          bypassRussian: _bypassRussian,
          excludedPackages: _excludedPackages,
        );

        // Проверяем валидность конфигурации ядром sing-box
        try {
          await _client.checkConfig(configJson);
        } catch (configError) {
          debugPrint("Config validation error: $configError");
          if (mounted) {
            setState(() {
              _isConnecting = false;
              _isConnected = false;
            });
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: LiveCraftTheme.surface,
                title: const Text("Ошибка конфигурации", style: TextStyle(color: LiveCraftTheme.error)),
                content: SingleChildScrollView(
                  child: Text("$configError", style: const TextStyle(color: LiveCraftTheme.text, fontSize: 13)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK", style: TextStyle(color: LiveCraftTheme.primary)),
                  )
                ],
              ),
            );
          }
          return;
        }
        
        await _client.connect(
          SessionOptions(
            config: configJson,
            networkMode: NetworkMode.vpn,
            perAppProxy: _excludedPackages.isNotEmpty
                ? PerAppProxyOptions(
                    mode: PerAppProxyMode.exclude,
                    packages: _excludedPackages,
                  )
                : null,
            notification: NotificationConfig(
              title: "Live Craft VPN",
              showTrafficStats: true,
              showStopButton: true,
              stopButtonLabel: "Отключить",
            ),
          ),
        );
      } catch (e) {
        debugPrint("Connect error: $e");
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isConnected = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка подключения: $e'), backgroundColor: LiveCraftTheme.error),
          );
        }
      }
    }
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LiveCraftTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Выберите сервер подключения",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: LiveCraftTheme.text,
                ),
              ),
              const SizedBox(height: 16),
              ...ServerConfig.availableServers.map((server) {
                final isSelected = server.id == _selectedServer.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TvFocusable(
                    onTap: () {
                      Navigator.pop(context);
                      if (server.id != _selectedServer.id) {
                        setState(() => _selectedServer = server);
                        if (_isConnected) {
                          _toggleConnection().then((_) => _toggleConnection());
                        }
                      }
                    },
                    child: ListTile(
                      leading: Text(server.flag, style: const TextStyle(fontSize: 26)),
                      title: Text(
                        server.city,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                      ),
                      subtitle: Text(server.description, style: const TextStyle(color: LiveCraftTheme.subtext, fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: LiveCraftTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "● ${server.ping}",
                          style: TextStyle(
                            color: isSelected ? LiveCraftTheme.gold : LiveCraftTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTvOrLandscape = MediaQuery.of(context).orientation == Orientation.landscape ||
                            MediaQuery.of(context).size.width > 680;

    return Scaffold(
      backgroundColor: LiveCraftTheme.background,
      body: SafeArea(
        child: isTvOrLandscape
            ? _buildTvLandscapeLayout()
            : _buildMobilePortraitLayout(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Android TV / Landscape Layout (16:9 Cinema 4K Mode with D-Pad Support)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTvLandscapeLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── LEFT PANEL: Controls & Settings (50%) ─────────────────────
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Logo & TV Edition Brand Header
                  Row(
                    children: [
                      Image.asset(
                        'assets/LiveCraft_Logo.png',
                        height: 44,
                        errorBuilder: (_, __, ___) => const Text(
                          "LIVE CRAFT",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: LiveCraftTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "LIVE CRAFT VPN",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                              color: LiveCraftTheme.primary,
                            ),
                          ),
                          Text(
                            "TV Edition • Xiaomi 4K Ultra-HD",
                            style: TextStyle(
                              fontSize: 11,
                              color: LiveCraftTheme.subtext.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: LiveCraftTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: LiveCraftTheme.border),
                        ),
                        child: Text(
                          _isConnected ? "ЗАЩИЩЕНО" : "ОТКЛЮЧЕНО",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: _isConnected ? LiveCraftTheme.activeGreen : LiveCraftTheme.subtext,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Server Selector Card (Focusable)
                  TvFocusable(
                    onTap: _showServerPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(_selectedServer.flag, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${_selectedServer.name} (${_selectedServer.city})",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedServer.description,
                                  style: const TextStyle(fontSize: 11, color: LiveCraftTheme.subtext),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: LiveCraftTheme.card,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "● ${_selectedServer.ping}",
                              style: const TextStyle(color: LiveCraftTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: LiveCraftTheme.subtext, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Russian Direct Services Toggle Card (Focusable)
                  TvFocusable(
                    onTap: () {
                      setState(() => _bypassRussian = !_bypassRussian);
                      _savePreferences();
                      if (_isConnected) {
                        _toggleConnection().then((_) => _toggleConnection());
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text("🇷🇺", style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Российские сервисы напрямую",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                                ),
                                Text(
                                  "Кинопоиск, Иви, Okko, Wink без замедления",
                                  style: TextStyle(fontSize: 11, color: LiveCraftTheme.subtext),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _bypassRussian,
                            activeColor: LiveCraftTheme.primary,
                            activeTrackColor: LiveCraftTheme.border,
                            inactiveThumbColor: LiveCraftTheme.subtext,
                            inactiveTrackColor: LiveCraftTheme.surface,
                            onChanged: (val) {
                              setState(() => _bypassRussian = val);
                              _savePreferences();
                              if (_isConnected) {
                                _toggleConnection().then((_) => _toggleConnection());
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. App Exclusions Card (Focusable)
                  TvFocusable(
                    onTap: () async {
                      final result = await Navigator.push<List<String>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppExclusionsScreen(initialExcluded: _excludedPackages),
                        ),
                      );
                      if (result != null) {
                        setState(() => _excludedPackages = result);
                        await _savePreferences();
                        if (_isConnected) {
                          _toggleConnection().then((_) => _toggleConnection());
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.apps_rounded, size: 22, color: LiveCraftTheme.gold),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Исключения приложений",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                                ),
                                Text(
                                  _excludedPackages.isEmpty
                                      ? "Все приложения через VPN"
                                      : "${_excludedPackages.length} прилож. напрямую (мимо VPN)",
                                  style: const TextStyle(fontSize: 11, color: LiveCraftTheme.subtext),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _excludedPackages.isNotEmpty ? LiveCraftTheme.card : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _excludedPackages.isNotEmpty ? "${_excludedPackages.length}" : "0",
                              style: TextStyle(
                                color: _excludedPackages.isNotEmpty ? LiveCraftTheme.primary : LiveCraftTheme.subtext,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: LiveCraftTheme.subtext, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Speed Badge
                  if (_isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: LiveCraftTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LiveCraftTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16, color: LiveCraftTheme.activeGreen),
                          const SizedBox(width: 4),
                          Text(_downloadSpeed, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text)),
                          const SizedBox(width: 18),
                          const Icon(Icons.arrow_upward_rounded, size: 16, color: LiveCraftTheme.gold),
                          const SizedBox(width: 4),
                          Text(_uploadSpeed, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 48),

          // ── RIGHT PANEL: Central Button & Big Status (50%) ─────────────
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Connection Duration Timer
                Text(
                  _formatDuration(_elapsedSeconds),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                    color: _isConnected ? LiveCraftTheme.activeGreen : LiveCraftTheme.subtext,
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Status text
                Text(
                  _isConnected
                      ? "● Защита активна (${_selectedServer.city})"
                      : (_isConnecting ? "Подключение к туннелю..." : "Нажмите [ОК] на пульте для защиты"),
                  style: const TextStyle(
                    fontSize: 13,
                    color: LiveCraftTheme.subtext,
                  ),
                ),

                const SizedBox(height: 32),

                // 3. Big Central TV Connect Button
                TvConnectButton(
                  isConnected: _isConnected,
                  isConnecting: _isConnecting,
                  onTap: _toggleConnection,
                  pulseAnimation: _pulseAnimation,
                ),

                const SizedBox(height: 32),

                const Text(
                  "Botanicco Group • Интеллектуальный ТВ шлюз 4K",
                  style: TextStyle(fontSize: 11, color: Color(0xFF454D47)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Mobile Portrait Layout (Classic Smartphone View)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobilePortraitLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // 1. Header with Brand Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/LiveCraft_Logo.png',
                height: 38,
                errorBuilder: (_, __, ___) => const Text(
                  "LIVE CRAFT",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: LiveCraftTheme.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: LiveCraftTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LiveCraftTheme.border),
                ),
                child: Text(
                  _isConnected ? "ЗАЩИЩЕНО" : "ОТКЛЮЧЕНО",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: _isConnected ? LiveCraftTheme.activeGreen : LiveCraftTheme.subtext,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 2. Timer & Status Display
          Text(
            _formatDuration(_elapsedSeconds),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'monospace',
              color: _isConnected ? LiveCraftTheme.activeGreen : LiveCraftTheme.subtext,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isConnected
                ? "● Защита активна (${_selectedServer.city})"
                : (_isConnecting ? "Подключение к туннелю..." : "Нажмите для защиты соединения"),
            style: const TextStyle(
              fontSize: 13,
              color: LiveCraftTheme.subtext,
            ),
          ),

          const SizedBox(height: 36),

          // 3. Central Glowing Action Button
          TvConnectButton(
            isConnected: _isConnected,
            isConnecting: _isConnecting,
            onTap: _toggleConnection,
            pulseAnimation: _pulseAnimation,
          ),

          const SizedBox(height: 36),

          // 4. Live Speed Stats Badge
          if (_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: LiveCraftTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LiveCraftTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 16, color: LiveCraftTheme.activeGreen),
                  const SizedBox(width: 4),
                  Text(_downloadSpeed, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text)),
                  const SizedBox(width: 20),
                  const Icon(Icons.arrow_upward_rounded, size: 16, color: LiveCraftTheme.gold),
                  const SizedBox(width: 4),
                  Text(_uploadSpeed, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text)),
                ],
              ),
            ),

          const Spacer(),

          // 5. Server Selector Card
          TvFocusable(
            onTap: _showServerPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(_selectedServer.flag, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_selectedServer.name} (${_selectedServer.city})",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedServer.description,
                          style: const TextStyle(fontSize: 11, color: LiveCraftTheme.subtext),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LiveCraftTheme.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "● ${_selectedServer.ping}",
                      style: const TextStyle(color: LiveCraftTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: LiveCraftTheme.subtext, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 6. Russian Direct Sites Toggle Card
          TvFocusable(
            onTap: () {
              setState(() => _bypassRussian = !_bypassRussian);
              _savePreferences();
              if (_isConnected) {
                _toggleConnection().then((_) => _toggleConnection());
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text("🇷🇺", style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Российские сайты напрямую",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                        ),
                        Text(
                          "Сбер, Госуслуги, банки без замедления",
                          style: TextStyle(fontSize: 10, color: LiveCraftTheme.subtext),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _bypassRussian,
                    activeColor: LiveCraftTheme.primary,
                    activeTrackColor: LiveCraftTheme.border,
                    inactiveThumbColor: LiveCraftTheme.subtext,
                    inactiveTrackColor: LiveCraftTheme.surface,
                    onChanged: (val) {
                      setState(() => _bypassRussian = val);
                      _savePreferences();
                      if (_isConnected) {
                        _toggleConnection().then((_) => _toggleConnection());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 7. App Exclusions Card
          TvFocusable(
            onTap: () async {
              final result = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (context) => AppExclusionsScreen(initialExcluded: _excludedPackages),
                ),
              );
              if (result != null) {
                setState(() => _excludedPackages = result);
                await _savePreferences();
                if (_isConnected) {
                  _toggleConnection().then((_) => _toggleConnection());
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.apps_rounded, size: 20, color: LiveCraftTheme.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Исключения приложений",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveCraftTheme.text),
                        ),
                        Text(
                          _excludedPackages.isEmpty
                              ? "Все приложения через VPN"
                              : "${_excludedPackages.length} прилож. напрямую (мимо VPN)",
                          style: const TextStyle(fontSize: 10, color: LiveCraftTheme.subtext),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _excludedPackages.isNotEmpty ? LiveCraftTheme.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _excludedPackages.isNotEmpty ? "${_excludedPackages.length}" : "0",
                      style: TextStyle(
                        color: _excludedPackages.isNotEmpty ? LiveCraftTheme.primary : LiveCraftTheme.subtext,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: LiveCraftTheme.subtext, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            "ООО «ЛайвКрафт» • Защищенная корпоративная сеть",
            style: TextStyle(fontSize: 10, color: Color(0xFF454D47)),
          ),
        ],
      ),
    );
  }
}
