// 파일 경로: lib/core/services/mock_api_service.dart
import 'dart:convert'; // For jsonEncode if needed for complex logging
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Provider 정의가 삭제되므로 주석 처리 또는 삭제 가능
import 'package:decathlon_demo_app/core/models/api_models.dart';
import 'package:logging/logging.dart';

// final mockApiServiceProvider = Provider<MockApiService>((ref) { // ⬅️ 이 부분을 삭제 또는 주석 처리
//   return MockApiService();
// });

class MockApiService {
  final _log = Logger('MockApiService');

  Future<Map<String, dynamic>> _delayedResponse(Map<String, dynamic> data,
      {int milliseconds = 300}) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
    String dataPreview = jsonEncode(data);
    if (dataPreview.length > 200) {
      dataPreview = "${dataPreview.substring(0, 200)}...";
    }
    _log.info("Returning mock response: $dataPreview");
    return data;
  }

  // --- 1. getUserCoupons ---
  Future<GetUserCouponsResponse> getUserCoupons({required String userId}) async {
    _log.info("[MockAPI] getUserCoupons called for userId: $userId");
    Map<String, dynamic> responseData;
    switch (userId) {
      case "newrunner_01":
        responseData = {
          "found": true,
          "coupons": [
            {
              "couponId": "NEW_MEMBER_10P",
              "couponName": "신규 회원 10% 할인 쿠폰",
              "description": """첫 구매 시 사용 가능한 10% 할인 쿠폰입니다. (견본품 앱 전용)""",
              "discountType": "percentage",
              "discountValue": 10.0,
              "expiryDate": "2025-12-31",
              "conditions": "일부 품목 제외, 첫 구매 한정, 최대 할인 금액 1만원"
            }
          ]
        };
        break;
      case "family_shopper":
        responseData = {
          "found": true,
          "coupons": [
            {
              "couponId": "FAMILY5000",
              "couponName": "가정의 달 기념 5만원 이상 구매 시 5천원 할인쿠폰",
              "description": """총 주문 금액 5만원 이상 시 사용 가능합니다. (견본품 앱 전용)""",
              "discountType": "fixed_amount",
              "discountValue": 5000.0,
              "expiryDate": "2025-05-31",
              "conditions": "일부 프로모션 중복 불가, 1인 1회 한정"
            }
          ]
        };
        break;
      case "camping_master":
        responseData = {"found": true, "coupons": []};
        break;
      default:
        responseData = {"found": false, "message": "사용자 ID ($userId)에 대한 쿠폰 정보를 찾을 수 없습니다."};
    }
    return GetUserCouponsResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 2. getProductInfo ---
  Future<GetProductInfoResponse> getProductInfo(
      {required String productName, String? brandName}) async {
    _log.info("[MockAPI] getProductInfo called for productName: '$productName', brandName: '$brandName'");
    Map<String, dynamic> responseData;
    if (productName == "KALENJI RUN SUPPORT") {
      responseData = {
        "found": true, "productName": "KALENJI RUN SUPPORT", "brandName": "KALENJI",
        "description": """발목 부분에 추가적인 서포트 구조가 있어 안정성이 뛰어나고, EVA 폼 미드솔로 충격 흡수가 잘 됩니다. 가격은 65,000원입니다. (견본품 정보)""",
        "price": 65000.0,
        "availableSizes": ["250mm", "260mm", "270mm", "280mm"],
        "availableColors": ["블루", "블랙", "네온 그린"],
        "imageUrl": "https://contents.mediadecathlon.com/p1854831/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/run-support-men-s-running-shoes-blue-yellow.jpg?format=auto"
      };
    } else if (productName == "KIPRUN KS500") {
      responseData = {
        "found": true, "productName": "KIPRUN KS500", "brandName": "KIPRUN",
        "description": """안정적인 지지력과 뛰어난 쿠셔닝이 장점입니다. (약 89,000원) (견본품 정보)""",
        "price": 89000.0, "availableSizes": ["260mm", "270mm", "280mm"], "availableColors": ["블랙", "그레이"],
        "imageUrl": "https://contents.mediadecathlon.com/p2006099/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/kiprun-ks500-men-s-running-shoes-black-grey.jpg?format=auto"
      };
    } else if (productName == "KIPRUN KD500") {
      responseData = {
        "found": true, "productName": "KIPRUN KD500", "brandName": "KIPRUN",
        "description": """경량성과 쿠셔닝의 조화가 좋습니다. (약 99,000원) (견본품 정보)""",
        "price": 99000.0, "availableSizes": ["255mm", "265mm", "275mm"], "availableColors": ["레드", "블루"],
        "imageUrl": "https://contents.mediadecathlon.com/p1854831/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/run-support-men-s-running-shoes-blue-yellow.jpg?format=auto"
      };
    } else if (productName == "QUECHUA AIR SECONDS 4.2 FRESH&BLACK") {
      responseData = {
        "found": true, "productName": "QUECHUA AIR SECONDS 4.2 FRESH&BLACK", "brandName": "QUECHUA",
        "description": """공기 주입식이라 설치가 매우 간편하고, 방수 및 차광 기능이 뛰어난 4인용 텐트입니다. (견본품 정보)""",
        "price": 459000.0, "availableSizes": ["4인용"], "availableColors": ["카키", "네이비", "그레이"],
        "imageUrl": "https://contents.mediadecathlon.com/p2170400/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/air-seconds-4-2-f-b-inflatable-tent-4-person-2-bedroom.jpg?format=auto"
      };
    } else if (productName == "KIPSTA F900 프로 축구공") {
      responseData = {
        "found": true, "productName": "KIPSTA F900 프로 축구공", "brandName": "KIPSTA",
        "description": """FIFA Quality Pro 인증을 받은 최상급 경기용 축구공입니다. (견본품 정보)""",
        "price": 45000.0, "availableSizes": ["5호", "4호"], "availableColors": ["화이트/블루"],
        "imageUrl": "https://contents.mediadecathlon.com/p1982093/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/f900-fifa-quality-pro-football-ball-size-5-white-blue.jpg?format=auto"
      };
    } else if (productName == "DOMYOS 여성용 심리스 레깅스") {
      responseData = {
        "found": true, "productName": "DOMYOS 여성용 심리스 레깅스", "brandName": "DOMYOS",
        "description": """봉제선을 최소화하여 착용감이 매우 부드럽고 활동성이 뛰어난 제품입니다. (견본품 정보)""",
        "price": 29900.0, "availableSizes": ["XS", "S", "M", "L", "XL"], "availableColors": ["블랙", "네이비", "버건디"],
        "imageUrl": "https://contents.mediadecathlon.com/p2010950/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/women-s-seamless-7-8-fitness-leggings-black.jpg?format=auto"
      };
    } else if (productName == "QUECHUA 컴팩트 폴딩 캠핑 의자") {
      responseData = {
        "found": true, "productName": "QUECHUA 컴팩트 폴딩 캠핑 의자", "brandName": "QUECHUA",
        "description": """가볍고 작게 접혀 휴대와 보관이 용이한 캠핑 의자입니다. (18,000원) (견본품 정보)""",
        "price": 18000.0, "availableSizes": ["단일 사이즈"], "availableColors": ["카키", "블루", "그레이"],
        "imageUrl": "https://contents.mediadecathlon.com/p2070004/k\$8f7e3d0f0d0e5c1e0b8f8f8f8f8f8f8f/sqrsize-300x300/folding-low-camping-chair-mh100.jpg?format=auto"
      };
    } else if (productName == "KIPSTA 소프트 축구공 4호") {
      responseData = {
        "found": true, "productName": "KIPSTA 소프트 축구공 4호", "brandName": "KIPSTA",
        "description": """안전한 부드러운 소재로 만들어져 아이들이 실내외에서 가지고 놀기 좋은 축구공입니다. (12,000원) (견본품 정보)""",
        "price": 12000.0, "availableSizes": ["4호"], "availableColors": ["옐로우", "오렌지"],
        "imageUrl": "https://contents.mediadecathlon.com/p1611750/k\$e8b1c6c721676367f6b0d0d9e4e5e6e7/sqrsize-300x300/mini-football-sunny-300-size-1-yellow.jpg?format=auto"
      };
    } else if (productName == "IWIKIDO 컴팩트 비치 쉘터") {
      responseData = {
        "found": true, "productName": "IWIKIDO 컴팩트 비치 쉘터", "brandName": "IWIKIDO",
        "description": """자외선 차단(UPF 50+) 기능이 있으며, 간편하게 설치하고 해체할 수 있는 소형 그늘막입니다. (29,900원) (견본품 정보)""",
        "price": 29900.0, "availableSizes": ["1-2인용"], "availableColors": ["블루/옐로우", "민트"],
        "imageUrl": "https://contents.mediadecathlon.com/p1936229/k\$b1f3ac7db4248b553a5355811d079d12/sqrsize-300x300/beach-shelter-iwiko-180-1-adult-2-children-anti-uv-orange-blue.jpg?format=auto"
      };
    }
    else {
      responseData = {"found": false, "message": "제품 '$productName' 정보를 찾을 수 없습니다."};
    }
    return GetProductInfoResponse.fromJson(await _delayedResponse(responseData));
  }

  // ... (getStoreStock, getProductLocationInStore, getStoreInfo, getUserPurchaseHistory, getProductReviews, generateOrderQRCode, getConversationHistory, findNearbyStores, recommendProductsByFeatures 메서드들은 이전과 동일하게 유지) ...
  // (길이 관계상 생략, 실제 파일에서는 모든 메서드 유지)
  // --- 3. getStoreStock ---
  Future<GetStoreStockResponse> getStoreStock(
      {required String productName,
        required String storeName,
        String? size,
        String? color}) async {
    _log.info("[MockAPI] getStoreStock called for '$productName' at '$storeName' (Size: $size, Color: $color)");
    Map<String, dynamic> responseData;
    String now = DateTime.now().toIso8601String();

    if (productName == "KALENJI RUN SUPPORT" && (size == "270mm" || size == "270")) {
      if (storeName == "데카트론 강남점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now,
          "variants": [{"size": "270mm", "color": "블루", "stockStatus": "in_stock", "quantity": 5}]};
      } else if (storeName == "데카트론 코엑스점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now,
          "variants": [{"size": "270mm", "color": "블루", "stockStatus": "in_stock", "quantity": 2}]};
      } else if (storeName == "데카트론 서초점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now,
          "variants": [{"size": "270mm", "color": "블루", "stockStatus": "out_of_stock", "quantity": 0}]};
      } else {
        responseData = {"found": false, "message": "$storeName 정보를 찾을 수 없습니다. ($productName, $size)"};
      }
    }
    else if (productName == "QUECHUA AIR SECONDS 4.2 FRESH&BLACK" && storeName == "데카트론 하남점" && size == null && color == null) {
      responseData = { "found": true, "productName": productName, "storeName": storeName, "lastChecked": now,
        "variants": [
          {"size": "4인용", "color": "카키", "stockStatus": "in_stock", "quantity": 3},
          {"size": "4인용", "color": "네이비", "stockStatus": "low_stock", "quantity": 1},
          {"size": "4인용", "color": "그레이", "stockStatus": "out_of_stock", "quantity": 0}
        ]};
    }
    else if (productName == "KIPSTA F900 프로 축구공" && size == "5호") {
      if (storeName == "데카트론 송도점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [{"size": "5호", "color": "화이트/블루", "stockStatus": "out_of_stock", "quantity": 0}]};
      } else if (storeName == "데카트론 청라점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [{"size": "5호", "color": "화이트/블루", "stockStatus": "in_stock", "quantity": 3}]};
      } else if (storeName == "데카트론 인천논현점") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [{"size": "5호", "color": "화이트/블루", "stockStatus": "in_stock", "quantity": 5}]};
      } else {
        responseData = {"found": false, "message": "$storeName 정보를 찾을 수 없습니다. ($productName, $size)"};
      }
    }
    else if (productName == "DOMYOS 여성용 심리스 레깅스" && storeName == "데카트론 고양점" && size == "M") {
      responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now,
        "variants": [{"size": "M", "color": "블랙", "stockStatus": "in_stock", "quantity": 15}]};
    }
    else if (storeName == "데카트론 월드컵점") {
      if (productName == "QUECHUA 컴팩트 폴딩 캠핑 의자") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [
          {"size": "단일 사이즈", "color": "카키", "stockStatus": "in_stock", "quantity": 12},
          {"size": "단일 사이즈", "color": "블루", "stockStatus": "in_stock", "quantity": 8}
        ]};
      } else if (productName == "IWIKIDO 컴팩트 비치 쉘터") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [
          {"size": "1-2인용", "color": "블루/옐로우", "stockStatus": "in_stock", "quantity": 7}
        ]};
      } else if (productName == "KIPSTA 소프트 축구공 4호") {
        responseData = {"found": true, "productName": productName, "storeName": storeName, "lastChecked": now, "variants": [
          {"size": "4호", "color": "옐로우", "stockStatus": "in_stock", "quantity": 20}
        ]};
      }
      else {
        responseData = {"found": false, "message": """'데카트론 월드컵점'에서 '$productName' 재고 정보를 찾을 수 없습니다."""};
      }
    }
    else {
      responseData = {"found": false, "message": """'$storeName' 매장의 '$productName' (사이즈: $size, 색상: $color) 재고 정보를 찾을 수 없습니다."""};
    }
    return GetStoreStockResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 4. getProductLocationInStore ---
  Future<GetProductLocationInStoreResponse> getProductLocationInStore(
      {String? productName, String? category, required String storeName}) async {
    _log.info("[MockAPI] getProductLocationInStore called for '$productName' / '$category' at '$storeName'");
    Map<String, dynamic> responseData;

    if (storeName == "데카트론 하남점" && (productName == "QUECHUA AIR SECONDS 4.2 FRESH&BLACK" || category == "캠핑텐트")) {
      responseData = {
        "found": true,
        "zone": "D구역",
        "aisle": "캠핑용품 코너",
        "details": "대형 텐트 전시 공간 안쪽에 샘플과 함께 진열되어 있습니다."
      };
    } else {
      responseData = {"found": false, "message": """'$storeName' 매장 내 '$productName' 또는 '$category' 위치 정보를 찾을 수 없습니다."""};
    }
    return GetProductLocationInStoreResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 5. getStoreInfo ---
  Future<GetStoreInfoResponse> getStoreInfo({required String storeName}) async {
    _log.info("[MockAPI] getStoreInfo called for storeName: '$storeName'");
    Map<String, dynamic> responseData;
    if (storeName == "데카트론 강남점") {
      responseData = {"found": true, "storeName": "데카트론 강남점", "address": "서울특별시 강남구 테헤란로 152 (역삼동, 강남파이낸스센터)",
        "operatingHours": "매일 10:00 - 22:00", "phoneNumber": "02-1234-5678", "services": ["주차 가능", "자전거 정비", "온라인 주문 픽업"]};
    } else if (storeName == "데카트론 코엑스점") {
      responseData = {"found": true, "storeName": "데카트론 코엑스점", "address": "서울특별시 강남구 영동대로 513 (삼성동, 코엑스몰 B1)",
        "operatingHours": "매일 10:30 - 22:00", "phoneNumber": "02-2345-6789", "services": ["주차 가능(코엑스몰)", "스포츠 체험존", "의류 커스텀"]};
    } else if (storeName == "데카트론 서초점") {
      responseData = {"found": true, "storeName": "데카트론 서초점", "address": "서울특별시 서초구 서초대로 77길 54 (서초동, W타워)",
        "operatingHours": "매일 10:00 - 21:30", "phoneNumber": "02-3456-7890", "services": ["주차 가능", "클라이밍 체험"]};
    } else if (storeName == "데카트론 하남점") {
      responseData = {"found": true, "storeName": "데카트론 하남점", "address": "경기도 하남시 미사대로 750 (스타필드 하남)",
        "operatingHours": "매일 10:00 - 22:00", "phoneNumber": "031-4567-8901", "services": ["대형 주차장", "키즈 스포츠존"]};
    } else if (storeName == "데카트론 송도점") {
      responseData = {"found": true, "storeName": "데카트론 송도점", "address": "인천광역시 연수구 송도국제대로 123 (송도 트리플스트리트)",
        "operatingHours": "매일 10:30 - 22:00", "phoneNumber": "032-5678-9012", "services": ["주차 가능", "러닝 트랙"]};
    } else if (storeName == "데카트론 청라점") {
      responseData = {"found": true, "storeName": "데카트론 청라점", "address": "인천광역시 서구 청라커낼로 252 (청라 지젤엠)",
        "operatingHours": "매일 10:00 - 21:00", "phoneNumber": "032-6789-0123", "services": ["주차 가능", "농구 코트", "풋살장"]};
    } else if (storeName == "데카트론 인천논현점") {
      responseData = {"found": true, "storeName": "데카트론 인천논현점", "address": "인천광역시 남동구 논고개로 87 (인천논현역)",
        "operatingHours": "매일 10:00 - 21:30", "phoneNumber": "032-7890-1234", "services": ["주차 가능", "자전거 시승"]};
    } else if (storeName == "데카트론 고양점") {
      responseData = {"found": true, "storeName": "데카트론 고양점", "address": "경기도 고양시 덕양구 고양대로 1955 (스타필드 고양)",
        "operatingHours": "매일 10:00 - 22:00", "phoneNumber": "031-8901-2345", "services": ["대형 주차장", "스포츠 클래스"]};
    } else if (storeName == "데카트론 월드컵점") {
      responseData = {"found": true, "storeName": "데카트론 월드컵점", "address": "서울특별시 마포구 월드컵로 240 (서울월드컵경기장)",
        "operatingHours": "매일 10:00 - 21:00", "phoneNumber": "02-9012-3456", "services": ["주차 가능", "축구 용품 전문"]};
    }
    else {
      responseData = {"found": false, "message": """'$storeName' 매장 정보를 찾을 수 없습니다."""};
    }
    return GetStoreInfoResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 6. getUserPurchaseHistory ---
  Future<GetUserPurchaseHistoryResponse> getUserPurchaseHistory({required String userId}) async {
    _log.info("[MockAPI] getUserPurchaseHistory called for userId: $userId");
    Map<String, dynamic> responseData;
    if (userId == "daily_active_user") {
      responseData = { "found": true, "purchaseHistory": [
        { "orderId": "ORD20250315S001", "purchaseDate": "2025-03-15", "productName": "DOMYOS 여성용 코튼 스트레치 레깅스",
          "size": "M", "color": "블랙", "quantity": 1, "pricePaid": 19900.0, "storeName": "데카트론 고양점" },
        { "orderId": "ORD20250120S002", "purchaseDate": "2025-01-20", "productName": "KIPRUN 여성용 웜 러닝 상의",
          "size": "S", "color": "핑크", "quantity": 1, "pricePaid": 32000.0, "storeName": "온라인 스토어" },
        { "orderId": "ORD20241105S003", "purchaseDate": "2024-11-05", "productName": "ARTENGO 여성용 테니스 스커트",
          "size": "M", "color": "화이트", "quantity": 1, "pricePaid": 25000.0, "storeName": "데카트론 송도점" }
      ]};
    } else {
      responseData = {"found": false, "message": """사용자($userId)의 구매 내역을 찾을 수 없습니다."""};
    }
    return GetUserPurchaseHistoryResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 7. getProductReviews ---
  Future<GetProductReviewsResponse> getProductReviews({required String productName}) async {
    _log.info("[MockAPI] getProductReviews called for productName: '$productName'");
    Map<String, dynamic> responseData;
    if (productName == "KALENJI RUN SUPPORT") {
      responseData = { "found": true, "productName": productName, "averageRating": 4.3, "totalReviews": 120,
        "summaryText": """입문용으로 부담 없고 발목을 잘 잡아줘서 만족한다'는 평이 많네요. 평균 별점은 5점 만점에 4.3점입니다.""",
        "reviews": [
          {"reviewerName": "달리기초보러너", "rating": 5.0, "reviewDate": "2025-04-10", "comment": "정말 편하고 발목을 잘 잡아줘요! 가격도 착해서 데카트론 첫 구매인데 대만족입니다!"},
          {"reviewerName": "주말조깅족", "rating": 4.0, "reviewDate": "2025-03-28", "comment": "가성비 좋아요. 매일 신기에는 쿠션이 살짝 아쉽지만, 주 1~2회 가볍게 뛰기엔 충분합니다."}
        ]};
    } else if (productName == "DOMYOS 여성용 심리스 레깅스") {
      responseData = { "found": true, "productName": productName, "averageRating": 4.7, "totalReviews": 85,
        "summaryText": """몸에 착 감기는 느낌이 좋다', '운동할 때 정말 편하다'는 의견이 많습니다. 평균 별점은 4.7점입니다.""",
        "reviews": [
          {"reviewerName": "요기니생활", "rating": 5.0, "reviewDate": "2025-05-01", "comment": "이거 진짜 물건이에요! Y존 부각도 없고 너무 편해서 색깔별로 쟁였어요."},
          {"reviewerName": "필라테스강사", "rating": 4.5, "reviewDate": "2025-04-22", "comment": "수업할 때 입는데 활동성이 정말 좋아요. 땀 흡수도 잘 되는 편입니다."}
        ]};
    } else {
      responseData = {"found": false, "message": """'$productName' 제품의 리뷰 정보를 찾을 수 없습니다."""};
    }
    return GetProductReviewsResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 8. generateOrderQRCode ---
  Future<GenerateOrderQRCodeResponse> generateOrderQRCode({
    required String userId, required String productName, required int quantity,
    required String size, required String color, required String storeName, String? couponId
  }) async {
    _log.info("[MockAPI] generateOrderQRCode for $userId, P:$productName, Q:$quantity, S:$size, C:$color, Store:$storeName, Coupon:$couponId");
    Map<String, dynamic> responseData;
    String orderId = "DECA-MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    double basePrice = 0;
    if (productName == "KALENJI RUN SUPPORT") {basePrice = 65000.0;}
    else if (productName == "QUECHUA AIR SECONDS 4.2 FRESH&BLACK") {basePrice = 459000.0;}
    else if (productName == "가족나들이세트") {basePrice = 65900.0;}

    double finalAmount = basePrice * quantity;
    String discountInfo = "";

    if (couponId == "NEW_MEMBER_10P" && userId == "newrunner_01") {
      finalAmount *= 0.9;
      discountInfo = "신규10% 적용";
    } else if (couponId == "FAMILY5000" && userId == "family_shopper") {
      if (finalAmount >= 50000) {
        finalAmount -= 5000;
        discountInfo = "가족5천원 적용";
      } else {
        discountInfo = "5만원 미만 쿠폰미적용";
      }
    }
    String qrData = "DECA_ORDER_MOCK|$orderId|$userId|$productName|QTY:$quantity|SZ:$size|CLR:$color|STORE:$storeName|AMT:${finalAmount.toInt()}|COUPON:${couponId ?? 'NONE'}|${DateTime.now().toIso8601String()}";

    if (basePrice > 0) {
      responseData = { "success": true, "qrCodeData": qrData, "orderId": orderId, "finalAmount": finalAmount, "message": "$discountInfo 결제 QR 생성 완료." };
    } else {
      responseData = {"success": false, "message": """주문($productName)에 대한 QR 코드 생성에 실패했습니다."""};
    }
    return GenerateOrderQRCodeResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 9. getConversationHistory ---
  Future<GetConversationHistoryResponse> getConversationHistory({
    required String userId, required int currentTurnCount,
    required int summaryInterval, required int recentKTurns
  }) async {
    _log.info("[MockAPI] getConversationHistory for $userId, turn:$currentTurnCount, interval:$summaryInterval, k:$recentKTurns");
    Map<String, dynamic> responseData;

    if (userId == "camping_master") {
      responseData = {
        "found": true,
        "summary": """고객(박선우님, 캠핑 숙련자)은 과거에 설치가 쉽고 방수/차광 기능이 우수한 4인용 텐트를 문의했었음. 구체적으로 'QUECHUA AIR SECONDS 4.2 FRESH&BLACK' 모델에 대한 긍정적 대화가 오갔음.""",
        "recent_turns": [
          {"role": "user", "content": "안녕하세요, 지난 방문 때 4인용 에어텐트 문의드렸었는데요."},
          {"role": "assistant", "content": "네, 박선우 고객님 반갑습니다! 어떤 모델을 보고 가셨었는지 기억나시나요? 아니면 찾으시는 특징을 다시 말씀해주시겠어요?"},
          {"role": "user", "content": "그때 FRESH&BLACK 기능 있는 거 말씀하셨던 것 같아요. 공기 넣는 거요."},
        ]
      };
    } else {
      responseData = {"found": true, "summary": null, "recent_turns": [], "message": """사용자($userId)의 이전 대화 기록이 없습니다."""};
    }
    return GetConversationHistoryResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 10. findNearbyStores ---
  Future<FindNearbyStoresResponse> findNearbyStores(
      {required String currentLocation, int? maxResults = 3}) async {
    _log.info("[MockAPI] findNearbyStores for '$currentLocation', maxResults: $maxResults");
    Map<String, dynamic> responseData;
    List<Map<String,String>> allStores = [
      {"name": "데카트론 강남점", "address": "서울특별시 강남구 테헤란로 152", "approximateDistance": "약 1.5km", "operatingHours": "10:00 - 22:00"},
      {"name": "데카트론 코엑스점", "address": "서울특별시 강남구 영동대로 513", "approximateDistance": "약 3km", "operatingHours": "10:30 - 22:00"},
      {"name": "데카트론 서초점", "address": "서울특별시 서초구 서초대로 77길 54", "approximateDistance": "약 2.5km", "operatingHours": "10:00 - 21:30"},
      {"name": "데카트론 송도점", "address": "인천광역시 연수구 송도국제대로 123", "approximateDistance": "약 1km (송도 내)", "operatingHours": "10:30 - 22:00"},
      {"name": "데카트론 청라점", "address": "인천광역시 서구 청라커낼로 252", "approximateDistance": "약 8km (연수구에서)", "operatingHours": "10:00 - 21:00"},
      {"name": "데카트론 인천논현점", "address": "인천광역시 남동구 논고개로 87", "approximateDistance": "약 5km (연수구에서)", "operatingHours": "10:00 - 21:30"},
    ];

    List<Map<String,String>> foundStores = [];
    if (currentLocation.contains("강남")) {
      foundStores = allStores.where((s) => s["address"]!.contains("강남") || s["address"]!.contains("서초")).toList();
    } else if (currentLocation.contains("연수구") || currentLocation.contains("송도")) {
      foundStores = allStores.where((s) => s["address"]!.contains("인천")).toList();
    }

    if (foundStores.isNotEmpty) {
      if (foundStores.length > (maxResults ?? 3)) {
        foundStores = foundStores.sublist(0, maxResults);
      }
      responseData = {"found": true, "stores": foundStores};
    } else {
      responseData = {"found": false, "message": """'$currentLocation' 근처 매장 정보를 찾을 수 없습니다."""};
    }
    return FindNearbyStoresResponse.fromJson(await _delayedResponse(responseData));
  }

  // --- 11. recommendProductsByFeatures ---
  Future<RecommendProductsByFeaturesResponse> recommendProductsByFeatures(
      {required List<String> features, String? category, int? maxResults = 3}) async {
    _log.info("[MockAPI] recommendProductsByFeatures for $features, category: $category, max: $maxResults");
    Map<String, dynamic> responseData;
    List<Map<String,dynamic>> allProducts = [
      { "productName": "KIPRUN KS500", "brandName": "KIPRUN", "shortDescription": "안정적인 지지력과 뛰어난 쿠셔닝이 장점입니다.", "price": 89000.0, "imageUrl": "https://contents.mediadecathlon.com/p2006099/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/kiprun-ks500-men-s-running-shoes-black-grey.jpg?format=auto", "tags": ["러닝화", "지지력", "쿠셔닝", "중급자"], "category": "러닝화"},
      { "productName": "KALENJI RUN SUPPORT", "brandName": "KALENJI", "shortDescription": "발목 지지 기능이 강화되었고, 입문용으로 적합합니다.", "price": 65000.0, "imageUrl": "https://contents.mediadecathlon.com/p1854831/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/run-support-men-s-running-shoes-blue-yellow.jpg?format=auto", "tags": ["러닝화", "발목 지지", "쿠셔닝", "가성비", "입문자"], "category": "러닝화"},
      { "productName": "KIPRUN KD500", "brandName": "KIPRUN", "shortDescription": "경량성과 쿠셔닝의 조화가 좋습니다.", "price": 99000.0, "imageUrl": "https://contents.mediadecathlon.com/p1854831/k\$7e8d8f4a5c6d7e8f9a0b1c2d3e4f5g6h/sqr/run-support-men-s-running-shoes-blue-yellow.jpg?format=auto", "tags": ["러닝화", "경량성", "쿠셔닝", "스피드"], "category": "러닝화"},
      { "productName": "QUECHUA 컴팩트 폴딩 캠핑 의자", "brandName": "QUECHUA", "shortDescription": "가볍고 작게 접혀 휴대와 보관이 용이합니다.", "price": 18000.0, "imageUrl": "https://contents.mediadecathlon.com/p2070004/k\$8f7e3d0f0d0e5c1e0b8f8f8f8f8f8f8f/sqrsize-300x300/folding-low-camping-chair-mh100.jpg", "tags": ["캠핑의자", "휴대용", "접이식", "경량"], "category": "캠핑의자"},
      { "productName": "KIPSTA 소프트 축구공 4호", "brandName": "KIPSTA", "shortDescription": "안전한 부드러운 소재로 아이들용으로 좋습니다.", "price": 12000.0, "imageUrl": "https://contents.mediadecathlon.com/p1611750/k\$e8b1c6c721676367f6b0d0d9e4e5e6e7/sqrsize-300x300/mini-football-sunny-300-size-1-yellow.jpg", "tags": ["축구공", "소프트", "아이들용", "4호"], "category": "축구공"},
      { "productName": "IWIKIDO 컴팩트 비치 쉘터", "brandName": "IWIKIDO", "shortDescription": "자외선 차단, 간편 설치 가능한 소형 그늘막입니다.", "price": 29900.0, "imageUrl": "https://contents.mediadecathlon.com/p1936229/k\$b1f3ac7db4248b553a5355811d079d12/sqrsize-300x300/beach-shelter-iwiko-180-1-adult-2-children-anti-uv-orange-blue.jpg", "tags": ["그늘막", "비치용품", "자외선차단", "간편설치", "소형"], "category": "캠핑용품"}
    ];

    List<Map<String,dynamic>> recommendedProducts = [];
    for (var product in allProducts) {
      bool categoryMatch = category == null || category.isEmpty || product['category'] == category;
      if (!categoryMatch) {
        continue;
      }

      List<String> matchedFeaturesForProduct = [];
      for (String feature in features) {
        if ((product['tags'] as List).any((tag) => (tag as String).toLowerCase().contains(feature.toLowerCase())) ||
            (product['shortDescription'] as String).toLowerCase().contains(feature.toLowerCase()) ||
            (product['productName'] as String).toLowerCase().contains(feature.toLowerCase()) ) {
          matchedFeaturesForProduct.add(feature);
        }
      }
      if (matchedFeaturesForProduct.isNotEmpty) {
        var productCopy = Map<String,dynamic>.from(product);
        productCopy.remove('tags');
        productCopy['matchedFeatures'] = matchedFeaturesForProduct;
        recommendedProducts.add(productCopy);
      }
    }

    if (recommendedProducts.length > (maxResults ?? 3)) {
      recommendedProducts = recommendedProducts.sublist(0, maxResults);
    }

    if (recommendedProducts.isNotEmpty) {
      responseData = {"found": true, "products": recommendedProducts};
    } else {
      responseData = {"found": false, "message": """요청하신 특징에 부합하는 제품을 찾을 수 없습니다."""};
    }
    return RecommendProductsByFeaturesResponse.fromJson(await _delayedResponse(responseData));
  }
}