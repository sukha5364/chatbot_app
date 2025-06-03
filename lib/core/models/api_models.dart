// 파일 경로: lib/core/models/api_models.dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_models.freezed.dart';
part 'api_models.g.dart';

// --- API 응답 공통 구조 ---
// OrNotFound 접미사를 갖는 API들은 이와 유사한 구조를 따를 수 있으나,
// 각 API의 특성에 맞게 found 필드 외 추가 필드를 가질 수 있으므로 개별 모델로 정의합니다.

// --- 1. getUserCoupons ---
// API 명세: UserCouponInfo
@freezed
class GetUserCouponsResponse with _$GetUserCouponsResponse {
  const factory GetUserCouponsResponse({
    @Default(false) bool found, // 개발 명세상 OrNotFound가 아니지만, 일관성을 위해 추가
    @JsonKey(includeIfNull: false) String? message, // found가 false일 경우 메시지
    @Default([]) List<Coupon> coupons,
  }) = _GetUserCouponsResponse;

  factory GetUserCouponsResponse.fromJson(Map<String, dynamic> json) =>
      _$GetUserCouponsResponseFromJson(json);
}

@freezed
class Coupon with _$Coupon {
  const factory Coupon({
    required String couponId,
    required String couponName,
    @JsonKey(includeIfNull: false) String? description,
    @JsonKey(includeIfNull: false) String? discountType, // "percentage", "fixed_amount"
    @JsonKey(includeIfNull: false) double? discountValue,
    @JsonKey(includeIfNull: false) String? expiryDate, // "YYYY-MM-DD"
    @JsonKey(includeIfNull: false) String? conditions,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);
}

// --- 2. getProductInfo ---
// API 명세: ProductDetailsOrNotFound
@freezed
class GetProductInfoResponse with _$GetProductInfoResponse {
  const factory GetProductInfoResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message, // not found 시
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) String? brandName,
    @JsonKey(includeIfNull: false) String? description,
    @JsonKey(includeIfNull: false) double? price,
    @Default([]) List<String> availableSizes,
    @Default([]) List<String> availableColors,
    @JsonKey(includeIfNull: false) String? imageUrl,
    // 기타 필요한 제품 상세 정보 필드
  }) = _GetProductInfoResponse;

  factory GetProductInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductInfoResponseFromJson(json);
}

// --- 3. getStoreStock ---
// API 명세: AllStockInfoOrProductNotFound
@freezed
class GetStoreStockResponse with _$GetStoreStockResponse {
  const factory GetStoreStockResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message, // not found 시
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) String? storeName,
    @Default([]) List<ProductVariantStock> variants,
    @JsonKey(includeIfNull: false) String? lastChecked, // ISO 8601 datetime string
  }) = _GetStoreStockResponse;

  factory GetStoreStockResponse.fromJson(Map<String, dynamic> json) =>
      _$GetStoreStockResponseFromJson(json);
}

@freezed
class ProductVariantStock with _$ProductVariantStock {
  const factory ProductVariantStock({
    @JsonKey(includeIfNull: false) String? size,
    @JsonKey(includeIfNull: false) String? color,
    required String stockStatus, // "in_stock", "low_stock", "out_of_stock"
    @JsonKey(includeIfNull: false) int? quantity,
  }) = _ProductVariantStock;

  factory ProductVariantStock.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantStockFromJson(json);
}

// --- 4. getProductLocationInStore ---
// API 명세: ProductLocationOrNotFound
@freezed
class GetProductLocationInStoreResponse with _$GetProductLocationInStoreResponse {
  const factory GetProductLocationInStoreResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? zone, // 예: "D구역"
    @JsonKey(includeIfNull: false) String? aisle, // 예: "캠핑용품 코너"
    @JsonKey(includeIfNull: false) String? details, // 예: "대형 텐트 전시 공간 안쪽"
  }) = _GetProductLocationInStoreResponse;

  factory GetProductLocationInStoreResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductLocationInStoreResponseFromJson(json);
}

// --- 5. getStoreInfo ---
// API 명세: StoreDetailsOrNotFound
@freezed
class GetStoreInfoResponse with _$GetStoreInfoResponse {
  const factory GetStoreInfoResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? storeName,
    @JsonKey(includeIfNull: false) String? address,
    @JsonKey(includeIfNull: false) String? operatingHours,
    @JsonKey(includeIfNull: false) String? phoneNumber,
    @Default([]) List<String> services,
  }) = _GetStoreInfoResponse;

  factory GetStoreInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GetStoreInfoResponseFromJson(json);
}

// --- 6. getUserPurchaseHistory ---
// API 명세: UserPurchaseHistoryInfo
@freezed
class GetUserPurchaseHistoryResponse with _$GetUserPurchaseHistoryResponse {
  const factory GetUserPurchaseHistoryResponse({
    @Default(false) bool found, // 명세에는 OrNotFound가 없으나 일관성/확장성 위해 추가
    @JsonKey(includeIfNull: false) String? message,
    @Default([]) List<PurchaseRecord> purchaseHistory,
  }) = _GetUserPurchaseHistoryResponse;

  factory GetUserPurchaseHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$GetUserPurchaseHistoryResponseFromJson(json);
}

