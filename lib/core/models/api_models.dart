// 파일 경로: lib/core/models/api_models.dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_models.freezed.dart';
part 'api_models.g.dart';

// --- 1. getUserCoupons ---
@freezed
class GetUserCouponsResponse with _$GetUserCouponsResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
  const factory GetUserCouponsResponse({
    @Default(false) bool found,
    @JsonKey(includeIfNull: false) String? message,
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
    @JsonKey(includeIfNull: false) String? discountType,
    @JsonKey(includeIfNull: false) double? discountValue,
    @JsonKey(includeIfNull: false) String? expiryDate,
    @JsonKey(includeIfNull: false) String? conditions,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);
}

// --- 2. getProductInfo ---
@freezed
class GetProductInfoResponse with _$GetProductInfoResponse {
  const factory GetProductInfoResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) String? brandName,
    @JsonKey(includeIfNull: false) String? description,
    @JsonKey(includeIfNull: false) double? price,
    @Default([]) List<String> availableSizes,
    @Default([]) List<String> availableColors,
    @JsonKey(includeIfNull: false) String? imageUrl,
  }) = _GetProductInfoResponse;

  factory GetProductInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductInfoResponseFromJson(json);
}

// --- 3. getStoreStock ---
@freezed
class GetStoreStockResponse with _$GetStoreStockResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
  const factory GetStoreStockResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) String? storeName,
    @Default([]) List<ProductVariantStock> variants,
    @JsonKey(includeIfNull: false) String? lastChecked,
  }) = _GetStoreStockResponse;

  factory GetStoreStockResponse.fromJson(Map<String, dynamic> json) =>
      _$GetStoreStockResponseFromJson(json);
}

@freezed
class ProductVariantStock with _$ProductVariantStock {
  const factory ProductVariantStock({
    @JsonKey(includeIfNull: false) String? size,
    @JsonKey(includeIfNull: false) String? color,
    required String stockStatus,
    @JsonKey(includeIfNull: false) int? quantity,
  }) = _ProductVariantStock;

  factory ProductVariantStock.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantStockFromJson(json);
}

// --- 4. getProductLocationInStore ---
@freezed
class GetProductLocationInStoreResponse with _$GetProductLocationInStoreResponse {
  const factory GetProductLocationInStoreResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? zone,
    @JsonKey(includeIfNull: false) String? aisle,
    @JsonKey(includeIfNull: false) String? details,
  }) = _GetProductLocationInStoreResponse;

  factory GetProductLocationInStoreResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductLocationInStoreResponseFromJson(json);
}

// --- 5. getStoreInfo ---
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
@freezed
class GetUserPurchaseHistoryResponse with _$GetUserPurchaseHistoryResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
  const factory GetUserPurchaseHistoryResponse({
    @Default(false) bool found,
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
    required String purchaseDate,
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
@freezed
class GetProductReviewsResponse with _$GetProductReviewsResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
  const factory GetProductReviewsResponse({
    required bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? productName,
    @JsonKey(includeIfNull: false) double? averageRating,
    @JsonKey(includeIfNull: false) int? totalReviews,
    @JsonKey(includeIfNull: false) String? summaryText,
    @Default([]) List<ReviewDetail> reviews,
  }) = _GetProductReviewsResponse;

  factory GetProductReviewsResponse.fromJson(Map<String, dynamic> json) =>
      _$GetProductReviewsResponseFromJson(json);
}

@freezed
class ReviewDetail with _$ReviewDetail {
  const factory ReviewDetail({
    @JsonKey(includeIfNull: false) String? reviewerName,
    required double rating,
    @JsonKey(includeIfNull: false) String? reviewDate,
    @JsonKey(includeIfNull: false) String? comment,
  }) = _ReviewDetail;

  factory ReviewDetail.fromJson(Map<String, dynamic> json) =>
      _$ReviewDetailFromJson(json);
}


// --- 8. generateOrderQRCode ---
@freezed
class GenerateOrderQRCodeResponse with _$GenerateOrderQRCodeResponse {
  const factory GenerateOrderQRCodeResponse({
    required bool success,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? qrCodeData,
    @JsonKey(includeIfNull: false) String? orderId,
    @JsonKey(includeIfNull: false) double? finalAmount,
  }) = _GenerateOrderQRCodeResponse;

  factory GenerateOrderQRCodeResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateOrderQRCodeResponseFromJson(json);
}

// --- 9. getConversationHistory ---
@freezed
class GetConversationHistoryResponse with _$GetConversationHistoryResponse {
  const factory GetConversationHistoryResponse({
    @Default(true) bool found,
    @JsonKey(includeIfNull: false) String? message,
    @JsonKey(includeIfNull: false) String? summary,
    @JsonKey(name: 'recent_turns') @Default([]) List<Map<String, String>> recentTurns,
  }) = _GetConversationHistoryResponse;

  factory GetConversationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$GetConversationHistoryResponseFromJson(json);
}

// --- 10. findNearbyStores ---
@freezed
class FindNearbyStoresResponse with _$FindNearbyStoresResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
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
    @JsonKey(includeIfNull: false) String? approximateDistance,
    @JsonKey(includeIfNull: false) String? operatingHours,
  }) = _NearbyStore;

  factory NearbyStore.fromJson(Map<String, dynamic> json) =>
      _$NearbyStoreFromJson(json);
}

// --- 11. recommendProductsByFeatures ---
@freezed
class RecommendProductsByFeaturesResponse with _$RecommendProductsByFeaturesResponse {
  @JsonSerializable(explicitToJson: true) // MODIFIED: 위치 이동
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
@JsonSerializable() // This is a plain class, so the class-level annotation is correct. No changes needed.
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