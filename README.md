# Vietnam TripMate – AI Travel Planner (MVP)

Ứng dụng Flutter giúp khách quốc tế lập lịch trình du lịch Việt Nam. MVP tập trung vào **Đà Nẵng** và **Hội An**. Giao diện app bằng tiếng Anh.

## Tính năng hiện có

| Tính năng | Trạng thái |
|---|---|
| Home: giới thiệu, Create a Trip, điểm đến phổ biến, chuyến đi đã lưu | ✅ |
| Create Trip: điểm xuất phát, điểm đến, ngày, số người, ngân sách, tiền tệ, sở thích, nhịp độ, phương tiện, kiểm tra đầu vào | ✅ |
| Itinerary: chia theo ngày và buổi sáng/chiều/tối, gom địa điểm gần nhau, ước tính di chuyển, thời gian dự phòng | ✅ |
| Sửa lịch trình: thêm, xóa, lên/xuống, chuyển buổi, thay địa điểm, tạo lại một ngày | ✅ |
| Places: nguồn dữ liệu, trạng thái xác minh, tọa độ | ✅ (dữ liệu **chưa xác minh**) |
| Trip Map: mở Apple Maps/Google Maps, chỉ đường, lộ trình cả ngày | ✅ (không dùng API trả phí, không xin quyền vị trí) |
| Affiliate Offers: interface `AffiliateProvider`, thông báo hoa hồng, cache offline | ✅ chỉ có **mock data** |
| Lưu SQLite offline, xóa từng chuyến hoặc toàn bộ | ✅ |
| AdMob, UMP consent | ⏳ Giai đoạn 6 |
| Lập lịch trình bằng AI (qua backend proxy) | ⏳ Giai đoạn sau |
| Build và ký iOS | ⏳ Cần MacBook + Xcode |

## Chạy app

Yêu cầu: Flutter stable (đã thử với Flutter 3.47.8 / Dart 3.13.7).

```bash
flutter pub get
flutter analyze        # kiểm tra tĩnh
flutter test           # unit test + widget test
```

**Trên Windows (xem thử nhanh bằng Chrome):**
```bash
flutter run -d chrome --web-port 8765
```
Bản web chỉ để xem thử trong lúc phát triển. Dữ liệu được lưu trong IndexedDB của trình duyệt và gắn với cổng 8765, nên hãy luôn dùng cùng một cổng.

**Android emulator (Windows hoặc Mac):** cài Android Studio, tạo máy ảo, rồi chạy `flutter run`.

**iOS (chỉ trên Mac):**
```bash
flutter doctor              # cần Xcode và CocoaPods theo yêu cầu
open -a Simulator
flutter run
```
Để chạy trên iPhone thật, mở `ios/Runner.xcworkspace` trong Xcode, chọn Team (Apple ID miễn phí là đủ để thử) tại *Signing & Capabilities*. Bundle ID hiện tại là `com.quangdatcse.vietnamTripmate`.

## Cấu trúc

```
lib/
  main.dart                 mở SQLite, nạp catalog, chạy app
  app/                      MaterialApp + Riverpod providers
  core/                     routing, theme, utils (ngày, khoảng cách, id)
  data/
    local/app_database.dart schema SQLite + migrations
    sources/                nạp assets/data/catalog.json vào SQLite
    repositories/           catalog, trips, settings, offers (có cache)
  models/                   Destination, Place, Trip, Itinerary, AffiliateOffer
  services/
    itinerary/              thuật toán lập lịch, chỉnh sửa, ước tính di chuyển
    maps/                   mở bản đồ ngoài
    affiliate/              AffiliateProvider + MockAffiliateProvider
    analytics/              đếm lượt nhấp deal cục bộ (mặc định tắt)
  features/                 các màn hình: home, create_trip, itinerary, places,
                            trip_map, affiliate_offers, settings
  shared/widgets/           widget cho trạng thái loading/empty/error, badge
assets/data/catalog.json    dữ liệu điểm đến và địa điểm do biên tập viên quản lý
test/                       test thuật toán, editor, validation, repository, widget
```

