import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/widgets/civic_widgets.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Returns a validated [LatLng] through Navigator.pop.
/// Native maps are enabled by default. Web requires its Maps JavaScript SDK
/// and GOOGLE_MAPS_ENABLED=true. Manual entry always remains available.
class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({
    super.key,
    this.initialLocation,
    this.isPreview = false,
    this.mapsEnabled = mapsEnabledByDefault,
  });

  final LatLng? initialLocation;
  final bool isPreview;
  final bool mapsEnabled;

  static const mapsEnabledByDefault =
      bool.fromEnvironment('GOOGLE_MAPS_ENABLED', defaultValue: !kIsWeb);

  static bool get supportsMaps =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final _formKey = GlobalKey<FormState>();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selection;
  String? _message;
  bool _locating = false;
  bool _draggingPin = false;
  bool _showMap = true;
  bool _validate = false;

  bool get _preview => widget.isPreview || AppSession.instance.isPreview;

  bool get _canShowMap =>
      !_preview && widget.mapsEnabled && MapLocationPicker.supportsMaps;

  bool get _canConfirm =>
      !_locating && !_draggingPin && _coordinateError == null;

  static final _mapGestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    if (initial != null &&
        FatehJangArea.validate(initial.latitude, initial.longitude) == null) {
      _setCoordinates(initial);
      _selection = initial;
    }
    // Opening the picker deliberately never requests location permission.
  }

  @override
  void dispose() {
    // GoogleMap owns and disposes its controller with the platform view.
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _setCoordinates(LatLng location) {
    // Retain precision so a valid perimeter tap is not rounded outside it.
    _latitude.text = location.latitude.toString();
    _longitude.text = location.longitude.toString();
  }

  String? get _coordinateError => FatehJangArea.validate(
        double.tryParse(_latitude.text.trim()),
        double.tryParse(_longitude.text.trim()),
      );

  void _coordinatesChanged(String _) {
    final error = _coordinateError;
    setState(() {
      _message =
          _latitude.text.trim().isNotEmpty && _longitude.text.trim().isNotEmpty
              ? error
              : null;
      _selection = error == null
          ? LatLng(
              double.parse(_latitude.text.trim()),
              double.parse(_longitude.text.trim()),
            )
          : null;
    });
  }

  bool _acceptLocation(LatLng location) {
    final error = FatehJangArea.validate(location.latitude, location.longitude);
    setState(() {
      // Keep the visible marker, coordinates and validation on the same point.
      // In particular, an invalid native drag must not confirm an older pin.
      _setCoordinates(location);
      _selection = location;
      _draggingPin = false;
      _message = error;
    });
    if (_validate) _formKey.currentState?.validate();
    return error == null;
  }

  Future<void> _currentLocation() async {
    if (_preview || _locating || _draggingPin) return;
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ReportSubmissionException(
          'Location services are off. Turn them on, or enter coordinates below.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (!mounted || _preview) return;
      if (permission == LocationPermission.denied) {
        // This is reached only after the user presses Use current location.
        permission = await Geolocator.requestPermission();
      }
      if (!mounted || _preview) return;
      if (permission == LocationPermission.deniedForever) {
        throw const ReportSubmissionException(
          'Location access is blocked. Enable it in your device or browser '
          'settings, or enter coordinates below.',
        );
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const ReportSubmissionException(
          'Location access was not granted. You can enter coordinates below.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted || _preview) return;
      final rawError = FatehJangArea.validate(
        position.latitude,
        position.longitude,
      );
      if (rawError != null) throw ReportSubmissionException(rawError);
      final location = LatLng(position.latitude, position.longitude);
      if (_acceptLocation(location)) await _moveCamera(location);
    } on ReportSubmissionException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Your location is unavailable right now. Try again or '
              'enter the issue’s coordinates below.';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _moveCamera(LatLng location) async {
    if (!_showMap || !_canShowMap) return;
    try {
      final update = CameraUpdate.newLatLngZoom(location, 17);
      if (MediaQuery.disableAnimationsOf(context)) {
        await _mapController?.moveCamera(update);
      } else {
        await _mapController?.animateCamera(update);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showMap = false;
          _message = 'The map is unavailable. Your selected coordinates are '
              'kept below; you can still confirm this location.';
        });
      }
    }
  }

  void _confirm() {
    if (_locating || _draggingPin) return;
    setState(() => _validate = true);
    if (!_formKey.currentState!.validate()) return;
    final error = _coordinateError;
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    Navigator.of(context).pop(
      LatLng(
        double.parse(_latitude.text.trim()),
        double.parse(_longitude.text.trim()),
      ),
    );
  }

  Widget _coordinateField({required bool latitude}) {
    return TextFormField(
      controller: latitude ? _latitude : _longitude,
      enabled: !_locating,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: latitude ? TextInputAction.next : TextInputAction.done,
      onChanged: _coordinatesChanged,
      onFieldSubmitted: latitude ? null : (_) => _confirm(),
      decoration: InputDecoration(
        labelText: latitude ? 'Latitude' : 'Longitude',
        hintText: latitude ? 'e.g. 33.55' : 'e.g. 72.63',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final number = double.tryParse(value?.trim() ?? '');
        final limit = latitude ? 90 : 180;
        if (number == null || !number.isFinite) {
          return 'Enter a valid ${latitude ? 'latitude' : 'longitude'}.';
        }
        if (number < -limit || number > limit) {
          return 'Use a value from −$limit to $limit.';
        }
        if (!latitude) return _coordinateError;
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose issue location')),
      bottomNavigationBar: Material(
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('Confirm location'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                autovalidateMode: _validate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(
                      title: 'Pinpoint the problem',
                      subtitle: 'Choose the issue’s location inside the '
                          'Fateh Jang service area.',
                    ),
                    const SizedBox(height: 24),
                    if (_canShowMap && _showMap) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 320,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _selection ?? FatehJangArea.center,
                              zoom: _selection == null ? 13 : 17,
                            ),
                            onMapCreated: (controller) {
                              if (mounted && _showMap) {
                                _mapController = controller;
                              }
                            },
                            onTap: _locating ? null : _acceptLocation,
                            onLongPress: _locating ? null : _acceptLocation,
                            gestureRecognizers: _mapGestures,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            polygons: {
                              Polygon(
                                polygonId: const PolygonId('fatehJangBoundary'),
                                points: FatehJangArea.boundary,
                                strokeWidth: 2,
                                strokeColor: colors.primary,
                                fillColor: colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            },
                            markers: {
                              if (_selection != null)
                                Marker(
                                  markerId: const MarkerId('issue-location'),
                                  position: _selection!,
                                  draggable: !_locating,
                                  onDragStart: (_) =>
                                      setState(() => _draggingPin = true),
                                  onDragEnd: _acceptLocation,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    _coordinateError == null
                                        ? BitmapDescriptor.hueGreen
                                        : BitmapDescriptor.hueRed,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: 'Issue location',
                                  ),
                                ),
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to drop a pin. Touch and hold the pin to drag it. '
                        'Zoom in to choose the exact spot inside the shaded area.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_selection != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _draggingPin
                                ? 'Release the pin to select this spot.'
                                : 'Pin: ${_selection!.latitude.toStringAsFixed(7)}, '
                                    '${_selection!.longitude.toStringAsFixed(7)}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _draggingPin
                            ? null
                            : () => setState(() {
                                  _showMap = false;
                                  _mapController = null;
                                }),
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Use coordinates instead'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: colors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _preview
                                  ? 'Try location entry in preview'
                                  : 'Choose a location with coordinates',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _preview
                                  ? 'Enter coordinates to explore this step '
                                      'offline. 33.55, 72.63 is inside the '
                                      'service area. No device location is used.'
                                  : 'Enter latitude and longitude below. '
                                      'You can copy them from your preferred '
                                      'map or use your current location.',
                            ),
                            if (_canShowMap) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _showMap = true),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Show map'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (!_preview) ...[
                      AsyncButton(
                        label: 'Use current location',
                        icon: Icons.my_location_outlined,
                        isLoading: _locating,
                        onPressed:
                            _locating || _draggingPin ? null : _currentLocation,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Location permission is requested only when you use '
                        'this button.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_message != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _message!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_canShowMap || !_showMap)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 520) {
                            return Column(
                              children: [
                                _coordinateField(latitude: true),
                                const SizedBox(height: 16),
                                _coordinateField(latitude: false),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _coordinateField(latitude: true)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _coordinateField(latitude: false)),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
