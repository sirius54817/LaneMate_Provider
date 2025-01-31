import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ecub_delivery/pages/seat_layout.dart';

class VehicleSelectionPage extends StatelessWidget {
  final LatLng startPoint;
  final LatLng destination;
  final String startAddress;
  final String destinationAddress;
  final String distance;
  final String duration;

  const VehicleSelectionPage({
    Key? key,
    required this.startPoint,
    required this.destination,
    required this.startAddress,
    required this.destinationAddress,
    required this.distance,
    required this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Vehicle'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[900],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Journey Details Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildLocationRow(
                  Icons.my_location,
                  'Start',
                  startAddress,
                  Colors.blue[700]!,
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Container(
                    height: 30,
                    width: 2,
                    color: Colors.grey[300],
                  ),
                ),
                SizedBox(height: 8),
                _buildLocationRow(
                  Icons.location_on,
                  'Destination',
                  destinationAddress,
                  Colors.red[700]!,
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTripDetail(Icons.timeline, distance, 'Distance'),
                    _buildTripDetail(Icons.access_time, duration, 'Duration'),
                  ],
                ),
              ],
            ),
          ),
          
          // Vehicle Selection Cards
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Vehicle Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildVehicleCard(
                    context,
                    'Sedan',
                    '4 Seats',
                    'Comfortable ride for up to 4 passengers',
                    'assets/sedan.png',
                    Colors.blue[50]!,
                  ),
                  SizedBox(height: 16),
                  _buildVehicleCard(
                    context,
                    'SUV',
                    '6 Seats',
                    'Spacious ride for up to 6 passengers',
                    'assets/suv.png',
                    Colors.green[50]!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String title, String address, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    String title,
    String capacity,
    String description,
    String imagePath,
    Color backgroundColor,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeatLayoutPage(
              vehicleType: title == 'Sedan' ? VehicleType.sedan : VehicleType.suv,
              startAddress: startAddress,
              destinationAddress: destinationAddress,
              distance: distance,
              duration: duration,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    capacity,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              imagePath,
              height: 80,
              width: 80,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  title == 'Sedan' ? Icons.directions_car : Icons.directions_car,
                  size: 80,
                  color: Colors.blue[300],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}