import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/service_model.dart';

part 'home_repository.g.dart';

class HomeRepository {
  Future<List<ServiceModel>> getServices() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    return [
      const ServiceModel(
        id: '1',
        name: 'تنظيف منازل',
        icon: Icons.cleaning_services,
        description: 'خدمات تنظيف شاملة للمنازل والشقق',
      ),
      const ServiceModel(
        id: '2',
        name: 'صيانة كهرباء',
        icon: Icons.electrical_services,
        description: 'إصلاح وصيانة الأعطال الكهربائية',
      ),
      const ServiceModel(
        id: '3',
        name: 'سباكة',
        icon: Icons.plumbing,
        description: 'خدمات السباكة والصرف الصحي',
      ),
      const ServiceModel(
        id: '4',
        name: 'نقل عفش',
        icon: Icons.local_shipping,
        description: 'نقل وتركيب الأثاث باحترافية',
      ),
      const ServiceModel(
        id: '5',
        name: 'مكافحة حشرات',
        icon: Icons.pest_control,
        description: 'القضاء على جميع أنواع الحشرات',
      ),
      const ServiceModel(
        id: '6',
        name: 'تكييف وتبريد',
        icon: Icons.ac_unit,
        description: 'صيانة وتركيب المكيفات',
      ),
    ];
  }
}

@riverpod
HomeRepository homeRepository(HomeRepositoryRef ref) {
  return HomeRepository();
}

@riverpod
Future<List<ServiceModel>> services(ServicesRef ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  return homeRepository.getServices();
}
