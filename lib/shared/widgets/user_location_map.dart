import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _fallbackLocation = LatLng(3.139, 101.6869);

Future<LatLng?> getCurrentUserLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return null;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    return null;
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  return LatLng(position.latitude, position.longitude);
}

class CurrentUserLocationMap extends StatefulWidget {
  const CurrentUserLocationMap({
    super.key,
    this.height = 220,
    this.initialZoom = 14.5,
  });

  final double height;
  final double initialZoom;

  @override
  State<CurrentUserLocationMap> createState() => _CurrentUserLocationMapState();
}

class _CurrentUserLocationMapState extends State<CurrentUserLocationMap> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isLoading = true;
  String? _message;
  LatLng _target = _fallbackLocation;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final location = await getCurrentUserLocation();
      if (!mounted) {
        return;
      }

      if (location == null) {
        setState(() {
          _target = _fallbackLocation;
          _message = 'Location access is unavailable. Showing Kuala Lumpur.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _target = location;
        _message = null;
        _isLoading = false;
      });

      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: widget.initialZoom),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _target = _fallbackLocation;
        _message = 'Unable to read your location right now.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = GoogleMap(
      key: const ValueKey('user-current-location-map'),
      initialCameraPosition: CameraPosition(
        target: _target,
        zoom: widget.initialZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: {
        Marker(
          markerId: const MarkerId('current-user-location'),
          position: _target,
          infoWindow: const InfoWindow(title: 'Your location'),
        ),
      },
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }

        if (_target != _fallbackLocation || _message == null) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _target, zoom: widget.initialZoom),
            ),
          );
        }
      },
      mapType: MapType.normal,
      compassEnabled: true,
      zoomControlsEnabled: true,
    );

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(child: map),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            if (_message != null && !_isLoading)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
