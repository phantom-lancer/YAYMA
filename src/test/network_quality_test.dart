import 'package:flutter_test/flutter_test.dart';
import 'package:yayma/src/features/core/services/network_quality.dart';
import 'package:yayma/src/rust/api/models.dart';

void main() {
  group('NetworkKind.fromChannel', () {
    test('maps every transport the platform channel can report', () {
      expect(NetworkKind.fromChannel('wifi'), NetworkKind.wifi);
      expect(NetworkKind.fromChannel('mobile'), NetworkKind.mobile);
      expect(NetworkKind.fromChannel('ethernet'), NetworkKind.ethernet);
      expect(NetworkKind.fromChannel('vpn'), NetworkKind.vpn);
      expect(NetworkKind.fromChannel('other'), NetworkKind.other);
      expect(NetworkKind.fromChannel('none'), NetworkKind.none);
    });

    test('treats an unknown or missing value as undetermined', () {
      expect(NetworkKind.fromChannel('carrier-pigeon'), NetworkKind.unknown);
      expect(NetworkKind.fromChannel(null), NetworkKind.unknown);
    });
  });

  group('quality profiles', () {
    test('only metered and unmetered transports pick a profile', () {
      expect(NetworkKind.wifi.hasQualityProfile, isTrue);
      expect(NetworkKind.ethernet.hasQualityProfile, isTrue);
      expect(NetworkKind.mobile.hasQualityProfile, isTrue);
      // An undetermined transport must never silently switch the stream.
      expect(NetworkKind.unknown.hasQualityProfile, isFalse);
      expect(NetworkKind.vpn.hasQualityProfile, isFalse);
      expect(NetworkKind.none.hasQualityProfile, isFalse);
    });

    test('labels describe the three real Yandex stream qualities', () {
      expect(AudioQuality.low.title, 'Экономное');
      expect(AudioQuality.normal.title, 'Стандартное');
      expect(AudioQuality.high.title, 'Высокое');
      expect(AudioQuality.high.detail, contains('lossless'));
    });
  });
}
