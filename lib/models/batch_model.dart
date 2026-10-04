class LectureItem {
  final String videoId;
  final String title;
  final String duration;
  final String date;
  bool isSelected;

  LectureItem({
    required this.videoId,
    required this.title,
    this.duration = '',
    this.date = '',
    this.isSelected = false,
  });

  factory LectureItem.fromJson(Map<String, dynamic> json) {
    return LectureItem(
      videoId: json['videoId'] ?? json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? json['topic'] ?? 'Untitled Lecture',
      duration: json['duration']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}

class NoteItem {
  final String url;
  final String name;
  final String date;
  bool isSelected;

  NoteItem({
    required this.url,
    required this.name,
    this.date = '',
    this.isSelected = false,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      url: json['url'] ?? json['attachmentUrl'] ?? '',
      name: json['name'] ?? json['title'] ?? 'Document Note',
      date: json['date']?.toString() ?? '',
    );
  }
}

class TopicInfo {
  final String chapterId;
  final String chapterName;
  final List<LectureItem> lectures;
  final List<NoteItem> notes;
  bool isExpanded;

  TopicInfo({
    required this.chapterId,
    required this.chapterName,
    required this.lectures,
    required this.notes,
    this.isExpanded = false,
  });

  factory TopicInfo.fromJson(Map<String, dynamic> json) {
    var rawLectures = json['lectures'] ?? json['videos'] ?? [];
    var rawNotes = json['notes'] ?? json['attachments'] ?? [];

    List<LectureItem> lList = [];
    if (rawLectures is List) {
      for (var item in rawLectures) {
        if (item is Map<String, dynamic>) {
          lList.add(LectureItem.fromJson(item));
        }
      }
    }

    List<NoteItem> nList = [];
    if (rawNotes is List) {
      for (var item in rawNotes) {
        if (item is Map<String, dynamic>) {
          nList.add(NoteItem.fromJson(item));
        }
      }
    }

    return TopicInfo(
      chapterId: json['chapterId'] ?? json['_id'] ?? json['id'] ?? '',
      chapterName: json['chapterName'] ?? json['name'] ?? json['topic'] ?? 'Chapter',
      lectures: lList,
      notes: nList,
    );
  }
}

class SubjectInfo {
  final String subjectId;
  final String subjectName;
  final List<TopicInfo> topics;

  SubjectInfo({
    required this.subjectId,
    required this.subjectName,
    required this.topics,
  });

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    var rawTopics = json['topics'] ?? json['chapters'] ?? [];
    List<TopicInfo> tList = [];
    if (rawTopics is List) {
      for (var item in rawTopics) {
        if (item is Map<String, dynamic>) {
          tList.add(TopicInfo.fromJson(item));
        }
      }
    }

    return SubjectInfo(
      subjectId: json['subjectId'] ?? json['_id'] ?? json['id'] ?? '',
      subjectName: json['subjectName'] ?? json['name'] ?? 'Subject',
      topics: tList,
    );
  }
}

class BatchManifest {
  final String id;
  final String name;
  final List<SubjectInfo> subjects;

  BatchManifest({
    required this.id,
    required this.name,
    required this.subjects,
  });

  factory BatchManifest.fromJson(Map<String, dynamic> json) {
    var batchObj = json['batch'] ?? json['data'] ?? json;
    String bId = batchObj['id'] ?? batchObj['_id'] ?? json['batchId'] ?? '';
    String bName = batchObj['name'] ?? batchObj['title'] ?? 'Course Batch';

    var rawSubjects = json['subjects'] ?? batchObj['subjects'] ?? [];
    List<SubjectInfo> sList = [];
    if (rawSubjects is List) {
      for (var item in rawSubjects) {
        if (item is Map<String, dynamic>) {
          sList.add(SubjectInfo.fromJson(item));
        }
      }
    }

    return BatchManifest(
      id: bId,
      name: bName,
      subjects: sList,
    );
  }
}
