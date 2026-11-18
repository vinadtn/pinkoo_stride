import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/recording/data/split_announcer_impl.dart';
import 'package:pinkoo_stride/features/recording/domain/split_alert.dart';

void main() {
  group('câu đọc', () {
    test('chạy thì đọc theo ki lô mét', () {
      const alert = SplitAlert(
        index: 2,
        mode: ActivityMode.run,
        distanceM: 2000,
        paceSecPerUnit: 350,
      );

      expect(VoiceSplitAnnouncer.sentenceFor(alert), contains('2 ki lô mét'));
      expect(VoiceSplitAnnouncer.sentenceFor(alert), contains('5:50'));
    });

    test('bơi thì đọc theo trăm mét', () {
      const alert = SplitAlert(
        index: 3,
        mode: ActivityMode.swim,
        distanceM: 300,
        paceSecPerUnit: 180,
      );

      final sentence = VoiceSplitAnnouncer.sentenceFor(alert);

      expect(sentence, contains('3 trăm mét'));
      expect(sentence, contains('100 mét'));
      expect(sentence, isNot(contains('ki lô mét')));
    });
  });

  group('cài đặt', () {
    test('id lưu xuống đọc lại ra đúng kiểu', () {
      for (final mode in SplitAlertMode.values) {
        expect(SplitAlertMode.fromId(mode.id), mode);
      }
    });

    test('giá trị lạ hoặc chưa đặt thì về Tắt', () {
      expect(SplitAlertMode.fromId(null), SplitAlertMode.off);
      expect(SplitAlertMode.fromId('khong-biet'), SplitAlertMode.off);
    });
  });
}
