import 'package:flutter/material.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/router.dart';
import 'package:sora/db/index.dart';
import 'package:sora/utils/bus.dart';
import 'package:sora/utils/c.dart';

class ViewDrawer extends StatefulWidget {
  ViewDrawer({this.selectedItem, this.changeSelected});

  final String selectedItem;
  final Function changeSelected;

  @override
  _ViewDrawerState createState() => _ViewDrawerState();
}

class _ViewDrawerState extends State<ViewDrawer> {
  List<TableLabel> _labels = [];

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future _loadLabels() async {
    var dbHelper = await openDB();
    final labels = await dbHelper.loadLabels();
    setState(() {
      _labels.clear();
      _labels.addAll(labels);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Container(
          height: 64,
          child: DrawerHeader(
            // child:
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('Sora', style: TextStyle(fontSize: 32)),
                ),
              ],
            ),
            margin: EdgeInsets.all(0.0),
            padding: EdgeInsets.all(0.0),
          ),
        ),
        ListTile(
          leading: Icon(Icons.note),
          selected: widget.selectedItem == '记事',
          title: Text('记事'),
          onTap: () {
            Navigator.pop(context);
            widget.changeSelected('记事');
            bus.emit(
              'ViewEntries:reloadEntries',
              {'type': 'status', 'status': STATUS_NORMAL},
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.archive),
          selected: widget.selectedItem == '存档',
          title: Text('存档'),
          onTap: () {
            Navigator.pop(context);
            widget.changeSelected('存档');
            bus.emit(
              'ViewEntries:reloadEntries',
              {'type': 'status', 'status': STATUS_ARCHIVE},
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.photo_library),
          selected: widget.selectedItem == '图片库',
          title: Text('图片库'),
          onTap: () {
            Navigator.pop(context);
            // widget.changeSelected('图片库');
            if (vIsLocked) {
              return;
            }
            toPhotos(context: context);
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
        ...List<Widget>.generate(_labels.length, (index) {
          var label = _labels[index];
          return ListTile(
            leading: Icon(Icons.label),
            selected: widget.selectedItem == label.name,
            title: Text(label.name),
            onTap: () {
              Navigator.pop(context);
              widget.changeSelected(label.name);
              bus.emit(
                'ViewEntries:reloadEntries',
                {'type': 'label', 'label': label},
              );
            },
            onLongPress: () {
              Navigator.pop(context);
              toEntryDetail(context: context, id: 'new', label: label)
                  .then((_) {
                bus.emit(
                  'ViewEntries:reloadEntry',
                  {'type': 'create', 'entry': null},
                );
              });
            },
          );
        }),
        ListTile(
          leading: Icon(Icons.label_important),
          selected: widget.selectedItem == '标签管理',
          title: Text('标签管理'),
          onTap: () {
            Navigator.pop(context);
            // widget.changeSelected('标签管理');
            if (vIsLocked) {
              return;
            }
            toLabels(context: context);
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
        ListTile(
          leading: Icon(Icons.delete),
          selected: widget.selectedItem == '回收站',
          title: Text('回收站'),
          onTap: () {
            Navigator.pop(context);
            widget.changeSelected('回收站');
            bus.emit(
              'ViewEntries:reloadEntries',
              {'type': 'status', 'status': STATUS_TRASH},
            );
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
        ListTile(
          leading: Icon(Icons.settings),
          selected: widget.selectedItem == '设置',
          title: Text('设置'),
          onTap: () {
            Navigator.pop(context);
            toSettings(context: context);
          },
        ),
        ListTile(
          leading: Icon(Icons.feedback),
          selected: widget.selectedItem == '反馈',
          title: Text('反馈'),
          onTap: () {
            Navigator.pop(context);
            // widget.changeSelected('反馈');
          },
        ),
      ],
    );
  }
}
