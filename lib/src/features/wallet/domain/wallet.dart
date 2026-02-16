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
      currency: json['currency']?.toString() ?? 'SAR',
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
