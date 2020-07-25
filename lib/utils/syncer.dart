///
/// 用来和服务器进行数据同步的类
///
/// created by keng42 @2019-08-14 15:34:31
///

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/db/index.dart';
import 'package:sora/utils/cbox.dart';

class Syncer {
  String website;
  String username;
  String token;

  String photosPath;
  String encPhotosPath;

  Syncer({this.website, this.username, this.token});

  Future<String> push(String type, {bool full = false}) async {
    print('push $type start');

    // 获取同步需要的设备和账号信息
    var sp = await SharedPreferences.getInstance();
    var device = sp.getString('device');
    var token = sp.getString('token');
    var cboxKey = sp.getString('cboxKey');

    if (device == null || device.isEmpty) {
      print('invalid device');
      return 'invalid device';
    }
    if (token == null || token.isEmpty) {
      print('invalid token');
      return 'invalid token';
    }
    if (cboxKey == null || cboxKey.isEmpty) {
      print('invalid cboxKey');
      return 'invalid cboxKey';
    }

    // 加密和解密需要的实例
    var key = Cbox.genKey(seed: cboxKey);
    var cbox = new Cbox(key: key);

    // 获取同步进程
    var spKeyTime = 'pushLast${type}Time';
    var spKeyID = 'pushLast${type}ID';
    var pushLastItemTime = sp.getString(spKeyTime);
    var pushLastItemID = sp.getString(spKeyID);

    // 推送全部数据
    if (full) {
      pushLastItemTime = null;
      pushLastItemID = null;
    }

    // 打开数据库
    var dbHelper = await openDB();

    // 根据更新时间从旧到新分页获取数据
    // 并转换为 sitem 对象
    var items;
    var sitems;
    switch (type) {
      case 'Entry':
        items = await dbHelper.loadEntries(
          order: 'asc',
          perPage: 20,
          lastItemTime: pushLastItemTime,
          lastItemID: pushLastItemID,
        );
        sitems = items.map((item) {
          return TableSitem.fromEntry(item, cbox: cbox).toMap();
        }).toList();
        break;
      case 'Label':
        items = await dbHelper.loadLabels();
        sitems = items.map((item) {
          return TableSitem.fromLabel(item, cbox: cbox).toMap();
        }).toList();
        break;
      case 'Photo':
        items = await dbHelper.loadPhotos(
          order: 'asc',
          perPage: 20,
          lastItemTime: pushLastItemTime,
          lastItemID: pushLastItemID,
        );
        sitems = items.map((item) {
          return TableSitem.fromPhoto(item, cbox: cbox).toMap();
        }).toList();
        break;
      default:
        print('invalid type');
        return 'invalid type';
    }

    // 同步完成
    if (items.isEmpty) {
      print('no more');
      return 'no more';
    }

    print('push ${items.length} $type');

    // 装备发送给服务器
    var dio = Dio();

    // try {
    var resp = await dio.post(
      "$website/api/v1/sync/push",
      data: {
        "app": "sora-${type.toLowerCase()}",
        "device": device,
        "sitems": sitems,
      },
      options: Options(
        headers: {
          'x-hawkinstoken': token,
        },
      ),
    );

    if (resp.statusCode == 201) {
      // 同步成功，开始下一页的同步
      var newLastItem = items[items.length - 1];
      var newLastItemTime = newLastItem.timeOfCreate;
      if (type != 'Photo') {
        newLastItemTime = newLastItem.timeOfUpdate;
      }
      await sp.setString(spKeyTime, newLastItemTime);
      await sp.setString(spKeyID, newLastItem.id);

      if (type == 'Label') {
        print('no more');
        return 'no more';
      }

      return push(type);
    }

    // 其他 20x 的没有同步成功的错误
    return resp.data['message'];
    // } catch (e) {
    //   // 40x 50x 的错误
    //   return e.message;
    // }
  }