@freezed
class PurchaseRecord with _$PurchaseRecord {
  const factory PurchaseRecord({
    required String orderId,
    required String purchaseDate, // "YYYY-MM-DD"
    required String productName,
    @JsonKey(includeIfNull: false) String? size,
    @JsonKey(includeIfNull: false) String? color,
    required int quantity,
    required double pricePaid,
    @JsonKey(includeIfNull: false) String? storeName,
  }) = _PurchaseRecord;

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _$PurchaseRecordFromJson(json);
}

// --- 7. getProductReviews ---
// API 명세: ProductReviewSummaryOrNotFound
@freezed
class GetProductReviewsResponse with _$GetProductReviewsResponse {
  const factory GetProductReviewsResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) double? averageRating, // 5점 만점
    @JsonKey(includeIfNull: false) int? totalReviews,
    @JsonKey(includeIfNull: false) String? summaryText, // 리뷰 요약
    @Default([]) List<ReviewDetail> reviews, // 일부 최신/주요 리뷰
  }) = _GetProductReviewsResponse;

  factory GetProductReviewsResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductReviewsResponseFromJson(json);
}

@freezed
class ReviewDetail with _$ReviewDetail {
  const factory ReviewDetail({
    @JsonKey(includeIfNull: false) String? reviewerName,
    required double rating,
    @JsonKey(includeIfNull: false) String? reviewDate, // "YYYY-MM-DD"
    @JsonKey(includeIfNull: false) String? comment,
  }) = _ReviewDetail;

  factory ReviewDetail.fromJson(Map<String, dynamic> json) =>
      _$ReviewDetailFromJson(json);
}


// --- 8. generateOrderQRCode ---
// API 명세: OrderQRCodeResult
@freezed
class GenerateOrderQRCodeResponse with _$GenerateOrderQRCodeResponse {
  const factory GenerateOrderQRCodeResponse({
    required bool success, // 명세와 일치 (found 대신 success)
    @JsonKey(includeIfNull: false) String? message, // if failed
    @JsonKey(includeIfNull: false) String? qrCodeData, // QR 생성용 데이터 문자열
    @JsonKey(includeIfNull: false) String? orderId,
    @JsonKey(includeIfNull: false) double? finalAmount,
  }) = _GenerateOrderQRCodeResponse;

  factory GenerateOrderQRCodeResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateOrderQRCodeResponseFromJson(json);
}

// --- 9. getConversationHistory ---
// API 명세: ConversationHistoryChunk
@freezed
class GetConversationHistoryResponse with _$GetConversationHistoryResponse {
  const factory GetConversationHistoryResponse({
    // 이 API는 항상 found: true 를 가정할 수도 있지만, 유연성을 위해 포함
    @Default(true) bool found, // 일반적으로 userId가 있으면 찾을 수 있다고 가정
    @JsonKey(includeIfNull: false) String? message, // 예외적인 경우
    @JsonKey(includeIfNull: false) String? summary,
    @JsonKey(name: 'recent_turns') @Default([]) List<Map<String, String>> recentTurns, // 명세서 형태: [{"role": "user", "content": "..."}]
  }) = _GetConversationHistoryResponse;

  factory GetConversationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$GetConversationHistoryResponseFromJson(json);
}

// --- 10. findNearbyStores ---
// API 명세: NearbyStoreListOrNotFound
@freezed
class FindNearbyStoresResponse with _$FindNearbyStoresResponse {
  const factory FindNearbyStoresResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @Default([]) List<NearbyStore> stores,
  }) = _FindNearbyStoresResponse;

  factory FindNearbyStoresResponse.fromJson(Map<String, dynamic> json) =>
      _$FindNearbyStoresResponseFromJson(json);
}

@freezed
class NearbyStore with _$NearbyStore {
  const factory NearbyStore({
    required String name,
    required String address,
    @JsonKey(includeIfNull: false) String? approximateDistance, // 예: "약 2km"
    @JsonKey(includeIfNull: false) String? operatingHours,
  }) = _NearbyStore;

  factory NearbyStore.fromJson(Map<String, dynamic> json) =>
      _$NearbyStoreFromJson(json);
}

// --- 11. recommendProductsByFeatures ---
// API 명세: RecommendedProductListOrNotFound
@freezed
class RecommendProductsByFeaturesResponse with _$RecommendProductsByFeaturesResponse {
  const factory RecommendProductsByFeaturesResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @Default([]) List<RecommendedProduct> products,
  }) = _RecommendProductsByFeaturesResponse;

  factory RecommendProductsByFeaturesResponse.fromJson(Map<String, dynamic> json) =>
      _$RecommendProductsByFeaturesResponseFromJson(json);
}

@freezed
class RecommendedProduct with _$RecommendedProduct {
  const factory RecommendedProduct({
    required String productName,
    @JsonKey(includeIfNull: false) String? brandName,
    @JsonKey(includeIfNull: false) String? shortDescription,
    @JsonKey(includeIfNull: false) double? price,
    @JsonKey(includeIfNull: false) String? imageUrl,
    @Default([]) List<String> matchedFeatures,
  }) = _RecommendedProduct;

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) =>
      _$RecommendedProductFromJson(json);
}

// 12. reportUnresolvedQuery
// API 명세: ReportUnresolvedQuery
class ReportUnresolvedQueryResponse {
  final bool success;
  final String message;
  final String reportId;

  ReportUnresolvedQueryResponse({
    required this.success,
    required this.message,
    required this.reportId,
  });

  factory ReportUnresolvedQueryResponse.fromJson(Map<String, dynamic> json) {
    return ReportUnresolvedQueryResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      reportId: json['reportId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'reportId': reportId,
    };
  }
}