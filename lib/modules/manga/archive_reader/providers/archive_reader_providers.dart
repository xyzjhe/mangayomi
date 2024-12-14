import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
part 'archive_reader_providers.g.dart';

@riverpod
Future<List<(String, LocalExtensionType, Uint8List, String)>>
    getArchivesDataFromDirectory(Ref ref, String path) async {
  return compute(_extractOnly, path);
}

@riverpod
Future<List<LocalArchive>> getArchiveDataFromDirectory(
    Ref ref, String path) async {
  return compute(_extract, path);
}

@riverpod
Future<(String, LocalExtensionType, Uint8List, String)> getArchivesDataFromFile(
    Ref ref, String path) async {
  return compute(_extractArchiveOnly, path);
}

@riverpod
Future<LocalArchive> getArchiveDataFromFile(Ref ref, String path) async {
  return compute(_extractArchive, path);
}

Future<List<LocalArchive>> _extract(String data) async {
  return await _searchForArchive(Directory(data));
}

Future<List<(String, LocalExtensionType, Uint8List, String)>> _extractOnly(
    String data) async {
  return await _searchForArchiveOnly(Directory(data));
}

List<LocalArchive> _list = [];
List<(String, LocalExtensionType, Uint8List, String)> _listOnly = [];
Future<List<LocalArchive>> _searchForArchive(Directory dir) async {
  List<FileSystemEntity> entities = dir.listSync();
  for (FileSystemEntity entity in entities) {
    if (entity is Directory) {
      _searchForArchive(entity);
    } else if (entity is File) {
      String path = entity.path;
      if (_isArchiveFile(path)) {
        final dd = await compute(_extractArchive, path);
        _list.add(dd);
      }
    }
  }
  return _list;
}

Future<List<(String, LocalExtensionType, Uint8List, String)>>
    _searchForArchiveOnly(Directory dir) async {
  List<FileSystemEntity> entities = dir.listSync();
  for (FileSystemEntity entity in entities) {
    if (entity is Directory) {
      _searchForArchive(entity);
    } else if (entity is File) {
      String path = entity.path;
      if (_isArchiveFile(path)) {
        final dd = await compute(_extractArchiveOnly, path);
        _listOnly.add(dd);
      }
    }
  }
  return _listOnly;
}

bool _isImageFile(String path) {
  List<String> imageExtensions = ['.png', '.jpg', '.jpeg'];
  String extension = path.toLowerCase();
  for (String imageExtension in imageExtensions) {
    if (extension.endsWith(imageExtension)) {
      return true;
    }
  }
  return false;
}

bool _isArchiveFile(String path) {
  List<String> archiveExtensions = ['.cbz', '.zip', 'cbt', 'tar'];
  String extension = path.toLowerCase();
  for (String archiveExtension in archiveExtensions) {
    if (extension.endsWith(archiveExtension)) {
      return true;
    }
  }
  return false;
}

LocalArchive _extractArchive(String path) {
  final localArchive = LocalArchive()
    ..path = path
    ..extensionType = setTypeExtension(p.extension(path).replaceFirst(".", ""))
    ..name = p.basenameWithoutExtension(path);
  Archive? archive;
  final inputStream = InputFileStream(path);
  final extensionType = localArchive.extensionType;
  if (extensionType == LocalExtensionType.cbt ||
      extensionType == LocalExtensionType.tar) {
    archive = TarDecoder().decodeStream(inputStream);
  } else {
    archive = ZipDecoder().decodeStream(inputStream);
  }

  for (final file in archive.files) {
    final filename = file.name;
    if (file.isFile) {
      if (_isImageFile(filename) && !filename.startsWith('.')) {
        final data = file.content;
        if (filename.contains("cover")) {
          localArchive.coverImage = data;
        } else {
          localArchive.images!.add(LocalImage()
            ..image = data
            ..name = p.basename(filename));
        }
      }
    }
  }
  localArchive.images!.sort((a, b) => a.name!.compareTo(b.name!));
  localArchive.coverImage ??= localArchive.images!.first.image;
  return localArchive;
}

(String, LocalExtensionType, Uint8List, String) _extractArchiveOnly(
    String path) {
  final extensionType =
      setTypeExtension(p.extension(path).replaceFirst('.', ''));
  final name = p.basenameWithoutExtension(path);
  Uint8List? coverImage;

  Archive? archive;
  final inputStream = InputFileStream(path);

  if (extensionType == LocalExtensionType.cbt ||
      extensionType == LocalExtensionType.tar) {
    archive = TarDecoder().decodeStream(inputStream);
  } else {
    archive = ZipDecoder().decodeStream(inputStream);
  }

  final cover = archive.files.where((file) =>
      file.isFile && _isImageFile(file.name) && file.name.contains("cover"));

  if (cover.isNotEmpty) {
    coverImage = cover.first.content;
  } else {
    List<ArchiveFile> lArchive = archive.files
        .where((file) =>
            file.isFile &&
            _isImageFile(file.name) &&
            !file.name.contains("cover"))
        .toList();
    lArchive.sort(
      (a, b) => a.name.compareTo(b.name),
    );
    coverImage = lArchive.first.content;
  }

  return (name, extensionType, coverImage, path);
}

String getTypeExtension(LocalExtensionType type) {
  return switch (type) {
    LocalExtensionType.cbt => type.name,
    LocalExtensionType.zip => type.name,
    LocalExtensionType.tar => type.name,
    _ => type.name,
  };
}

LocalExtensionType setTypeExtension(String extension) {
  return switch (extension) {
    "cbt" => LocalExtensionType.cbt,
    "zip" => LocalExtensionType.zip,
    "tar" => LocalExtensionType.tar,
    _ => LocalExtensionType.cbz,
  };
}
