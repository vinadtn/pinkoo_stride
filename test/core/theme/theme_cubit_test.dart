import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:pinkoo_stride/core/constants/storage_keys.dart';
import 'package:pinkoo_stride/core/storage/local_storage.dart';
import 'package:pinkoo_stride/core/theme/theme_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalStorage extends Mock implements LocalStorage {}

void main() {
  late _MockLocalStorage storage;

  setUp(() {
    storage = _MockLocalStorage();
    when(() => storage.setString(any(), any())).thenAnswer((_) async => true);
  });

  test('mặc định là ThemeMode.system khi chưa lưu gì', () {
    when(() => storage.getString(StorageKeys.themeMode)).thenReturn(null);
    expect(ThemeCubit(storage).state, ThemeMode.system);
  });

  test('đọc lại lựa chọn đã lưu', () {
    when(() => storage.getString(StorageKeys.themeMode)).thenReturn('dark');
    expect(ThemeCubit(storage).state, ThemeMode.dark);
  });

  blocTest<ThemeCubit, ThemeMode>(
    'setThemeMode phát state mới và lưu xuống storage',
    setUp: () => when(() => storage.getString(StorageKeys.themeMode)).thenReturn(null),
    build: () => ThemeCubit(storage),
    act: (cubit) => cubit.setThemeMode(ThemeMode.light),
    expect: () => [ThemeMode.light],
    verify: (_) => verify(() => storage.setString(StorageKeys.themeMode, 'light')).called(1),
  );
}