## Cơ sở dữ liệu

Các bảng gồm: `destinations`, `places`, `trips`, `trip_destinations`, `itinerary_days`, `itinerary_items`, `affiliate_offers`, `app_settings`. Khóa ngoại được bật (`PRAGMA foreign_keys = ON`):

- Xóa trip sẽ xóa luôn ngày, mục lịch trình và liên kết điểm đến (CASCADE).
- Không thể xóa place hoặc destination đang được lịch trình sử dụng (RESTRICT).

**Thay đổi schema:** tăng `schemaVersion` trong [app_database.dart](lib/data/local/app_database.dart) và thêm migration mới. Không sửa migration cũ.

**Cập nhật dữ liệu địa điểm:** sửa [catalog.json](assets/data/catalog.json) rồi **tăng `version`**. App sẽ nạp lại dữ liệu mà không xóa chuyến đi đã lưu.

## Về dữ liệu

- Địa điểm trong catalog là địa điểm có thật. Tuy nhiên mô tả và tọa độ là **bản nháp biên tập** (`verification_status: unverified`) và chưa được kiểm tra tại chỗ.
- Catalog **không** có giờ mở cửa, giá vé hay hình ảnh. Chỉ thêm khi có nguồn và giấy phép rõ ràng. Khi đã xác minh, đổi `verification_status` thành `verified` và điền `verified_on`.
- Thời gian di chuyển là **ước tính**: khoảng cách đường chim bay × 1,4, chia cho tốc độ trung bình. App luôn ghi rõ đây là ước tính.
- Tour trong Offers là **MOCK**: tên sản phẩm chỉ là mẫu, không có giá. Link dẫn tới trang tìm kiếm Viator thông thường, không có mã affiliate.

## Tích hợp affiliate thật (sau khi được duyệt)

1. Đăng ký chương trình affiliate hoặc API của đối tác (ví dụ Viator Partner Program). Đọc kỹ điều khoản về cache, hiển thị giá, hình ảnh và giới hạn gọi API.
2. Tạo class mới implement `AffiliateProvider` trong `lib/services/affiliate/`. Dùng `bookingUrl` đúng như đối tác trả về.
3. Đổi `affiliateProviderProvider` trong [providers.dart](lib/app/providers.dart).
4. **Không đưa API key vào app.** Nếu API cần key bí mật, hãy gọi qua backend hoặc proxy.

## Làm việc trên hai máy (Windows ↔ Mac)

```bash
git pull                 # trước khi làm
# ... code ...
flutter analyze && flutter test
git add .
git commit -m "Mô tả thay đổi"
git push                 # sau khi làm xong
```

- Lần đầu trên Mac: `git clone https://github.com/quangdatcse/vn-trip-plan.git`, rồi `flutter pub get`.
- **Có commit:** `lib/`, `test/`, `assets/`, `android/`, `ios/` (trừ các file do máy tự sinh), `web/`, `pubspec.yaml`, `pubspec.lock`.
- **Không commit:** file theo từng máy như `android/local.properties`, `ios/Flutter/Generated.xcconfig`, `ios/Pods/`, `build/`, `.dart_tool/`.
- **Không bao giờ commit:** `.env`, `key.properties`, `*.jks`, `*.p12`, `*.mobileprovision`, API key. Danh sách đầy đủ nằm trong `.gitignore`.
- **Khi có merge conflict:** mở file trong VS Code, chọn *Accept Current / Incoming / Both*, chạy lại `flutter test`, rồi commit.

## Giai đoạn tiếp theo

1. Chạy trên Android emulator, sau đó trên iOS Simulator khi đã có Mac và Xcode.
2. Xác minh dữ liệu địa điểm (tọa độ, mô tả) và bổ sung hình ảnh có giấy phép.
3. Tích hợp AdMob bằng test ad unit, kèm UMP consent. Cân nhắc ATT nếu có tracking.
4. Viết Privacy Policy, trang Support và khai báo App Privacy.
5. Build, ký và gửi TestFlight. Bước này cần Apple Developer Program.
