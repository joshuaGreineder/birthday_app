import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class PickedBackupFile {
  final String name;
  final String contents;

  const PickedBackupFile(this.name, this.contents);
}

/// System share sheet for export, system file picker for import.
/// Reads bytes from the picker so the app does not request storage permission.
class BackupTransfer {
  const BackupTransfer();

  Future<void> share({
    required String filename,
    required String contents,
    required String mimeType,
  }) async {
    final dir = await Directory.systemTemp.createTemp('happaroo_export');
    final separator = Platform.pathSeparator;
    final file = File('${dir.path}$separator$filename');
    await file.writeAsString(contents, encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: filename)],
      subject: filename,
    );
  }

  Future<PickedBackupFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The selected file was empty.');
    }
    try {
      return PickedBackupFile(picked.name, utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('That file is not valid UTF-8 text.');
    }
  }
}
