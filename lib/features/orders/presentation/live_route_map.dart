import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Google Map for a delivery: a pin on the customer's address and, when the
/// rider allows location, a blue dot for the rider with the straight-line
/// distance between them. Turn-by-turn directions stay with the Navigate
/// button, which opens Google Maps.
///
/// Needs a Google Maps API key in `AndroidManifest.xml`; without one the
/// map area stays blank. The address is placed with the phone's own
/// geocoder, so it can be a street or two off; if it cannot be found at
/// all, the pincode is used, and failing that a short note is shown.
class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({
    super.key,
    required this.address,
    required this.pincode,
    required this.eta,
    this.latitude,
    this.longitude,
  });

  final String address;
  final String pincode;
  final String eta;

  /// The spot the customer pinned for this address in their app. When
  /// given, the map uses it as it is and does not look the address up.
  final double? latitude;
  final double? longitude;

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> {
  static const _height = 260.0;

  GoogleMapController? _map;
  LatLng? _customer;
  LatLng? _rider;
  bool _lookingUp = true;
  bool _exactAddress = true;

  /// True when the pin is the customer's own, not looked up from text.
  bool _pinned = false;
  bool _locationAllowed = false;

  @override
  void initState() {
    super.initState();
    _locateCustomer();
    _locateRider();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<LatLng?> _geocode(String query) async {
    try {
      // Uses the phone's built-in geocoder: no API key and no charge.
      final found = await Geocoding()
          .locationFromAddress(query)
          .timeout(const Duration(seconds: 10));
      if (found.isEmpty) return null;
      return LatLng(found.first.latitude, found.first.longitude);
    } on Exception {
      return null;
    }
  }

  Future<void> _locateCustomer() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      // The customer's own pin: exact, and needs no lookup.
      setState(() {
        _customer = LatLng(lat, lng);
        _pinned = true;
        _lookingUp = false;
      });
      _frame();
      return;
    }
    var exact = true;
    var point = await _geocode('${widget.address}, India');
    if (point == null && widget.pincode.isNotEmpty) {
      exact = false;
      point = await _geocode('${widget.pincode}, India');
    }
    if (!mounted) return;
    setState(() {
      _customer = point;
      _exactAddress = exact;
      _lookingUp = false;
    });
    _frame();
  }

  Future<void> _locateRider() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (mounted) setState(() => _locationAllowed = true);
      final at = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _rider = LatLng(at.latitude, at.longitude));
      _frame();
    } on Exception {
      // No GPS fix: the customer's pin is still shown.
    }
  }

  /// Zooms so the rider and the customer are both in view.
  void _frame() {
    final map = _map;
    final customer = _customer;
    final rider = _rider;
    if (map == null || customer == null) return;
    if (rider == null) {
      map.animateCamera(CameraUpdate.newLatLngZoom(customer, 15));
      return;
    }
    double low(double a, double b) => a < b ? a : b;
    double high(double a, double b) => a > b ? a : b;
    final bounds = LatLngBounds(
      southwest: LatLng(
        low(customer.latitude, rider.latitude),
        low(customer.longitude, rider.longitude),
      ),
      northeast: LatLng(
        high(customer.latitude, rider.latitude),
        high(customer.longitude, rider.longitude),
      ),
    );
    map.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
  }

  String? get _distance {
    final customer = _customer;
    final rider = _rider;
    if (customer == null || rider == null) return null;
    final metres = Geolocator.distanceBetween(
      rider.latitude,
      rider.longitude,
      customer.latitude,
      customer.longitude,
    );
    return metres < 1000
        ? '${metres.round()} m away'
        : '${(metres / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final Widget content;
    if (_lookingUp) {
      content = const ColoredBox(
        color: AppColors.primarySoft,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (customer == null) {
      content = const _NoPin();
    } else {
      content = Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: customer, zoom: 15),
            onMapCreated: (controller) {
              _map = controller;
              _frame();
            },
            markers: {
              Marker(
                markerId: const MarkerId('customer'),
                position: customer,
                infoWindow: InfoWindow(
                  title: 'Deliver here',
                  snippet: widget.address,
                ),
              ),
            },
            myLocationEnabled: _locationAllowed,
            myLocationButtonEnabled: _locationAllowed,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Lets the map be dragged inside the scrolling page.
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                EagerGestureRecognizer.new,
              ),
            },
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _Chip(
              Icons.near_me_rounded,
              _distance ??
                  (_pinned
                      ? 'Pinned by customer'
                      : _exactAddress
                          ? 'Customer location'
                          : 'Pincode area only'),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _Chip(Icons.schedule_rounded, 'Deliver by ${widget.eta}'),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(height: _height, child: content),
    );
  }
}

class _NoPin extends StatelessWidget {
  const _NoPin();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.primary),
              SizedBox(height: 8),
              Text(
                "Couldn't place this address on the map. "
                'Use Navigate to open it in Google Maps.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
