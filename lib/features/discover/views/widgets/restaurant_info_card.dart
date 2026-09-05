import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../../models/discover_restaurant.dart';

class RestaurantInfoCard extends StatelessWidget {
  const RestaurantInfoCard({required this.restaurant, super.key});

  final DiscoverRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: LucideIcons.mapPin,
            label: 'Address',
            value: _formatAddress(restaurant.address),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: LucideIcons.clock,
            label: 'Operating Hours',
            value: _formatOperatingHours(restaurant.operatingHours),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: LucideIcons.phone,
            label: 'Contact',
            value: _formatContact(restaurant.contact),
          ),
        ],
      ),
    );
  }

  static String _formatAddress(String? address) {
    if (address == null || address.trim().isEmpty) return '-';
    return address.trim();
  }

  static String _formatOperatingHours(String? hours) {
    final formatted = formatOperatingHours(hours);
    return formatted.isEmpty ? '-' : formatted;
  }

  static String _formatContact(String? contact) {
    if (contact == null || contact.trim().isEmpty) return '-';
    return contact.trim();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
