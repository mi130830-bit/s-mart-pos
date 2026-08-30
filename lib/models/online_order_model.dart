import 'dart:convert';

class OnlineOrderItem {
  final int productId;
  final String name;
  final double quantity;
  final double price;
  final double subtotal;

  OnlineOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OnlineOrderItem.fromJson(Map<String, dynamic> json) {
    return OnlineOrderItem(
      productId: int.tryParse(json['productId']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
      };
}

class OnlineOrder {
  final int id;
  final String orderNumber;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final String lineUserId;
  final String lineDisplayName;
  final String deliveryType; // 'delivery' or 'pickup'
  final String deliveryAddress;
  final String gpsLocation;
  final double distanceKm;
  final double deliveryFee;
  final double totalAmount;
  final double grandTotal;
  final String? couponCode;
  final double couponDiscount;
  final DateTime? couponReservedUntil;
  final String? couponReservationStatus;
  final int? posOrderId;
  final List<OnlineOrderItem> items;
  final String notes;
  final String
      status; // 'PENDING', 'CONFIRMED', 'DISPATCHED', 'COMPLETED', 'CANCELLED'
  final String confirmedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  OnlineOrder({
    required this.id,
    required this.orderNumber,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.lineUserId,
    required this.lineDisplayName,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.gpsLocation,
    required this.distanceKm,
    required this.deliveryFee,
    required this.totalAmount,
    required this.grandTotal,
    this.couponCode,
    this.couponDiscount = 0.0,
    this.couponReservedUntil,
    this.couponReservationStatus,
    this.posOrderId,
    required this.items,
    required this.notes,
    required this.status,
    required this.confirmedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDelivery => deliveryType == 'delivery';
  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isDispatched => status == 'DISPATCHED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  factory OnlineOrder.fromJson(Map<String, dynamic> json) {
    List<OnlineOrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) =>
              OnlineOrderItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
    } else if (json['itemsJson'] != null) {
      try {
        final list = jsonDecode(json['itemsJson'].toString()) as List;
        parsedItems = list
            .map((i) =>
                OnlineOrderItem.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList();
      } catch (_) {}
    }

    final reservation = json['couponReservation'] is Map
        ? Map<String, dynamic>.from(json['couponReservation'] as Map)
        : const <String, dynamic>{};

    return OnlineOrder(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerId: json['customerId'] != null
          ? int.tryParse(json['customerId'].toString())
          : null,
      customerName: json['customerName']?.toString() ?? 'ลูกค้าออนไลน์',
      customerPhone: json['customerPhone']?.toString() ?? '',
      lineUserId: json['lineUserId']?.toString() ?? '',
      lineDisplayName: json['lineDisplayName']?.toString() ?? '',
      deliveryType: json['deliveryType']?.toString() ?? 'pickup',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      gpsLocation: json['gpsLocation']?.toString() ?? '',
      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? '0') ?? 0.0,
      deliveryFee:
          double.tryParse(json['deliveryFee']?.toString() ?? '0') ?? 0.0,
      totalAmount:
          double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      grandTotal: double.tryParse(json['grandTotal']?.toString() ?? '0') ?? 0.0,
      couponCode: _nullableText(json['couponCode'] ?? reservation['code']),
      couponDiscount: double.tryParse(
              (json['couponDiscount'] ?? reservation['discount'])?.toString() ??
                  '0') ??
          0.0,
      couponReservedUntil: DateTime.tryParse(
          (json['couponReservedUntil'] ?? reservation['reservedUntil'])
                  ?.toString() ??
              ''),
      couponReservationStatus: _nullableText(
          json['couponReservationStatus'] ?? reservation['status']),
      posOrderId: int.tryParse(json['posOrderId']?.toString() ?? ''),
      items: parsedItems,
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      confirmedBy: json['confirmedBy']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
