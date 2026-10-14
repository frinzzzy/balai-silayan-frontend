import 'package:flutter/material.dart';

class OrderProgressTimeline extends StatelessWidget {
  final int activeIndex; // 0: Received, 1: Preparing, 2: Served, 3: Paid

  const OrderProgressTimeline({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final steps = ['Received', 'Preparing', 'Served', 'Paid'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE ORDER PROGRESS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.1),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (index) {
              final bool isPassed = index <= activeIndex;
              final bool isCurrent = index == activeIndex;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: isPassed ? const Color(0xFF203F35) : const Color(0xFFE5DFD3),
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isPassed ? const Color(0xFF203F35) : const Color(0xFFFFFDFA),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPassed ? const Color(0xFF203F35) : const Color(0xFFE5DFD3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isPassed
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF788078))),
                          ),
                        ),
                        if (index < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: index < activeIndex ? const Color(0xFF203F35) : const Color(0xFFE5DFD3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? const Color(0xFF203F35) : const Color(0xFF788078),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
