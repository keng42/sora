import 'package:flutter/material.dart';
import 'package:sora/db/tables.dart';

import 'package:sora/views/page-entry.dart';
import 'package:sora/views/page-photo.dart';
import 'package:sora/views/page-photos.dart';
import 'package:sora/views/page-labels.dart';
import 'package:sora/views/page-settings.dart';

Future toEntryDetail(
    {BuildContext context, String id, TableLabel label}) async {
  return Navigator.of(context).push(
    new MaterialPageRoute(
      builder: (context) {
        return PageEntry(id: id, label: label);
      },
    ),
  );
}

void toPhotoDetail({
  BuildContext context,
  String entryID = '',
  String photoID = '',
  List initPhotos,
}) {
  Navigator.of(context).push(
    new MaterialPageRoute(
      builder: (context) {
        return new PagePhoto(
          entryID: entryID,
          photoID: photoID,
          initPhotos: initPhotos,
        );
      },
    ),
  );
}

void toPhotos({BuildContext context}) {
  Navigator.of(context).push(
    new MaterialPageRoute(
      builder: (context) {
        return PagePhotos();
      },
    ),
  );
}

Future toLabels({BuildContext context, TableEntry entry}) async {
  return Navigator.of(context).push(
    new MaterialPageRoute(
      builder: (context) {
        return new PageLabels(entry: entry);
      },
    ),
  );
}

Future toSettings({BuildContext context}) async {
  return Navigator.of(context).push(
    new MaterialPageRoute(
      builder: (context) {
        return new PageSettings();
      },
    ),
  );
}
