///
/// 数据库操作
///
/// 创建一个新的记事
/// 更新一个记事
/// 获取一个记事
/// 根据标签、搜索关键字、状态 来分页获取记事
/// 创建一个新的标签
/// 更新一个标签
/// 获取所有标签
/// 创建一个图片记录
/// 分页获取所有图片
///
/// created by keng42 @2019-08-06 12:34:33
///

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:sora/db/tables.dart';

class DBHelper {
  Database db;

  // 初始化数据库
  Future init() async {
    if (db != null) {
      return;
    }
    // 获取数据库文件的存储路径
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'sora.db');

    //根据数据库文件路径和数据库版本号创建数据库表
    db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tblEntry (
            $colID TEXT PRIMARY KEY, 
            $colTitle TEXT,
            $colContent TEXT,
            $colPhotos TEXT,
            $colLabels TEXT,
            $colVersion INTEGER,
            $colTimeOfCreate TEXT,
            $colTimeOfUpdate TEXT,
            $colIsLocked INTEGER,
            $colStatus INTEGER);
          ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tblPhoto (
            $colID TEXT PRIMARY KEY, 
            $colEntryID TEXT,
            $colFilename TEXT,
            $colSize INTEGER,
            $colWidth INTEGER,
            $colHeight INTEGER,
            $colHash TEXT,
            $colTimeOfCreate TEXT,
            $colTimeOfUpdate TEXT,
            $colStatus INTEGER);
          ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tblLabel (
            $colID TEXT PRIMARY KEY, 
            $colName TEXT,
            $colColor TEXT,
            $colVersion INTEGER,
            $colTimeOfCreate TEXT,
            $colTimeOfUpdate TEXT,
            $colIsLocked INTEGER,
            $colStatus INTEGER);
          ''');
      },
    );
  }

  Future<Database> ready() async {
    if (db == null) {
      await init();
    }
    return db;
  }

  // 创建一个新的记事
  Future<TableEntry> saveEntry(TableEntry entry) async {
    await db.insert(tblEntry, entry.toMap());
    return entry;
  }

  // 更新一个记事
  Future<int> updateEntry(TableEntry entry) async {
    return await db.update(tblEntry, entry.toMap(),
        where: '$colID = ?', whereArgs: [entry.id]);
  }

  // 获取一个记事
  Future<TableEntry> loadEntry(String id) async {
    List<Map> maps = await db.query(tblEntry,
        columns: [
          colID,
          colTitle,
          colContent,
          colPhotos,
          colLabels,
          colVersion,
          colTimeOfCreate,
          colTimeOfUpdate,
          colIsLocked,
          colStatus,
        ],
        where: '$colID = ?',
        whereArgs: [id]);
    if (maps.length > 0) {
      return TableEntry.fromMap(maps.first);
    }
    return null;
  }

  // 获取最近的一个记事
  Future<TableEntry> loadLatestEntry() async {
    List<Map> maps =
        await db.query(tblEntry, limit: 1, orderBy: '$colTimeOfUpdate desc');
    if (maps.length > 0) {
      return TableEntry.fromMap(maps.first);
    }
    return null;
  }

  // 根据标签、搜索关键字、状态 来分页获取记事
  Future<List<TableEntry>> loadEntries({
    int page = 1,
    int perPage = 10,
    int status = STATUS_NORMAL,
    String order = 'desc',
    String orderKey = colTimeOfUpdate,
    String keyword,
    String label,
    String lastItemTime,
    String lastItemID,
  }) async {
    var whereTemplate = '$colStatus = ?';
    var whereArgs = ['$status'];

    // 根据某个条目作为分割线
    if (lastItemTime != null) {
      // 默认的降序，从最新的到最旧的
      var op = order == 'desc' ? '<=' : '>=';
      whereTemplate = '$whereTemplate AND $orderKey $op ?';
      whereArgs.add(lastItemTime);
      if (lastItemID != null) {
        whereTemplate = '$whereTemplate AND $colID != ?';
        whereArgs.add(lastItemID);
      }
    }

    if (keyword != null && keyword.isNotEmpty) {
      whereTemplate =
          "$whereTemplate AND ($colTitle LIKE ? OR $colContent LIKE ?)";
      whereArgs.add('%$keyword%');
      whereArgs.add('%$keyword%');
    }
    if (label != null && label.isNotEmpty) {
      whereTemplate = "$whereTemplate AND $colLabels LIKE ?";
      whereArgs.add('%$label%');
    }

    List<Map> maps = await db.query(
      tblEntry,
      where: whereTemplate,
      whereArgs: whereArgs,
      orderBy: '$orderKey $order',
      limit: perPage,
      offset: (page - 1) * perPage,
    );

    if (maps == null || maps.length == 0) {
      return [];
    }

    List<TableEntry> entrys = [];
    for (int i = 0; i < maps.length; i++) {
      entrys.add(TableEntry.fromMap(maps[i]));
    }

    return entrys;
  }

  // 创建一个新的标签
  Future<TableLabel> saveLabel(TableLabel label) async {
    await db.insert(tblLabel, label.toMap());
    return label;
  }

  // 更新一个标签
  Future<int> updateLabel(TableLabel label) async {
    return await db.update(tblLabel, label.toMap(),
        where: '$colID = ?', whereArgs: [label.id]);
  }

  // 获取一个标签
  Future<TableEntry> loadLabel(String id) async {
    List<Map> maps =
        await db.query(tblLabel, where: '$colID = ?', whereArgs: [id]);
    if (maps.length > 0) {
      return TableEntry.fromMap(maps.first);
    }
    return null;
  }

  // 获取所有标签
  Future<List<TableLabel>> loadLabels() async {
    List<Map> maps = await db
        .query(tblLabel, where: '$colStatus = ?', whereArgs: [STATUS_NORMAL]);

    if (maps == null || maps.length == 0) {
      return [];
    }

    List<TableLabel> labels = [];
    for (int i = 0; i < maps.length; i++) {
      labels.add(TableLabel.fromMap(maps[i]));
    }

    return labels;
  }

  // 创建一个图片记录
  Future<TablePhoto> savePhoto(TablePhoto photo) async {
    await db.insert(tblPhoto, photo.toMap());
    return photo;
  }

  // 更新一个图片记录
  Future<int> updatePhoto(TablePhoto photo) async {
    return await db.update(tblPhoto, photo.toMap(),
        where: '$colID = ?', whereArgs: [photo.id]);
  }

  // 获取一个图片记录
  Future<TableEntry> loadPhoto(String id) async {
    List<Map> maps =
        await db.query(tblPhoto, where: '$colID = ?', whereArgs: [id]);
    if (maps.length > 0) {
      return TableEntry.fromMap(maps.first);
    }
    return null;
  }

  // 分页获取所有图片
  // 默认按创建时间倒序查询
  Future<List<TablePhoto>> loadPhotos({
    int page = 1,
    int perPage = 10,
    String order = 'desc',
    String lastItemTime,
    String lastItemID,
  }) async {
    var whereTemplate = '$colStatus = ?';
    var whereArgs = ['$STATUS_NORMAL'];

    // 根据某个条目作为分割线
    if (lastItemTime != null) {
      // 默认的降序，从最新的到最旧的
      var op = order == 'desc' ? '<=' : '>=';
      whereTemplate = '$whereTemplate AND $colTimeOfUpdate $op ?';
      whereArgs.add(lastItemTime);
      if (lastItemID != null) {
        whereTemplate = '$whereTemplate AND $colID != ?';
        whereArgs.add(lastItemID);
      }
    }

    List<Map> maps = await db.query(tblPhoto,
        where: whereTemplate,
        whereArgs: whereArgs,
        orderBy: '$colTimeOfUpdate $order',
        limit: perPage,
        offset: (page - 1) * perPage);

    if (maps == null || maps.length == 0) {
      return [];
    }

    List<TablePhoto> photos = [];
    for (int i = 0; i < maps.length; i++) {
      photos.add(TablePhoto.fromMap(maps[i]));
    }

    return photos;
  }

  // 删除一个图片记录
  Future<int> trashPhoto(String id) async {
    var now = DateTime.now().toIso8601String();
    return await db.update(
        tblPhoto, {colStatus: STATUS_TRASH, colTimeOfUpdate: now},
        where: '$colID = ?', whereArgs: [id]);
  }

  // 更新或创建一个记事
  Future safeUpdateEntry(TableEntry item) async {
    var oldItem = await loadEntry(item.id);
    if (oldItem == null) {
      return await saveEntry(item);
    }
    return await updateEntry(item);
  }

  // 更新或创建一个标签
  Future safeUpdateLabel(TableLabel item) async {
    var oldItem = await loadLabel(item.id);
    if (oldItem == null) {
      return await saveLabel(item);
    }
    return await updateLabel(item);
  }

  // 更新或创建一个图片记录
  Future safeUpdatePhoto(TablePhoto item) async {
    var oldItem = await loadPhoto(item.id);
    if (oldItem == null) {
      return await savePhoto(item);
    }
    return await updatePhoto(item);
  }

  Future close() async {
    await db.close();
    db = null;
  }

  Future reInit() async {
    await close();
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'sora.db');
    await deleteDatabase(path);
    await init();
  }
}

// 全局单实例数据库操作对象
final dbHelper = new DBHelper();

final uuid = Uuid();

Future<DBHelper> openDB() async {
  if (dbHelper.db == null) {
    await dbHelper.init();
  }
  return dbHelper;
}
