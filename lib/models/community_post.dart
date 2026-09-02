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

/// A notice-feed post in the joined association's community feed.
class CommunityPost {
  CommunityPost({
    required this.id,
    required this.authorName,
    this.isCommittee = true,
    this.pinned = false,
    required this.timeLabel,
    required this.title,
    required this.body,
    this.likeCount = 0,
    List<Comment>? comments,
  }) : comments = comments ?? [];

  final String id;
  final String authorName;
  final bool isCommittee;
  final bool pinned;
  final String timeLabel;
  final String title;
  final String body;
  int likeCount;
  List<Comment> comments;

  Map<String, dynamic> toMap() => {
    'id': id,
    'authorName': authorName,
    'isCommittee': isCommittee,
    'pinned': pinned,
    'timeLabel': timeLabel,
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
    timeLabel: map['timeLabel'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    likeCount: map['likeCount'] as int? ?? 0,
    comments: (map['comments'] as List? ?? [])
        .map((c) => Comment.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );
}
