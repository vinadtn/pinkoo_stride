import 'activity_mode.dart';

/// Ước lượng calo theo công thức MET — cách tính phổ thông nhất khi không có
/// nhịp tim: `kcal = MET × cân nặng(kg) × số giờ`.
///
/// Đây là **ước lượng**, không phải đo: không tính tới tuổi, giới tính, độ dốc
/// hay nhịp tim. UI luôn ghi rõ "ước lượng" để không ai hiểu nhầm là số đo thật.
double estimateCalories({
  required ActivityMode mode,
  required num seconds,
  required double weightKg,
}) {
  if (seconds <= 0 || weightKg <= 0) return 0;
  return mode.met * weightKg * (seconds / 3600);
}

/// Cân nặng mặc định khi người dùng chưa nhập, kg.
///
/// Buổi bơi mẫu của prototype ghi 520 kcal cho 1:03:46 ở MET 8 — tức người đó
/// khoảng 61 kg. Lấy 60 cho tròn.
const double defaultWeightKg = 60;
