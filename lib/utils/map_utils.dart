import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<LatLng>> getPolylinePoints(LatLng start, LatLng end) async {
  final polylinePoints = PolylinePoints();
  
  try {
    final result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo', // Your API key
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
    );

    if (result.points.isNotEmpty) {
      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }
  } catch (e) {
    print('Error fetching polyline points: $e');
  }
  return [];
} 