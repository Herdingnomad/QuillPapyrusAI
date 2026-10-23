import 'dart:convert';
import 'package:uuid/uuid.dart';

class TemplateAppliedResult {
  final String content;
  final int cursorOffset;

  const TemplateAppliedResult({
    required this.content,
    required this.cursorOffset,
  });
}

class DocumentTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String icon;
  final String content;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.content,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DocumentTemplate copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? icon,
    String? content,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      content: content ?? this.content,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Expands macro variables with support for user-selected date formats:
  /// - 'us'  : MM-DD-YYYY (e.g. 09-12-2026)
  /// - 'iso' : YYYY-MM-DD (e.g. 2026-09-12)
  /// - 'eu'  : DD-MM-YYYY (e.g. 12-09-2026)
  TemplateAppliedResult applyVariables({
    String? title,
    String dateFormat = 'us',
    DateTime? now,
  }) {
    final dt = now ?? DateTime.now();
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    final usDate = '$mm-$dd-$yyyy';
    final isoDate = '$yyyy-$mm-$dd';
    final euDate = '$dd-$mm-$yyyy';

    String defaultDate;
    switch (dateFormat.toLowerCase()) {
      case 'iso':
        defaultDate = isoDate;
        break;
      case 'eu':
        defaultDate = euDate;
        break;
      case 'us':
      default:
        defaultDate = usDate;
        break;
    }

    final timeStr = '$hh:$min';
    final effectiveTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : this.title;

    var result = content
        .replaceAll('{{date}}', defaultDate)
        .replaceAll('{{date_us}}', usDate)
        .replaceAll('{{date_iso}}', isoDate)
        .replaceAll('{{date_eu}}', euDate)
        .replaceAll('{{time}}', timeStr)
        .replaceAll('{{datetime}}', '$defaultDate $timeStr')
        .replaceAll('{{year}}', yyyy)
        .replaceAll('{{month}}', mm)
        .replaceAll('{{day}}', dd)
        .replaceAll('{{title}}', effectiveTitle)
        .replaceAll('{{uuid}}', const Uuid().v4());

    int cursorOffset = -1;
    const cursorToken = '{{cursor}}';
    final tokenIndex = result.indexOf(cursorToken);
    if (tokenIndex != -1) {
      cursorOffset = tokenIndex;
      result = result.replaceFirst(cursorToken, '');
    } else {
      cursorOffset = result.length;
    }

    return TemplateAppliedResult(
      content: result,
      cursorOffset: cursorOffset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'icon': icon,
      'content': content,
      'is_builtin': isBuiltIn ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory DocumentTemplate.fromMap(Map<String, dynamic> map) {
    return DocumentTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      icon: map['icon'] as String? ?? 'description',
      content: map['content'] as String? ?? '',
      isBuiltIn: (map['is_builtin'] == 1 || map['is_builtin'] == true),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int? ?? 0),
    );
  }

  factory DocumentTemplate.fromJson(String source) =>
      DocumentTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);

  // Default Seed Templates
  static List<DocumentTemplate> get defaultTemplates {
    final now = DateTime(2026, 1, 1);
    return [
      DocumentTemplate(
        id: 'daily_journal',
        title: 'Daily Journal & Reflections',
        description: 'Morning mindset, daily priorities, wins, and evening retrospective.',
        category: 'Personal',
        icon: 'coffee',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [journal, reflections, daily]
topics: [personal-growth, mindfulness]
mood: "Focused"
weather: "Sunny"
---

# ☕ {{title}}
**Date:** {{date}} | **Time:** {{time}}

## 🌅 Morning Focus & Intentions
- **Top Priority 1:** {{cursor}}
- **Top Priority 2:** 
- **Top Priority 3:** 

### Gratitude
1. 
2. 
3. 

---

## 📝 Daily Notes & Log
- 

---

## 🌙 Evening Reflection
- **What went well today?** 
- **What could be improved?** 
- **Tomorrow's Core Goal:** 
''',
      ),
      DocumentTemplate(
        id: 'project_spec',
        title: 'Project Specification & RFC',
        description: 'System architecture, design goals, API contracts, and implementation milestones.',
        category: 'Engineering',
        icon: 'rocket',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [architecture, rfc, specification]
topics: [engineering, design]
status: "Draft"
author: "Engineering Team"
---

# 🚀 {{title}}
**Status:** Draft | **Author:** Team | **Last Updated:** {{date}}

## 1. Executive Summary
{{cursor}}A high-level overview of the feature, system component, or architecture change.

## 2. Goals & Non-Goals
### Goals
- 
- 

### Non-Goals
- 

## 3. Architecture & Technical Design
```mermaid
graph TD
    A[Client UI] --> B[Controller Layer]
    B --> C[Local SQLite DB]
    B --> D[On-Device AI Engine]
```

### Data Models & Schemas
- 

## 4. Milestones & Delivery Plan
- [ ] Phase 1: Core foundation & data schema
- [ ] Phase 2: State management & business logic
- [ ] Phase 3: UI integration & unit tests
''',
      ),
      DocumentTemplate(
        id: 'meeting_notes',
        title: 'Meeting Notes & Action Items',
        description: 'Structured sync agenda, key discussion points, decisions, and action item matrix.',
        category: 'Work',
        icon: 'groups',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [meeting, sync, action-items]
topics: [team, collaboration]
attendees: []
---

# 👥 {{title}}
**Date:** {{date}} | **Time:** {{time}}

## 🎯 Meeting Objective
{{cursor}}

## 📋 Agenda
1. Project Status & Blockers
2. Key Architecture Decisions
3. Next Steps & Assignments

## 💬 Discussion Notes
- 
- 

## ⚖️ Decisions Made
> [!NOTE]
> 

## ✅ Action Items
| Task | Assignee | Due Date | Status |
| :--- | :--- | :--- | :--- |
| Initial draft review | | {{date}} | Pending |
| Verify SQLite migrations | | | In Progress |
''',
      ),
      DocumentTemplate(
        id: 'weekly_review',
        title: 'Weekly Review & Roadmap',
        description: 'End-of-week retrospective, key metrics, achievements, and roadmap planning.',
        category: 'Work',
        icon: 'analytics',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [review, retrospective, roadmap]
topics: [productivity, planning]
week: "{{year}}-W"
---

# 📊 {{title}}
**Week of:** {{date}}

## 🏆 Highlights & Key Wins
- {{cursor}}
- 

## ⚠️ Challenges & Blockers
- 

## 📈 Metric Review
| Metric | Goal | Actual | Status |
| :--- | :--- | :--- | :--- |
| Commits / PRs | | | 🟢 |
| Tests Passing | 100% | 100% | 🟢 |

## 🎯 Next Week Priorities
1. 
2. 
3. 
''',
      ),
      DocumentTemplate(
        id: 'farm_field_log',
        title: 'Farm & Field Log',
        description: 'Pasture rotation, herd/flock health observation, rainfall, and maintenance log.',
        category: 'Field',
        icon: 'agriculture',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [farm, livestock, pasture, field-log]
topics: [agriculture, herd-management]
rainfall_inches: 0.0
---

# 🌾 {{title}}
**Date:** {{date}} | **Weather:** Sunny, 72°F | **Rainfall:** 0.0"

## 🐐 Herd & Livestock Health
- **Active Group:** Main Herd
- **Observations:** {{cursor}}
- **Feed & Supplements:** Hay + Mineral loose mix

## 🌿 Pasture & Grazing Rotation
- **Current Paddock:** Paddock 2 (Day 4 of 7)
- **Grass Height (Entry/Current):** 8" -> 5"
- **Next Rotation:** Paddock 3

## 🚜 Equipment & Fence Maintenance
- [ ] Inspect perimeter solar energizer
- [ ] Check float valves on north water trough
''',
      ),
      DocumentTemplate(
        id: 'research_notes',
        title: 'Scientific & Research Note',
        description: 'Hypothesis, experimental setup, observations, raw data tables, and conclusions.',
        category: 'Research',
        icon: 'science',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [research, experiment, science]
topics: [methodology, findings]
hypothesis: ""
---

# 🔬 {{title}}
**Date:** {{date}}

## 💡 Hypothesis
{{cursor}}

## 🧪 Methodology & Setup
- **Sample:** 
- **Controls:** 
- **Variables:** 

## 📊 Observations & Data
| Sample ID | Variable A | Measurement | Outcome |
| :--- | :--- | :--- | :--- |
| #01 | | | |
| #02 | | | |

## 📌 Findings & Next Steps
- 
''',
      ),
      DocumentTemplate(
        id: 'blank_starter',
        title: 'Clean Frontmatter Starter',
        description: 'Minimal starting template with standard YAML frontmatter headers.',
        category: 'General',
        icon: 'description',
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
        content: '''---
title: "{{title}}"
date: {{date}}
tags: [notes]
topics: [general]
---

# {{title}}

{{cursor}}
''',
      ),
    ];
  }
}
