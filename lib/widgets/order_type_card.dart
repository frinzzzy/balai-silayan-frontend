import 'package:flutter/material.dart';

class OrderTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const OrderTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF203F35) : const Color(0xFFFFFDFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3),
              width: 1.5,
            ),
            boxShadow: [
              if (!isSelected && isEnabled)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFFD7BF91) : const Color(0xFF203F35),
                    size: 26,
                  ),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFFF8F4EC) : const Color(0xFF788078),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFF8F4EC) : const Color(0xFF203F35),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? const Color(0xFFCBD7CF) : const Color(0xFF788078),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
