// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// File: lib/core/utils/csv_export_web.dart

import 'dart:convert';
import 'dart:html' as html;

void saveCsvFile(String csvContent, String fileName) {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
