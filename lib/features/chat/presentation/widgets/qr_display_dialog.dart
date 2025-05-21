// 파일 경로: lib/features/chat/presentation/widgets/qr_display_dialog.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

void showQrDialog(BuildContext context, String qrData, String title) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: SizedBox(
          width: 250, // QR 코드 영역 크기 조절
          height: 250,
          child: Center(
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false, // QR 코드 모듈 사이의 간격
              // embeddedImage: AssetImage('assets/images/decathlon_logo_small.png'), // 중앙 로고 (선택)
              // embeddedImageStyle: QrEmbeddedImageStyle(size: Size(40, 40)),
              errorStateBuilder: (cxt, err) {
                return const Center(
                  child: Text(
                    "QR 코드 생성 오류.\n잠시 후 다시 시도해주세요.",
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('닫기'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
    },
  );
}