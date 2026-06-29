import 'package:flutter/material.dart';

class FeedButton extends StatefulWidget {
  final Future<void> Function() onFeedClicked;
  final bool isTriggered;

  const FeedButton({
    super.key,
    required this.onFeedClicked,
    required this.isTriggered,
  });

  @override
  State<FeedButton> createState() => _FeedButtonState();
}

class _FeedButtonState extends State<FeedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!widget.isTriggered) {
          await widget.onFeedClicked();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.isTriggered
                      ? const Color(0xFF00FF87).withOpacity(0.6)
                      : const Color(0xFF00FF87).withOpacity(0.2 + (_controller.value * 0.2)),
                  blurRadius: widget.isTriggered ? 50 : 20 + (_controller.value * 20),
                  spreadRadius: widget.isTriggered ? 10 : 5 + (_controller.value * 5),
                ),
              ],
              gradient: RadialGradient(
                colors: widget.isTriggered
                    ? [const Color(0xFF00FF87).withOpacity(0.8), const Color(0xFF00E676).withOpacity(0.4)]
                    : [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
              ),
              border: Border.all(
                color: widget.isTriggered ? const Color(0xFF00FF87) : Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                widget.isTriggered ? 'FEEDING...' : 'FEED NOW',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
