import 'package:flutter/material.dart';
import 'delivery_map_marker.dart';

class DeliveryMapView extends StatefulWidget {
  final List<DeliveryMapMarker> markers;
  final void Function(DeliveryMapMarker)? onMarkerTap;

  const DeliveryMapView({
    super.key,
    required this.markers,
    this.onMarkerTap,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  final TransformationController _transformationController = TransformationController();

  void _zoom(double factor) {
    final matrix = _transformationController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    
    double targetScale = currentScale * factor;
    if (targetScale < 0.5) targetScale = 0.5;
    if (targetScale > 4.0) targetScale = 4.0;
    
    final double zoomRatio = targetScale / currentScale;
    
    // Zoom around center (approximated for 200x200 canvas)
    const double cx = 100.0;
    const double cy = 100.0;
    
    final translation = Matrix4.translationValues(cx, cy, 0);
    final scale = Matrix4.diagonal3Values(zoomRatio, zoomRatio, 1.0);
    final translationInv = Matrix4.translationValues(-cx, -cy, 0);
    
    matrix.multiply(translation);
    matrix.multiply(scale);
    matrix.multiply(translationInv);
    
    setState(() {
      _transformationController.value = matrix;
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMarkers = widget.markers.isNotEmpty;

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
                                hasMarkers ? 'ปักหมุดสำเร็จ ${widget.markers.length} ตำแหน่ง' : 'ไม่พบข้อมูลจัดส่ง',
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
                                    ? 'LAT/LNG ACTIVE | Mapped: ${widget.markers.length}'
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

                    // Right Column: Interactive Map Pins
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
                            Positioned.fill(
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                boundaryMargin: const EdgeInsets.all(150),
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

                                    // Real GPS Plotting
                                    if (hasMarkers)
                                      ..._buildPins()
                                    else
                                      Icon(
                                        Icons.map_outlined,
                                        size: 40,
                                        color: Colors.indigo.shade700,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Map Controls overlay (keeps button size fixed outside InteractiveViewer)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Row(
                                children: [
                                  _MapRoundButton(
                                    icon: Icons.add,
                                    onTap: () => _zoom(1.3),
                                  ),
                                  const SizedBox(width: 4),
                                  _MapRoundButton(
                                    icon: Icons.remove,
                                    onTap: () => _zoom(0.7),
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

  List<Widget> _buildPins() {
    if (widget.markers.isEmpty) return [];

    if (widget.markers.length == 1) {
      return [
        _AnimatedPulsePin(
          marker: widget.markers.first,
          onTap: widget.onMarkerTap,
        )
      ];
    }

    double minLat = widget.markers.first.latitude;
    double maxLat = widget.markers.first.latitude;
    double minLng = widget.markers.first.longitude;
    double maxLng = widget.markers.first.longitude;

    for (var m in widget.markers) {
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
      if (m.longitude < minLng) minLng = m.longitude;
      if (m.longitude > maxLng) maxLng = m.longitude;
    }

    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    if (latDiff == 0) latDiff = 0.005;
    if (lngDiff == 0) lngDiff = 0.005;

    // Pad by 20%
    minLat -= latDiff * 0.2;
    maxLat += latDiff * 0.2;
    minLng -= lngDiff * 0.2;
    maxLng += lngDiff * 0.2;
    
    latDiff = maxLat - minLat;
    lngDiff = maxLng - minLng;

    return widget.markers.map((m) {
      // Y: -1 (top) to 1 (bottom). High latitude is top (smaller Y).
      double yPercentage = (maxLat - m.latitude) / latDiff; 
      double alignY = (yPercentage * 2) - 1; 

      // X: -1 (left) to 1 (right). Low longitude is left (smaller X).
      double xPercentage = (m.longitude - minLng) / lngDiff; 
      double alignX = (xPercentage * 2) - 1; 

      return Align(
        alignment: Alignment(alignX, alignY),
        child: _AnimatedPulsePin(
          marker: m,
          onTap: widget.onMarkerTap,
        ),
      );
    }).toList();
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
      message: marker.title,
      child: GestureDetector(
        onTap: () => onTap?.call(marker),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                marker.title.length > 15 ? '${marker.title.substring(0, 15)}...' : marker.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Container(
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
          ],
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
