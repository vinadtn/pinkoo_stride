import 'package:flutter/foundation.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/map_style_choice.dart';

/// Giữ kiểu bản đồ đang chọn và lưu lại cho lần mở app sau.
///
/// Là `ValueNotifier` chứ không phải Cubit: đây là một lựa chọn đơn lẻ, không
/// có luồng trạng thái nào để quản — dùng Cubit chỉ thêm tầng cho vui.
class MapStyleStore extends ValueNotifier<MapStyleChoice> {
  MapStyleStore(this._storage)
    : super(MapStyleChoice.fromId(_storage.getString(StorageKeys.mapStyle)));

  final LocalStorage _storage;

  Future<void> select(MapStyleChoice choice) async {
    if (choice == value) return;
    value = choice;
    await _storage.setString(StorageKeys.mapStyle, choice.id);
  }
}
