import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Chụp một widget đang hiển thị thành PNG.
///
/// Không cần package nào: `RepaintBoundary` + `toImage` có sẵn trong Flutter.
/// [pixelRatio] là tỉ lệ nhân so với kích thước thiết kế — thẻ 540×960 với
/// pixelRatio 2 ra đúng **1080×1920**, khổ Instagram Story yêu cầu.
Future<Uint8List> captureWidgetPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError(
      'Không tìm thấy RepaintBoundary để chụp — widget chưa được gắn vào cây?',
    );
  }

  // Lần build đầu tiên có thể chưa vẽ xong; chụp lúc đó ra ảnh trống.
  if (boundary.debugNeedsPaint) {
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Không encode được ảnh PNG');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
