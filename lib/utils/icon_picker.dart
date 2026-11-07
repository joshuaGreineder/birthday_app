import 'package:flutter/material.dart';

/// Utility class for icon selection
class IconPicker {
  /// Available icons for custom event types (similar to birthday/anniversary style)
  static final List<IconData> availableIcons = [
    Icons.cake_rounded,
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.celebration_rounded,
    Icons.local_florist_rounded,
    Icons.pets_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.home_rounded,
    Icons.flight_rounded,
    Icons.restaurant_rounded,
    Icons.music_note_rounded,
    Icons.sports_soccer_rounded,
    Icons.book_rounded,
    Icons.beach_access_rounded,
    Icons.directions_car_rounded,
    Icons.camera_alt_rounded,
    Icons.computer_rounded,
    Icons.phone_rounded,
    Icons.games_rounded,
    Icons.movie_rounded,
    Icons.shopping_bag_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.local_cafe_rounded,
    Icons.emoji_events_rounded,
    Icons.card_giftcard_rounded,
    Icons.celebration_outlined,
    Icons.favorite_border_rounded,
  ];

  /// Match a stored code point to a const icon. Unknown points use the star.
  static IconData iconForCodePoint(int codePoint) {
    for (final icon in availableIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.star_rounded;
  }

  /// Get icon by index
  static IconData getIcon(int index) {
    if (index >= 0 && index < availableIcons.length) {
      return availableIcons[index];
    }
    return Icons.star_rounded; // Default icon
  }

  /// Get index of icon
  static int getIconIndex(IconData icon) {
    return availableIcons.indexOf(icon);
  }

  /// Get icon name for display
  static String getIconName(IconData icon) {
    final index = availableIcons.indexOf(icon);
    if (index == -1) return 'Star';
    
    final names = [
      'Cake',
      'Heart',
      'Star',
      'Celebration',
      'Flower',
      'Pet',
      'Work',
      'School',
      'Home',
      'Flight',
      'Restaurant',
      'Music',
      'Sports',
      'Book',
      'Beach',
      'Car',
      'Camera',
      'Computer',
      'Phone',
      'Games',
      'Movie',
      'Shopping',
      'Fitness',
      'Spa',
      'Cafe',
      'Trophy',
      'Gift',
      'Party',
      'Heart Outline',
    ];
    
    return names[index];
  }
}

