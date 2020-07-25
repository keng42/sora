import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sora/utils/c.dart';
import 'package:sora/views/view-entries.dart';
import 'package:sora/views/view-drawer.dart';
import 'package:sora/router.dart';
import 'package:sora/utils/bus.dart';

import 'db/tables.dart';

// 应用入口
void main() => runApp(MyApp());

// 主应用
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sora', // 最近任务标题
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'Sora'),
    );
  }
}

// 主页：列表、抽屉
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isVisible = true;
  bool _isFullCard = false;
  bool _isSearching = false;
  bool _isLocked = true;
  String _title;
  Color _bgColor;
  String _drawerSelectedItem = '记事';
  TableLabel _label;

  @override
  void initState() {
    super.initState();

    bus.on('ViewEntries:reloadEntries', _onReloadEntries);
  }

  void _onReloadEntries(payload) {
    var type = payload['type'];
    if (type == 'label') {
      _label = payload['label'];
    } else {
      _label = null;
    }
  }

  void _changeFABVisible(visible) {
    setState(() {
      _isVisible = visible;
    });
  }

  void _changeAppBar(String newTitle, Color newBgColor) {
    setState(() {
      _title = newTitle == null || newTitle.isEmpty ? widget.title : newTitle;
      _bgColor =
          newBgColor == null ? Theme.of(context).primaryColor : newBgColor;
    });
  }

  void _changeSelected(String selectedItem) {
    _drawerSelectedItem = selectedItem;
  }

  Widget _buildAppBarTitle() {
    if (_isSearching) {
      return Theme(
        data: Theme.of(context).copyWith(splashColor: Colors.transparent),
        child: TextField(
          onSubmitted: (newVal) {
            if (newVal == 'enisis') {
              vIsLocked = !vIsLocked;
              setState(() {
                _isSearching = false;
              });

              bus.emit('ViewEntries:lockChanged', {});
              setState(() {
                _isLocked = vIsLocked;
              });
              return;
            }
            bus.emit(
              'ViewEntries:reloadEntries',
              {'type': 'search', 'keyword': newVal},
            );
          },
          keyboardAppearance: Brightness.light,
          textInputAction: TextInputAction.search,
          autofocus: true,
          autocorrect: false,
          maxLines: 1,
          minLines: 1,
          style: TextStyle(color: Colors.white),
          textAlignVertical: TextAlignVertical.center,
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            hasFloatingPlaceholder: false,
            hintText: '搜索...',
          ),
        ),
      );
    }
    return Text(_title == null || _title.isEmpty ? widget.title : _title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        centerTitle: true,
        backgroundColor: _bgColor,
        actions: <Widget>[
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
              });
            },
            icon: _isSearching ? Icon(Icons.close) : Icon(Icons.search),
          ),
          _isLocked
              ? Container()
              : IconButton(
                  onPressed: () {
                    vIsLocked = true;
                    setState(() {
                      _isLocked = vIsLocked;
                    });
                    bus.emit('ViewEntries:lockChanged', {});
                  },
                  icon: Icon(Icons.lock),
                ),
          IconButton(
            onPressed: () {
              setState(() {
                _isFullCard = !_isFullCard;
              });
            },
            icon: _isFullCard ? Icon(Icons.grid_on) : Icon(Icons.view_list),
          ),
        ],
      ),
      drawer: Drawer(
        child: ViewDrawer(
          selectedItem: _drawerSelectedItem,
          changeSelected: _changeSelected,
        ),
      ),
      floatingActionButton: new AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: Duration(milliseconds: 500),
        child: new FloatingActionButton(
          onPressed: () {
            toEntryDetail(context: context, id: 'new', label: _label).then((_) {
              bus.emit(
                'ViewEntries:reloadEntry',
                {'type': 'create', 'entry': null},
              );
            });
          },
          child: new Icon(Icons.add),
        ),
      ),
      body: ViewEntries(
        changeFABVisible: _changeFABVisible,
        changeAppBar: _changeAppBar,
        fabVisible: _isVisible,
        isFullCard: _isFullCard,
      ),
    );
  }
}

// 编辑详情页
// 标签管理和选择页
// 图片详情页：缩放，旋转，黑色背景
// 所有图片列表页
