import 'package:flutter/material.dart';

class PassengerDetailsPage extends StatefulWidget {
  final Set<String> selectedSeats;

  const PassengerDetailsPage({
    Key? key,
    required this.selectedSeats,
  }) : super(key: key);

  @override
  State<PassengerDetailsPage> createState() => _PassengerDetailsPageState();
}

class _PassengerDetailsPageState extends State<PassengerDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, Map<String, String>> passengerDetails = {};

  @override
  void initState() {
    super.initState();
    // Initialize the passenger details map for each seat
    for (var seatId in widget.selectedSeats) {
      passengerDetails[seatId] = {
        'name': '',
        'age': '',
        'gender': 'Male',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Passenger Details',
          style: TextStyle(color: Colors.blue[900]),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: widget.selectedSeats.length,
                itemBuilder: (context, index) {
                  String seatId = widget.selectedSeats.elementAt(index);
                  return _buildPassengerCard(seatId, index + 1);
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // TODO: Implement booking confirmation
                    print('Passenger details: $passengerDetails');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm Booking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerCard(String seatId, int passengerNumber) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passenger $passengerNumber (Seat: ${seatId.replaceAll('_', ' ').toUpperCase()})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter passenger name';
                }
                return null;
              },
              onSaved: (value) {
                passengerDetails[seatId]!['name'] = value!;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter passenger age';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter a valid age';
                }
                return null;
              },
              onSaved: (value) {
                passengerDetails[seatId]!['age'] = value!;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              value: passengerDetails[seatId]!['gender'],
              items: ['Male', 'Female', 'Other']
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  passengerDetails[seatId]!['gender'] = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
} 