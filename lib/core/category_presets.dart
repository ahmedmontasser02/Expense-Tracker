import 'package:flutter/material.dart';

/// Curated icon set + palette for user-defined categories.
/// Icons are persisted as their codePoint strings so the schema stays simple.
class IconPresets {
  IconPresets._();

  static const Map<String, IconData> icons = {
    'restaurant': Icons.restaurant,
    'fastfood': Icons.fastfood,
    'coffee': Icons.local_cafe,
    'directions_car': Icons.directions_car,
    'local_gas_station': Icons.local_gas_station,
    'home': Icons.home,
    'bolt': Icons.bolt,
    'water_drop': Icons.water_drop,
    'phone_iphone': Icons.phone_iphone,
    'subscriptions': Icons.subscriptions,
    'movie': Icons.movie,
    'sports_esports': Icons.sports_esports,
    'fitness_center': Icons.fitness_center,
    'local_hospital': Icons.local_hospital,
    'shopping_bag': Icons.shopping_bag,
    'shopping_cart': Icons.shopping_cart,
    'checkroom': Icons.checkroom,
    'school': Icons.school,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'redeem': Icons.redeem,
    'work': Icons.work,
    'savings': Icons.savings,
    'trending_up': Icons.trending_up,
    'stars': Icons.stars,
    'account_balance': Icons.account_balance,
    'more_horiz': Icons.more_horiz,
  };

  static const defaultCode = 'more_horiz';

  static IconData? of(String code) => icons[code];

  /// Stable list of Material colors used for category swatches.
  static const List<Color> palette = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF00897B),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
    Color(0xFF00ACC1),
  ];
}

/// Default categories seeded on first launch (and topped up on upgrade).
class SeedCategories {
  SeedCategories._();

  /// (name, iconCode, palette index)
  static const expenses = <(String, String, int)>[
    ('Lunch & Dining', 'fastfood', 0),
    ('Snacks & Coffee', 'coffee', 8),
    ('Groceries', 'shopping_cart', 3),
    ('Games', 'sports_esports', 6),
    ('Rent', 'home', 10),
    ('Transport', 'directions_car', 1),
    ('Fuel', 'local_gas_station', 2),
    ('Utilities', 'water_drop', 5),
    ('Phone & Internet', 'phone_iphone', 4),
    ('Subscriptions', 'subscriptions', 11),
    ('Entertainment', 'movie', 8),
    ('Health', 'local_hospital', 0),
    ('Fitness', 'fitness_center', 3),
    ('Shopping', 'shopping_bag', 11),
    ('Clothing', 'checkroom', 9),
    ('Education', 'school', 6),
    ('Travel', 'flight', 9),
    ('Pets', 'pets', 10),
    ('Gifts', 'redeem', 8),
    ('Other', 'more_horiz', 10),
  ];

  static const incomes = <(String, String, int)>[
    ('Salary', 'work', 3),
    ('Freelance', 'bolt', 2),
    ('Investments', 'trending_up', 4),
    ('Bonus', 'stars', 2),
    ('Gifts', 'redeem', 8),
    ('Other Income', 'more_horiz', 10),
  ];
}
