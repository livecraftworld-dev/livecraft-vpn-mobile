import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.borderRadius,
    this.padding,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isFocused ? LiveCraftTheme.card : LiveCraftTheme.surface,
            borderRadius: radius,
            border: Border.all(
              color: _isFocused ? LiveCraftTheme.gold : LiveCraftTheme.border,
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: LiveCraftTheme.gold.withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class TvConnectButton extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;

  const TvConnectButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  State<TvConnectButton> createState() => _TvConnectButtonState();
}

class _TvConnectButtonState extends State<TvConnectButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: widget.pulseAnimation,
          builder: (context, child) {
            final scale = widget.isConnected
                ? widget.pulseAnimation.value
                : (_isFocused ? 1.06 : 1.0);

            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiveCraftTheme.surface,
                  border: Border.all(
                    color: widget.isConnected
                        ? LiveCraftTheme.activeGreen
                        : (_isFocused ? LiveCraftTheme.gold : LiveCraftTheme.primary),
                    width: _isFocused ? 4.5 : 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isConnected
                          ? LiveCraftTheme.activeGlow
                          : (_isFocused ? const Color(0x66C5A880) : Colors.transparent),
                      blurRadius: _isFocused ? 42 : 28,
                      spreadRadius: _isFocused ? 10 : 4,
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isConnecting
                      ? const CircularProgressIndicator(color: LiveCraftTheme.gold, strokeWidth: 3.5)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 68,
                              color: widget.isConnected
                                  ? LiveCraftTheme.activeGreen
                                  : (_isFocused ? LiveCraftTheme.gold : LiveCraftTheme.primary),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.isConnected ? "ОТКЛЮЧИТЬ" : "ПОДКЛЮЧИТЬ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                color: widget.isConnected
                                    ? LiveCraftTheme.activeGreen
                                    : (_isFocused ? LiveCraftTheme.gold : LiveCraftTheme.text),
                              ),
                            ),
                            if (_isFocused) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LiveCraftTheme.card,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "[ ОК ]",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: LiveCraftTheme.gold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
