///
/// 提供一些操作 Shared Preferences 的方法
///
/// created by keng42 @2019-08-14 15:31:17
///

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final uuid2 = Uuid();

// 获取当前设备ID，若不存在则新建一个
Future<String> loadDevice() async {
  SharedPreferences sp = await SharedPreferences.getInstance();
  var device = sp.getString('device');
  if (device == null || device.isEmpty) {
    device = uuid2.v4();
    await sp.setString('device', device);
  }

  return device;
}
