import 'dart:convert';
import 'package:sora/utils/cbox.dart';

const STATUS_NORMAL = 0;
const STATUS_TRASH = 1;
const STATUS_ARCHIVE = 2;

const tblEntry = 'entry';
const tblPhoto = 'photo';
const tblLabel = 'label';

const colID = 'id';
const colTitle = 'title';
const colContent = 'content';
const colPhotos = 'photos';
const colLabels = 'labels';
const colVersion = 'version';
const colTimeOfCreate = 'timeOfCreate';
const colTimeOfUpdate = 'timeOfUpdate';
const colIsLocked = 'isLocked';
const colStatus = 'status';
const colEntryID = 'entryID';
const colFilename = 'filename';
const colSize = 'size';
const colWidth = 'width';
const colHeight = 'height';
const colName = 'name';
const colColor = 'color';
const colHash = 'hash';

const colApp = 'app';
const colUUID = 'uuid';
const colClientUpdated = 'clientUpdated';
const colClientCreated = 'clientCreated';
const colTrash = 'trash';

const List emptyArr = [];

class TableEntry {
  String id;
  String title;
  String content;
  List photos;
  List labels;

  int version;
  String timeOfCreate;
  String timeOfUpdate;
  bool isLocked;
  int status = STATUS_NORMAL;

  TableEntry(
    this.id,
    this.title,
    this.content, {
    this.photos = emptyArr,
    this.labels = emptyArr,
    this.isLocked = false,
    this.version = 0,
    this.timeOfCreate,
    this.timeOfUpdate,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      colID: id,
      colTitle: title,
      colContent: content,
      colPhotos: JsonCodec().encode(photos),
      colLabels: JsonCodec().encode(labels),
      colVersion: version,
      colTimeOfCreate: timeOfCreate,
      colTimeOfUpdate: timeOfUpdate,
      colIsLocked: isLocked ? 1 : 0,
      colStatus: status,
    };
    return map;
  }

  TableEntry.fromMap(Map<String, dynamic> map) {
    id = map[colID];
    title = map[colTitle];
    content = map[colContent];
    photos = List.from(JsonCodec().decode(map[colPhotos]));
    labels = List.from(JsonCodec().decode(map[colLabels]));
    version = map[colVersion];
    timeOfCreate = map[colTimeOfCreate];
    timeOfUpdate = map[colTimeOfUpdate];
    isLocked = map[colIsLocked] == 1;
    status = map[colStatus];
  }
}

class TablePhoto {
  String id;
  String entryID;
  String filename;

  int size;
  int width;
  int height;
  String hash;
  int status = STATUS_NORMAL;

  String timeOfCreate;
  String timeOfUpdate;

  TablePhoto(
    this.id,
    this.entryID,
    this.filename, {
    this.size = 0,
    this.width = 0,
    this.height = 0,
    this.hash = '',
    this.timeOfCreate,
    this.timeOfUpdate,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      colID: id,
      colEntryID: entryID,
      colFilename: filename,
      colSize: size,
      colWidth: width,
      colHeight: height,
      colHash: hash,
      colStatus: status,
      colTimeOfCreate: timeOfCreate,
      colTimeOfUpdate: timeOfUpdate,
    };
    return map;
  }

  TablePhoto.fromMap(Map<String, dynamic> map) {
    id = map[colID];
    entryID = map[colEntryID];
    filename = map[colFilename];
    size = map[colSize];
    width = map[colWidth];
    height = map[colHeight];
    hash = map[colHash];
    status = map[colStatus];
    timeOfCreate = map[colTimeOfCreate];
    timeOfUpdate = map[colTimeOfUpdate];
  }
}

class TableLabel {
  String id;
  String name;

  String color;

  int version;
  String timeOfCreate;
  String timeOfUpdate;
  bool isLocked;
  int status = STATUS_NORMAL;

  TableLabel(
    this.id,
    this.name, {
    this.color = '#ffffff',
    this.isLocked = false,
    this.version = 0,
    this.timeOfCreate,
    this.timeOfUpdate,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      colID: id,
      colName: name,
      colColor: color,
      colVersion: version,
      colTimeOfCreate: timeOfCreate,
      colTimeOfUpdate: timeOfUpdate,
      colIsLocked: isLocked ? 1 : 0,
      colStatus: status,
    };
    return map;
  }

  TableLabel.fromMap(Map<String, dynamic> map) {
    id = map[colID];
    name = map[colName];
    color = map[colColor];
    version = map[colVersion];
    timeOfCreate = map[colTimeOfCreate];
    timeOfUpdate = map[colTimeOfUpdate];
    isLocked = map[colIsLocked] == 1;
    status = map[colStatus];
  }
}

class TableSitem {
  String app;
  String uuid;
  String content;
  String clientUpdated;
  String clientCreated;
  // entry.status 的 trash 不是这里的 trash
  // 这里的 trash 应该是回收站里永久删除的那种
  // 所以，现在的阶段这里永远为 0
  int trash;

  TableSitem({
    this.app,
    this.uuid,
    this.content,
    this.clientUpdated,
    this.clientCreated,
    this.trash = 0,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      colApp: app,
      colUUID: uuid,
      colContent: content,
      colClientUpdated: clientUpdated,
      colClientCreated: clientCreated,
      colTrash: trash,
    };
    return map;
  }

  TableSitem.fromMap(Map<String, dynamic> map) {
    app = map[colApp];
    uuid = map[colUUID];
    content = map[colContent];
    clientUpdated = map[colClientUpdated];
    clientCreated = map[colClientCreated];
    trash = map[colTrash];
  }

  TableSitem.fromEntry(TableEntry entry, {Cbox cbox}) {
    var plain = JsonCodec().encode(entry.toMap());
    app = 'sora-entry';
    uuid = entry.id;
    content = cbox == null ? plain : cbox.encrypt(plain);
    clientUpdated = entry.timeOfUpdate;
    clientCreated = entry.timeOfCreate;
    trash = 0;
  }

  TableEntry toEntry({Cbox cbox}) {
    var plain = cbox == null ? content : cbox.decrypt(content);
    var entry = TableEntry.fromMap(JsonCodec().decode(plain));
    return entry;
  }

  TableSitem.fromLabel(TableLabel label, {Cbox cbox}) {
    var plain = JsonCodec().encode(label.toMap());
    app = 'sora-label';
    uuid = label.id;
    content = cbox == null ? plain : cbox.encrypt(plain);
    clientUpdated = label.timeOfUpdate;
    clientCreated = label.timeOfCreate;
    trash = 0;
  }

  TableLabel toLabel({Cbox cbox}) {
    var plain = cbox == null ? content : cbox.decrypt(content);
    var label = TableLabel.fromMap(JsonCodec().decode(plain));
    return label;
  }

  TableSitem.fromPhoto(TablePhoto photo, {Cbox cbox}) {
    var plain = JsonCodec().encode(photo.toMap());
    app = 'sora-photo';
    uuid = photo.id;
    content = cbox == null ? plain : cbox.encrypt(plain);
    clientUpdated = photo.timeOfCreate;
    clientCreated = photo.timeOfCreate;
    trash = 0;
  }

  TablePhoto toPhoto({Cbox cbox}) {
    var plain = cbox == null ? content : cbox.decrypt(content);
    var photo = TablePhoto.fromMap(JsonCodec().decode(plain));
    return photo;
  }
}
