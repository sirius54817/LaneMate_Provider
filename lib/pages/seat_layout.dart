import 'package:flutter/material.dart';

enum VehicleType { sedan, suv }

class SeatLayoutPage extends StatelessWidget {
  final VehicleType vehicleType;
  final String startAddress;
  final String destinationAddress;
  final String distance;
  final String duration;

  const SeatLayoutPage({
    Key? key,
    required this.vehicleType,
    required this.startAddress,
    required this.destinationAddress,
    required this.distance,
    required this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          vehicleType == VehicleType.sedan ? 'Sedan Layout' : 'SUV Layout',
          style: TextStyle(color: Colors.blue[900]),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      body: Column(
        children: [
          // Journey details card
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
                _buildAddressRow('From:', startAddress),
                SizedBox(height: 8),
                _buildAddressRow('To:', destinationAddress),
                Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetail('Distance', distance),
                    _buildDetail('Duration', duration),
                  ],
                ),
              ],
            ),
          ),

          // Seat layout visualization
          Expanded(
            child: Container(
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
                  Text(
                    'Seat Layout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: vehicleType == VehicleType.sedan
                        ? _buildSedanLayout()
                        : _buildSUVLayout(),
                  ),
                ],
              ),
            ),
          ),

          // Continue button
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement booking logic
                print('Booking confirmed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSedanLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First row (2 seats)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSeat(isDriver: true),
            SizedBox(width: 20),
            _buildSeat(),
          ],
        ),
        SizedBox(height: 40),
        // Second row (2 seats)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSeat(),
            SizedBox(width: 20),
            _buildSeat(),
          ],
        ),
      ],
    );
  }

  Widget _buildSUVLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First row (2 seats)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSeat(isDriver: true),
            SizedBox(width: 20),
            _buildSeat(),
          ],
        ),
        SizedBox(height: 40),
        // Second row (2 seats)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSeat(),
            SizedBox(width: 20),
            _buildSeat(),
          ],
        ),
        SizedBox(height: 40),
        // Third row (2 seats)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSeat(),
            SizedBox(width: 20),
            _buildSeat(),
          ],
        ),
      ],
    );
  }

  Widget _buildSeat({bool isDriver = false}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDriver ? Colors.grey[300] : Colors.blue[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDriver ? Colors.grey : Colors.blue,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event_seat,
          color: isDriver ? Colors.grey[600] : Colors.blue[700],
          size: 30,
        ),
      ),
    );
  }

  Widget _buildAddressRow(String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 