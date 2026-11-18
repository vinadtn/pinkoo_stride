import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinkoo_stride/core/network/connectivity_cubit.dart';
import 'package:pinkoo_stride/core/theme/app_theme.dart';
import 'package:pinkoo_stride/core/widgets/network_status_banner.dart';
import 'package:pinkoo_stride/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockConnectivityCubit extends MockCubit<NetworkStatus> implements ConnectivityCubit {}

const _offlineText = 'Mất kết nối mạng';
const _reconnectedText = 'Đã kết nối lại';

void main() {
  Future<void> pumpBanner(WidgetTester tester, List<NetworkStatus> statuses) async {
    final cubit = _MockConnectivityCubit();
    whenListen(cubit, Stream.fromIterable(statuses), initialState: NetworkStatus.unknown);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ConnectivityCubit>.value(
          value: cubit,
          child: const NetworkStatusBanner(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(); // nhận các state trong stream
  }

  testWidgets('mở app khi đang có mạng → không hiện gì', (tester) async {
    await pumpBanner(tester, const [NetworkStatus.online]);
    await tester.pumpAndSettle();

    expect(find.text(_offlineText), findsNothing);
    expect(find.text(_reconnectedText), findsNothing);
  });

  testWidgets('mất mạng → hiện "Mất kết nối mạng" và giữ nguyên', (tester) async {
    await pumpBanner(tester, const [NetworkStatus.online, NetworkStatus.offline]);
    await tester.pump(const Duration(seconds: 10));

    expect(find.text(_offlineText), findsOneWidget);
  });

  testWidgets('có mạng lại → hiện "Đã kết nối lại" rồi tự ẩn sau 3 giây', (tester) async {
    await pumpBanner(tester, const [NetworkStatus.offline, NetworkStatus.online]);
    await tester.pump();

    expect(find.text(_reconnectedText), findsOneWidget);
    expect(find.text(_offlineText), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_reconnectedText), findsNothing);
  });
}
