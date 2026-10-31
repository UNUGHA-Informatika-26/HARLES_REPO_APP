import 'package:flutter/material.dart';
import '../models/user_model.dart';

class DriverFleetRadarMap extends StatefulWidget {
  final List<UserModel> drivers;
  final String? selectedPickupLocation;
  final double height;

  const DriverFleetRadarMap({
    super.key,
    required this.drivers,
    this.selectedPickupLocation,
    this.height = 220.0,
  });

  @override
  State<DriverFleetRadarMap> createState() => _DriverFleetRadarMapState();
}

class _DriverFleetRadarMapState extends State<DriverFleetRadarMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double _zoom = 1.0;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDrivers = widget.drivers.where((d) => d.role == UserRole.driver && d.isOnbid).toList();

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA), // Google Maps Light Green Land Base
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryTeal.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Real Light Map Painter (Winding Rivers, Roads, Greenery)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RealJeruklegiMapPainter(
                    zoom: _zoom,
                    pulse: _pulseAnimation.value,
                    driverCount: activeDrivers.length,
                  ),
                );
              },
            ),
          ),

          // 2. Real Jeruklegi / Cilacap Landmark Badges
          Positioned(
            left: 120,
            top: 45,
            child: _buildLandmarkBadge(label: 'Bale Andap 🏖️', color: Colors.purple),
          ),
          Positioned(
            right: 40,
            top: 30,
            child: _buildLandmarkBadge(label: 'DM GreenHouse 🌿', color: Colors.green.shade800),
          ),
          Positioned(
            left: 30,
            bottom: 45,
            child: _buildLandmarkBadge(label: 'Stasiun Jeruklegi 🚉', color: Colors.indigo),
          ),
          Positioned(
            right: 80,
            bottom: 50,
            child: _buildLandmarkBadge(label: 'Pasar Jeruklegi 🏪', color: Colors.teal.shade800),
          ),

          // 3. Top Header Title Badge
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
                border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded, color: _darkTeal, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Peta Radar Jeruklegi - Cilacap (${activeDrivers.length} Driver Online)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkText),
                  ),
                ],
              ),
            ),
          ),

          // 4. Zoom Controls (+ / -)
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _buildZoomBtn(
                  icon: Icons.add_rounded,
                  onPressed: () => setState(() => _zoom = (_zoom + 0.2).clamp(0.8, 2.0)),
                ),
                const SizedBox(height: 6),
                _buildZoomBtn(
                  icon: Icons.remove_rounded,
                  onPressed: () => setState(() => _zoom = (_zoom - 0.2).clamp(0.8, 2.0)),
                ),
              ],
            ),
          ),

          // 5. Real Driver Location Pins Overlaid on Light Map
          if (activeDrivers.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12))),
                child: const Text('Belum ada Driver yang sedang Onbid (Online)', style: TextStyle(color: _darkText, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            )
          else
            ...activeDrivers.asMap().entries.map((entry) {
              final idx = entry.key;
              final driver = entry.value;

              final positions = [
                const Alignment(-0.35, -0.15),
                const Alignment(0.45, -0.35),
                const Alignment(-0.25, 0.45),
                const Alignment(0.55, 0.35),
                const Alignment(-0.6, 0.15),
              ];
              final align = positions[idx % positions.length];

              return Align(
                alignment: align,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _darkTeal, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.two_wheeler_rounded, color: _darkTeal, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${driver.fullName.split(' ').first} (📍 ${driver.currentLocation})',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkText),
                      ),
                    ],
                  ),
                ),
              );
            }),

          // 6. Customer Pickup Location Marker (if selected)
          if (widget.selectedPickupLocation != null)
            Align(
              alignment: const Alignment(0.0, -0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Titik Jemput Customer',
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

  Widget _buildLandmarkBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildZoomBtn({required IconData icon, required VoidCallback onPressed}) {
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
        icon: Icon(icon, color: _darkText),
        onPressed: onPressed,
      ),
    );
  }
}

class _RealJeruklegiMapPainter extends CustomPainter {
  final double zoom;
  final double pulse;
  final int driverCount;

  _RealJeruklegiMapPainter({
    required this.zoom,
    required this.pulse,
    required this.driverCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Google Maps Light Green Land Terrain Base
    final landPaint = Paint()..color = const Color(0xFFE6F4EA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. Real River / Winding Waterways (Sungai Jeruklegi / Serayu)
    final riverPaint = Paint()
      ..color = const Color(0xFF7DD3FC) // Light Cyan Water
      ..strokeWidth = 22 * zoom
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

    // Secondary Branch River Stream
    final streamPaint = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..strokeWidth = 10 * zoom
      ..style = PaintingStyle.stroke;

    final streamPath = Path()
      ..moveTo(size.width * 0.45, size.height * 0.45)
      ..cubicTo(
        size.width * 0.65, size.height * 0.6,
        size.width * 0.8, size.height * 0.2,
        size.width, size.height * 0.15,
      );
    canvas.drawPath(streamPath, streamPaint);

    // 3. Road Networks (White Secondary Streets & Light Yellow Main Roads)
    final mainRoadBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 10 * zoom
      ..style = PaintingStyle.stroke;

    final mainRoad = Paint()
      ..color = const Color(0xFFFEF08A) // Yellow Primary Road
      ..strokeWidth = 7 * zoom
      ..style = PaintingStyle.stroke;

    final streetBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 6 * zoom
      ..style = PaintingStyle.stroke;

    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 4 * zoom
      ..style = PaintingStyle.stroke;

    // Main Jalan Raya Jeruklegi
    final rPath1 = Path()
      ..moveTo(size.width * 0.1, 0)
      ..lineTo(size.width * 0.9, size.height);
    canvas.drawPath(rPath1, mainRoadBorder);
    canvas.drawPath(rPath1, mainRoad);

    // Secondary Street Grid
    final rPath2 = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.35);
    canvas.drawPath(rPath2, streetBorder);
    canvas.drawPath(rPath2, street);

    final rPath3 = Path()
      ..moveTo(0, size.height * 0.65)
      ..lineTo(size.width, size.height * 0.65);
    canvas.drawPath(rPath3, streetBorder);
    canvas.drawPath(rPath3, street);

    // 4. Radar Pulse Ring on Center
    final pulsePaint = Paint()
      ..color = const Color(0xFF13C5BC).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 32 * pulse * zoom, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _RealJeruklegiMapPainter oldDelegate) {
    return oldDelegate.zoom != zoom || oldDelegate.pulse != pulse;
  }
}
