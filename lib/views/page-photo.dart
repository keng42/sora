import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:sora/db/index.dart';
import 'package:sora/db/tables.dart';

class PagePhoto extends StatefulWidget {
  final String entryID;
  final List<TablePhoto> initPhotos;
  final String photoID;

  PagePhoto({
    this.entryID = '',
    this.photoID = '',
    this.initPhotos,
  });

  @override
  _PagePhtotState createState() => _PagePhtotState();
}

class _PagePhtotState extends State<PagePhoto> {
  int _page = 0;
  int _pages = 1000;
  String _photosPath;
  PageController _pageController;
  List<PhotoViewGalleryPageOptions> _pageOptions = [];

  @override
  void initState() {
    super.initState();
    // 进入当前页面则进入全屏模式
    SystemChrome.setEnabledSystemUIOverlays([]);

    if (widget.entryID.isNotEmpty) {
      _loadEntryPhotos();
    } else {
      _loadAllPhotos();
    }
  }

  @override
  void deactivate() {
    // 退出当前页面则退出全屏模式
    SystemChrome.setEnabledSystemUIOverlays([
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    super.deactivate();
  }

  Future _loadEntryPhotos() async {
    var dataDir = await getApplicationDocumentsDirectory();
    setState(() {
      _photosPath = '${dataDir.path}/photos';
    });

    var dbHelper = await openDB();
    var entry = await dbHelper.loadEntry(widget.entryID);
    List<PhotoViewGalleryPageOptions> pageOptions = [];
    entry.photos.forEach((photo) {
      pageOptions.add(PhotoViewGalleryPageOptions(
        imageProvider: new FileImage(File('$_photosPath/${photo['filename']}')),
        heroTag: photo['id'],
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
      ));
    });

    var index = entry.photos.indexWhere((item) {
      return item['id'] == widget.photoID;
    });
    if (index == -1) {
      index = 0;
    }

    _pageController = new PageController(initialPage: index);

    setState(() {
      _pages = pageOptions.length;
      _pageOptions.addAll(pageOptions);
    });
  }

  int olderPage = 0;
  int newerPage = 0;
  bool olderLoadedAll = false;
  bool newerLoadedAll = false;
  bool olderLoading = false;
  bool newerLoading = false;
  TablePhoto olderLastItem;
  TablePhoto newerLastItem;

  Future _loadAllPhotos() async {
    var dataDir = await getApplicationDocumentsDirectory();
    setState(() {
      _photosPath = '${dataDir.path}/photos';
    });

    if (widget.initPhotos != null && widget.initPhotos.length > 0) {
      olderLastItem = widget.initPhotos[widget.initPhotos.length - 1];
      newerLastItem = widget.initPhotos[0];
    }

    List<TablePhoto> photos = widget.initPhotos;
    if (photos == null) {
      photos = [];
    }

    List<PhotoViewGalleryPageOptions> pageOptions = [];
    photos.forEach((photo) {
      pageOptions.add(PhotoViewGalleryPageOptions(
        imageProvider: new FileImage(File('$_photosPath/${photo.filename}')),
        heroTag: photo.id,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
      ));
    });

    var index = photos.indexWhere((item) {
      return item.id == widget.photoID;
    });
    if (index == -1) {
      index = 0;
    }

    _pageController = new PageController(initialPage: index);

    setState(() {
      _pageOptions.addAll(pageOptions);
    });
  }

  Future _loadMorePhotos({String type = 'older'}) async {
    var order = 'desc';
    var page = olderPage;
    TablePhoto lastItem = olderLastItem;
    if (type == 'older') {
      olderLoading = true;
    } else {
      newerLoading = true;
      order = 'asc';
      page = newerPage;
      lastItem = newerLastItem;
    }
    var lastItemTime = lastItem.timeOfCreate;
    var lastItemID = lastItem.id;

    var dbHelper = await openDB();
    var photos = await dbHelper.loadPhotos(
      order: order,
      page: page,
      perPage: 10,
      lastItemID: lastItemID,
      lastItemTime: lastItemTime,
    );

    List<PhotoViewGalleryPageOptions> pageOptions = [];
    photos.forEach((photo) {
      pageOptions.add(PhotoViewGalleryPageOptions(
        imageProvider: new FileImage(File('$_photosPath/${photo.filename}')),
        heroTag: photo.id,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
      ));
    });

    if (type == 'older') {
      olderLoading = false;
      olderPage++;
      if (pageOptions.length < 10) {
        olderLoadedAll = true;
      }
      setState(() {
        _pageOptions.addAll(pageOptions);
      });
    } else {
      await new Future.delayed(const Duration(milliseconds: 600));

      newerLoading = false;
      newerPage++;
      if (pageOptions.length < 10) {
        newerLoadedAll = true;
      }
      setState(() {
        _pageOptions.insertAll(0, pageOptions);
        _pageController.jumpToPage(pageOptions.length);
      });
    }
  }

  void _pageChanged(newPage) {
    _page = newPage;

    // 已全部加载完成
    if (_pageOptions.length >= _pages) {
      return;
    }

    // // 向右边滑动，加载旧的
    if (!olderLoading && !olderLoadedAll && _page == _pageOptions.length - 1) {
      _loadMorePhotos(type: 'older');
    }
    if (!newerLoading && !newerLoadedAll && _page == 0) {
      _loadMorePhotos(type: 'newer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pageOptions.length > 0
          ? PhotoViewGallery.builder(
              enableRotation: false,
              pageController: _pageController,
              itemCount: _pageOptions.length,
              builder: (context, index) {
                return _pageOptions[index];
              },
              onPageChanged: (page) {
                _pageChanged(page);
              },
            )
          : Center(
              child: new CircularProgressIndicator(),
            ),
    );
  }
}
