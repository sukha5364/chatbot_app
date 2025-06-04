// lib/shared/utils/image_utils.dart
import 'package:logging/logging.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull를 사용하기 위해 추가

final _log = Logger('ImageUtils');

// 제품 식별자(제품명 또는 imageUrl에 담긴 키)를 로컬 애셋 경로로 매핑합니다.
const Map<String, String> _productImageMap = {
  'KALENJI RUN SUPPORT': 'assets/product_images/kalenji_run_support.png',
  'KIPRUN KS500': 'assets/product_images/kiprun_ks500.png',
  'KIPRUN KD500': 'assets/product_images/kiprun_kd500.png',
  'QUECHUA AIR SECONDS 4.2 FRESH&BLACK': 'assets/product_images/quechua_air_seconds_4_2_fb.png',
  'KIPSTA F900 프로 축구공': 'assets/product_images/kipsta_f900_football.png',
  'DOMYOS 여성용 심리스 레깅스': 'assets/product_images/domyos_seamless_leggings.png',
  'QUECHUA 컴팩트 폴딩 캠핑 의자': 'assets/product_images/quechua_folding_chair.png',
  'KIPSTA 소프트 축구공 4호': 'assets/product_images/kipsta_soft_football.png',
  'IWIKIDO 컴팩트 비치 쉘터': 'assets/product_images/iwikido_beach_shelter.png',

  // $ 문자가 포함된 URL 키에 r 접두사(raw string) 추가
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P2602496/K$C48993D048591DB8C9C9EA6B8D3D94A9/%EB%82%A8%EC%84%B1-%EB%9F%AC%EB%8B%9D%ED%99%94-KS500-2-KIPRUN-8772865.JPG?F=768X0&FORMAT=AUTO':
  'assets/product_images/kiprun_ks500.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P2006099/K$7E8D8F4A5C6D7E8F9A0B1C2D3E4F5G6H/SQR/KIPRUN-KS500-MEN-S-RUNNING-SHOES-BLACK-GREY.JPG?FORMAT=AUTO':
  'assets/product_images/kiprun_ks500.png', // 동일 이미지 키 다른 URL 예시에도 적용
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P1854831/K$7E8D8F4A5C6D7E8F9A0B1C2D3E4F5G6H/SQR/RUN-SUPPORT-MEN-S-RUNNING-SHOES-BLUE-YELLOW.JPG?FORMAT=AUTO':
  'assets/product_images/kalenji_run_support.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P2170400/K$7E8D8F4A5C6D7E8F9A0B1C2D3E4F5G6H/SQR/AIR-SECONDS-4-2-F-B-INFLATABLE-TENT-4-PERSON-2-BEDROOM.JPG?FORMAT=AUTO':
  'assets/product_images/quechua_air_seconds_4_2_fb.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P1982093/K$7E8D8F4A5C6D7E8F9A0B1C2D3E4F5G6H/SQR/F900-FIFA-QUALITY-PRO-FOOTBALL-BALL-SIZE-5-WHITE-BLUE.JPG?FORMAT=AUTO':
  'assets/product_images/kipsta_f900_football.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P2010950/K$7E8D8F4A5C6D7E8F9A0B1C2D3E4F5G6H/SQR/WOMEN-S-SEAMLESS-7-8-FITNESS-LEGGINGS-BLACK.JPG?FORMAT=AUTO':
  'assets/product_images/domyos_seamless_leggings.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P2070004/K$8F7E3D0F0D0E5C1E0B8F8F8F8F8F8F8F/SQRSIZE-300X300/FOLDING-LOW-CAMPING-CHAIR-MH100.JPG?FORMAT=AUTO':
  'assets/product_images/quechua_folding_chair.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P1611750/K$E8B1C6C721676367F6B0D0D9E4E5E6E7/SQRSIZE-300X300/MINI-FOOTBALL-SUNNY-300-SIZE-1-YELLOW.JPG?FORMAT=AUTO':
  'assets/product_images/kipsta_soft_football.png',
  r'HTTPS://CONTENTS.MEDIADECATHLON.COM/P1936229/K$B1F3AC7DB4248B553A5355811D079D12/SQRSIZE-300X300/BEACH-SHELTER-IWIKO-180-1-ADULT-2-CHILDREN-ANTI-UV-ORANGE-BLUE.JPG?FORMAT=AUTO':
  'assets/product_images/iwikido_beach_shelter.png',
  // 추가적인 제품 이미지 키와 경로 매핑
};

String? getProductImagePath(String? productIdentifier) {
  if (productIdentifier == null || productIdentifier.isEmpty) {
    _log.fine("getProductImagePath called with null or empty identifier.");
    return null;
  }

  // 키 조회 시 일관성을 위해 대문자로 변환 (맵의 키도 대문자 또는 raw string 처리된 원본)
  // raw string으로 키를 정의했으므로, 조회 시에도 동일한 형태로 조회하거나,
  // 또는 맵의 키 자체를 정규화된 형태로 (예: 대문자 변환, 특수문자 제거 등) 저장하는 것이 좋습니다.
  // 여기서는 Mock API가 반환하는 imageUrl 값을 그대로 사용한다고 가정하고,
  // 해당 값이 _productImageMap의 raw string 키와 일치하거나, 제품명과 일치하는지 확인합니다.

  String? path = _productImageMap[productIdentifier] ?? _productImageMap[productIdentifier.toUpperCase()];

  // 직접 매칭되지 않은 경우, 키의 일부 또는 식별자의 일부가 포함되는지 확인 (더 유연한 매칭)
  if (path == null) {
    final upperIdentifier = productIdentifier.toUpperCase();
    final fallbackEntry = _productImageMap.entries.firstWhereOrNull(
            (entry) => entry.key.toUpperCase().contains(upperIdentifier) || upperIdentifier.contains(entry.key.toUpperCase()));

    if (fallbackEntry != null) {
      path = fallbackEntry.value;
      _log.fine("Found fallback image for '$productIdentifier' (matched key: '${fallbackEntry.key}') -> '$path'");
    }
  }

  if (path != null) {
    _log.fine("Found image for '$productIdentifier' -> '$path'");
  } else {
    _log.warning("No local image path found for identifier: '$productIdentifier'");
  }
  return path;
}

String normalizeProductNameForKey(String productName) {
  return productName.toUpperCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^\w-]'), '');
}