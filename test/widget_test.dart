import 'package:flutter_test/flutter_test.dart';

import 'package:study_progress/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyProgressApp());

    expect(find.text('学习进度记录本'), findsOneWidget);
    expect(find.text('新增课程'), findsOneWidget);
  });
}
