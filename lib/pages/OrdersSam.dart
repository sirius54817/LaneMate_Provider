class OrdersSam {
  final String orderId;
  final String itemName;
  final String userId;
  final String itemPrice;
  // final String latt;
  // final String long;
  // final String address;

  OrdersSam({
    required this.orderId,
    required this.itemName,
    required this.userId,
    required this.itemPrice,
    // required this.latt,
    // required this.long,
    // required this.address,
  });

  static fromMap(Map<String, dynamic> order) {}
}
