/// Local menu image resolver — lahat ng screens (admin stock, customer menu)
/// ay gumagamit dito para sa dish photos nang naka-bundled sa lib/menus/.
///
/// Hindi na nila ginagamit ang backend `image_url` (na may mga dead
/// Pinterest links na nagbibigay ng 403). Kunin muna ang local bundled
/// assets; kung wala sa map, icon na lang ang magbabalik.
final Map<String, String> kMenuImageOverrides = <String, String>{
  'Bihon': 'lib/menus/Pancit Bihon.jpg',
  'Mike Bihon': 'lib/menus/Mike Bihon.jpg',
  'Pansit Canton': 'lib/menus/Pansit Canton.jpg',
  'Pansit Bihon Guisado': 'lib/menus/Canton-Bihon.jpg',
  'Filipino Style Spaghetti': 'lib/menus/Filipino Style Spaghetti.jpg',
  'Creamy Carbonara': 'lib/menus/Creamy Carbonarra.jpg',
  'Baked Macaroni': 'lib/menus/Baked Macaroni.jpg',
  'Clubhouse Sandwich W/ Fries': 'lib/menus/Clubhouse Sandwich with Fries.jpg',
  'Ham and Cheese Sandwich': 'lib/menus/Ham and Cheese Sandwich.jpg',
  'Tuna Melt Sandwich': 'lib/menus/Tuna Melt Sandwich.jpg',
  'Plain Wings': 'lib/menus/Plain Wings.jpg',
  'Buffalo Wings': 'lib/menus/Buffalo Wings.jpg',
  'Honey Garlic Wings': 'lib/menus/Honey Garlic Wings.jpg',
  'Caesar Salad': 'lib/menus/Caesar Salad.jpg',
  'Chopsuey': 'lib/menus/Chopsuey.jpg',
  'Pinakbet': 'lib/menus/Pinakbet.jpg',
  'Kare-Kare (Labot)': 'lib/menus/Kare-Kare (Labot).jpg',
  'Bulalo Special': 'lib/menus/Bulalo Special.jpg',
  'Sinigang na Baboy': 'lib/menus/Sinigang na Baboy.jpg',
  'Sizzling Chicken': 'lib/menus/Sizzling Chicken.jpg',
  'Sizzling Pork Sisig': 'lib/menus/Sizzling Pork Sisig.jpg',
  'Sizzling Tofu': 'lib/menus/Sizzling Tofu.jpg',
  'French Fries': 'lib/menus/French Fries.jpg',
  'Nachos Supreme': 'lib/menus/Nachos Supreme.jpg',
  'Fish and Chips': 'lib/menus/Fish and Chips.jpg',
  'Tapsilog': 'lib/menus/Tapsilog.jpg',
  'Porksilog': 'lib/menus/Porksilog.jpg',
  'Chickensilog': 'lib/menus/Chickensilog.jpg',
  'Bangusilog': 'lib/menus/Bangusilog.jpg',
  'Super Supreme Pizza': 'lib/menus/Super Supreme Pizza.jpg',
  'Hawaiian Overload': 'lib/menus/Hawaiian Overload.jpg',
  'Pepperoni Classic': 'lib/menus/Pepperoni Classic.jpg',
  'Bottled Water': 'lib/menus/Bottled Water.jpg',
  'Iced Tea (Glass)': 'lib/menus/Iced Tea (Glass).jpg',
  'Blue Lemonade': 'lib/menus/Blue Lemonade.jpg',
  'Coke Regular (330ml)': 'lib/menus/Coke Regular.jpg',
  'Sprite (330ml)': 'lib/menus/Sprite (330ml).jpg',
  'Plain Rice (Solo)': 'lib/menus/Plain Rice (Solo).jpg',
  'Garlic Rice': 'lib/menus/Garlic Rice.jpg',
  'Java Rice': 'lib/menus/Java Rice.jpg',
  'Halo-Halo Special': 'lib/menus/Halo-Halo Special.jpg',
  'Leche Flan': 'lib/menus/Leche Flan.jpg',
  'Mango Panna Cotta': 'lib/menus/Mango Panna Cotta.jpg',
  'Bibimbap': 'lib/menus/Bibimbap.jpg',
  'Kimchi Fried Rice': 'lib/menus/Kimchi Fried Rice.jpg',
  'Tteokbokki': 'lib/menus/Tteokbokki.jpg',
  'Ramen with Cheese': 'lib/menus/Ramen with Cheese.jpg',
};

String? localMenuImageFor(String dishName) {
  final String cleaned = dishName.trim();
  if (cleaned.isEmpty) return null;

  final String? direct = kMenuImageOverrides[cleaned];
  if (direct != null) return direct;

  final String norm = cleaned
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  if (norm.isEmpty) return null;

  final List<String> tokens =
      norm.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
  String? bestFile;
  double bestScore = 0;

  for (final MapEntry<String, String> entry in kMenuImageOverrides.entries) {
    final List<String> keyTokens = entry.key
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
    if (keyTokens.isEmpty) continue;
    final int shared = tokens.where((t) => keyTokens.contains(t)).length;
    final double score = tokens.isEmpty ? 0 : (shared / tokens.length);
    if (score > bestScore) {
      bestScore = score;
      bestFile = entry.value;
    }
  }

  return bestFile;
}
