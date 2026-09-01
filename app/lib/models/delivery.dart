class Delivery {
  final String id;                  // bytes32 as hex string
  final String customerAddress;     // address
  final String driverAddress;       // address
  final int distanceMeters;         // uint32
  final int fiatAmountCents;        // uint32
  final int rating;                 // uint8 (0-5)
  final DeliveryStatus status;      // enum
  final DateTime createdAt;         // uint64 timestamp
  final DateTime? completedAt;      // uint64 timestamp
  final String? description;        // Optional for UI purposes

  Delivery({
    required this.id,
    required this.customerAddress,
    required this.driverAddress,
    required this.distanceMeters,
    required this.fiatAmountCents,
    required this.rating,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.description,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] as String,
      customerAddress: json['customerAddress'] as String,
      driverAddress: json['driverAddress'] as String,
      distanceMeters: json['distanceMeters'] as int,
      fiatAmountCents: json['fiatAmountCents'] as int,
      rating: json['rating'] as int,
      status: DeliveryStatus.values[json['status'] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as int) * 1000),
      completedAt: json['completedAt'] != null && json['completedAt'] != 0
          ? DateTime.fromMillisecondsSinceEpoch((json['completedAt'] as int) * 1000)
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerAddress': customerAddress,
      'driverAddress': driverAddress,
      'distanceMeters': distanceMeters,
      'fiatAmountCents': fiatAmountCents,
      'rating': rating,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch ~/ 1000,
      'completedAt': completedAt != null ? completedAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'description': description,
    };
  }

  Delivery copyWith({
    String? id,
    String? customerAddress,
    String? driverAddress,
    int? distanceMeters,
    int? fiatAmountCents,
    int? rating,
    DeliveryStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? description,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerAddress: customerAddress ?? this.customerAddress,
      driverAddress: driverAddress ?? this.driverAddress,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      fiatAmountCents: fiatAmountCents ?? this.fiatAmountCents,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      description: description ?? this.description,
    );
  }
  
  // Helper getters for UI display
  double get distanceKm => distanceMeters / 1000.0;
  double get fiatAmountUSD => fiatAmountCents / 100.0;
}

enum DeliveryStatus {
  created,      // 0
  inProgress,   // 1
  completed,    // 2
  cancelled,    // 3
}
