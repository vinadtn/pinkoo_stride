import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/storage_keys.dart';
import '../storage/local_storage.dart';

/// State = Locale đang chọn. `null` nghĩa là theo ngôn ngữ của thiết bị.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(this._storage) : super(_readSaved(_storage));

  final LocalStorage _storage;

  static Locale? _readSaved(LocalStorage storage) {
    final code = storage.getString(StorageKeys.languageCode);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == state) return;
    emit(locale);
    if (locale == null) {
      await _storage.remove(StorageKeys.languageCode);
    } else {
      await _storage.setString(StorageKeys.languageCode, locale.languageCode);
    }
  }
}
