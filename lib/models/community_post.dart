/// A comment on a community post.
class Comment {
  Comment({required this.authorName, required this.text});

  final String authorName;
  final String text;

  Map<String, dynamic> toMap() => {'authorName': authorName, 'text': text};

  factory Comment.fromMap(Map<String, dynamic> map) => Comment(
    authorName: map['authorName'] as String? ?? '',
    text: map['text'] as String? ?? '',
  );
}

/// A notice-feed post in this building's own notice board.
class CommunityPost {
  CommunityPost({
    required this.id,
    required this.authorName,
    this.isCommittee = true,
    this.pinned = false,
    DateTime? createdAt,
    required this.title,
    required this.body,
    this.likeCount = 0,
    List<Comment>? comments,
  }) : createdAt = createdAt ?? DateTime.now(),
       comments = comments ?? [];

  final String id;
  final String authorName;
  final bool isCommittee;
  final bool pinned;
  final DateTime createdAt;
  final String title;
  final String body;
  int likeCount;
  List<Comment> comments;

  /// A relative "time ago" label computed fresh every time it's read,
  /// rather than a string frozen at posting time — that was the bug: a
  /// stored `timeLabel: 'Just now'` never stopped saying "Just now", no
  /// matter how much later it was actually viewed.
  String get timeLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'authorName': authorName,
    'isCommittee': isCommittee,
    'pinned': pinned,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'likeCount': likeCount,
    'comments': comments.map((c) => c.toMap()).toList(),
  };

  factory CommunityPost.fromMap(Map<String, dynamic> map) => CommunityPost(
    id: map['id'] as String,
    authorName: map['authorName'] as String? ?? '',
    isCommittee: map['isCommittee'] as bool? ?? true,
    pinned: map['pinned'] as bool? ?? false,
    createdAt: map['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
        : DateTime.now(),
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    likeCount: map['likeCount'] as int? ?? 0,
    comments: (map['comments'] as List? ?? [])
        .map((c) => Comment.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );
}
