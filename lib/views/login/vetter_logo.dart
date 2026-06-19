import 'package:flutter/material.dart';

class VetterLogo extends StatelessWidget {
  final double size;
  final Color color;

  const VetterLogo({
    super.key,
    this.size = 24.0,
    this.color = const Color(0xFF001450), // Dark blue from SVGs
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (1065.7183 / 1000.0), // Keep aspect ratio
      child: CustomPaint(painter: VetterLogoPainter(color: color)),
    );
  }
}

class VetterLogoPainter extends CustomPainter {
  final Color color;
  const VetterLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    // Scale canvas to fit size
    final double scaleX = size.width / 1000.0;
    final double scaleY = size.height / 1065.7183;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Center the drawing in size
    final double dx = (size.width - 1000.0 * scale) / 2;
    final double dy = (size.height - 1065.7183 * scale) / 2;
    canvas.translate(dx, dy);
    canvas.scale(scale);

    // 1. Draw circular portion (from first path)
    canvas.drawCircle(const Offset(500.0017, 184.9602), 184.9588, paint);

    // 2. Draw V-shape/shield portion (from second path)
    final path = Path()
      ..moveTo(500.0017, 1065.7183)
      ..lineTo(0.0, 397.6206)
      ..lineTo(366.0178, 397.6206)
      ..lineTo(500.0016, 567.3732)
      ..lineTo(633.9854, 397.6206)
      ..lineTo(1000.0, 397.6206)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
