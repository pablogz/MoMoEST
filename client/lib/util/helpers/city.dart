import 'package:latlong2/latlong.dart';

class City {
  late final String _lblCity;
  late final String _lblCountry;
  late final LatLng _point;

  City(this._lblCity, this._lblCountry, this._point);

  LatLng get point => _point;
  String get lblCity => _lblCity;
  String get lblCountry => _lblCountry;
}
