class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });
  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;
  factory Folder.fromMap(Map<String, Object?> row) => Folder(
    id: row['id'] as int,
    name: row['name'] as String,
    createdAt: row['created_at'] as String,
    cardCount: (row['card_count'] as int?) ?? 0,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'created_at': createdAt,
  };
}

class CatalogueCard {
  const CatalogueCard({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });
  static const suits = ['spades', 'hearts', 'diamonds', 'clubs'];
  static const symbols = {
    'spades': '♠',
    'hearts': '♥',
    'diamonds': '♦',
    'clubs': '♣',
  };
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;
  factory CatalogueCard.fromMap(Map<String, Object?> row) => CatalogueCard(
    id: row['id'] as int,
    title: row['title'] as String,
    suit: row['suit'] as String,
    notes: row['notes'] as String,
    imageRef: row['image_ref'] as String?,
    folderId: row['folder_id'] as int,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title.trim(),
    'suit': suit,
    'notes': notes,
    'image_ref': (imageRef?.trim().isEmpty ?? true) ? null : imageRef!.trim(),
    'folder_id': folderId,
  };
}
