import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sora/utils/c.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/db/index.dart';
import 'package:sora/router.dart';

class PageEntry extends StatefulWidget {
  PageEntry({this.id, this.label});

  final String id;
  final TableLabel label;

  @override
  _PageEntryState createState() => _PageEntryState();
}

class _PageEntryState extends State<PageEntry> {
  ScrollController _scrollController = new ScrollController();
  TextEditingController _contentController = new TextEditingController();
  TextEditingController _titleController = new TextEditingController();

  TableEntry _entry;
  TableEntry _oldEntry;
  String _photosPath;
  bool _textChanged = true;
  String _textChangedContent = '';
  String _textChangedTitle = '';
  bool _shouldTrashEmptyEntry = true;
  Map<String, int> _filesMap = {};
  Map<String, String> _labelsMap = {};

  @override
  void initState() {
    super.initState();

    _readPhotosPath();

    // 滚动到顶部或底部时隐藏键盘
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == 0.0) {
        FocusScope.of(context).unfocus();
      } else if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        FocusScope.of(context).unfocus();
      }
    });
    _loadEntry();
  }

  @override
  void deactivate() async {
    super.deactivate();
  }

  @override
  void dispose() async {
    super.dispose();
    await _saveEntry();
  }

  String _pad(number) {
    return number > 9 ? '$number' : '0$number';
  }

  String _iso2time(iso) {
    var dt = DateTime.parse(iso);
    var now = DateTime.now();
    var str = '';

    if (dt.year != now.year) {
      str = '${dt.year}年';
    }
    if (dt.month != now.month || dt.day != now.day) {
      str = '$str${dt.month}月${dt.day}日';
    }
    if (str.isNotEmpty) {
      str = '$str ';
    }

    var h = _pad(dt.hour);
    var m = _pad(dt.minute);
    return '$str$h:$m';
  }

  Future _readPhotosPath() async {
    var dataDir = await getApplicationDocumentsDirectory();
    setState(() {
      _photosPath = '${dataDir.path}/photos';
    });
  }

  Future _checkFileExists(TableEntry entry) async {
    Map<String, int> tmp = {};
    if (entry.photos != null && entry.photos.isNotEmpty) {
      for (var i = 0; i < entry.photos.length; i++) {
        var item = entry.photos[i];
        var filepath = '$_photosPath/${item['filename']}';
        var b = await new File(filepath).exists();
        tmp[filepath] = b ? STATUS_FILE_EXISTS : STATUS_FILE_MISSED;
      }
    }

    if (tmp.isNotEmpty) {
      setState(() {
        _filesMap.addAll(tmp);
      });
    }
  }

  Future _loadEntry() async {
    final dbHelper = await openDB();

    var entry;
    if (widget.id != 'new') {
      entry = await dbHelper.loadEntry(widget.id);
    }

    if (entry == null) {
      final now = DateTime.now().toIso8601String();
      entry = new TableEntry(
        uuid.v4(),
        '',
        '',
        timeOfCreate: now,
        timeOfUpdate: now,
        photos: [],
        labels: [],
      );
      if (widget.label != null) {
        entry.labels.add(widget.label.id);
      }
      await dbHelper.saveEntry(entry);
    }

    if (_photosPath.isEmpty) {
      await _readPhotosPath();
    }

    await _loadLabels(entry.labels);

    setState(() {
      _entry = entry;
      _oldEntry = new TableEntry('', _entry.title, _entry.content);
    });

    _textChangedContent = _entry.content;
    _textChangedTitle = _entry.title;

    _contentController.text = _entry.content;
    _titleController.text = _entry.title;

    // 更新文本是否已经变更，从而决定是否显示保存按钮
    _contentController.addListener(() {
      if (_textChanged && _textChangedContent == _contentController.text) {
        setState(() {
          _textChanged = false;
        });
      } else if (!_textChanged &&
          _textChangedContent != _contentController.text) {
        setState(() {
          _textChanged = true;
        });
      }
    });
    _titleController.addListener(() {
      if (_textChanged && _textChangedTitle == _titleController.text) {
        setState(() {
          _textChanged = false;
        });
      } else if (!_textChanged && _textChangedTitle != _titleController.text) {
        setState(() {
          _textChanged = true;
        });
      }
    });

    _checkFileExists(entry);
  }

  // 记事的标签列表更新后重新加载标签数据
  Future _loadEntryLabels() async {
    // 延迟1s，等待之前的记事保存完成
    await new Future.delayed(const Duration(milliseconds: 1000));

    final dbHelper = await openDB();

    var entry = await dbHelper.loadEntry(_entry.id);

    await _loadLabels(entry.labels);

    setState(() {
      _entry.labels = entry.labels;
    });
  }

  Widget _img2widget(String filepath) {
    if (filepath == null || filepath.isEmpty) {
      return null;
    }

    if (_filesMap[filepath] == null ||
        _filesMap[filepath] == STATUS_FILE_UNKNOW) {
      return new Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.grey[100],
        child: Center(
          child: Icon(Icons.image, color: Colors.grey[700]),
        ),
      );
    }

    if (_filesMap[filepath] == STATUS_FILE_EXISTS) {
      return new Image.file(new File(filepath));
    }

    return new Container(
      padding: EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.broken_image, color: Colors.grey[700]),
      ),
    );
  }

  Future _saveEntry() async {
    if (_entry == null) {
      return;
    }
    if (_shouldTrashEmptyEntry &&
        _entry.title.isEmpty &&
        _entry.content.isEmpty &&
        _entry.photos.length == 0) {
      _entry.status = STATUS_TRASH;
    } else {
      // 标题和正文没有修改则不需要保存
      if (_oldEntry.title == _entry.title &&
          _oldEntry.content == _entry.content) {
        return;
      }
    }

    _entry.timeOfUpdate = DateTime.now().toIso8601String();

    final dbHelper = await openDB();
    await dbHelper.updateEntry(_entry);

    _textChangedContent = _entry.content;
    _textChangedTitle = _entry.title;
  }

  // 将状态的更新写入数据库
  Future _saveEntryStatus(newStatus) async {
    if (_entry == null) {
      return;
    }

    setState(() {
      _entry.status = newStatus;
    });

    final dbHelper = await openDB();
    await dbHelper.updateEntry(_entry);
  }

  Future _getImage({source = ImageSource.camera}) async {
    var image = await ImagePicker.pickImage(source: source);

    var stat = await image.stat();

    var id = uuid.v4();
    var filename = '$id.jpg';
    var now = DateTime.now().toIso8601String();

    if (_photosPath == null) {
      await _readPhotosPath();
    }

    await image.copy('$_photosPath/$filename');

    var photo = new TablePhoto(
      id,
      _entry.id,
      filename,
      timeOfCreate: now,
      timeOfUpdate: now,
      size: stat.size,
    );

    var dbHelper = await openDB();
    await dbHelper.savePhoto(photo);

    setState(() {
      _filesMap['$_photosPath/$filename'] = STATUS_FILE_EXISTS;
      _entry.photos.add(photo.toMap());
      _entry.timeOfUpdate = DateTime.now().toIso8601String();
    });

    await dbHelper.updateEntry(_entry);

    Navigator.of(context).pop();
  }

  Future _confirmRemovePhoto(photoItem) async {
    var flag = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('确认删除图片？'),
          actions: <Widget>[
            FlatButton(
              child: Text('删除'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            FlatButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      },
    );

    if (!flag) {
      return;
    }

    setState(() {
      _entry.photos.remove(photoItem);
    });

    var dbHelper = await openDB();
    _entry.timeOfUpdate = DateTime.now().toIso8601String();
    dbHelper.updateEntry(_entry);
    dbHelper.trashPhoto(photoItem['id']);
  }

  // 读取所有的标签数据
  Future _loadLabels(List selecteds) async {
    var dbHelper = await openDB();
    final labels = await dbHelper.loadLabels();
    Map<String, String> map = {};
    labels.forEach((item) {
      map[item.id] = item.name;
    });

    // 已删除的标签也要处理
    selecteds.forEach((id) {
      if (map[id] == null) {
        map[id] = 'X';
      }
    });

    setState(() {
      _labelsMap = map;
    });
  }

  Widget _buildForm() {
    return Container(
      padding: EdgeInsets.only(
        top: 16.0,
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
        // bottom: MediaQuery.of(context).size.height - 298,
      ),
      child: Column(
        children: <Widget>[
          ...List<Widget>.generate(_entry.photos.length, (index) {
            var item = _entry.photos[index];
            return Container(
              padding: EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () {
                  toPhotoDetail(
                    context: context,
                    entryID: _entry.id,
                    photoID: item['id'],
                  );
                },
                onLongPress: () {
                  _confirmRemovePhoto(item);
                },
                child: _img2widget("$_photosPath/${item['filename']}"),
              ),
            );
          }),
          Container(
            child: Theme(
              data: Theme.of(context).copyWith(splashColor: Colors.transparent),
              child: TextField(
                controller: _titleController,
                onChanged: (newVal) {
                  _entry.title = newVal;
                },
                keyboardAppearance: Brightness.light,
                // textInputAction: TextInputAction.next,
                maxLines: 1,
                minLines: 1,
                style: Theme.of(context).textTheme.title,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hasFloatingPlaceholder: false,
                  hintText: '标题',
                  contentPadding: EdgeInsets.only(top: 12),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Theme(
              data: Theme.of(context).copyWith(splashColor: Colors.transparent),
              child: TextField(
                controller: _contentController,
                onChanged: (newVal) {
                  _entry.content = newVal;
                },
                enableInteractiveSelection: true,
                keyboardAppearance: Brightness.light,
                keyboardType: TextInputType.multiline,
                maxLines: 10000,
                minLines: 1,
                style: TextStyle(
                  fontSize: 16.0,
                  letterSpacing: 0.6,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hasFloatingPlaceholder: false,
                  hintText: '记事',
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(bottom: 128.0),
            child: GestureDetector(
              onTap: () {
                _shouldTrashEmptyEntry = false;
                toLabels(context: context, entry: _entry).then((_) {
                  _loadEntryLabels();
                  _shouldTrashEmptyEntry = true;
                });
              },
              child: Row(
                children: List<Widget>.generate(
                  _entry.labels.length,
                  (index) {
                    var label = _entry.labels[index];
                    return LabelCard(_labelsMap[label]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: true,
      persistentFooterButtons: <Widget>[
        IconButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new ListTile(
                      leading: new Icon(Icons.camera),
                      title: new Text('拍照'),
                      onTap: () {
                        _getImage(source: ImageSource.camera);
                      },
                    ),
                    new ListTile(
                      leading: new Icon(Icons.image),
                      title: new Text('选择图片'),
                      onTap: () {
                        _getImage(source: ImageSource.gallery);
                      },
                    ),
                  ],
                );
              },
            );
          },
          icon: Icon(Icons.add),
        ),
        Container(
          width: MediaQuery.of(context).size.width -
              (MediaQuery.of(context).orientation == Orientation.landscape
                  ? 261
                  : 128),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _entry != null
                  ? Text(
                      '上次编辑时间：${_iso2time(_entry.timeOfUpdate)}',
                      style: Theme.of(context).textTheme.caption,
                    )
                  : Container(),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new ListTile(
                      leading: new Icon(Icons.label),
                      title: new Text('标签'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _shouldTrashEmptyEntry = false;
                        toLabels(context: context, entry: _entry).then((_) {
                          _loadEntryLabels();
                          _shouldTrashEmptyEntry = true;
                        });
                      },
                    ),
                    new ListTile(
                      leading: _entry.status == STATUS_ARCHIVE
                          ? Icon(Icons.unarchive)
                          : Icon(Icons.archive),
                      title: _entry.status == STATUS_ARCHIVE
                          ? Text('还原')
                          : Text('存档'),
                      onTap: () {
                        setState(() {
                          var newStatus = _entry.status == STATUS_ARCHIVE
                              ? STATUS_NORMAL
                              : STATUS_ARCHIVE;
                          _saveEntryStatus(newStatus);
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    new ListTile(
                      leading: _entry.status == STATUS_TRASH
                          ? Icon(Icons.restore_from_trash)
                          : Icon(Icons.delete),
                      title: _entry.status == STATUS_TRASH
                          ? Text('还原')
                          : Text('删除'),
                      onTap: () {
                        setState(() {
                          var newStatus = _entry.status == STATUS_TRASH
                              ? STATUS_NORMAL
                              : STATUS_TRASH;
                          _saveEntryStatus(newStatus);
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
          icon: Icon(Icons.more_vert),
        ),
      ],
      appBar: new AppBar(
        actions: <Widget>[
          _textChanged
              ? IconButton(
                  onPressed: () {
                    _saveEntry().then((_) {
                      setState(() {
                        _textChanged = false;
                      });
                      Navigator.of(context).pop();
                    });
                  },
                  icon: Icon(Icons.save),
                )
              : Container(),
          _entry != null
              ? IconButton(
                  onPressed: () async {
                    _entry.isLocked = !_entry.isLocked;
                    final dbHelper = await openDB();
                    await dbHelper.updateEntry(_entry);

                    setState(() {
                      _entry.isLocked = _entry.isLocked;
                    });
                  },
                  icon: _entry.isLocked
                      ? Icon(Icons.lock_outline)
                      : Icon(Icons.lock),
                )
              : Container(),
        ],
      ),
      body: _entry != null
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
              return new SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                child: new ConstrainedBox(
                  constraints: constraints.copyWith(
                      minHeight: constraints.maxHeight,
                      maxHeight: double.infinity),
                  child: _buildForm(),
                ),
              );
            })
          : Container(),
    );
  }
}

// 标签列表的项
class LabelCard extends StatelessWidget {
  final String name;

  LabelCard(this.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 6.0, bottom: 6.0, left: 8.0, right: 8.0),
      margin: EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      child: Text(name, style: Theme.of(context).textTheme.caption),
    );
  }
}