  Future<String> pull(String type, {bool full = false}) async {
    print('pull $type start');

    // 获取同步需要的设备和账号信息
    var sp = await SharedPreferences.getInstance();
    var device = sp.getString('device');
    var token = sp.getString('token');
    var cboxKey = sp.getString('cboxKey');

    if (device == null || device.isEmpty) {
      print('invalid device');
      return 'invalid device';
    }
    if (token == null || token.isEmpty) {
      print('invalid token');
      return 'invalid token';
    }
    if (cboxKey == null || cboxKey.isEmpty) {
      print('invalid cboxKey');
      return 'invalid cboxKey';
    }

    // 加密和解密需要的实例
    var key = Cbox.genKey(seed: cboxKey);
    var cbox = new Cbox(key: key);

    // 获取同步进程
    var spKeyTime = 'pullLast${type}Time';
    var spKeyPage = 'pullLast${type}Page';
    var pullLastItemTime = sp.getInt(spKeyTime);
    var pullLastItemPage = sp.getInt(spKeyPage);
    pullLastItemTime = pullLastItemTime != null ? pullLastItemTime : 0;
    pullLastItemPage = pullLastItemPage != null ? pullLastItemPage : 0;

    // 推送全部数据
    if (full) {
      pullLastItemTime = 0;
      pullLastItemPage = 0;
    }

    // 开始拉取数据
    var dio = new Dio();
    var resp;

    // try {
    resp = await dio.post(
      "$website/api/v1/sync/pull",
      data: {
        "app": "sora-${type.toLowerCase()}",
        "device": device,
        "syncKey": pullLastItemTime,
        "page": pullLastItemPage,
      },
      options: Options(
        headers: {
          'x-hawkinstoken': token,
        },
      ),
    );

    if (resp.statusCode != 201) {
      // 20x 错误
      return resp.data['message'];
    }
    // } catch (e) {
    //   return e.message;
    // }

    var sitems = resp.data['sitems'];
    var items;

    var dbHelper = await openDB();
    var updater;

    switch (type) {
      case 'Entry':
        updater = dbHelper.safeUpdateEntry;
        items = sitems.map((item) {
          return TableSitem.fromMap(item).toEntry(cbox: cbox);
        }).toList();
        break;
      case 'Label':
        updater = dbHelper.safeUpdateLabel;
        items = sitems.map((item) {
          return TableSitem.fromMap(item).toLabel(cbox: cbox);
        }).toList();
        break;
      case 'Photo':
        updater = dbHelper.safeUpdatePhoto;
        items = sitems.map((item) {
          return TableSitem.fromMap(item).toPhoto(cbox: cbox);
        }).toList();
        break;
      default:
        print('invalid type');
        return 'invalid type';
    }

    print('pull ${items.length} $type');

    // 写入数据库
    for (var i = 0; i < items.length; i++) {
      await updater(items[i]);
    }

    // 保存同步进程
    await sp.setInt(spKeyTime, resp.data['newSyncKey']);
    await sp.setInt(spKeyPage, resp.data['newPage']);

    if (resp.data['hasMore']) {
      // 下一页同步
      await pull(type);
    }

    print('no more');
    return 'no more';
  }

