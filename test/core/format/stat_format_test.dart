import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/format/stat_format.dart';

void main() {
  group('distance', () {
    test('dưới 1 km hiện mét, không thập phân', () {
      expect(StatFormat.distance(0), '0 m');
      expect(StatFormat.distance(849.6), '850 m');
      expect(StatFormat.distance(999.4), '999 m');
    });

    test('từ 1 km hiện km với dấu PHẨY thập phân kiểu Việt Nam', () {
      expect(StatFormat.distance(2125.8), '2,13 km');
      expect(StatFormat.distance(1000), '1,00 km');
      expect(StatFormat.distance(42195), '42,20 km');
    });

    test('trên 1000 km có dấu chấm phân nhóm nghìn', () {
      expect(StatFormat.distance(1234567), '1.234,57 km');
    });

    test('value và unit tách rời khớp với bản gộp', () {
      for (final m in [0.0, 500.0, 999.9, 1000.0, 2125.8]) {
        expect('${StatFormat.distanceValue(m)} ${StatFormat.distanceUnit(m)}',
            StatFormat.distance(m));
      }
    });
  });

  group('duration', () {
    test('chưa tới một giờ thì bỏ phần giờ', () {
      expect(StatFormat.duration(0), '0:00');
      expect(StatFormat.duration(59), '0:59');
      expect(StatFormat.duration(725), '12:05');
      expect(StatFormat.duration(3599), '59:59');
    });

    test('từ một giờ thì hiện giờ, phút luôn hai chữ số', () {
      expect(StatFormat.duration(3600), '1:00:00');
      expect(StatFormat.duration(3826), '1:03:46'); // buổi bơi mẫu
      expect(StatFormat.duration(3794), '1:03:14'); // thời gian di chuyển
    });

    test('số âm hoặc không hữu hạn vẫn ra chuỗi hợp lệ', () {
      expect(StatFormat.duration(-5), '0:00');
      expect(StatFormat.duration(double.nan), '0:00');
      expect(StatFormat.duration(double.infinity), '0:00');
    });
  });

  group('clock', () {
    test('luôn đủ giờ:phút:giây để layout không nhảy khi qua mốc 1 giờ', () {
      expect(StatFormat.clock(0), '0:00:00');
      expect(StatFormat.clock(59), '0:00:59');
      expect(StatFormat.clock(3599), '0:59:59');
      expect(StatFormat.clock(3826), '1:03:46');
    });
  });

  group('pace', () {
    test('giây mỗi đơn vị → phút:giây', () {
      expect(StatFormat.pace(180), '3:00'); // 3:00 /100m của buổi bơi
      expect(StatFormat.pace(112), '1:52'); // chặng nhanh nhất
      expect(StatFormat.pace(330), '5:30');
    });

    test('chưa đi được gì hoặc pace vô lý thì hiện --:--', () {
      expect(StatFormat.pace(0), '--:--');
      expect(StatFormat.pace(-10), '--:--');
      expect(StatFormat.pace(double.infinity), '--:--');
      expect(StatFormat.pace(double.nan), '--:--');
      // Trên 100 phút cho một km nghĩa là đang đứng, không phải đang đi.
      expect(StatFormat.pace(6001), '--:--');
    });
  });

  group('speedKmh', () {
    test('một chữ số thập phân, dấu phẩy', () {
      expect(StatFormat.speedKmh(24.52), '24,5');
      expect(StatFormat.speedKmh(2), '2,0');
    });

    test('không hợp lệ thì về 0,0', () {
      expect(StatFormat.speedKmh(0), '0,0');
      expect(StatFormat.speedKmh(-3), '0,0');
      expect(StatFormat.speedKmh(double.nan), '0,0');
    });
  });

  test('count phân nhóm nghìn bằng dấu chấm', () {
    expect(StatFormat.count(3812), '3.812');
    expect(StatFormat.count(0), '0');
  });

  test('calories làm tròn về số nguyên', () {
    expect(StatFormat.calories(519.6), '520');
  });
}
