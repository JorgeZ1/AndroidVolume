import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:floating_volume/src/app_language.dart';
import 'package:floating_volume/src/services/report_service.dart';
import 'package:floating_volume/src/screens/report_screen.dart';

final sample = ReportImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=',
  ),
  'image/png',
);
void main() {
  setUp(() => LanguageSettings.selection.value = AppLanguage.english);
  test('report IDs are unique valid version 4 UUIDs', () {
    final ids = List.generate(100, (_) => ReportService.newId());
    expect(ids.toSet(), hasLength(100));
    for (final id in ids) {
      expect(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(id),
        isTrue,
      );
    }
  });
  test('two images serialized and returned reference verified', () async {
    final id = ReportService.newId();
    final service = ReportService(
      client: MockClient((request) async {
        final json = jsonDecode(request.body);
        expect(json['images'], hasLength(2));
        expect(json['description'], 'A reproducible volume issue');
        expect(request.url.toString(), ReportService.endpoint);
        return http.Response(jsonEncode({'id': id}), 201);
      }),
    );
    expect(
      await service.submit(
        id: id,
        category: ReportCategory.volume,
        description: ' A reproducible volume issue ',
        images: [sample, sample],
        diagnostics: {},
      ),
      id,
    );
    service.close();
  });
  test('three images rejected before any network call', () async {
    final service = ReportService(
      client: MockClient((_) async => throw StateError('must not send')),
    );
    await expectLater(
      service.submit(
        id: ReportService.newId(),
        category: ReportCategory.other,
        description: 'Test description',
        images: [sample, sample, sample],
        diagnostics: {},
      ),
      throwsA(isA<ReportException>()),
    );
    service.close();
  });
  test('rate limit is handled as a retryable error', () async {
    final service = ReportService(
      client: MockClient((_) async => http.Response('{}', 429)),
    );
    await expectLater(
      service.submit(
        id: ReportService.newId(),
        category: ReportCategory.other,
        description: 'Test description',
        images: [],
        diagnostics: {},
      ),
      throwsA(isA<ReportException>().having((e) => e.code, 'code', 'limit')),
    );
    service.close();
  });
  testWidgets('two previews, no third image, and removal restores picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReportScreen(pickImage: () async => sample)),
    );
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Add image'));
      await tester.tap(find.text('Add image'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Images (optional): 2/2'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Add image'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byTooltip('Remove image').first);
    await tester.tap(find.byTooltip('Remove image').first);
    await tester.pumpAndSettle();
    expect(find.text('Images (optional): 1/2'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Add image'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed send keeps the description available for retry', (
    tester,
  ) async {
    final service = ReportService(
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(service: service, pickImage: () async => null),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField),
      'A volume issue to investigate',
    );
    final scrollable =
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      200,
      scrollable: scrollable,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Send report'),
      150,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('Could not send.'),
      ),
      100,
      scrollable: scrollable,
    );
    expect(find.textContaining('Could not send.'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byType(TextFormField),
      -200,
      scrollable: scrollable,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'A volume issue to investigate',
    );
    service.close();
  });
  testWidgets('Spanish support UI fits a narrow screen', (tester) async {
    LanguageSettings.selection.value = AppLanguage.spanish;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ReportScreen(pickImage: () async => null)),
    );
    expect(find.text('Reportar un problema'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Enviar reporte'),
      200,
      scrollable:
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final keyboard in [0.0, 240.0]) {
    testWidgets('send footer stays above navigation and keyboard $keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding = FakeViewPadding(bottom: keyboard == 0 ? 48 : 0);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        MaterialApp(home: ReportScreen(pickImage: () async => null)),
      );
      final rect = tester.getRect(
        find.widgetWithText(FilledButton, 'Send report'),
      );
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(
        rect.bottom,
        lessThanOrEqualTo(640 - (keyboard == 0 ? 48 : keyboard) - 12),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('two images can be selected with one picker opening', (
    tester,
  ) async {
    var openings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          pickImages: (remaining) async {
            openings++;
            expect(remaining, 2);
            return [
              sample,
              sample,
              sample,
            ]; // Defensive cap even if platform ignores limit.
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Add image'));
    await tester.tap(find.text('Add image'));
    await tester.pumpAndSettle();
    expect(openings, 1);
    expect(find.text('Images (optional): 2/2'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });
  test('a report without any image can be submitted', () async {
    final id = ReportService.newId();
    final service = ReportService(
      client: MockClient((request) async {
        expect(jsonDecode(request.body)['images'], isEmpty);
        return http.Response(jsonEncode({'id': id}), 201);
      }),
    );
    expect(
      await service.submit(
        id: id,
        category: ReportCategory.other,
        description: 'A report without attachments',
        images: [],
        diagnostics: {},
      ),
      id,
    );
    service.close();
  });
  testWidgets('short description shows a clear warning without sending', (
    tester,
  ) async {
    final service = ReportService(
      client: MockClient((_) async => throw StateError('must not send')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(service: service, pickImages: (_) async => []),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'jnmlpkl');
    final scrollable =
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      200,
      scrollable: scrollable,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(
      find.text('Describe the problem using at least 10 characters.'),
      findsOneWidget,
    );
    expect(find.text('Please enter at least 10 characters.'), findsOneWidget);
    service.close();
  });
}
