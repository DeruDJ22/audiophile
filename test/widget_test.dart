import 'package:flutter_test/flutter_test.dart';
import 'package:kuroakai_audio/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const KuroakaiAudioApp(initialArgs: []));
    expect(find.byType(KuroakaiAudioApp), findsOneWidget);
  });
}
