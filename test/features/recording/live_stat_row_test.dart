import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/format/stat_format.dart';
import 'package:pinkoo_stride/core/theme/app_theme.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/recording/presentation/cubit/recording_state.dart';
import 'package:pinkoo_stride/features/recording/presentation/widgets/live_stat_row.dart';
import 'package:pinkoo_stride/l10n/gen/app_localizations.dart';

/// Hàng ba số liệu lúc đang ghi phải chia đều bề ngang, cùng một cỡ chữ và căn
/// giữa từng cột — nhìn lướt khi đang chạy, lệch một chút là khó đọc.
void main() {
  const rowWidth = 360.0;

  Future<void> pumpRow(WidgetTester tester, RecordingState state) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: rowWidth, child: LiveStatRow(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Quãng đường và thời gian cho ra ba chuỗi khác hẳn nhau, để `find.text`
  // không bắt nhầm cột này sang cột kia.
  const state = RecordingState(
    mode: ActivityMode.run,
    status: RecordingStatus.recording,
    distanceM: 5230,
    elapsedSec: 1830,
  );

  final distance = StatFormat.distanceValue(state.distanceM);
  final time = StatFormat.clock(state.elapsedSec);
  final pace = StatFormat.pace(state.paceSecPerUnit);

  testWidgets('ba số liệu dùng chung một cỡ chữ', (tester) async {
    await pumpRow(tester, state);

    final sizes = <double?>{
      for (final value in [distance, time, pace])
        tester.widget<Text>(find.text(value)).style?.fontSize,
    };

    expect(sizes.single, isNotNull, reason: 'cả ba cột phải cùng một cỡ chữ');
  });

  testWidgets('ba cột chia đều bề ngang và căn giữa từng cột', (tester) async {
    await pumpRow(tester, state);

    // Chia ba đều nhau thì tâm mỗi cột rơi đúng 1/6, 3/6 và 5/6 bề ngang.
    expect(tester.getCenter(find.text(distance)).dx, closeTo(rowWidth / 6, 1));
    expect(tester.getCenter(find.text(time)).dx, closeTo(rowWidth / 2, 1));
    expect(tester.getCenter(find.text(pace)).dx, closeTo(rowWidth * 5 / 6, 1));
  });

  testWidgets('màn hẹp thì cả ba cùng nhỏ lại, không cột to cột nhỏ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Align(
          alignment: Alignment.topLeft,
          // Hẹp hơn hẳn: "30:30" không còn vừa ở cỡ chữ lớn nhất.
          child: SizedBox(width: 240, child: LiveStatRow(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sizes = <double?>{
      for (final value in [distance, time, pace])
        tester.widget<Text>(find.text(value)).style?.fontSize,
    };

    expect(sizes.single, isNotNull, reason: 'thu nhỏ thì phải thu đều cả ba cột');
    expect(find.byType(LiveStatRow), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'không được tràn bề ngang');
  });
}
