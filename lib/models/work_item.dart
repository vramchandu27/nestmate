/// How soon a work item needs attention. Deliberately only two levels:
/// a longer scale invites agonising over which middle value applies, and
/// what an admin actually wants to know is "does this need doing now?"
enum WorkPriority { normal, urgent }

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
    this.dueOn,
    this.assignedTo = '',
    this.priority = WorkPriority.normal,
    this.estimatedCostPaise = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  bool isDone;
  final DateTime createdAt;
  DateTime? completedAt;

  /// When it needs doing by. Null for anything with no deadline — most
  /// items have one, but "look into a cheaper trash contract" doesn't.
  DateTime? dueOn;

  /// Who is handling it — the watchman, a plumber, a committee member.
  /// Free text rather than a picker: the people a society calls are not a
  /// list the app could usefully predefine.
  String assignedTo;

  WorkPriority priority;

  /// What it's expected to cost, if known. Separate from the actual
  /// expense that gets recorded later, so the two can be compared.
  int estimatedCostPaise;

  /// Past its due date and still not done. Drives the overdue styling in
  /// the list — computed rather than stored, since it changes with the
  /// date rather than with the item.
  bool get isOverdue {
    final due = dueOn;
    if (due == null || isDone) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'isDone': isDone,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'dueOn': dueOn?.millisecondsSinceEpoch,
    'assignedTo': assignedTo,
    'priority': priority.name,
    'estimatedCostPaise': estimatedCostPaise,
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
    dueOn: map['dueOn'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['dueOn'] as int)
        : null,
    assignedTo: map['assignedTo'] as String? ?? '',
    priority: WorkPriority.values.byName(
      map['priority'] as String? ?? 'normal',
    ),
    estimatedCostPaise: map['estimatedCostPaise'] as int? ?? 0,
  );
}
