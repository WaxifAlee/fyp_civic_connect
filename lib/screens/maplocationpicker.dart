import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key});

  @override
  _MapLocationPickerState createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(33.6844, 72.9784);
  LatLng? _pickedLocation;

  final List<LatLng> _fatehJangBoundary = [
    LatLng(33.6013, 72.5843), // Top-left
    LatLng(33.5765, 72.6912), // Top-right
    LatLng(33.4857, 72.6903), // Bottom-right
    LatLng(33.4701, 72.5750), // Bottom-left
    LatLng(33.6013, 72.5843), // Closing the polygon
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enable location services.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions are denied.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLng(
            _initialPosition)); // Move camera to current location
      });
    }
  }

  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    int n = polygon.length;
    bool inside = false;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = polygon[i].latitude, yi = polygon[i].longitude;
      double xj = polygon[j].latitude, yj = polygon[j].longitude;

      bool intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  void _onMapTapped(LatLng position) {
    if (_isPointInsidePolygon(position, _fatehJangBoundary)) {
      setState(() {
        _pickedLocation = position;
      });
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Invalid Location"),
          content: Text("You can only pick locations within Fateh Jang."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _goToCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    LatLng currentLocation = LatLng(position.latitude, position.longitude);
    _mapController?.animateCamera(CameraUpdate.newLatLng(
        currentLocation)); // Move camera to current location
    setState(() {
      _pickedLocation = currentLocation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pick Location")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTapped,
            polygons: {
              Polygon(
                polygonId: PolygonId("fatehJangBoundary"),
                points: _fatehJangBoundary,
                strokeWidth: 2,
                strokeColor: Colors.red,
                fillColor: Colors.red.withOpacity(0.2),
              ),
            },
            markers: _pickedLocation != null
                ? {
                    Marker(
                      markerId: MarkerId("picked-location"),
                      position: _pickedLocation!,
                    ),
                  }
                : {},
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              child: Icon(Icons.my_location),
            ),
          ),
          if (_pickedLocation != null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _pickedLocation);
                },
                child: Text("Confirm Location"),
              ),
            ),
        ],
      ),
    );
  }
}
