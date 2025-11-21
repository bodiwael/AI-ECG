import 'package:flutter/material.dart';

class AnimatedHeart extends StatefulWidget {
  final int bpm;
  final bool isConnected;

  const AnimatedHeart({
    super.key,
    required this.bpm,
    required this.isConnected,
  });

  @override
  State<AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calculateDuration(),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isConnected && widget.bpm > 0) {
      _controller.repeat(reverse: true);
    }
  }

  Duration _calculateDuration() {
    // Calculate animation duration based on BPM
    // One heartbeat cycle (systole + diastole)
    if (widget.bpm <= 0) {
      return const Duration(milliseconds: 500);
    }
    int msPerBeat = (60000 / widget.bpm / 2).round();
    return Duration(milliseconds: msPerBeat.clamp(150, 1000));
  }

  @override
  void didUpdateWidget(AnimatedHeart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation based on connection and BPM
    if (widget.isConnected && widget.bpm > 0) {
      _controller.duration = _calculateDuration();
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color heartColor;
    if (!widget.isConnected) {
      heartColor = Colors.grey;
    } else if (widget.bpm < 60) {
      heartColor = const Color(0xFFFFC107); // Bradycardia - yellow
    } else if (widget.bpm > 100) {
      heartColor = const Color(0xFFFF5252); // Tachycardia - red
    } else {
      heartColor = const Color(0xFFFF5252); // Normal - red
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isConnected ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: heartColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite,
              color: heartColor,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}
