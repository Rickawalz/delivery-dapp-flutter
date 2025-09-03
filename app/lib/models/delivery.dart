class Delivery {
  final String id;
  final String senderAddress;
  final String receiverAddress;
  final String description;
  final double value;
  final DateTime createdAt;
  final DeliveryStatus status;
  final String? courierAddress;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;

  Delivery({
    required this.id,
    required this.senderAddress,
    required this.receiverAddress,
    required this.description,
    required this.value,
    required this.createdAt,
    required this.status,
    this.courierAddress,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] as String,
      senderAddress: json['senderAddress'] as String,
      receiverAddress: json['receiverAddress'] as String,
      description: json['description'] as String,
      value: (json['value'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: DeliveryStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      courierAddress: json['courierAddress'] as String?,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] != null
          ? DateTime.parse(json['estimatedDeliveryTime'] as String)
          : null,
      actualDeliveryTime: json['actualDeliveryTime'] != null
          ? DateTime.parse(json['actualDeliveryTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderAddress': senderAddress,
      'receiverAddress': receiverAddress,
      'description': description,
      'value': value,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString(),
      'courierAddress': courierAddress,
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'actualDeliveryTime': actualDeliveryTime?.toIso8601String(),
    };
  }

  Delivery copyWith({
    String? id,
    String? senderAddress,
    String? receiverAddress,
    String? description,
    double? value,
    DateTime? createdAt,
    DeliveryStatus? status,
    String? courierAddress,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
  }) {
    return Delivery(
      id: id ?? this.id,
      senderAddress: senderAddress ?? this.senderAddress,
      receiverAddress: receiverAddress ?? this.receiverAddress,
      description: description ?? this.description,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      courierAddress: courierAddress ?? this.courierAddress,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
    );
  }
}

enum DeliveryStatus {
  pending,
  accepted,
  inTransit,
  delivered,
  cancelled,
} 