import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/utils/map_utils.dart';

class RideMap extends StatefulWidget {
  final GeoPoint? startLocation;
  final GeoPoint? endLocation;
  final bool showFullRoute;
  final LatLng? driverLocation;
  final bool showDriverLocation;

  const RideMap({
    Key? key,
    this.startLocation,
    this.endLocation,
    this.showFullRoute = false,
    this.driverLocation,
    this.showDriverLocation = false,
  }) : super(key: key);

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _drawRoute();
  }

  Future<void> _drawRoute() async {
    final points = await getPolylinePoints(
      LatLng(widget.startLocation!.latitude, widget.startLocation!.longitude),
      LatLng(widget.endLocation!.latitude, widget.endLocation!.longitude),
    );

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.startLocation!.latitude,
          widget.startLocation!.longitude,
        ),
        zoom: 12,
      ),
      markers: {
        Marker(
          markerId: MarkerId('start'),
          position: LatLng(
            widget.startLocation!.latitude,
            widget.startLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: MarkerId('end'),
          position: LatLng(
            widget.endLocation!.latitude,
            widget.endLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        if (widget.showDriverLocation && widget.driverLocation != null)
          Marker(
            markerId: MarkerId('driver'),
            position: widget.driverLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            flat: true,
            anchor: Offset(0.5, 0.5),
            zIndex: 2,
          ),
      },
      polylines: _polylines,
      circles: widget.showDriverLocation && widget.driverLocation != null ? {
        Circle(
          circleId: CircleId('driverRadius'),
          center: widget.driverLocation!,
          radius: 100, // 100 meters radius
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 1,
        ),
      } : {},
      onMapCreated: (controller) => _mapController = controller,
    );
  }
} 