enum IssueStatus { inProgress, resolved }

/// A maintenance problem a resident reported.
class IssueReport {
  IssueReport({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    this.photoAdded = false,
    this.photoUrl,
    required this.flatNumber,
    this.status = IssueStatus.inProgress,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String type;
  String location;
  bool photoAdded;
  String? photoUrl;
  final String flatNumber;
  IssueStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type,
    'location': location,
    'photoAdded': photoAdded,
    'photoUrl': photoUrl,
    'flatNumber': flatNumber,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory IssueReport.fromMap(Map<String, dynamic> map) => IssueReport(
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    type: map['type'] as String? ?? '',
    location: map['location'] as String? ?? '',
    photoAdded: map['photoAdded'] as bool? ?? false,
    photoUrl: map['photoUrl'] as String?,
    flatNumber: map['flatNumber'] as String? ?? '',
    status: IssueStatus.values.byName(map['status'] as String? ?? 'inProgress'),
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
  );
}
