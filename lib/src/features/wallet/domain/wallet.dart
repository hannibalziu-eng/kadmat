// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    required String userId,
    required double balance,
    @Default(0.0) double totalEarnings,
    required String currency,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Wallet;

  const Wallet._();

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  factory Wallet.fromApiJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final normalized = <String, dynamic>{
      'id': json['id']?.toString() ?? '',
      'user_id': json['user_id']?.toString() ?? '',
      'balance': _asDouble(json['balance']),
      'totalEarnings': _asDouble(
        json['total_earnings'] ?? json['totalEarnings'],
      ),
      'currency': _normalizeCurrency(json['currency']),
      'created_at':
          _asDateTimeString(json['created_at']) ??
          _asDateTimeString(json['updated_at']) ??
          now.toIso8601String(),
      'updated_at':
          _asDateTimeString(json['updated_at']) ??
          _asDateTimeString(json['created_at']) ??
          now.toIso8601String(),
    };
    return Wallet.fromJson(normalized);
  }

  @override
  @JsonKey(name: 'user_id')
  String get userId => throw UnimplementedError();
  @override
  @JsonKey(name: 'total_earnings')
  double get totalEarnings => throw UnimplementedError();
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw UnimplementedError();
}

@freezed
class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String id,
    required String walletId,
    required double amount,
    required String type, // deposit, withdrawal, payment, commission
    String? description,
    String? referenceId,
    required DateTime createdAt,
  }) = _WalletTransaction;

  const WalletTransaction._();

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);

  factory WalletTransaction.fromApiJson(Map<String, dynamic> json) {
    final createdAt =
        _asDateTimeString(json['created_at']) ??
        DateTime.now().toIso8601String();
    final normalized = <String, dynamic>{
      'id': json['id']?.toString() ?? '',
      'wallet_id': json['wallet_id']?.toString() ?? '',
      'amount': _asDouble(json['amount']),
      'type': json['type']?.toString() ?? 'transaction',
      'description': json['description']?.toString(),
      'reference_id': json['reference_id']?.toString(),
      'created_at': createdAt,
    };
    return WalletTransaction.fromJson(normalized);
  }

  @override
  @JsonKey(name: 'wallet_id')
  String get walletId => throw UnimplementedError();
  @override
  @JsonKey(name: 'reference_id')
  String? get referenceId => throw UnimplementedError();
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw UnimplementedError();
}

class WithdrawRequest {
  WithdrawRequest({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.status,
    this.bankAccount,
    this.notes,
    this.rejectionReason,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String walletId;
  final double amount;
  final String currency;
  final String status;
  final String? bankAccount;
  final String? notes;
  final String? rejectionReason;
  final DateTime createdAt;

  factory WithdrawRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      walletId: json['wallet_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: _normalizeCurrency(json['currency']),
      status: json['status']?.toString() ?? 'pending',
      bankAccount: json['bank_account']?.toString(),
      notes: json['notes']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get localizedStatus {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'paid':
        return 'مدفوع';
      default:
        return 'قيد المراجعة';
    }
  }
}

String _normalizeCurrency(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return 'د.ل';

  switch (raw.toUpperCase()) {
    case 'SAR':
    case 'LYD':
      return 'د.ل';
    default:
      return raw;
  }
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

String? _asDateTimeString(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toIso8601String();
}
