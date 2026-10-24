import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';

class ChildHomeScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback onOpenActivities;

  const ChildHomeScreen({
    super.key,
    required this.user,
    required this.onOpenActivities,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          Text(
            'Hola, ${user.name}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Listo para comenzar?',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.cardBg,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.mintLight,
                      foregroundColor: AppColors.primaryDark,
                      child: Icon(Icons.extension_rounded, size: 32),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Mis actividades',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aquí encontrarás las actividades preparadas para ti.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onOpenActivities,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Ir a mis actividades'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
