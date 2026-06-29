import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PulsingSosButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const PulsingSosButton({super.key, required this.onTap, this.size = 180.0});

  @override
  State<PulsingSosButton> createState() => _PulsingSosButtonState();
}

class _PulsingSosButtonState extends State<PulsingSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onTap();
      },
      child: SizedBox(
        width: widget.size + 60,
        height: widget.size + 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Pulsing Ring 2
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final scale = 1.0 + (_animationController.value * 0.35);
                final opacity = 0.25 * (1.0 - _animationController.value);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF1744).withOpacity(opacity),
                    ),
                  ),
                );
              },
            ),
            // Inner Pulsing Ring 1
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final scale =
                    1.0 + ((_animationController.value + 0.5) % 1.0 * 0.25);
                final opacity =
                    0.4 * (1.0 - ((_animationController.value + 0.5) % 1.0));
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF5252).withOpacity(opacity),
                    ),
                  ),
                );
              },
            ),
            // The Main Button
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF1744), // Neon Red
                    Color(0xFFB71C1C), // Deep Crimson
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gavel_rounded, // Visual indicator for crime/SOS
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOS BEGAL!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          const Shadow(
                            blurRadius: 10.0,
                            color: Colors.black45,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TEKAN DARURAT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
