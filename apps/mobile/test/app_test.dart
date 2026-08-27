import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('앱 껍데기가 뜬다', (tester) async {
    await tester.pumpWidget(const DropApp());
    expect(find.text('DROP — Flutter 재구축 (BRU-152)'), findsOneWidget);
  });
}
