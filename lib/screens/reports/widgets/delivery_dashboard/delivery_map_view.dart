import 'package:flutter/material.dart';
import 'delivery_map_marker.dart';

class DeliveryMapView extends StatelessWidget {
  final List<DeliveryMapMarker> markers;
  final void Function(DeliveryMapMarker)? onMarkerTap;

  const DeliveryMapView({
    super.key,
    required this.markers,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMarkers = markers.isNotEmpty;

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.indigo.shade800, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 🗺️ Map Grid Background Grid Pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: GridPaper(
                  color: Colors.indigo.shade400,
                  interval: 40,
                  subdivisions: 4,
                ),
              ),
            ),

            // 📍 Simulated Radar/Scanner Sweep Lines
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.indigo.shade900.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),

            // 🎯 Map Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left Column: Navigation controls & metadata
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade800.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.indigo.shade600, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2ECC71),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'GPS MONITORING',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasMarkers ? 'ปักหมุดสำเร็จ ${markers.length} ตำแหน่ง' : 'ไม่พบข้อมูลจัดส่ง',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasMarkers
                                    ? 'คลิกรายการจัดส่งด้านล่างเพื่อเปิด Google Maps นำทาง'
                                    : 'กรุณาเลือกช่วงเวลาที่มีรายการจัดส่ง',
                                style: TextStyle(
                                  color: Colors.indigo.shade200,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          // Mini HUD coordinate panel
                          Row(
                            children: [
                              Icon(Icons.gps_fixed, size: 14, color: Colors.indigo.shade300),
                              const SizedBox(width: 6),
                              Text(
                                hasMarkers
                                    ? 'LAT/LNG ACTIVE | Mapped: ${markers.length}'
                                    : 'NO ACTIVE GPS COORDINATES',
                                style: TextStyle(
                                  color: Colors.indigo.shade300,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Right Column: Mock Map Pin Graphic & Interactive Pins
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade800, width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Concentric Radar Rings
                            ...List.generate(3, (index) {
                              final size = (index + 1) * 60.0;
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.indigo.shade500.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                              );
                            }),

                            // Pulse indicator at center
                            if (hasMarkers) ...[
                              _AnimatedPulsePin(
                                marker: markers.first,
                                onTap: onMarkerTap,
                              ),
                              if (markers.length > 1)
                                Positioned(
                                  top: 30,
                                  right: 40,
                                  child: _AnimatedPulsePin(
                                    marker: markers[1],
                                    onTap: onMarkerTap,
                                  ),
                                ),
                              if (markers.length > 2)
                                Positioned(
                                  bottom: 40,
                                  left: 30,
                                  child: _AnimatedPulsePin(
                                    marker: markers[2],
                                    onTap: onMarkerTap,
                                  ),
                                ),
                            ] else
                              Icon(
                                Icons.map_outlined,
                                size: 40,
                                color: Colors.indigo.shade700,
                              ),

                            // Map Controls overlay
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Row(
                                children: [
                                  _MapRoundButton(
                                    icon: Icons.add,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 4),
                                  _MapRoundButton(
                                    icon: Icons.remove,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

class _AnimatedPulsePin extends StatelessWidget {
  final DeliveryMapMarker marker;
  final void Function(DeliveryMapMarker)? onTap;

  const _AnimatedPulsePin({
    required this.marker,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${marker.title}\n${marker.snippet ?? ''}',
      child: GestureDetector(
        onTap: () => onTap?.call(marker),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.pinkAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.pinkAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent,
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.location_on,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapRoundButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.indigo.shade800.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.indigo.shade600, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