  Future<String> syncFiles({bool full = false}) async {
    print('syncFiles start');

    // 获取同步需要的设备和账号信息
    var sp = await SharedPreferences.getInstance();
    var device = sp.getString('device');
    var token = sp.getString('token');
    var cboxKey = sp.getString('cboxKey');

    if (device == null || device.isEmpty) {
      print('invalid device');
      return 'invalid device';
    }
    if (token == null || token.isEmpty) {
      print('invalid token');
      return 'invalid token';
    }
    if (cboxKey == null || cboxKey.isEmpty) {
      print('invalid cboxKey');
      return 'invalid cboxKey';
    }

    // 加密和解密需要的实例
    var key = Cbox.genKey(seed: cboxKey);
    var cbox = new Cbox(key: key);

    // 获取同步进程
    var spKeyTime = 'syncLastFileTime';
    var spKeyID = 'syncLastFileID';
    var pushLastItemTime = sp.getString(spKeyTime);
    var pushLastItemID = sp.getString(spKeyID);

    // 推送全部数据
    if (full) {
      pushLastItemTime = null;
      pushLastItemID = null;
    }

    // 打开数据库
    var dbHelper = await openDB();

    var items = await dbHelper.loadPhotos(
      order: 'asc',
      perPage: 20,
      lastItemTime: pushLastItemTime,
      lastItemID: pushLastItemID,
    );

    if (items.isEmpty) {
      return 'no more';
    }

    print('syncing ${items.length} files');

    if (photosPath == null) {
      var dataDir = await getApplicationDocumentsDirectory();
      photosPath = '${dataDir.path}/photos';
      encPhotosPath = '$photosPath-enc';
    }

    var filenames = items.map((item) {
      return item.filename;
    }).toList();
    var filesInfo = await checkServerFiles(filenames, token: token);
    print('filesInfo $filesInfo');
    List missedFiles = filesInfo['missFiles'];
    List serverFiles = filesInfo['existsFiles'];

    for (var i = 0; i < items.length; i++) {
      var item = items[i];

      // 检查本地是否有
      var file = new File('$photosPath/${item.filename}');
      var b = await file.exists();
      if (b) {
        if (missedFiles.contains(item.filename)) {
          await uploadFile(item.filename, cbox: cbox, token: token);
        }
      } else {
        // 从服务器中下载
        if (serverFiles.contains(item.filename)) {
          await downloadFile(item.filename, cbox: cbox, token: token);
        } else {
          print('file lost ${item.filename}');
        }
      }
    }

    var lastItem = items[items.length - 1];
    var newPushLastItemTime = lastItem.timeOfCreate;
    var newPushLastItemID = lastItem.id;
    await sp.setString(spKeyTime, newPushLastItemTime);
    await sp.setString(spKeyID, newPushLastItemID);

    return syncFiles();
  }

  Future<String> syncNow({bool full = false}) async {
    try {
      await push('Entry', full: full);
      await push('Label', full: full);
      await push('Photo', full: full);
      await pull('Entry', full: full);
      await pull('Label', full: full);
      await pull('Photo', full: full);
      await syncFiles(full: true);
    } catch (e) {
      print(e);
      return e.message;
    }

    return 'success';
  }

  Future downloadFile(String filename, {Cbox cbox, String token}) async {
    var dio = new Dio();

    print('downloading $filename');

    await dio.download(
      '$website/api/v1/file/get/$filename',
      '$encPhotosPath/$filename',
      options: Options(
        headers: {
          'x-hawkinstoken': token,
        },
      ),
    );

    print('decrypting $filename');

    await cbox.decryptFile(
      new File('$encPhotosPath/$filename'),
      new File('$photosPath/$filename'),
    );
  }

  Future uploadFile(String filename, {Cbox cbox, String token}) async {
    print('upload $filename start');
    var encFile = new File('$encPhotosPath/$filename');
    var b = await encFile.exists();
    if (!b) {
      print('encrypting $filename');
      await cbox.encryptFile(
        new File('$photosPath/$filename'),
        new File('$encPhotosPath/$filename'),
      );
    }

    print('uploading $filename');

    var dio = new Dio();
    FormData formData = new FormData.fromMap(
      {
        "photo": await MultipartFile.fromFile('$encPhotosPath/$filename',
            filename: filename),
      },
    );

    var resp = await dio.post(
      '$website/api/v1/file/upload',
      data: formData,
      options: Options(
        headers: {
          'x-hawkinstoken': token,
        },
      ),
    );

    print('uploaded: ${resp.data}');
  }

  Future checkServerFiles(List<String> filenames, {String token}) async {
    var dio = new Dio();

    var resp = await dio.post(
      '$website/api/v1/file/check',
      data: {'filenames': filenames},
      options: Options(
        headers: {
          'x-hawkinstoken': token,
        },
      ),
    );

    return resp.data;
  }
}
