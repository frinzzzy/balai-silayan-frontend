import 'package:flutter/material.dart';

/// Lightweight pulsing skeleton placeholder used for loading states.
/// Purely visual — no logic involved.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double opacity = 0.05 + (0.05 * _controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.fromRGBO(25, 56, 47, opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
