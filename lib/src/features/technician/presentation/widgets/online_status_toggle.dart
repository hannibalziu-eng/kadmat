import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadmat/src/features/technician/domain/technician_status.dart';
import 'package:kadmat/src/features/technician/presentation/providers/technician_providers.dart';

class OnlineStatusToggle extends ConsumerWidget {
  const OnlineStatusToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(technicianOnlineStatusProvider);
    final isOnline = status == TechnicianStatus.online;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.arabicLabel,
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: isOnline,
          activeThumbColor: Colors.green,
          inactiveThumbColor: Colors.grey,
          onChanged: (_) async {
            try {
              await ref.read(technicianOnlineStatusProvider.notifier).toggle();
            } catch (e) {
              if (context.mounted) {
                final normalized = e.toString().toLowerCase();
                final message = normalized.contains('permission')
                    ? 'تعذر تحديث الحالة. يرجى السماح بالموقع أولاً.'
                    : 'تعذر تحديث الحالة حالياً. حاول مرة أخرى.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
