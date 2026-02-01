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
