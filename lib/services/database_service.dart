import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
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

      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    } catch (e) {
      // In-memory fallback if disk DB fails
      return await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
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
        // Fallback if FTS5 virtual table extension is not present in device SQLite
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
        return ChatMessage(
          id: maps[i]['id'] as String,
          chatId: maps[i]['chat_id'] as String,
          sender: MessageSender.values.firstWhere(
            (e) => e.name == maps[i]['sender'],
            orElse: () => MessageSender.user,
          ),
          content: maps[i]['content'] as String,
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
}
