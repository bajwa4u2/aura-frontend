class Note {
  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });
}
