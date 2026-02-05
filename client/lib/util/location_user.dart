import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';

class LocationUser {
  static const int distanceFilter = 10;
  static const Duration timeLimit = Duration(minutes: 60);
  static const Duration intervalDuration = Duration(seconds: 1);
  static Position? lastPosition;
  static const LocationAccuracy locationAccuracy = LocationAccuracy.high;

  late StreamController<Position>? _strLocationUser;
  late bool _isEnable;
  late bool _hasPermission;
  late LocationSettings _locationSettings;
  StreamSubscription? _streamSubscription;

  LocationUser(TargetPlatform defaultTargetPlatform) {
    _strLocationUser = null;
    _isEnable = false;
    _hasPermission = false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _locationSettings = AndroidSettings(
          forceLocationManager: false,
          accuracy: locationAccuracy,
          distanceFilter: distanceFilter,
          intervalDuration: intervalDuration,
          timeLimit: timeLimit,
        );
        break;
      case TargetPlatform.iOS:
        _locationSettings = AppleSettings(
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: true,
          showBackgroundLocationIndicator: false,
          accuracy: locationAccuracy,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        );
        break;
      default:
        _locationSettings = const LocationSettings(
          accuracy: locationAccuracy,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        );
    }
  }

  bool get hasPermissions => _hasPermission;
  bool get isEnable => _isEnable;

  /// Checks de location permissions
  /// Returns [true] if the app has permissions to turn on the location
  Future<bool> checkPermissions(BuildContext context) async {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    bool out = true;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      smState.showSnackBar(
        SnackBar(
          backgroundColor: colorScheme.errorContainer,
          content: Text(
            appLoca!.serviciosLocalizacionDescativados,
            style: td.textTheme.bodyMedium!
                .copyWith(color: colorScheme.onErrorContainer),
          ),
        ),
      );
      out = false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.errorContainer,
          content: Text(
            appLoca!.aceptarPermisosUbicacion,
            style: td.textTheme.bodyMedium!
                .copyWith(color: colorScheme.onErrorContainer),
          ),
        ));
        out = false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      smState.showSnackBar(SnackBar(
        backgroundColor: colorScheme.errorContainer,
        content: Text(
          appLoca!.aceptarPermisosUbicacion,
          style: td.textTheme.bodyMedium!
              .copyWith(color: colorScheme.onErrorContainer),
        ),
      ));
      out = false;
    }
    _hasPermission = out;
    return out;
  }

  Stream<Position>? get positionUser {
    if (_hasPermission != false) {
      _strLocationUser ??= StreamController.broadcast();
      _start();
      return _strLocationUser!.stream;
    }
    return null;
  }

  void _start() async {
    await _streamSubscription?.cancel();
    _streamSubscription =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen((Position? point) async {
      if (point is Position) {
        lastPosition = point;
        _strLocationUser?.sink.add(point);
      }
    }, onError: (e) {
      if (e is LocationServiceDisabledException) {
        _hasPermission = false;
      }
    });
  }

  Future<Position?> get currentLocationUser async {
    if (_hasPermission) {
      lastPosition = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings);
      return lastPosition;
    }
    return null;
  }

  void dispose() {
    _strLocationUser?.close();
    _strLocationUser = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }
}
