
class CategoryM {
  final int id;
  final String catcode;
  final String title;
  final String? image;

  CategoryM({
    required this.id,
    required this.catcode,
    required this.title,
    this.image,
  });

  factory CategoryM.fromJson(Map<String, dynamic> j) => CategoryM(
    id: j['id'] as int,
    catcode: (j['catcode'] ?? '').toString(),
    title: (j['name'] ?? '').toString(),
    image: j['image'] as String?,
  );
}

class SubcategoryM {
  final int id;
  final String subcode;
  final String title;
  final String image;

  SubcategoryM({
    required this.id,
    required this.subcode,
    required this.title,
    required this.image,
  });

  factory SubcategoryM.fromJson(Map<String, dynamic> j) => SubcategoryM(
    id: j['id'] as int,
    subcode: (j['subcode'] ?? '').toString(),
    title: (j['name'] ?? '').toString(),
    image: (j['image'] ?? '').toString(),
  );
}

class SectionM {
  final CategoryM category;
  final List<SubcategoryM> subcategories;

  SectionM({required this.category, required this.subcategories});

  factory SectionM.fromJson(Map<String, dynamic> j) => SectionM(
    category: CategoryM.fromJson(j['category'] as Map<String, dynamic>),
    subcategories: (j['subcategories'] as List<dynamic>? ?? [])
        .map((e) => SubcategoryM.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class SubWithCat {
  final SubcategoryM sub;
  final CategoryM cat;

  SubWithCat({required this.sub, required this.cat});
}
