import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

part 'service_model.freezed.dart';

@freezed
class ServiceModel with _$ServiceModel {
  const factory ServiceModel({
    required String id,
    required String name,
    required IconData icon,
    required String description,
  }) = _ServiceModel;
}
