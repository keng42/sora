import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:sora/utils/c.dart';
import 'package:sora/router.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/db/index.dart';
import 'package:sora/utils/bus.dart';

class ViewEntries extends StatefulWidget {
  ViewEntries({
    this.changeFABVisible,
    this.changeAppBar,
    this.fabVisible,
    this.isFullCard,
  });

  final Function changeFABVisible;
  final Function changeAppBar;
  final bool fabVisible;
  final bool isFullCard;

  @override
  _ViewEntriesState createState() => _ViewEntriesState();
}

class _ViewEntriesState extends State<ViewEntries>
    with AutomaticKeepAliveClientMixin {
  ScrollController _scrollController = new ScrollController();

  int _status = STATUS_NORMAL;
  bool _loading = false;
  bool _loadedAll = false;
  String _keyword;
  String _photosPath;
  String _lastItemID;
  String _lastItemTime;
  TableLabel _label;
  List<TableEntry> _entries = [];
  Map<String, int> _filesMap = {};
  bool isLocked = true;
  Map<String, TableLabel> _labelsMap = {};

  @override
  void initState() {
    super.initState();

    _loadLabels();

    _createDirs().then((_) {
      // 首次拉取数据
      return _loadMore(true);
    }).then((_) {
      _scrollController.addListener(() {
        if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent) {
          _addMoreData();
        }
        if (_scrollController.position.userScrollDirection ==
            ScrollDirection.reverse) {
          if (widget.fabVisible == true) {
            widget.changeFABVisible(false);
          }
        } else {
          if (_scrollController.position.userScrollDirection ==
              ScrollDirection.forward) {
            if (widget.fabVisible == false) {
              widget.changeFABVisible(true);
            }
          }
        }
      });

      bus.on('ViewEntries:reloadEntry', _onReloadEntry);
      bus.on('ViewEntries:reloadEntries', _onReloadEntries);
      bus.on('ViewEntries:reloadLabels', _onReloadLabels);
      bus.on('ViewEntries:lockChanged', _lockChnaged);
    });
  }

  @override
  void deactivate() {
    super.deactivate();
    print('ViewEntries::deactivate');
    if (vIsLocked != isLocked) {
      setState(() {
        print('ViewEntries::deactivate changeLock $vIsLocked');
        isLocked = vIsLocked;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  void _lockChnaged(payload) {
    if (vIsLocked != isLocked) {
      setState(() {
        isLocked = vIsLocked;
      });
    }
  }

  void _onReloadLabels(payload) {
    _loadLabels();
  }

  void _onReloadEntries(payload) {
    var type = payload['type'];
    if (type == 'status') {
      setState(() {
        _label = null;
        _keyword = null;
        _status = payload['status'];
      });
    }
    if (type == 'label') {
      setState(() {
        _label = payload['label'];
      });
    }
    if (type == 'search') {
      setState(() {
        _keyword = payload['keyword'];
      });
    }

    _updateAppBar();
    _refreshData();
  }

  void _updateAppBar() {
    var title;
    var bgColor;
    if (_status == STATUS_NORMAL) {
      title = null;
      bgColor = null;
    } else if (_status == STATUS_ARCHIVE) {
      title = '存档';
      bgColor = Colors.blueGrey;
    } else if (_status == STATUS_TRASH) {
      title = '回收站';
      bgColor = Colors.brown;
    }

    if (_label != null) {
      title = '${title == null ? '记事' : title} - ${_label.name}';
    }

    widget.changeAppBar(title, bgColor);
  }

  void _onReloadEntry(payload) {
    var type = payload['type'];

    if (type == 'create') {
      _onNewEntry();
      return;
    }

    if (type == 'status') {
      TableEntry entry = payload['entry'];
      if (entry == null) {
        return;
      }
      if (entry.status != _status) {
        var index = _entries.indexWhere((item) {
          return item.id == entry.id;
        });
        if (index >= 0) {
          setState(() {
            _entries.removeAt(index);
          });
        }
      }
      return;
    }
  }

  bool _checkIfEntryLocked(TableEntry item) {
    if (!isLocked) {
      return false;
    }
    if (item.isLocked) {
      return true;
    }
    var id = item.labels.firstWhere((it) {
      return _labelsMap[it] != null && _labelsMap[it].isLocked;
    }, orElse: () {
      return null;
    });
    if (id != null) {
      return true;
    }
    return false;
  }

  // 读取所有的标签数据
  Future _loadLabels() async {
    var dbHelper = await openDB();
    final labels = await dbHelper.loadLabels();
    Map<String, TableLabel> map = {};
    labels.forEach((item) {
      map[item.id] = item;
    });

    setState(() {
      _labelsMap = map;
    });
  }

  Future _onNewEntry() async {
    // 延迟1s，等待之前的记事保存完成
    await new Future.delayed(const Duration(milliseconds: 1000));

    final dbHelper = await openDB();
    var newEntry = await dbHelper.loadLatestEntry();

    if (newEntry == null || newEntry.status != STATUS_NORMAL) {
      return;
    }

    if (newEntry.title.isEmpty &&
        newEntry.content.isEmpty &&
        newEntry.photos.length == 0) {
      newEntry.status = STATUS_TRASH;
      await dbHelper.updateEntry(newEntry);
      return;
    }

    await _checkFileExists([newEntry]);

    setState(() {
      _entries.insert(0, newEntry);
    });
  }

  // 下拉刷新数据
  Future _refreshData() async {
    _lastItemID = null;
    _lastItemTime = null;
    _loadedAll = false;
    await _loadMore(false);
  }

  // 上拉加载数据
  Future _addMoreData() async {
    await _loadMore(true);
  }

  // 从数据库读取更多
  Future _loadMore(bool _beAdd) async {
    if (_loading || _loadedAll) {
      return;
    }
    _loading = true;
    var dbHelper = await openDB();
    final entries = await dbHelper.loadEntries(
      orderKey: colTimeOfCreate,
      lastItemID: _lastItemID,
      lastItemTime: _lastItemTime,
      label: _label == null ? null : _label.id,
      keyword: _keyword,
      status: _status,
    );

    if (entries.length < 10) {
      _loadedAll = true;
    }
    if (entries.length > 0) {
      _lastItemTime = entries[entries.length - 1].timeOfCreate;
      _lastItemID = entries[entries.length - 1].id;
    }

    setState(() {
      if (!_beAdd) {
        _entries.clear();
        _entries = entries;
      } else {
        _entries.addAll(entries);
      }
    });

    _loading = false;

    _checkFileExists(entries);

    // 若当前列表没有满，则继续加载
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _addMoreData();
    }
  }

  Future _checkFileExists(List<TableEntry> entries) async {
    Map<String, int> tmp = {};
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i];
      if (entry.photos != null && entry.photos.isNotEmpty) {
        var filepath = '$_photosPath/${entry.photos[0]['filename']}';
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

  // 从详情页面回来后，重新加载一个记事
  Future _reloadEntry(TableEntry entry) async {
    await new Future.delayed(const Duration(milliseconds: 1000));

    var dbHelper = await openDB();
    var newEntry = await dbHelper.loadEntry(entry.id);

    if (newEntry.status != _status) {
      var index = _entries.indexWhere((item) {
        return item.id == newEntry.id;
      });
      if (index >= 0) {
        setState(() {
          _entries.removeAt(index);
        });
      }
    } else {
      await _checkFileExists([newEntry]);
      setState(() {
        entry.title = newEntry.title;
        entry.content = newEntry.content;
        entry.photos = newEntry.photos;
        entry.labels = newEntry.labels;
      });
    }
  }

  Future _createDirs() async {
    var dataDir = await getApplicationDocumentsDirectory();
    var photoDir = new Directory('${dataDir.path}/photos');
    if (!(await photoDir.exists())) {
      await photoDir.create();
    }
    var photoDir2 = new Directory('${dataDir.path}/photos-enc');
    if (!(await photoDir2.exists())) {
      await photoDir2.create();
    }
    _photosPath = photoDir.path;
  }

  // 复制一个记事
  Future _duplicateEntry(TableEntry oldEntry) async {
    final dbHelper = await openDB();

    var entry;
    entry = await dbHelper.loadEntry(oldEntry.id);
    entry.id = uuid.v4();
    final now = DateTime.now().toIso8601String();
    entry.timeOfCreate = now;
    entry.timeOfUpdate = now;

    // copy photos?
    entry.photos = [];

    await dbHelper.saveEntry(entry);

    setState(() {
      _entries.insert(0, entry);
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
      // 优化图片加载速度
      return new FadeInImage(
        placeholder: MemoryImage(kTransparentImage),
        image: new FileImage(new File(filepath)),
      );
      // return new Image.file(new File(filepath));
    }

    return new Container(
      padding: EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.broken_image, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildItemsView() {
    return StaggeredGridView.countBuilder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(8.0),
      controller: _scrollController,
      itemCount: _entries.length,
      primary: false,
      crossAxisCount: 4,
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 4.0,
      itemBuilder: (context, index) {
        var item = _entries[index];
        var img = item.photos.length > 0
            ? "$_photosPath/${item.photos[0]['filename']}"
            : '';
        return GestureDetector(
          onTap: () {
            if (_checkIfEntryLocked(item)) {
              return;
            }
            toEntryDetail(context: context, id: item.id).then((_) {
              _reloadEntry(item);
            });
          },
          onLongPress: () {
            if (_checkIfEntryLocked(item)) {
              return;
            }
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  contentPadding: EdgeInsets.all(0),
                  content: ListTile(
                    title: Text('复制记事'),
                    onTap: () {
                      _duplicateEntry(item).then((_) {});
                      Navigator.of(context).pop(false);
                    },
                  ),
                );
              },
            );
          },
          // opacity: _checkIfEntryLocked(item) ? 0 : 1,
          child: _checkIfEntryLocked(item)
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.all(
                      Radius.circular(8.0),
                    ),
                  ),
                  margin: EdgeInsets.all(4.0),
                  height: 48,
                  child: Icon(
                    Icons.lock,
                    color: Colors.grey[700],
                  ),
                )
              : TileCard(
                  labels: item.labels.map((id) {
                    if (_labelsMap[id] == null) {
                      return 'X';
                    }
                    return _labelsMap[id].name;
                  }).toList(),
                  isFullCard: widget.isFullCard,
                  id: item.id,
                  img: img,
                  imgWidget: _img2widget(img),
                  title: item.title,
                  content: item.content,
                ),
        );
      },
      staggeredTileBuilder: (index) =>
          StaggeredTile.fit(widget.isFullCard ? 4 : 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return new LayoutBuilder(builder: (
      BuildContext context,
      BoxConstraints constraints,
    ) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        child: _buildItemsView(),
      );
    });
  }
}

