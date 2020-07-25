///
/// 设置页面
///
/// created by keng42 @2019-08-14 15:37:42
///

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sora/db/index.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/utils/syncer.dart';
import 'package:sora/db/sp.dart';

class PageSettings extends StatefulWidget {
  @override
  _PageSettingsState createState() => _PageSettingsState();
}

class _PageSettingsState extends State<PageSettings> {
  int _all = 0;
  int _normal = 0;
  int _trash = 0;
  int _archive = 0;
  int _labels = 0;
  int _photos = 0;

  String _device = '';
  String _website = '';
  String _username = '';
  String _token = '';
  String _cboxKey = '';
  // 获取同步进程
  String _pushLastEntryTime = '';
  String _pushLastEntryID = '';
  String _pushLastLabelTime = '';
  String _pushLastLabelID = '';
  String _pushLastPhotoTime = '';
  String _pushLastPhotoID = '';
  String _pullLastEntryTime = '';
  String _pullLastEntryPage = '';
  String _pullLastLabelTime = '';
  String _pullLastLabelPage = '';
  String _pullLastPhotoTime = '';
  String _pullLastPhotoPage = '';
  String _syncLastFileTime = '';
  String _syncLastFileID = '';
  String _syncResult = '';

  TextEditingController _websiteTEC = new TextEditingController();
  TextEditingController _usernameTEC = new TextEditingController();
  TextEditingController _tokenTEC = new TextEditingController();
  TextEditingController _cboxKeyTEC = new TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadSyncInfo();
  }

  @override
  void deactivate() async {
    super.deactivate();
  }

  // 获取 SP 中的字段值，并处理类型错误返回默认值
  int spInt(sp, key) {
    var val;
    try {
      val = sp.getInt(key);
    } catch (e) {
      return 0;
    }
    return val != null ? val : 0;
  }

  String spString(sp, key) {
    var val;
    try {
      val = sp.getString(key);
    } catch (e) {
      return '';
    }
    return val != null ? val : '';
  }

  String toDateStr(isoStr) {
    try {
      return DateTime.parse(isoStr).toLocal().toString();
    } catch (e) {
      return isoStr;
    }
  }

  // 加载同步状态
  Future _loadSyncStatus() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    var pushLastEntryTime = spString(sp, 'pushLastEntryTime');
    var pushLastEntryID = spString(sp, 'pushLastEntryID');
    var pushLastLabelTime = spString(sp, 'pushLastLabelTime');
    var pushLastLabelID = spString(sp, 'pushLastLabelID');
    var pushLastPhotoTime = spString(sp, 'pushLastPhotoTime');
    var pushLastPhotoID = spString(sp, 'pushLastPhotoID');
    var pullLastEntryTime = spInt(sp, 'pullLastEntryTime');
    var pullLastEntryPage = spInt(sp, 'pullLastEntryPage');
    var pullLastLabelTime = spInt(sp, 'pullLastLabelTime');
    var pullLastLabelPage = spInt(sp, 'pullLastLabelPage');
    var pullLastPhotoTime = spInt(sp, 'pullLastPhotoTime');
    var pullLastPhotoPage = spInt(sp, 'pullLastPhotoPage');
    var syncLastFileTime = spString(sp, 'syncLastFileTime');
    var syncLastFileID = spString(sp, 'syncLastFileID');
    var syncResult = spString(sp, 'syncResult');

    var pullLastEntryTimeStr =
        DateTime.fromMillisecondsSinceEpoch(pullLastEntryTime)
            .toLocal()
            .toString();
    var pullLastLabelTimeStr =
        DateTime.fromMillisecondsSinceEpoch(pullLastLabelTime)
            .toLocal()
            .toString();
    var pullLastPhotoTimeStr =
        DateTime.fromMillisecondsSinceEpoch(pullLastPhotoTime)
            .toLocal()
            .toString();

    setState(() {
      _syncResult = syncResult;
      _pushLastEntryTime = toDateStr(pushLastEntryTime);
      _pushLastEntryID = pushLastEntryID;
      _pushLastLabelTime = toDateStr(pushLastLabelTime);
      _pushLastLabelID = pushLastLabelID;
      _pushLastPhotoTime = toDateStr(pushLastPhotoTime);
      _pushLastPhotoID = pushLastPhotoID;
      _pullLastEntryTime = pullLastEntryTimeStr;
      _pullLastEntryPage = '$pullLastEntryPage';
      _pullLastLabelTime = pullLastLabelTimeStr;
      _pullLastLabelPage = '$pullLastLabelPage';
      _pullLastPhotoTime = pullLastPhotoTimeStr;
      _pullLastPhotoPage = '$pullLastPhotoPage';
      _syncLastFileTime = syncLastFileTime;
      _syncLastFileID = syncLastFileID;
    });
  }

  Future _loadSyncInfo() async {
    var device = await loadDevice();

    SharedPreferences sp = await SharedPreferences.getInstance();

    var token = sp.getString('token');
    token = token != null ? token : '';

    var username = sp.getString('username');
    username = username != null ? username : '';

    var website = sp.getString('website');
    website = website != null && website.isNotEmpty
        ? website
        : 'http://lan.keng42.com:7001';

    var cboxKey = sp.getString('cboxKey');
    cboxKey = cboxKey != null ? cboxKey : '';

    setState(() {
      _device = device;
      _token = token;
      _username = username;
      _website = website;
      _cboxKey = cboxKey;
    });

    _websiteTEC.text = _website;
    _usernameTEC.text = _username;
    _tokenTEC.text = _token;
    _cboxKeyTEC.text = _cboxKey;

    _form['username'] = _username;
    _form['website'] = _website;
    _form['cboxKey'] = _cboxKey;

    await _loadSyncStatus();
  }

  Future _loadInfo() async {
    var dbHelper = await openDB();
    var result = await dbHelper.db.rawQuery('select count(id) from $tblEntry');
    var all = result[0]['count(id)'];
    result = await dbHelper.db.rawQuery(
        'select count(id) from $tblEntry where $colStatus = "$STATUS_NORMAL"');
    var normal = result[0]['count(id)'];
    result = await dbHelper.db.rawQuery(
        'select count(id) from $tblEntry where $colStatus = "$STATUS_TRASH"');
    var trash = result[0]['count(id)'];
    result = await dbHelper.db.rawQuery(
        'select count(id) from $tblEntry where $colStatus = "$STATUS_ARCHIVE"');
    var archive = result[0]['count(id)'];
    result = await dbHelper.db.rawQuery(
        'select count(id) from $tblLabel where $colStatus = "$STATUS_NORMAL"');
    var labels = result[0]['count(id)'];
    result = await dbHelper.db.rawQuery(
        'select count(id) from $tblPhoto where $colStatus = "$STATUS_NORMAL"');
    var photos = result[0]['count(id)'];
    setState(() {
      _all = all;
      _normal = normal;
      _trash = trash;
      _archive = archive;
      _labels = labels;
      _photos = photos;
    });
  }

  Future _exportAll() async {
    _loadInfo();
  }

  Future _importAll() async {}

  Future _toggleLogin() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    if (_token.isNotEmpty) {
      // 注销
      await sp.setString('token', '');
      setState(() {
        _token = '';
      });
      return;
    }

    var dio = new Dio();

    try {
      var resp = await dio.post(
        "${_form['website']}/api/v1/account/login",
        data: {"username": _form['username'], "password": _form['password']},
      );

      if (resp.statusCode == 201) {
        var token = resp.data['token'];
        var userID = resp.data['userID'];
        // 登录
        await sp.setString('token', token);
        await sp.setString('userID', userID);
        await sp.setString('username', _form['username']);
        await sp.setString('website', _form['website']);
        await sp.setString('cboxKey', _form['cboxKey']);
        setState(() {
          _token = token;
          _username = _form['username'];
          _website = _form['website'];
          _cboxKey = _form['cboxKey'];
        });
        return;
      }
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text('登录失败：${resp.data['message']}')),
      );
    } catch (e) {
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text('登录失败：${e.message}')),
      );
    }
  }

  Future _syncNow(BuildContext context) async {
    Syncer syncer = new Syncer(
      website: _website,
      username: _username,
      token: _token,
    );
    var result = await syncer.syncNow();

    if (result == 'success') {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('同步完成')));
      return;
    }

    if (result.contains('SocketException')) {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('同步失败：网络错误')));
      return;
    }

    if (result.contains('Http status error [401]')) {
      var sp = await SharedPreferences.getInstance();
      await sp.setString('token', '');
      setState(() {
        _token = '';
      });
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('登录状态失效')));
      return;
    }

    Scaffold.of(context).showSnackBar(SnackBar(content: Text('同步失败：$result')));

    await _loadSyncStatus();
  }

  Map<String, String> _form = {
    'token': '',
    'username': '',
    'website': '',
    'cboxKey': '',
  };
  Map<String, String> _formType2Hint = {
    'website': '网址',
    'username': '用户名',
    'password': '密码',
    'cboxKey': '数据加密密钥',
  };

  Widget _buildInput(String type) {
    TextEditingController controller;
    bool isSecure = false;

    switch (type) {
      case 'website':
        controller = _websiteTEC;
        break;
      case 'username':
        controller = _usernameTEC;
        break;
      case 'password':
        isSecure = true;
        break;
      case 'cboxKey':
        isSecure = true;
        controller = _cboxKeyTEC;
        break;
      default:
    }

    return Theme(
      data: Theme.of(context).copyWith(splashColor: Colors.transparent),
      child: TextField(
        controller: controller,
        onChanged: (newVal) {
          _form[type] = newVal;
        },
        keyboardAppearance: Brightness.light,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        maxLines: 1,
        minLines: 1,
        obscureText: isSecure,
        decoration: InputDecoration(
          labelText: _formType2Hint[type],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('统计', style: Theme.of(context).textTheme.title),
            Padding(padding: EdgeInsets.all(8.0)),
            Text('''
总数量：$_all 
记事：$_normal 
存档：$_archive 
回收站：$_trash

标签：$_labels
图片：$_photos'''),
            Padding(padding: EdgeInsets.all(8.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                RaisedButton(
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  child: Text('导出'),
                  onPressed: () {
                    _exportAll();
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                RaisedButton(
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  child: Text('导入'),
                  onPressed: () {
                    _importAll();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('同步', style: Theme.of(context).textTheme.title),
            Padding(padding: EdgeInsets.all(8.0)),
            Text('设备：$_device'),
            Text(_token.isNotEmpty
                ? '''
网址：$_website
账户：$_username

记事：
推送时间：$_pushLastEntryTime
推送指示：$_pushLastEntryID
拉取时间：$_pullLastEntryTime
拉取指示：$_pullLastEntryPage

标签：
推送时间：$_pushLastLabelTime
推送指示：$_pushLastLabelID
拉取时间：$_pullLastLabelTime
拉取指示：$_pullLastLabelPage

照片：
推送时间：$_pushLastPhotoTime
推送指示：$_pushLastPhotoID
拉取时间：$_pullLastPhotoTime
拉取指示：$_pullLastPhotoPage

文件：
同步时间：$_syncLastFileTime
同步指示：$_syncLastFileID

同步结果：$_syncResult'''
                : '若需要同步，请先登录'),
            Padding(padding: EdgeInsets.all(8.0)),
            _token.isEmpty
                ? Container(
                    child: Column(
                      children: <Widget>[
                        _buildInput('website'),
                        _buildInput('username'),
                        _buildInput('password'),
                        _buildInput('cboxKey'),
                      ],
                    ),
                  )
                : Container(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _token.isNotEmpty
                    ? RaisedButton(
                        color: Theme.of(context).primaryColor,
                        textColor: Colors.white,
                        child: Text('立即同步'),
                        onPressed: () {
                          _syncNow(context);
                        },
                      )
                    : Container(),
                Padding(padding: EdgeInsets.all(8)),
                RaisedButton(
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  child: _token.isEmpty ? Text('登录') : Text('注销'),
                  onPressed: () {
                    _toggleLogin();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: Text('设置'),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: ConstrainedBox(
              constraints: constraints.copyWith(
                minHeight: constraints.maxHeight,
                maxHeight: double.infinity,
              ),
              child: Column(
                children: <Widget>[
                  _buildInfoCard(),
                  _buildSyncCard(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
