class MenuItem {
  final String name;
  final String category;
  final String defaultStation;
  final List<String> availableModifiers;

  const MenuItem({
    required this.name,
    required this.category,
    required this.defaultStation,
    this.availableModifiers = const [],
  });
}

const List<MenuItem> menuCatalog = [
  MenuItem(name: 'Classic Burger', category: 'Burgers', defaultStation: 'Grill', availableModifiers: ['No Onion', 'Extra Cheese', 'Rare', 'Well Done']),
  MenuItem(name: 'Cheese Burger', category: 'Burgers', defaultStation: 'Grill', availableModifiers: ['No Onion', 'Bacon']),
  MenuItem(name: 'Fries', category: 'Sides', defaultStation: 'Fryer', availableModifiers: ['No Salt', 'Large']),
  MenuItem(name: 'Onion Rings', category: 'Sides', defaultStation: 'Fryer'),
  MenuItem(name: 'Coke', category: 'Drinks', defaultStation: 'Counter'),
  MenuItem(name: 'Sprite', category: 'Drinks', defaultStation: 'Counter'),
  MenuItem(name: 'Chicken Salad', category: 'Salads', defaultStation: 'Cold Line'),
];
