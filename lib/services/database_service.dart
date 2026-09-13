import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/models/document_template.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'quill_papyrus.db');

      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      await _ensureAllTablesExist(db);
      return db;
    } catch (e) {
      // In-memory fallback if disk DB fails
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      await _ensureAllTablesExist(db);
      return db;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _ensureAllTablesExist(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureAllTablesExist(db);
  }

  Future<void> _ensureAllTablesExist(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chats (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          linked_doc_uri TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          chat_id TEXT NOT NULL,
          sender TEXT CHECK (sender IN ('user', 'assistant', 'system')),
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          FOREIGN KEY (chat_id) REFERENCES chats (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS workspace_index USING fts5(
            file_uri UNINDEXED,
            file_name,
            parent_folder,
            heading_context,
            content,
            tags
          )
        ''');
      } catch (_) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS workspace_index (
            file_uri TEXT,
            file_name TEXT,
            parent_folder TEXT,
            heading_context TEXT,
            content TEXT,
            tags TEXT
          )
        ''');
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_themes (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          is_dark INTEGER NOT NULL,
          colors_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS templates (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          category TEXT NOT NULL,
          icon TEXT NOT NULL,
          content TEXT NOT NULL,
          is_builtin INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      // Seed default templates if empty
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM templates');
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      if (count == 0) {
        for (final tmpl in DocumentTemplate.defaultTemplates) {
          await db.insert('templates', tmpl.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Repair any stuck messages from previous token stripping bugs
      try {
        await db.execute('''
          UPDATE messages
          SET content = REPLACE(content, 'Iamfunctioningwell.HowmayIassistyou', 'I am functioning well. How may I assist you?')
          WHERE content LIKE '%Iamfunctioningwell%';
        ''');
        await db.execute('''
          UPDATE messages
          SET content = REPLACE(content, 'Hello!HowcanIhelpyoutoday?<<', 'Hello! How can I help you today?')
          WHERE content LIKE '%Hello!HowcanIhelpyoutoday?<<%';
        ''');
        await db.execute('''
          UPDATE messages
          SET content = REPLACE(content, 'Hello!HowcanIhelpyoutoday?', 'Hello! How can I help you today?')
          WHERE content LIKE '%Hello!HowcanIhelpyoutoday?%';
        ''');
      } catch (_) {}
    } catch (_) {}
  }

  // Chats
  Future<void> insertChat(Chat chat) async {
    try {
      final db = await database;
      await db.insert(
        'chats',
        {
          'id': chat.id,
          'title': chat.title,
          'created_at': chat.createdAt.millisecondsSinceEpoch,
          'updated_at': chat.updatedAt.millisecondsSinceEpoch,
          'linked_doc_uri': chat.linkedDocUri,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<List<Chat>> getChats() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('chats', orderBy: 'updated_at DESC');
      return List.generate(maps.length, (i) {
        return Chat(
          id: maps[i]['id'] as String,
          title: maps[i]['title'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(maps[i]['updated_at'] as int),
          linkedDocUri: maps[i]['linked_doc_uri'] as String?,
        );
      });
    } catch (_) {
      return [];
    }
  }

  Future<Chat?> getChatById(String id) async {
    try {
      final db = await database;
      final maps = await db.query('chats', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        return Chat(
          id: maps.first['id'] as String,
          title: maps.first['title'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(maps.first['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(maps.first['updated_at'] as int),
          linkedDocUri: maps.first['linked_doc_uri'] as String?,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateChat(Chat chat) async {
    try {
      final db = await database;
      await db.update(
        'chats',
        {
          'title': chat.title,
          'updated_at': chat.updatedAt.millisecondsSinceEpoch,
          'linked_doc_uri': chat.linkedDocUri,
        },
        where: 'id = ?',
        whereArgs: [chat.id],
      );
    } catch (_) {}
  }

  Future<void> deleteChat(String id) async {
    try {
      final db = await database;
      await db.delete('chats', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // Messages
  Future<void> insertMessage(ChatMessage message) async {
    try {
      final db = await database;
      await db.insert(
        'messages',
        {
          'id': message.id,
          'chat_id': message.chatId,
          'sender': message.sender.name,
          'content': message.content,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<List<ChatMessage>> getMessages(String chatId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'messages',
        where: 'chat_id = ?',
        whereArgs: [chatId],
        orderBy: 'timestamp ASC',
      );
      return List.generate(maps.length, (i) {
        final rawContent = maps[i]['content'] as String;
        final cleanContent = DiffService.repairMissingSpaces(
          DiffService.cleanSpecialTokens(rawContent),
        );
        return ChatMessage(
          id: maps[i]['id'] as String,
          chatId: maps[i]['chat_id'] as String,
          sender: MessageSender.values.firstWhere(
            (e) => e.name == maps[i]['sender'],
            orElse: () => MessageSender.user,
          ),
          content: cleanContent,
          timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp'] as int),
        );
      });
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      final db = await database;
      await db.delete('messages', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // Workspace Index
  Future<void> upsertWorkspaceIndex({
    required String fileUri,
    required String fileName,
    required String parentFolder,
    required String headingContext,
    required String content,
    required String tags,
  }) async {
    try {
      final db = await database;
      await db.insert(
        'workspace_index',
        {
          'file_uri': fileUri,
          'file_name': fileName,
          'parent_folder': parentFolder,
          'heading_context': headingContext,
          'content': content,
          'tags': tags,
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> searchWorkspace(String query, {String? parentFolder}) async {
    try {
      final db = await database;
      final clean = query.trim();
      if (clean.isEmpty) return [];

      String sql = "SELECT * FROM workspace_index WHERE content LIKE ? OR heading_context LIKE ? OR file_name LIKE ?";
      List<dynamic> args = ['%$clean%', '%$clean%', '%$clean%'];

      if (parentFolder != null) {
        sql += " AND parent_folder = ?";
        args.add(parentFolder);
      }

      return await db.rawQuery(sql, args);
    } catch (_) {
      return [];
    }
  }

  Future<void> clearWorkspaceIndex() async {
    try {
      final db = await database;
      await db.delete('workspace_index');
    } catch (_) {}
  }

  Future<void> deleteFromWorkspaceIndex(String fileUri) async {
    try {
      final db = await database;
      await db.delete('workspace_index', where: 'file_uri = ?', whereArgs: [fileUri]);
    } catch (_) {}
  }

  // Custom Themes CRUD
  Future<List<AppThemeData>> getCustomThemes() async {
    try {
      final db = await database;
      final maps = await db.query('custom_themes', orderBy: 'updated_at DESC');
      final list = <AppThemeData>[];
      for (final m in maps) {
        try {
          final colorsJson = m['colors_json'] as String;
          final colorsMap = (jsonDecode(colorsJson) as Map<String, dynamic>?) ?? {};
          list.add(AppThemeData.fromMap({
            'id': m['id'] as String,
            'name': m['name'] as String,
            'isDark': m['is_dark'] as int,
            'isCustom': 1,
            'colors': colorsMap,
          }));
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> upsertCustomTheme(AppThemeData theme) async {
    try {
      final db = await database;
      final colors = theme.toMap()['colors'];
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'custom_themes',
        {
          'id': theme.id,
          'name': theme.name,
          'is_dark': theme.isDark ? 1 : 0,
          'colors_json': jsonEncode(colors),
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> deleteCustomTheme(String id) async {
    try {
      final db = await database;
      await db.delete('custom_themes', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // Templates CRUD
  Future<List<DocumentTemplate>> getTemplates() async {
    try {
      final db = await database;
      final maps = await db.query('templates', orderBy: 'is_builtin DESC, updated_at DESC');
      return maps.map((m) => DocumentTemplate.fromMap(m)).toList();
    } catch (_) {
      return DocumentTemplate.defaultTemplates;
    }
  }

  Future<void> upsertTemplate(DocumentTemplate template) async {
    try {
      final db = await database;
      await db.insert(
        'templates',
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> deleteTemplate(String id) async {
    try {
      final db = await database;
      await db.delete('templates', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // App Settings (Key-Value)
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      final maps = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
      if (maps.isNotEmpty) {
        return maps.first['value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'app_settings',
        {
          'key': key,
          'value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