class TileCard extends StatelessWidget {
  final String id;
  final String img;
  final String title;
  final String content;
  final bool isFullCard;

  final Widget imgWidget;
  final List<String> labels;

  TileCard({
    this.isFullCard,
    this.id,
    this.img,
    this.title,
    this.content,
    this.imgWidget,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(width: 1.0, color: Colors.grey[100]),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          img.isEmpty && title.isEmpty && content.isEmpty
              ? Container(
                  padding: EdgeInsets.all(16.0),
                )
              : Container(),
          img.isNotEmpty
              ? ClipRRect(
                  child: imgWidget, // Image.file(new File(img)),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0),
                    bottomLeft: title.isEmpty && content.isEmpty
                        ? Radius.circular(8.0)
                        : Radius.zero,
                    bottomRight: title.isEmpty && content.isEmpty
                        ? Radius.circular(8.0)
                        : Radius.zero,
                  ),
                )
              : Container(),
          title.isNotEmpty
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  margin: EdgeInsets.only(
                    top: 8.0,
                    bottom: content.isEmpty ? 8.0 : 0,
                  ),
                  child: Text(
                    '$title',
                    style: TextStyle(
                      fontSize: Theme.of(context).textTheme.title.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: isFullCard ? 10 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Container(),
          content.isNotEmpty
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '$content',
                    style: TextStyle(
                      fontSize: Theme.of(context).textTheme.body1.fontSize,
                    ),
                    maxLines: isFullCard ? 100 : 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Container(),
          labels.isNotEmpty
              ? Container(
                  padding:
                      EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                  child: Row(
                    children: List<Widget>.generate(
                      labels.length,
                      (index) {
                        var label = labels[index];
                        return LabelCard(label);
                      },
                    ),
                  ),
                )
              : Container(),
        ],
      ),
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
      padding: EdgeInsets.only(top: 2.0, bottom: 2.0, left: 4.0, right: 4.0),
      margin: EdgeInsets.only(right: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      child: Text(name,
          style: TextStyle(
            color: Theme.of(context).textTheme.caption.color,
            fontSize: 10,
          )),
    );
  }
}
