/// One thing the admin needs to get done — a private checklist, entirely
/// separate from anything a resident sees (unlike issues, which residents
/// report). E.g. "Call electrician about lobby light," "Renew CCTV AMC."
class WorkItem {
  WorkItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isDone = false,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  bool isDone;
  final DateTime createdAt;
  DateTime? completedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'isDone': isDone,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  factory WorkItem.fromMap(Map<String, dynamic> map) => WorkItem(
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    isDone: map['isDone'] as bool? ?? false,
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
    completedAt: map['completedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
        : null,
  );
}
