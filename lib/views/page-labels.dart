import 'package:flutter/material.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/db/index.dart';
import 'package:sora/utils/bus.dart';

class PageLabels extends StatefulWidget {
  final TableEntry entry;

  PageLabels({this.entry});

  @override
  _PageLabelsState createState() => _PageLabelsState();
}

class _PageLabelsState extends State<PageLabels> {
  List<TableLabel> _labels = [];
  String _searchKey = '';
  List<String> _selecteds = [];

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void deactivate() async {
    await _updateEntryLabels();
    bus.emit('ViewEntries:reloadLabels', {});
    super.deactivate();
  }

  Future _loadLabels() async {
    var dbHelper = await openDB();
    final labels = await dbHelper.loadLabels();
    List<String> selecteds = [];
    if (widget.entry != null) {
      widget.entry.labels.forEach((item) {
        selecteds.add(item);
      });
    } else {
      labels.forEach((item) {
        if (item.isLocked) {
          selecteds.add(item.id);
        }
      });
    }
    setState(() {
      _selecteds = selecteds;
      _labels.clear();
      _labels.addAll(labels);
    });
  }

  Future _trashLabel(label) async {
    label.status = STATUS_TRASH;
    await _updateLabel(label);
  }

  Future _updateLabel(label) async {
    var dbHelper = await openDB();
    await dbHelper.updateLabel(label);
  }

  Future _updateEntryLabels() async {
    if (widget.entry == null) {
      return;
    }

    // 排除掉已经删除的标签
    var map = {};
    var tmp = [];
    _labels.forEach((item) {
      map[item.id] = true;
    });
    _selecteds.forEach((id) {
      if (map[id]) {
        tmp.add(id);
      }
    });

    widget.entry.labels = tmp;
    var dbHelper = await openDB();
    await dbHelper.updateEntry(widget.entry);
  }

  Future _createLabel() async {
    var name = _searchKey.trim();
    if (name.isEmpty) {
      return;
    }
    var dbHelper = await openDB();
    final now = DateTime.now().toIso8601String();

    var label = new TableLabel(
      uuid.v4(),
      name,
      timeOfCreate: now,
      timeOfUpdate: now,
    );
    await dbHelper.saveLabel(label);

    setState(() {
      _searchKey = '';
      _labels.add(label);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: Theme(
          data: Theme.of(context).copyWith(splashColor: Colors.transparent),
          child: TextField(
            onChanged: (newVal) {
              setState(() {
                _searchKey = newVal;
              });
            },
            style: TextStyle(color: Colors.white),
            keyboardAppearance: Brightness.light,
            cursorColor: Colors.white,
            decoration: InputDecoration(
              border: InputBorder.none,
              hasFloatingPlaceholder: false,
              hintStyle: TextStyle(color: Colors.white60),
              hintText: '输入标签名称',
            ),
          ),
        ),
      ),
      body: Container(
        child: ListView.builder(
          itemCount: _labels.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (_searchKey.isEmpty) {
                return Container();
              }
              return ListTile(
                title: Text('创建新标签 "$_searchKey"'),
                leading: Icon(
                  Icons.add,
                  color: Theme.of(context).primaryColor,
                ),
                onTap: () {
                  _createLabel();
                },
              );
            }
            final item = _labels[index - 1];
            if (item.status == STATUS_TRASH ||
                item.name.indexOf(_searchKey) == -1) {
              return Container();
            }
            return Dismissible(
              key: new Key(item.id),
              background: Container(
                color: Colors.green,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                ),
              ),
              secondaryBackground: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart) {
                  _trashLabel(item);
                  setState(() {
                    _labels.removeAt(index - 1);
                  });
                }
              },
              confirmDismiss: (direction) async {
                var _alertDialog;

                if (direction == DismissDirection.endToStart) {
                  // 从右向左 也就是删除
                  _alertDialog = AlertDialog(
                    title: Text('确认删除 ${item.name} ？'),
                    actions: <Widget>[
                      FlatButton(
                        child: Text(
                          '删除',
                          style: TextStyle(color: Colors.red),
                        ),
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
                } else if (direction == DismissDirection.startToEnd) {
                  // 编辑
                  _alertDialog = AlertDialog(
                    title: Text('重命名标签'),
                    content: Container(
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(splashColor: Colors.transparent),
                        child: TextField(
                          controller:
                              new TextEditingController(text: item.name),
                          keyboardAppearance: Brightness.light,
                          maxLines: 1,
                          minLines: 1,
                          autofocus: true,
                          style: Theme.of(context).textTheme.body1,
                          onSubmitted: (newVal) {
                            setState(() {
                              item.name = newVal;
                            });
                            _updateLabel(item);
                            Navigator.of(context).pop(false);
                          },
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hasFloatingPlaceholder: false,
                            hintText: '标签',
                            contentPadding: EdgeInsets.only(top: 12),
                          ),
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        child: Text('取消'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                      ),
                    ],
                  );
                }

                var isDismiss = await showDialog(
                    context: context,
                    builder: (context) {
                      return _alertDialog;
                    });
                return isDismiss;
              },
              child: ListTile(
                title: Text(item.name),
                onTap: () {
                  if (widget.entry != null) {
                    setState(() {
                      if (_selecteds.contains(item.id)) {
                        _selecteds.remove(item.id);
                      } else {
                        _selecteds.add(item.id);
                      }
                    });
                  } else {
                    setState(() {
                      item.isLocked = !item.isLocked;
                    });
                    _updateLabel(item);
                  }
                },
                leading: Icon(Icons.label),
                trailing: widget.entry != null
                    ? Checkbox(
                        value: _selecteds.contains(item.id),
                        onChanged: (newValue) {
                          setState(() {
                            if (newValue) {
                              _selecteds.add(item.id);
                            } else {
                              _selecteds.remove(item.id);
                            }
                          });
                        },
                      )
                    : Container(
                        child: item.isLocked
                            ? Icon(
                                Icons.lock,
                                color: Theme.of(context).primaryColor,
                              )
                            : Icon(Icons.lock_outline),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
