/// Điểm đã biết "đi được bao xa, mất bao lâu" kể từ lúc bắt đầu.
abstract interface class TimedPoint {
  /// Giây kể từ điểm đầu tiên.
  double get tSec;

  /// Quãng đường cộng dồn tới điểm này, mét.
  double get cumulativeM;
}

/// Một chặng trong biểu đồ split.
class RouteSplit {
  const RouteSplit({
    required this.index,
    required this.distanceM,
    required this.durationSec,
    required this.isPartial,
  });

  /// Đếm từ 1.
  final int index;
  final double distanceM;
  final double durationSec;

  /// Chặng cuối chưa đủ độ dài (ví dụ 26 m còn lại của buổi bơi 2.125,8 m).
  final bool isPartial;

  /// Giây cho mỗi mét — dùng so sánh nhanh/chậm giữa các chặng.
  double get secPerMeter => distanceM == 0 ? 0 : durationSec / distanceM;
}

/// Chia đường đi thành các chặng dài [splitDistanceM] mét.
///
/// Mốc chặng rơi đúng vào ranh giới quãng đường (nội suy thời gian giữa hai
/// điểm GPS kẹp mốc đó), không phải "cứ N điểm một chặng" — nên 2.125,8 m chia
/// 100 m ra đúng 21 chặng tròn + một chặng lẻ 25,8 m, khớp với prototype.
///
/// [points] phải sắp xếp tăng theo thời gian và `cumulativeM` không giảm.
List<RouteSplit> computeSplits(List<TimedPoint> points, {required int splitDistanceM}) {
  if (points.length < 2 || splitDistanceM <= 0) return const [];

  final total = points.last.cumulativeM;
  final fullSplits = total ~/ splitDistanceM;

  final splits = <RouteSplit>[];
  var prevTime = points.first.tSec;
  var cursor = 0; // không quét lại từ đầu cho mỗi mốc

  for (var k = 1; k <= fullSplits; k++) {
    final boundary = (k * splitDistanceM).toDouble();
    while (cursor < points.length - 1 && points[cursor + 1].cumulativeM < boundary) {
      cursor++;
    }
    final time = _timeAtDistance(points, cursor, boundary);
    splits.add(
      RouteSplit(
        index: k,
        distanceM: splitDistanceM.toDouble(),
        durationSec: time - prevTime,
        isPartial: false,
      ),
    );
    prevTime = time;
  }

  final remainder = total - fullSplits * splitDistanceM;
  // Dưới 1 m thì chỉ là nhiễu làm tròn, không đáng thành một chặng riêng.
  if (remainder >= 1) {
    splits.add(
      RouteSplit(
        index: fullSplits + 1,
        distanceM: remainder,
        durationSec: points.last.tSec - prevTime,
        isPartial: true,
      ),
    );
  }

  return splits;
}

/// Thời điểm (giây) đi qua mốc [distance], nội suy tuyến tính giữa
/// `points[from]` và điểm kế tiếp.
double _timeAtDistance(List<TimedPoint> points, int from, double distance) {
  final a = points[from];
  if (from + 1 >= points.length) return a.tSec;
  final b = points[from + 1];

  final span = b.cumulativeM - a.cumulativeM;
  if (span <= 0) return b.tSec;

  final ratio = ((distance - a.cumulativeM) / span).clamp(0.0, 1.0);
  return a.tSec + (b.tSec - a.tSec) * ratio;
}

/// Chỉ số (trong danh sách) của chặng nhanh nhất, chỉ xét chặng đủ độ dài.
/// Trả về -1 khi không có chặng nào đủ.
int fastestSplitIndex(List<RouteSplit> splits) {
  var best = -1;
  var bestSec = double.infinity;
  for (var i = 0; i < splits.length; i++) {
    final s = splits[i];
    if (s.isPartial) continue;
    if (s.durationSec < bestSec) {
      bestSec = s.durationSec;
      best = i;
    }
  }
  return best;
}
