@Tags(['demo'])
library;

// Renders the example app frame by frame into build/demo_frames/ and writes
// the screenshots to doc/. Run through tool/make_demo.sh.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final boundaryKey = GlobalKey();
  var frame = 0;

  Future<void> shot(WidgetTester t, String path) async {
    await t.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> record(WidgetTester t, Duration d) async {
    const step = Duration(milliseconds: 66);
    for (var el = Duration.zero; el < d; el += step) {
      await t.pump(step);
      await shot(
          t, 'build/demo_frames/f${(frame++).toString().padLeft(4, '0')}.png');
    }
  }

  testWidgets('record demo', (t) async {
    await _loadFont('Roboto', '$fonts/Roboto-Regular.ttf');
    await _loadFont('Roboto', '$fonts/Roboto-Medium.ttf');
    await _loadFont('MaterialIcons', '$fonts/MaterialIcons-Regular.otf');
    Directory('build/demo_frames').createSync(recursive: true);
    Directory('doc').createSync(recursive: true);

    await t.binding.setSurfaceSize(const Size(400, 640));
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await t.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: const ExampleApp()));
    await t.pumpAndSettle();
    await shot(t, 'doc/screenshot_light.png');

    Future<void> tapKey(String k) async {
      await t.tap(find.byKey(ValueKey(k)));
    }

    await record(t, const Duration(milliseconds: 500));
    await tapKey('shuffle');
    await record(t, const Duration(milliseconds: 1300));
    await tapKey('add');
    await record(t, const Duration(milliseconds: 900));
    await tapKey('add');
    await record(t, const Duration(milliseconds: 900));
    await t.tap(find.widgetWithText(ChoiceChip, 'Work'));
    await record(t, const Duration(milliseconds: 1400));
    await t.tap(find.widgetWithText(ChoiceChip, 'All'));
    await record(t, const Duration(milliseconds: 1400));
    await tapKey('remove');
    await record(t, const Duration(milliseconds: 800));
    await tapKey('sort');
    await record(t, const Duration(milliseconds: 1500));
    await tapKey('shuffle');
    await record(t, const Duration(milliseconds: 1300));

    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await t.pumpAndSettle();
    await shot(t, 'doc/screenshot_dark.png');
    t.platformDispatcher.clearAllTestValues();
    await t.binding.setSurfaceSize(null);
  });
}
