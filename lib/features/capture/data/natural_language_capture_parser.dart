import '../models/capture_draft.dart';

/// Conservative, on-device parsing for quick capture.
///
/// This parser intentionally understands only clear project/task phrasing.
/// Nothing is created until the user reviews and confirms the resulting draft.
class NaturalLanguageCaptureParser {
  const NaturalLanguageCaptureParser();

  static final RegExp _leadingIntent = RegExp(
    r"^(?:i\s+(?:need|have|want|must|should)\s+to\s+|i\s+have\s+|i've\s+got\s+|need\s+to\s+|must\s+|should\s+|please\s+)",
    caseSensitive: false,
  );
  static final RegExp _projectHint = RegExp(
    r'\b(exam|project|launch|campaign|course|assignment|scholarship|fellowship|thesis|business plan)\b',
    caseSensitive: false,
  );
  static final RegExp _actionStart = RegExp(
    r'^(?:revise|review|study|read|practice|practise|do|complete|finish|write|draft|submit|prepare|apply|send|call|email|build|create|design|research|check|update|fix|test|rehearse|learn|work on|schedule|contact|visit)\b',
    caseSensitive: false,
  );
  static final RegExp _actionSplit = RegExp(
    r'\s+and\s+(?=(?:revise|review|study|read|practice|practise|do|complete|finish|write|draft|submit|prepare|apply|send|call|email|build|create|design|research|check|update|fix|test|rehearse|learn|work on|schedule|contact|visit)\b)',
    caseSensitive: false,
  );
  static final RegExp _monthFirst = RegExp(
    r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b',
    caseSensitive: false,
  );
  static final RegExp _dayFirst = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+(\d{4}))?\b',
    caseSensitive: false,
  );
  static final RegExp _weekday = RegExp(
    r'\b(?:(next)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );
  static final RegExp _relative = RegExp(
    r'\bin\s+(\d+)\s+(days?|weeks?)\b',
    caseSensitive: false,
  );

  static const _months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static const _weekdays = <String, int>{
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// Parses explicit assistant capture commands without broadening ordinary
  /// prose into mutations. The returned draft still goes through the same
  /// review + CaptureService path as Quick Capture.
  CaptureDraft? parseCommand(String input, {DateTime? now}) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final reference = now ?? DateTime.now();

    final projectMatch = RegExp(
      r'^(?:create|add)\s+(?:a\s+)?project(?:\s+(?:called|named))?\s*[:\-]?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (projectMatch != null) {
      final payload = (projectMatch.group(1) ?? '').trim();
      return _projectCommandDraft(raw, payload, reference);
    }

    final taskPatterns = <RegExp>[
      RegExp(
        r'^(?:create|add)\s+(?:a\s+)?task(?:\s+(?:called|named))?\s*[:\-]?\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'^add\s+(.+?)\s+to\s+(?:my\s+)?tasks?$', caseSensitive: false),
      RegExp(r'^remember\s+to\s+(.+)$', caseSensitive: false),
    ];
    for (final pattern in taskPatterns) {
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final payload = (match.group(1) ?? '').trim();
      return _taskCommandDraft(raw, payload, reference);
    }
    return null;
  }

  CaptureDraft? _taskCommandDraft(
    String raw,
    String payload,
    DateTime reference,
  ) {
    if (payload.isEmpty) return null;
    final deadlineMatch = _parseDeadline(payload, reference);
    var title = _stripDeadline(payload, deadlineMatch?.matchedText);
    title = title
        .replaceAll(
          RegExp(r'\b(?:by|due|deadline|on)\b[:\s-]*$', caseSensitive: false),
          '',
        )
        .trim();
    if (title.isEmpty || title.length > 180) return null;
    return CaptureDraft(
      kind: CaptureDraftKind.task,
      rawText: raw,
      deadline: deadlineMatch?.date,
      tasks: [_sentenceCase(title)],
    );
  }

  CaptureDraft? _projectCommandDraft(
    String raw,
    String payload,
    DateTime reference,
  ) {
    if (payload.isEmpty) return null;
    final deadlineMatch = _parseDeadline(payload, reference);
    var body = payload;
    final deadlinePhrase = deadlineMatch?.matchedText;
    if (deadlinePhrase != null && deadlinePhrase.isNotEmpty) {
      body = body.replaceFirst(
        RegExp(RegExp.escape(deadlinePhrase), caseSensitive: false),
        '',
      );
    }
    body = body
        .replaceAll(
          RegExp(
            r'[,;]?\s*\bwith\s+(?:a\s+)?(?:deadline|due\s+date)\b[:\s-]*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'[,;]?\s*\b(?:by|due|deadline|on)\b[:\s-]*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    String projectName = body;
    String? taskText;
    final withTasks = RegExp(
      r'^(.*?)\s+with\s+tasks?\s*[:\-]?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(body);
    if (withTasks != null) {
      projectName = (withTasks.group(1) ?? '').trim();
      taskText = (withTasks.group(2) ?? '').trim();
    }

    if (projectName.isEmpty || projectName.length > 100) return null;
    final tasks = <String>[];
    if (taskText != null && taskText.isNotEmpty) {
      for (final segment in _segments(taskText)) {
        for (final clause in segment.split(_actionSplit)) {
          var task = clause.trim();
          task = task.replaceFirst(_leadingIntent, '').trim();
          if (task.isEmpty) continue;
          if (_actionStart.hasMatch(task)) {
            task = _sentenceCase(task);
            if (!tasks.contains(task)) tasks.add(task);
          }
        }
      }
    }

    return CaptureDraft(
      kind: CaptureDraftKind.project,
      rawText: raw,
      projectName: _sentenceCase(projectName),
      deadline: deadlineMatch?.date,
      tasks: tasks,
    );
  }

  CaptureDraft? parse(String input, {DateTime? now}) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return null;
    }
    final reference = now ?? DateTime.now();
    final deadlineMatch = _parseDeadline(raw, reference);
    final deadline = deadlineMatch?.date;
    final segments = _segments(raw);
    final tasks = <String>[];

    for (final segment in segments) {
      for (final clause in segment.split(_actionSplit)) {
        final task = _taskFromClause(clause, deadlineMatch?.matchedText);
        if (task != null && !tasks.contains(task)) {
          tasks.add(task);
        }
      }
    }

    final firstSegment = segments.isEmpty ? raw : segments.first;
    final projectName = _projectName(
      firstSegment,
      deadlineMatch?.matchedText,
      hasMultipleTasks: tasks.length > 1,
    );

    if (projectName != null) {
      final filteredTasks = tasks
          .where((task) => _normalize(task) != _normalize(projectName))
          .toList(growable: false);
      return CaptureDraft(
        kind: CaptureDraftKind.project,
        rawText: raw,
        projectName: projectName,
        deadline: deadline,
        tasks: filteredTasks,
      );
    }

    if (tasks.length == 1) {
      return CaptureDraft(
        kind: CaptureDraftKind.task,
        rawText: raw,
        deadline: deadline,
        tasks: tasks,
      );
    }
    if (tasks.length > 1) {
      return CaptureDraft(
        kind: CaptureDraftKind.taskList,
        rawText: raw,
        deadline: deadline,
        tasks: tasks,
      );
    }
    return null;
  }

  List<String> _segments(String input) {
    return input
        .split(RegExp(r'[;\n.]|,(?!\s*\d{4}\b)'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? _taskFromClause(String clause, String? deadlinePhrase) {
    var candidate = clause.trim();
    candidate = candidate.replaceFirst(_leadingIntent, '').trim();
    candidate = _stripDeadline(candidate, deadlinePhrase);
    candidate = candidate.replaceFirst(
      RegExp(r'^(?:to\s+)', caseSensitive: false),
      '',
    );
    candidate = candidate.trim();
    if (!_actionStart.hasMatch(candidate)) {
      return null;
    }
    return _sentenceCase(candidate);
  }

  String? _projectName(
    String firstSegment,
    String? deadlinePhrase, {
    required bool hasMultipleTasks,
  }) {
    var candidate = firstSegment.trim();
    candidate = candidate.replaceFirst(_leadingIntent, '').trim();
    candidate = _stripDeadline(candidate, deadlinePhrase);
    candidate = candidate
        .replaceAll(
          RegExp(r'\b(?:deadline|due)\b[:\s-]*$', caseSensitive: false),
          '',
        )
        .trim();

    final startsWithAction = _actionStart.hasMatch(candidate);
    final looksLikeProject = _projectHint.hasMatch(candidate);
    if (startsWithAction || (!looksLikeProject && !hasMultipleTasks)) {
      return null;
    }
    if (candidate.isEmpty || candidate.length > 100) {
      return null;
    }
    return _sentenceCase(candidate);
  }

  String _stripDeadline(String input, String? matchedText) {
    var value = input;
    if (matchedText != null && matchedText.isNotEmpty) {
      value = value.replaceFirst(
        RegExp(RegExp.escape(matchedText), caseSensitive: false),
        '',
      );
    }
    value = value.replaceAll(
      RegExp(r'\b(?:by|due|deadline|on)\s*[:\-]?\s*$', caseSensitive: false),
      '',
    );
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  _DeadlineMatch? _parseDeadline(String input, DateTime now) {
    final normalized = input.toLowerCase();
    if (RegExp(r'\btoday\b').hasMatch(normalized)) {
      return _DeadlineMatch(_endOfDay(now), 'today');
    }
    if (RegExp(r'\btomorrow\b').hasMatch(normalized)) {
      return _DeadlineMatch(
        _endOfDay(now.add(const Duration(days: 1))),
        'tomorrow',
      );
    }

    final monthFirst = _monthFirst.firstMatch(input);
    if (monthFirst != null) {
      final month = _months[(monthFirst.group(1) ?? '').toLowerCase()];
      final day = int.tryParse(monthFirst.group(2) ?? '');
      final year = int.tryParse(monthFirst.group(3) ?? '');
      final date = _absoluteDate(now, year, month, day);
      if (date != null) {
        return _DeadlineMatch(date, monthFirst.group(0) ?? '');
      }
    }

    final dayFirst = _dayFirst.firstMatch(input);
    if (dayFirst != null) {
      final day = int.tryParse(dayFirst.group(1) ?? '');
      final month = _months[(dayFirst.group(2) ?? '').toLowerCase()];
      final year = int.tryParse(dayFirst.group(3) ?? '');
      final date = _absoluteDate(now, year, month, day);
      if (date != null) {
        return _DeadlineMatch(date, dayFirst.group(0) ?? '');
      }
    }

    final relative = _relative.firstMatch(input);
    if (relative != null) {
      final amount = int.tryParse(relative.group(1) ?? '');
      final unit = (relative.group(2) ?? '').toLowerCase();
      if (amount != null && amount > 0) {
        final days = unit.startsWith('week') ? amount * 7 : amount;
        return _DeadlineMatch(
          _endOfDay(now.add(Duration(days: days))),
          relative.group(0) ?? '',
        );
      }
    }

    final weekday = _weekday.firstMatch(input);
    if (weekday != null) {
      final isNext = weekday.group(1) != null;
      final target = _weekdays[(weekday.group(2) ?? '').toLowerCase()];
      if (target != null) {
        var delta = (target - now.weekday + 7) % 7;
        if (isNext) {
          delta = delta == 0 ? 7 : delta + 7;
        }
        final date = now.add(Duration(days: delta));
        return _DeadlineMatch(_endOfDay(date), weekday.group(0) ?? '');
      }
    }
    return null;
  }

  DateTime? _absoluteDate(DateTime now, int? year, int? month, int? day) {
    if (month == null || day == null || day < 1 || day > 31) {
      return null;
    }
    var resolvedYear = year ?? now.year;
    var candidate = DateTime(resolvedYear, month, day, 23, 59);
    if (candidate.month != month || candidate.day != day) {
      return null;
    }
    if (year == null && candidate.isBefore(now)) {
      resolvedYear += 1;
      candidate = DateTime(resolvedYear, month, day, 23, 59);
    }
    return candidate;
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59);
  }

  String _sentenceCase(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String _normalize(String value) => value.trim().toLowerCase();
}

class _DeadlineMatch {
  const _DeadlineMatch(this.date, this.matchedText);

  final DateTime date;
  final String matchedText;
}
