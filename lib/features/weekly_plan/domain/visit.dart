class Visit {
  final String accountId;
  final String accountName;
  final String address;
  final String date;
  final String day;
  final String driverId;
  final String driverUid;
  final bool completed;
  final String notes;
  final int order;

  const Visit({
    required this.accountId,
    required this.accountName,
    required this.address,
    required this.date,
    required this.day,
    required this.driverId,
    required this.driverUid,
    required this.completed,
    required this.notes,
    required this.order,
  });

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      accountId: map['account_id'] as String? ?? '',
      accountName: map['account_name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      date: map['date'] as String? ?? '',
      day: map['day'] as String? ?? '',
      driverId: map['driver_id'] as String? ?? '',
      driverUid: map['driver_uid'] as String? ?? '',
      completed: map['completed'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
      order: map['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_id': accountId,
      'account_name': accountName,
      'address': address,
      'date': date,
      'day': day,
      'driver_id': driverId,
      'driver_uid': driverUid,
      'completed': completed,
      'notes': notes,
      'order': order,
    };
  }

  Visit copyWith({
    String? accountId,
    String? accountName,
    String? address,
    String? date,
    String? day,
    String? driverId,
    String? driverUid,
    bool? completed,
    String? notes,
    int? order,
  }) {
    return Visit(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      address: address ?? this.address,
      date: date ?? this.date,
      day: day ?? this.day,
      driverId: driverId ?? this.driverId,
      driverUid: driverUid ?? this.driverUid,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      order: order ?? this.order,
    );
  }
}
