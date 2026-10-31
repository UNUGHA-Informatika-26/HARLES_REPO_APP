import 'package:flutter/material.dart';

class LiveMapView extends StatefulWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final String? driverName;
  final bool isDriverView;
  final double height;

  const LiveMapView({
    super.key,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.driverName,
    this.isDriverView = false,
    this.height = 200.0,
  });

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  double _zoomLevel = 1.0;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA), // Google Maps Light Green Land Base
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryTeal.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Custom Light Map Canvas Background & Winding River Route Line
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MapPainter(
                    zoom: _zoomLevel,
                    pulseValue: _pulseAnimation.value,
                    isDriverView: widget.isDriverView,
                  ),
                );
              },
            ),
          ),

          // 2. Pickup Location Pin Badge (Top Left of Map)
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location_rounded, color: Colors.blue, size: 14),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.pickupAddress.isNotEmpty ? widget.pickupAddress : 'Lokasi Penjemputan',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Dropoff Location Pin Badge (Bottom Right of Map)
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.dropoffAddress.isNotEmpty ? widget.dropoffAddress : 'Tujuan Pengantaran',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Map Zoom Controls (+ / -)
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.add_rounded,
                  onPressed: () {
                    setState(() {
                      _zoomLevel = (_zoomLevel + 0.2).clamp(0.8, 2.0);
                    });
                  },
                ),
                const SizedBox(height: 6),
                _buildMapButton(
                  icon: Icons.remove_rounded,
                  onPressed: () {
                    setState(() {
                      _zoomLevel = (_zoomLevel - 0.2).clamp(0.8, 2.0);
                    });
                  },
                ),
              ],
            ),
          ),

          // 5. Driver GPS Radar Badge Overlay
          if (widget.isDriverView)
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _darkTeal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: _primaryTeal, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'GPS Live Navigasi Driver',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: const Color(0xFF0F172A)),
        onPressed: onPressed,
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double zoom;
  final double pulseValue;
  final bool isDriverView;

  _MapPainter({
    required this.zoom,
    required this.pulseValue,
    required this.isDriverView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Google Maps Light Green Land Terrain Base
    final bgPaint = Paint()..color = const Color(0xFFE6F4EA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Real River / Winding Waterways
    final riverPaint = Paint()
      ..color = const Color(0xFF7DD3FC) // Light Cyan Water
      ..strokeWidth = 20 * zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..cubicTo(
        size.width * 0.25, size.height * 0.1,
        size.width * 0.15, size.height * 0.5,
        size.width * 0.45, size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.7, size.height * 0.4,
        size.width * 0.35, size.height * 0.9,
        0, size.height * 0.85,
      );
    canvas.drawPath(riverPath, riverPaint);

    // 3. Roads Networks
    final highwayBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 12 * zoom
      ..style = PaintingStyle.stroke;

    final highway = Paint()
      ..color = const Color(0xFFFEF08A) // Yellow Primary Road
      ..strokeWidth = 9 * zoom
      ..style = PaintingStyle.stroke;

    final streetBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 8 * zoom
      ..style = PaintingStyle.stroke;

    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 6 * zoom
      ..style = PaintingStyle.stroke;

    final hPath = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(size.width * 0.3, size.height * 0.2, size.width * 0.6, size.height * 0.7, size.width, size.height * 0.65);
    canvas.drawPath(hPath, highwayBorder);
    canvas.drawPath(hPath, highway);

    final sPath = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.75, size.height);
    canvas.drawPath(sPath, streetBorder);
    canvas.drawPath(sPath, street);

    // 4. Route Path Line (Green/Teal Route Connection)
    final routePaint = Paint()
      ..color = const Color(0xFF13C5BC)
      ..strokeWidth = 4 * zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.75, size.height * 0.65);

    canvas.drawPath(routePath, routePaint);

    // Pulse Ring around Pickup Location
    final pulsePaint = Paint()
      ..color = const Color(0xFF13C5BC).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.35), 18 * pulseValue * zoom, pulsePaint);

    // Pickup Marker (Blue)
    final blueMarker = Paint()..color = Colors.blue.shade600;
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.35), 8 * zoom, blueMarker);

    // Dropoff Marker (Red)
    final redMarker = Paint()..color = Colors.red.shade600;
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.65), 8 * zoom, redMarker);

    // Driver Vehicle Icon / Position (Center of Route)
    final vehiclePos = Offset(size.width * 0.5, size.height * 0.5);
    final vehicleBg = Paint()..color = const Color(0xFF005F5B);
    canvas.drawCircle(vehiclePos, 11 * zoom, vehicleBg);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.zoom != zoom || oldDelegate.pulseValue != pulseValue;
  }
}
