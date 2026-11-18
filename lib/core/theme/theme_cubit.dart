import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/storage_keys.dart';
import '../storage/local_storage.dart';

/// Quản lý chế độ sáng / tối / theo hệ thống, lưu lại lựa chọn của người dùng.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._storage) : super(_readSaved(_storage));

  final LocalStorage _storage;

  static ThemeMode _readSaved(LocalStorage storage) {
    final saved = storage.getString(StorageKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _storage.setString(StorageKeys.themeMode, mode.name);
  }

  /// Đảo nhanh sáng ↔ tối dựa trên độ sáng đang hiển thị thực tế.
  Future<void> toggle(Brightness current) =>
      setThemeMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
