import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinkoo_stride/core/storage/local_storage.dart';
import 'package:pinkoo_stride/core/theme/app_theme.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/map/data/map_style_store.dart';
import 'package:pinkoo_stride/features/recording/presentation/cubit/recording_cubit.dart';
import 'package:pinkoo_stride/features/recording/presentation/cubit/recording_state.dart';
import 'package:pinkoo_stride/features/recording/presentation/pages/recording_page.dart';
import 'package:pinkoo_stride/features/recording/presentation/widgets/swim_lock_overlay.dart';
import 'package:pinkoo_stride/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecordingCubit extends MockCubit<RecordingState> implements RecordingCubit {}

/// Khoá màn hình chỉ dành cho Bơi — ba chế độ còn lại cầm máy trên tay.
void main() {
  late _MockRecordingCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cubit = _MockRecordingCubit();

    // RecordingPage lấy MapStyleStore qua service locator.
    await GetIt.I.reset();
    GetIt.I.registerSingleton<MapStyleStore>(
      MapStyleStore(LocalStorage(await SharedPreferences.getInstance())),
    );
  });

  tearDown(() => GetIt.I.reset());

  Future<void> pumpPage(WidgetTester tester, ActivityMode mode) async {
    final state = RecordingState(mode: mode, status: RecordingStatus.recording);
    whenListen(cubit, const Stream<RecordingState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<RecordingCubit>.value(
          value: cubit,
          child: const RecordingPage(),
        ),
      ),
    );
    await tester.pump();
  }

  final lockButton = find.byIcon(Icons.lock_outline_rounded);

  testWidgets('chế độ Bơi có nút khoá', (tester) async {
    await pumpPage(tester, ActivityMode.swim);

    expect(lockButton, findsOneWidget);
  });

  testWidgets('ba chế độ còn lại KHÔNG có nút khoá', (tester) async {
    for (final mode in [ActivityMode.run, ActivityMode.walk, ActivityMode.ride]) {
      await pumpPage(tester, mode);
      expect(lockButton, findsNothing, reason: 'chế độ ${mode.id} không được có nút khoá');
    }
  });

  testWidgets('bấm khoá thì hiện lớp phủ', (tester) async {
    await pumpPage(tester, ActivityMode.swim);
    expect(find.byType(SwimLockOverlay), findsNothing);

    await tester.tap(lockButton);
    await tester.pump();

    expect(find.byType(SwimLockOverlay), findsOneWidget);
  });

  testWidgets('đang khoá thì chạm vào nút Dừng không ăn', (tester) async {
    await pumpPage(tester, ActivityMode.swim);
    await tester.tap(lockButton);
    await tester.pump();

    // Chạm vào đúng chỗ nút Dừng nằm — lớp phủ phải nuốt cú chạm này.
    await tester.tap(find.byIcon(Icons.stop_rounded), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));

    verifyNever(() => cubit.finish());
    expect(find.byType(SwimLockOverlay), findsOneWidget, reason: 'vẫn phải đang khoá');
  });

  testWidgets('lớp phủ vẫn hiện số liệu để liếc nhìn', (tester) async {
    await pumpPage(tester, ActivityMode.swim);
    await tester.tap(lockButton);
    await tester.pump();

    expect(find.text('Màn hình đang khoá'), findsOneWidget);
    expect(find.text('Giữ 2 giây để mở khoá'), findsWidgets);
  });
}
