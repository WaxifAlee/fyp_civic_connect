import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as platform;
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';
import 'package:fyp_civic_connect/features/reports/presentation/map_location_picker.dart';

// Keep the actual picker and GoogleMap configuration, replacing only the native
// platform surface. Widget tests do not contact Maps or require an API key.
class TestMapPlatform extends platform.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
      int creationId, PlatformViewCreatedCallback onPlatformViewCreated,
      {required platform.MapWidgetConfiguration widgetConfiguration,
      platform.MapConfiguration mapConfiguration =
          const platform.MapConfiguration(),
      platform.MapObjects mapObjects = const platform.MapObjects()}) {
    return const SizedBox.expand();
  }
}

void main() {
  late platform.GoogleMapsFlutterPlatform originalPlatform;

  setUp(() {
    AppSession.instance.leavePreview();
    originalPlatform = platform.GoogleMapsFlutterPlatform.instance;
    platform.GoogleMapsFlutterPlatform.instance = TestMapPlatform();
  });

  tearDown(() {
    platform.GoogleMapsFlutterPlatform.instance = originalPlatform;
    AppSession.instance.leavePreview();
  });

  Future<void> openPicker(WidgetTester tester,
      {LatLng? initial,
      bool preview = false,
      bool? mapsEnabled,
      ValueChanged<LatLng?>? onResult}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(
                  builder: (_) => mapsEnabled == null
                      ? MapLocationPicker(
                          initialLocation: initial, isPreview: preview)
                      : MapLocationPicker(
                          initialLocation: initial,
                          isPreview: preview,
                          mapsEnabled: mapsEnabled),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  GoogleMap map(WidgetTester tester) =>
      tester.widget<GoogleMap>(find.byType(GoogleMap));

  FilledButton confirm(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm location'));

  testWidgets('native map is enabled by default and waits for an explicit pin',
      (tester) async {
    await openPicker(tester);
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(map(tester).markers, isEmpty);
    expect(confirm(tester).onPressed, isNull);
    expect(map(tester).myLocationEnabled, isFalse);
    expect(
        map(tester)
            .gestureRecognizers
            .any((factory) => factory.constructor() is EagerGestureRecognizer),
        isTrue);
  });

  testWidgets('tap and drag confirm the exact final coordinates',
      (tester) async {
    LatLng? result;
    await openPicker(tester,
        mapsEnabled: true, onResult: (value) => result = value);
    const first = LatLng(33.550123456, 72.630987654);
    const moved = LatLng(33.552987654, 72.633123456);
    map(tester).onTap!(first);
    await tester.pump();
    var marker = map(tester).markers.single;
    expect(marker.position, first);
    expect(marker.draggable, isTrue);
    expect(marker.onDragEnd, isNotNull);
    marker.onDragStart!(first);
    await tester.pump();
    expect(confirm(tester).onPressed, isNull);
    marker.onDragEnd!(moved);
    await tester.pump();
    expect(map(tester).markers.single.position, moved);
    expect(confirm(tester).onPressed, isNotNull);
    // Confirmation remains reachable without scrolling through the map/form.
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(result, moved);
    expect(find.text('Open picker'), findsOneWidget);
  });

  testWidgets('an invalid drag cannot silently confirm the previous pin',
      (tester) async {
    await openPicker(tester,
        initial: const LatLng(33.55, 72.63), mapsEnabled: true);
    const outside = LatLng(33.68, 72.98);
    map(tester).markers.single.onDragEnd!(outside);
    await tester.pump();
    expect(map(tester).markers.single.position, outside);
    expect(find.text('Choose a location inside the Fateh Jang service area.'),
        findsOneWidget);
    expect(confirm(tester).onPressed, isNull);
    const corrected = LatLng(33.555, 72.635);
    map(tester).onTap!(corrected);
    await tester.pump();
    expect(map(tester).markers.single.position, corrected);
    expect(confirm(tester).onPressed, isNotNull);
  });

  testWidgets('manual editing and reopening the map preserve full precision',
      (tester) async {
    await openPicker(tester,
        initial: const LatLng(33.55, 72.63), mapsEnabled: true);
    await tester.ensureVisible(find.text('Use coordinates instead'));
    await tester.tap(find.text('Use coordinates instead'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '33.552987654');
    await tester.enterText(fields.at(1), '72.633123456');
    await tester.ensureVisible(find.text('Show map'));
    await tester.tap(find.text('Show map'));
    await tester.pumpAndSettle();
    expect(map(tester).markers.single.position,
        const LatLng(33.552987654, 72.633123456));
    expect(map(tester).initialCameraPosition.target,
        const LatLng(33.552987654, 72.633123456));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling an edited pin returns no replacement location',
      (tester) async {
    LatLng? result = const LatLng(0, 0);
    await openPicker(tester,
        initial: const LatLng(33.55, 72.63),
        mapsEnabled: true,
        onResult: (value) => result = value);
    map(tester).onTap!(const LatLng(33.553, 72.633));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('offline preview and explicit map opt-out keep manual entry',
      (tester) async {
    await openPicker(tester, preview: true, mapsEnabled: true);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await openPicker(tester, mapsEnabled: false);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('map confirmation stays reachable at $size with large text',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openPicker(tester,
          initial: const LatLng(33.55, 72.63), mapsEnabled: true);
      expect(find.text('Confirm location').hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(find.text('Open picker'), findsOneWidget);
    });
  }
}
