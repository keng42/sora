import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sora/db/index.dart';
import 'package:sora/db/tables.dart';
import 'package:sora/utils/c.dart';
import 'package:sora/router.dart';

class PagePhotos extends StatefulWidget {
  @override
  _PagePhotosState createState() => _PagePhotosState();
}

class _PagePhotosState extends State<PagePhotos>
    with AutomaticKeepAliveClientMixin {
  ScrollController _scrollController = new ScrollController();

  int _page = 0;
  int _size = 10;
  String _photosPath;
  List<TablePhoto> _photos = [];
  Map<String, int> _filesMap = {};

  @override
  void initState() {
    super.initState();

    _readPhotosPath().then((_) {
      // 首次拉取数据
      return _loadPhotos(true);
    }).then((_) {
      _scrollController.addListener(() {
        if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent) {
          _addMoreData();
        }
      });
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future _readPhotosPath() async {
    var dataDir = await getApplicationDocumentsDirectory();
    setState(() {
      _photosPath = '${dataDir.path}/photos';
    });
  }

  // 上拉加载数据
  Future _addMoreData() async {
    _page++;
    return _loadPhotos(true);
  }

  // 分页加载图片
  Future _loadPhotos(bool _beAdd) async {
    var dbHelper = await openDB();
    var photos = await dbHelper.loadPhotos(page: _page, perPage: _size);

    setState(() {
      if (!_beAdd) {
        _photos.clear();
        _photos = photos;
      } else {
        _photos.addAll(photos);
      }
    });

    _checkFileExists(photos);
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
      return new Image.file(
        new File(filepath),
        fit: BoxFit.cover,
      );
    }

    return new Container(
      padding: EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.broken_image, color: Colors.grey[700]),
      ),
    );
  }

  Future _checkFileExists(List<TablePhoto> photos) async {
    Map<String, int> tmp = {};
    for (var i = 0; i < photos.length; i++) {
      var item = photos[i];
      var filepath = '$_photosPath/${item.filename}';
      var b = await new File(filepath).exists();
      tmp[filepath] = b ? STATUS_FILE_EXISTS : STATUS_FILE_MISSED;
    }

    if (tmp.isNotEmpty) {
      setState(() {
        _filesMap.addAll(tmp);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: new AppBar(
        title: new Text('图片库'),
      ),
      body: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
        children: List.generate(
          _photos.length,
          (index) {
            var item = _photos[index];
            List<TablePhoto> initPhotos = [];
            if (index > 0) {
              initPhotos.add(_photos[index - 1]);
            }
            initPhotos.add(item);
            if (index < _photos.length - 1) {
              initPhotos.add(_photos[index + 1]);
            }
            return GestureDetector(
              onTap: () {
                toPhotoDetail(
                  context: context,
                  photoID: item.id,
                  initPhotos: initPhotos,
                );
              },
              child: _img2widget('$_photosPath/${item.filename}'),

              // Image.file(
              //   new File('$_photosPath/${item.filename}'),
              //   fit: BoxFit.cover,
              // ),
            );
          },
        ),
      ),
    );
  }
}
