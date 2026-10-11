import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpiryStatus { safe, expiringSoon, expiresToday, expired }

class Grocery {
  const Grocery({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unitPrice = 0,
    required this.unit,
    required this.purchaseDate,
    required this.expirationDate,
    required this.storageLocation,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final double unitPrice;
  double get totalCost => quantity * unitPrice;
  final String unit;
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final String storageLocation;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath;

  Grocery copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    double? unitPrice,
    String? unit,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    String? storageLocation,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
  }) {
    return Grocery(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      storageLocation: storageLocation ?? this.storageLocation,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  factory Grocery.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Grocery(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? 'pieces',
      purchaseDate: _readDate(data['purchaseDate']),
      expirationDate: _readDate(data['expirationDate']),
      storageLocation: data['storageLocation'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      imagePath: data['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unit': unit,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expirationDate': Timestamp.fromDate(expirationDate),
      'storageLocation': storageLocation,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'imagePath': imagePath,
    };
  }

  int get daysRemaining {
    final today = _dateOnly(DateTime.now());
    final expiry = _dateOnly(expirationDate);
    return expiry.difference(today).inDays;
  }

  ExpiryStatus get expiryStatus {
    final days = daysRemaining;
    if (days < 0) {
      return ExpiryStatus.expired;
    }
    if (days == 0) {
      return ExpiryStatus.expiresToday;
    }
    if (days <= 7) {
      return ExpiryStatus.expiringSoon;
    }
    return ExpiryStatus.safe;
  }

  bool get isExpiringSoon =>
      expiryStatus == ExpiryStatus.expiringSoon ||
      expiryStatus == ExpiryStatus.expiresToday;

  bool get isExpired => expiryStatus == ExpiryStatus.expired;

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
