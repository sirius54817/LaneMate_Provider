import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';

class PassengerOrdersPage extends StatefulWidget {
  const PassengerOrdersPage({super.key});

  @override
  State<PassengerOrdersPage> createState() => _PassengerOrdersPageState();
}

class _PassengerOrdersPageState extends State<PassengerOrdersPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _ordersService = OrdersService();

  List<String> get _tabs => ['Current Requests', 'Completed'];

  String _getStatusForIndex(int index) {
    switch (index) {
      case 0: return 'pending';
      case 1: return 'completed';
      default: return 'pending';
    }
  }

  void _initTabController() {
    _tabController?.dispose();
    _tabController = TabController(
      length: 2,
      vsync: this,
    );
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      _initTabController();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'LaneMate',
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 22,
              ),
            ),
            Text(
              'My Rides',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController!,
          tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
          labelColor: Colors.blue[900],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[900],
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        controller: _tabController!,
        children: _tabs.asMap().entries.map((entry) {
          return _buildOrdersList(_getStatusForIndex(entry.key));
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersService.streamOrdersByStatus(
        status,
        isDriver: false,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return _buildEmptyState(status);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(orders[index]),
        );
      },
    );
  }

  Widget _buildEmptyState(String status) {
    String message = status == 'pending'
        ? 'No active ride requests'
        : 'No completed rides yet';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == 'completed' ? Icons.check_circle : Icons.directions_car,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    // Keep the same card UI as the driver's page
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... rest of your card UI
          ],
        ),
      ),
    );
  }
} 