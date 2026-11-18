import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/calorie_estimate.dart';

void main() {
  test('đúng bốn chế độ cơ bản', () {
    expect(ActivityMode.values.map((m) => m.id), ['run', 'walk', 'swim', 'ride']);
  });

  test('id là duy nhất và không rỗng — DB lưu theo id này', () {
    final ids = ActivityMode.values.map((m) => m.id).toSet();
    expect(ids.length, ActivityMode.values.length);
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });

  test('fromId đọc lại đúng, id lạ thì về run chứ không nổ', () {
    for (final mode in ActivityMode.values) {
      expect(ActivityMode.fromId(mode.id), mode);
    }
    expect(ActivityMode.fromId('kayak'), ActivityMode.run);
    expect(ActivityMode.fromId(''), ActivityMode.run);
  });

  test('chỉ Bơi chia chặng 100 m, chỉ Đạp xe hiện tốc độ', () {
    expect(ActivityMode.swim.splitsIn100m, isTrue);
    expect(ActivityMode.swim.splitDistanceM, 100);
    for (final mode in [ActivityMode.run, ActivityMode.walk, ActivityMode.ride]) {
      expect(mode.splitsIn100m, isFalse);
      expect(mode.splitDistanceM, 1000);
    }

    expect(ActivityMode.ride.showsSpeed, isTrue);
    expect(ActivityMode.ride.paceUnit, PaceUnit.speedKmh);
    for (final mode in [ActivityMode.run, ActivityMode.walk, ActivityMode.swim]) {
      expect(mode.showsSpeed, isFalse);
    }
  });

  test('ngưỡng lọc hợp lý và nhất quán giữa các chế độ', () {
    for (final mode in ActivityMode.values) {
      expect(mode.maxAccuracyM, greaterThan(0));
      expect(mode.met, greaterThan(0));
      expect(mode.gpsDistanceFilterM, greaterThan(0));
      // Ngưỡng "đang di chuyển" phải thấp hơn hẳn ngưỡng "nhảy GPS", không thì
      // mọi điểm hợp lệ đều bị coi là đứng yên.
      expect(mode.minMovingSpeedMps, lessThan(mode.maxSpeedMps));
    }

    // Bơi được nới sai số vì máy ngập nước; đạp xe cho tốc độ cao nhất.
    expect(ActivityMode.swim.maxAccuracyM, greaterThan(ActivityMode.run.maxAccuracyM));
    expect(ActivityMode.ride.maxSpeedMps, greaterThan(ActivityMode.run.maxSpeedMps));
    expect(ActivityMode.walk.maxSpeedMps, lessThan(ActivityMode.run.maxSpeedMps));
  });

  test('MET: chạy tốn nhiều năng lượng nhất, đi bộ ít nhất', () {
    expect(ActivityMode.run.met, greaterThan(ActivityMode.swim.met));
    expect(ActivityMode.swim.met, greaterThan(ActivityMode.ride.met));
    expect(ActivityMode.walk.met, lessThan(ActivityMode.ride.met));
  });

  group('estimateCalories', () {
    test('ra đúng công thức MET × kg × giờ', () {
      // Buổi bơi mẫu: MET 8, 1:03:46 (3826 s), người ~61 kg → ~520 kcal như
      // prototype hiển thị.
      final kcal = estimateCalories(
        mode: ActivityMode.swim,
        seconds: 3826,
        weightKg: 61,
      );
      expect(kcal, closeTo(518, 5));
    });

    test('đầu vào vô lý thì ra 0, không ra số âm', () {
      expect(estimateCalories(mode: ActivityMode.run, seconds: 0, weightKg: 60), 0);
      expect(estimateCalories(mode: ActivityMode.run, seconds: -10, weightKg: 60), 0);
      expect(estimateCalories(mode: ActivityMode.run, seconds: 600, weightKg: 0), 0);
    });

    test('cân nặng mặc định dùng được ngay khi người dùng chưa nhập', () {
      expect(defaultWeightKg, inInclusiveRange(40, 100));
      expect(
        estimateCalories(mode: ActivityMode.run, seconds: 1800, weightKg: defaultWeightKg),
        greaterThan(0),
      );
    });
  });
}
