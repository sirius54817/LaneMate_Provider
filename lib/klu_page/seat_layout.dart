import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'passenger_details_page.dart';

enum VehicleType { bus }

class SeatLayoutPage extends StatefulWidget {
  final VehicleType vehicleType;
  final String startAddress;
  final String destinationAddress;
  final String distance;
  final String duration;
  final LatLng startPoint;
  final LatLng destination;

  const SeatLayoutPage({
    Key? key,
    required this.vehicleType,
    required this.startAddress,
    required this.destinationAddress,
    required this.distance,
    required this.duration,
    required this.startPoint,
    required this.destination,
  }) : super(key: key);

  @override
  State<SeatLayoutPage> createState() => _SeatLayoutPageState();
}

class _SeatLayoutPageState extends State<SeatLayoutPage> {
  Set<String> selectedSeats = {};

  void toggleSeat(String seatId) {
    setState(() {
      if (selectedSeats.contains(seatId)) {
        selectedSeats.remove(seatId);
      } else {
        selectedSeats.add(seatId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bus Layout',
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
                _buildAddressRow('From:', widget.startAddress),
                SizedBox(height: 8),
                _buildAddressRow('To:', widget.destinationAddress),
                Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetail('Distance', widget.distance),
                    _buildDetail('Duration', widget.duration),
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
                    'Select Your Seat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: _buildBusLayout(),
                  ),
                ],
              ),
            ),
          ),

          // Continue button
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${selectedSeats.length} seats selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: selectedSeats.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PassengerDetailsPage(
                                selectedSeats: selectedSeats,
                                startAddress: widget.startAddress,
                                destinationAddress: widget.destinationAddress,
                                startPoint: widget.startPoint,
                                destination: widget.destination,
                                distance: widget.distance,
                                vehicleType: 'bus',
                              ),
                            ),
                          );
                        }
                      : null,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Driver section
          Row(
            children: [
              _buildSeat(seatId: 'driver', isDriver: true),
              SizedBox(width: 100), // Space for entrance
            ],
          ),
          SizedBox(height: 20),
          // Passenger seats (10 rows of 4 seats)
          for (int row = 1; row <= 10; row++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSeat(seatId: 'L${row}A'),
                _buildSeat(seatId: 'L${row}B'),
                SizedBox(width: 40), // Aisle
                _buildSeat(seatId: 'R${row}A'),
                _buildSeat(seatId: 'R${row}B'),
              ],
            ),
            SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildSeat({required String seatId, bool isDriver = false}) {
    final bool isSelected = selectedSeats.contains(seatId);
    
    return GestureDetector(
      onTap: isDriver ? null : () => toggleSeat(seatId),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDriver 
              ? Colors.grey[300]
              : isSelected 
                  ? Colors.blue[700]
                  : Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDriver 
                ? Colors.grey
                : isSelected 
                    ? Colors.blue[900]!
                    : Colors.blue,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.event_seat,
            color: isDriver 
                ? Colors.grey[600]
                : isSelected 
                    ? Colors.white
                    : Colors.blue[700],
            size: 24,
          ),
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