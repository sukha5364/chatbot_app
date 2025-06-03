// lib/tool_layer/mock_api_tool_runners.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/tool_layer/tool_runner.dart';
import 'package:decathlon_demo_app/core/providers/core_providers.dart'; // mockApiServiceProvider
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart'; // currentUserProfileProvider
import 'package:decathlon_demo_app/core/config/app_config.dart'; // appConfigProvider (for default values if needed)

// Helper function to get current user ID or a default
String _getUserId(Ref ref, Map<String, dynamic> args) {
  return args['userId'] as String? ?? ref.read(currentUserProfileProvider)?.id ?? 'unknown_user_id';
}

// --- ToolRunner Implementations ---

class GetUserCouponsRunner implements ToolRunner {
  @override
  String get name => 'getUserCoupons';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final userId = _getUserId(ref, args); // userId 인자 우선 사용
    final response = await mockService.getUserCoupons(userId: userId);
    return response.toJson();
  }
}

class GetProductInfoRunner implements ToolRunner {
  @override
  String get name => 'getProductInfo';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final productName = args['productName'] as String;
    final brandName = args['brandName'] as String?;
    final response = await mockService.getProductInfo(productName: productName, brandName: brandName);
    return response.toJson();
  }
}

class GetStoreStockRunner implements ToolRunner {
  @override
  String get name => 'getStoreStock';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final productName = args['productName'] as String;
    final storeName = args['storeName'] as String;
    final size = args['size'] as String?;
    final color = args['color'] as String?;
    final response = await mockService.getStoreStock(
        productName: productName, storeName: storeName, size: size, color: color);
    return response.toJson();
  }
}

class GetProductLocationInStoreRunner implements ToolRunner {
  @override
  String get name => 'getProductLocationInStore';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final productName = args['productName'] as String?;
    final category = args['category'] as String?;
    final storeName = args['storeName'] as String;

    if (productName == null && category == null) {
      return {"found": false, "message": "Tool Error: productName 또는 category 중 하나는 필수입니다."};
    }
    final response = await mockService.getProductLocationInStore(
        productName: productName, category: category, storeName: storeName);
    return response.toJson();
  }
}

class GetStoreInfoRunner implements ToolRunner {
  @override
  String get name => 'getStoreInfo';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final storeName = args['storeName'] as String;
    final response = await mockService.getStoreInfo(storeName: storeName);
    return response.toJson();
  }
}

class GetUserPurchaseHistoryRunner implements ToolRunner {
  @override
  String get name => 'getUserPurchaseHistory';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final userId = _getUserId(ref, args);
    final response = await mockService.getUserPurchaseHistory(userId: userId);
    return response.toJson();
  }
}
// (나머지 Runner들은 다음 Chunk에서 계속)
class GetProductReviewsRunner implements ToolRunner {
  @override
  String get name => 'getProductReviews';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final productName = args['productName'] as String;
    final response = await mockService.getProductReviews(productName: productName);
    return response.toJson();
  }
}

class GenerateOrderQRCodeRunner implements ToolRunner {
  @override
  String get name => 'generateOrderQRCode';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final userId = _getUserId(ref, args);
    final productName = args['productName'] as String;
    final quantity = (args['quantity'] as num?)?.toInt() ?? 1;
    final size = args['size'] as String? ?? "N/A"; // 기본값 제공
    final color = args['color'] as String? ?? "N/A"; // 기본값 제공
    final storeName = args['storeName'] as String;
    final couponId = args['couponId'] as String?;

    final response = await mockService.generateOrderQRCode(
        userId: userId,
        productName: productName,
        quantity: quantity,
        size: size,
        color: color,
        storeName: storeName,
        couponId: couponId);
    return response.toJson();
  }
}

class GetConversationHistoryRunner implements ToolRunner {
  @override
  String get name => 'getConversationHistory';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final appConfig = ref.read(appConfigProvider).value; // AppConfig 접근

    final userId = _getUserId(ref, args);
    final currentTurnCount = (args['currentTurnCount'] as num?)?.toInt() ?? 0; // LLM이 제공

    // AppConfig에서 기본값을 가져오거나, LLM이 제공한 값을 사용
    final summaryInterval = (args['summaryInterval'] as num?)?.toInt() ?? appConfig?.summarizeEveryNTurns ?? 3;
    final recentKTurns = (args['recentKTurns'] as num?)?.toInt() ?? appConfig?.recentKTurns ?? 3;

    final response = await mockService.getConversationHistory(
        userId: userId,
        currentTurnCount: currentTurnCount,
        summaryInterval: summaryInterval,
        recentKTurns: recentKTurns);
    return response.toJson();
  }
}

class FindNearbyStoresRunner implements ToolRunner {
  @override
  String get name => 'findNearbyStores';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);
    final currentLocation = args['currentLocation'] as String;
    final maxResults = (args['maxResults'] as num?)?.toInt(); // 기본값은 MockService 내부에서 처리
    final response = await mockService.findNearbyStores(
        currentLocation: currentLocation, maxResults: maxResults);
    return response.toJson();
  }
}

class RecommendProductsByFeaturesRunner implements ToolRunner {
  @override
  String get name => 'recommendProductsByFeatures';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);

    final features = (args['features'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? <String>[]; // 빈 리스트로 기본값 처리

    if (features.isEmpty) {
      return {"found": false, "message": "Tool Error: features 목록은 필수입니다."};
    }

    final category = args['category'] as String?;
    final maxResults = (args['maxResults'] as num?)?.toInt();

    final response = await mockService.recommendProductsByFeatures(
        features: features, category: category, maxResults: maxResults);
    return response.toJson();
  }
}

class ReportUnresolvedQueryRunner implements ToolRunner {
  @override
  String get name => 'reportUnresolvedQuery';

  @override
  Future<Map<String, dynamic>> run(String argsJson, Ref ref) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final mockService = ref.read(mockApiServiceProvider);

    final userId = args['userId'] as String;
    final userQuestion = args['userQuestion'] as String;

    final response = await mockService.reportUnresolvedQuery(
      userId: userId,
      userQuestion: userQuestion,
    );
    // toJson()가 Map<String, dynamic> 형태로 반환됨
    return response.toJson();
  }
}

// 모든 ToolRunner 인스턴스를 생성하여 리스트로 반환하는 함수 (ToolRegistry에 등록하기 위함)
List<ToolRunner> getAllMockApiToolRunners() {
  return [
    GetUserCouponsRunner(),
    GetProductInfoRunner(),
    GetStoreStockRunner(),
    GetProductLocationInStoreRunner(),
    GetStoreInfoRunner(),
    GetUserPurchaseHistoryRunner(),
    GetProductReviewsRunner(),
    GenerateOrderQRCodeRunner(),
    GetConversationHistoryRunner(),
    FindNearbyStoresRunner(),
    RecommendProductsByFeaturesRunner(),
    ReportUnresolvedQueryRunner(),
  ];
}