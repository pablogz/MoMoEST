import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_network/image_network.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/feed.dart';
import 'package:momoest/util/helpers/feed.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/helpers/itineraries.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/itineraries.dart';
import 'package:momoest/main.dart';
import 'package:momoest/features.dart';
import 'package:momoest/util/auth/firebase.dart';
import 'package:momoest/util/helpers/chest_marker.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/answers.dart';
import 'package:momoest/util/map_layer.dart';

class MyMap extends StatefulWidget {
  final String? center, zoom;
  const MyMap({
    super.key,
    this.center,
    this.zoom,
  });

  @override
  State<MyMap> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  final SearchController _searchController = SearchController();
  int _currentPageIndex = 0;
  bool _userIded = false,
      _mapCenterInUser = false,
      _cargaInicial = true,
      _tryingSignIn = false;
  late bool _extendedBar,
      _filterOpen,
      _visibleLabel,
      _barraAlLado,
      _barraAlLadoExpandida,
      _locationON,
      _ini;
  late double _rotationDegree;

  List<Marker> _myMarkers = <Marker>[] /*, _myMarkersNPi = <Marker>[]*/;
  List<Feature> _currentFeatures = <Feature>[];
  List<CircleMarker> _userCirclePosition = <CircleMarker>[];
  final MapController _mapController = MapController();
  late StreamSubscription<MapEvent> _strSubMap;
  List<Widget> _pages = [];
  late LatLng _lastCenter;
  late double _lastZoom;
  late int _lastMapEventScrollWheelZoom, _lastBack, _lastMoveEvent;
  Position? _locationUser;
  late IconData _iconLocation;
  late List<Itinerary> _itineraries;

  final Set<SpatialThingType> _filtrosActivos = {};

  late String _filtroIt;
  late TextEditingController _controllerFilterIt;

  @override
  void initState() {
    _filtroIt = '';
    _controllerFilterIt = TextEditingController();
    _ini = false;
    _rotationDegree = 0;
    _visibleLabel = true;
    _filterOpen = false;
    _lastMapEventScrollWheelZoom = 0;
    _lastMoveEvent = 0;
    _locationON = MyApp.locationUser.isEnable;
    _barraAlLado = false;
    _barraAlLadoExpandida = false;
    _lastBack = 0;
    if (widget.center != null && widget.center!.split(',').length == 2) {
      List<String> pos = widget.center!.split(',');
      double? latd = double.tryParse(pos.first);
      double? lond = double.tryParse(pos.last);
      if (latd != null &&
          lond != null &&
          latd >= -90 &&
          latd <= 90 &&
          lond >= -180 &&
          lond <= 180) {
        _lastCenter = LatLng(latd, lond);
      } else {
        if (UserXEST.userXEST.isNotGuest &&
            UserXEST.userXEST.lastMapView.point != null) {
          _lastCenter = UserXEST.userXEST.lastMapView.point!;
        } else {
          _lastCenter = const LatLng(41.6529, -4.72839);
        }
      }
    } else {
      _lastCenter = const LatLng(41.6529, -4.72839);
    }
    if (widget.zoom != null) {
      double? zumd = double.tryParse(widget.zoom!);
      if (zumd != null &&
          zumd <= MapLayer.maxZoom &&
          zumd >= MapLayer.minZoom) {
        _lastZoom = zumd;
      } else {
        if (UserXEST.userXEST.isNotGuest &&
            UserXEST.userXEST.lastMapView.zoom != null) {
          _lastZoom = UserXEST.userXEST.lastMapView.zoom!;
        } else {
          _lastZoom = 15.0;
        }
      }
    } else {
      _lastZoom = 15.0;
    }
    _itineraries = [];
    _extendedBar = true;
    checkUserLogin();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _strSubMap = _mapController.mapEventStream
          .where((event) =>
              event is MapEventMoveEnd ||
              event is MapEventDoubleTapZoomEnd ||
              event is MapEventScrollWheelZoom ||
              event is MapEventMoveStart ||
              event is MapEventDoubleTapZoomStart ||
              event is MapEventMove ||
              event is MapEventRotateEnd)
          .listen((event) async {
        LatLng latLng = _mapController.camera.center;
        if (mounted) {
          GoRouter.of(context).go(
              '/home?center=${latLng.latitude},${latLng.longitude}&zoom=${_mapController.camera.zoom}');
        }
        if ((event is MapEventScrollWheelZoom ||
                event is MapEventMoveStart ||
                event is MapEventDoubleTapZoomStart) &&
            !MapLayer.onlyIconInfoMap) {
          setState(() => MapLayer.onlyIconInfoMap = true);
        }
        if (event is MapEventMoveEnd ||
            event is MapEventDoubleTapZoomEnd ||
            event is MapEventScrollWheelZoom ||
            event is MapEventMove ||
            event is MapEventRotateEnd) {
          if (_mapController.camera.rotation != 0) {
            setState(
                () => _rotationDegree = _mapController.camera.rotation / 360);
          }
          if (event is MapEventScrollWheelZoom) {
            int current = DateTime.now().millisecondsSinceEpoch;
            if (_lastMapEventScrollWheelZoom + 200 < current) {
              _lastMapEventScrollWheelZoom = current;
              checkMarkerType();
            }
          } else {
            if (event is MapEventMove) {
              int current = DateTime.now().millisecondsSinceEpoch;
              if (_lastMoveEvent + 500 < current) {
                _lastMoveEvent = current;
                checkMarkerType();
              }
            } else {
              checkMarkerType();
            }
          }
        }
      });

      await MapData.loadCacheTiles();
      checkMarkerType();
    });
  }

  @override
  void dispose() {
    _strSubMap.cancel();
    if (_locationON) {
      MyApp.locationUser.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double widthWindow = MediaQuery.of(context).size.width;
    _barraAlLado =
        Auxiliar.getLateralMargin(widthWindow) == Auxiliar.mediumMargin;
    _barraAlLadoExpandida = _barraAlLado && widthWindow > 839;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    _pages = [
      widgetMap(_barraAlLado),
      widgetItineraries(),
      widgetFeeds(),
      widgetProfile(),
    ];
    List<NavigationDestination> lstNavigationDestination = [
      _navigationDestination(Icons.map_outlined, Icons.map, appLoca.mapa),
      _navigationDestination(
          Icons.route_outlined, Icons.route, appLoca.itinerarios),
      _navigationDestination(
          UserXEST.userXEST.hasFeedEnable
              ? Badge(
                  label: Text("1"), child: Icon(Icons.dynamic_feed_outlined))
              : Icons.dynamic_feed_outlined,
          UserXEST.userXEST.hasFeedEnable
              ? Badge(label: Text("1"), child: Icon(Icons.dynamic_feed))
              : Icons.dynamic_feed,
          appLoca.feeds),
      _navigationDestination(
          UserXEST.userXEST.isNotGuest
              ? Icons.person_outline
              : Icons.person_off_outlined,
          UserXEST.userXEST.isNotGuest ? Icons.person : Icons.person_off,
          appLoca.perfil),
    ];
    List<NavigationRailDestination> lstNavigationRailDestination = [
      _navigationRailDestination(Icons.map_outlined, Icons.map, appLoca.mapa),
      _navigationRailDestination(
          Icons.route_outlined, Icons.route, appLoca.itinerarios),
      UserXEST.userXEST.hasFeedEnable
          ? _navigationRailDestination(
              Badge(label: Text("1"), child: Icon(Icons.dynamic_feed_outlined)),
              Badge(label: Text("1"), child: Icon(Icons.dynamic_feed)),
              appLoca.feeds)
          : _navigationRailDestination(
              Icons.dynamic_feed_outlined, Icons.dynamic_feed, appLoca.feeds),
      _navigationRailDestination(
          UserXEST.userXEST.isNotGuest
              ? Icons.person_outline
              : Icons.person_off_outlined,
          UserXEST.userXEST.isNotGuest ? Icons.person : Icons.person_off,
          appLoca.perfil),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool popInvoked, Object? result) async {
        if (_currentPageIndex != 0) {
          _currentPageIndex = 0;
          changePage(0);
          // return false;
        } else {
          int now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastBack < 2000) {
            SystemNavigator.pop();
          } else {
            _lastBack = now;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(appLoca.atrasSalir),
              duration: const Duration(milliseconds: 1500),
            ));
          }
        }
      },
      child: Scaffold(
          bottomNavigationBar: _barraAlLado
              ? null
              : NavigationBar(
                  onDestinationSelected: (int index) => changePage(index),
                  selectedIndex: _currentPageIndex,
                  destinations: lstNavigationDestination,
                ),
          floatingActionButton: widgetFab(),
          body: _barraAlLado
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: _currentPageIndex,
                    leading: _barraAlLadoExpandida
                        ? _extendedBar
                            ? Row(
                                spacing: 30,
                                children: [
                                  IconButton(
                                      icon: Icon(
                                        Icons.menu,
                                        semanticLabel: appLoca.cerrarMenu,
                                      ),
                                      onPressed: () => setState(
                                            (() =>
                                                {_extendedBar = !_extendedBar}),
                                          )),
                                  SvgPicture.asset(
                                    Theme.of(context).brightness ==
                                            Brightness.light
                                        ? "images/logoName_light.svg"
                                        : "images/logoName_dark.svg",
                                    height: 42,
                                    semanticsLabel: appLoca.chest,
                                  )
                                ],
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.menu,
                                  semanticLabel: appLoca.abrirMenu,
                                ),
                                onPressed: () => setState(() {
                                  _extendedBar = !_extendedBar;
                                }),
                              )
                        : Text(
                            appLoca.chest,
                            style: textTheme.titleLarge,
                            semanticsLabel: appLoca.chest,
                          ),
                    groupAlignment: -1,
                    onDestinationSelected: (int index) => changePage(index),
                    useIndicator: true,
                    labelType: _barraAlLadoExpandida && _extendedBar
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    extended: _barraAlLadoExpandida && _extendedBar,
                    destinations: lstNavigationRailDestination,
                    elevation: 1,
                  ),
                  Flexible(child: _pages[_currentPageIndex])
                ])
              : _pages[_currentPageIndex]),
    );
  }

  NavigationRailDestination _navigationRailDestination(
          Object icon, Object iconSelected, String label) =>
      icon is IconData && iconSelected is IconData
          ? NavigationRailDestination(
              icon: Icon(
                icon,
                semanticLabel: label,
              ),
              selectedIcon: Icon(
                iconSelected,
                semanticLabel: label,
              ),
              label: Text(label),
            )
          : NavigationRailDestination(
              icon: icon as Widget,
              selectedIcon: iconSelected as Widget,
              label: Text(label),
            );

  NavigationDestination _navigationDestination(
          Object icon, Object iconSelected, String label) =>
      icon is IconData && iconSelected is IconData
          ? NavigationDestination(
              icon: Icon(
                icon,
                semanticLabel: label,
              ),
              selectedIcon: Icon(
                iconSelected,
                semanticLabel: label,
              ),
              label: label,
            )
          : NavigationDestination(
              icon: icon as Widget,
              selectedIcon: iconSelected as Widget,
              label: label,
            );

  void checkUserLogin() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) setState(() => _userIded = user != null);
    });
  }

  Widget widgetMap(bool progresoAbajo) {
    ThemeData td = Theme.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ColorScheme colorScheme = td.colorScheme;

    List<Widget> filterbar = [];

    filterbar.add(FloatingActionButton.small(
      onPressed: () {
        setState(() => _filterOpen = !_filterOpen);
      },
      tooltip:
          _filterOpen ? appLoca.abrirListaFiltros : appLoca.cerrarListaFiltros,
      heroTag: null,
      child: Icon(_filterOpen
          ? Icons.close_fullscreen
          : _filtrosActivos.isEmpty
              ? Icons.filter_alt_off
              : Icons.filter_alt),
    ));
    Set<SpatialThingType> sFilters = {
      SpatialThingType.artwork,
      SpatialThingType.attraction,
      SpatialThingType.castle,
      SpatialThingType.fountain,
      SpatialThingType.museum,
      SpatialThingType.palace,
      SpatialThingType.placeOfWorship,
      SpatialThingType.square,
      SpatialThingType.tower,
    };
    Map<SpatialThingType, String> sFilterLabel = {
      SpatialThingType.artwork: appLoca.artwork,
      SpatialThingType.attraction: appLoca.attraction,
      SpatialThingType.castle: appLoca.castle,
      SpatialThingType.fountain: appLoca.fountain,
      SpatialThingType.museum: appLoca.museum,
      SpatialThingType.palace: appLoca.palace,
      SpatialThingType.placeOfWorship: appLoca.placeOfWorship,
      SpatialThingType.square: appLoca.square,
      SpatialThingType.tower: appLoca.tower,
    };

    filterbar.addAll(
      List<Widget>.generate(sFilters.length, (int index) {
        SpatialThingType sf = sFilters.elementAt(index);
        return Visibility(
          visible: _filterOpen,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: FilterChip(
              label: Text(sFilterLabel[sf]!),
              showCheckmark: false,
              selectedColor: colorScheme.primaryContainer,
              selected: _filtrosActivos.contains(sf),
              onSelected: (bool v) {
                setState(() {
                  switch (sf) {
                    case SpatialThingType.placeOfWorship:
                      Set<SpatialThingType> lugarCulto = {
                        SpatialThingType.cathedral,
                        SpatialThingType.church,
                        SpatialThingType.placeOfWorship
                      };
                      v
                          ? _filtrosActivos.addAll(lugarCulto)
                          : _filtrosActivos.removeAll(lugarCulto);
                      break;
                    default:
                      v ? _filtrosActivos.add(sf) : _filtrosActivos.remove(sf);
                  }
                  v ? _filtrosActivos.add(sf) : _filtrosActivos.remove(sf);
                });
                checkMarkerType();
              },
            ),
          ),
        );
      }).toList(),
    );

    return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              maxZoom: MapLayer.maxZoom,
              minZoom: MapLayer.minZoom,
              initialCenter: _lastCenter,
              initialZoom: _lastZoom,
              keepAlive: false,
              interactionOptions: InteractionOptions(
                flags: kIsWeb
                    ? InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.scrollWheelZoom
                    : InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.scrollWheelZoom |
                        InteractiveFlag.rotate,
                pinchZoomThreshold: 2.0,
              ),
              onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
              onMapReady: () {
                _ini = true;
              },
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white54
                  : Colors.black54,
            ),
            children: [
              MapLayer.tileLayerWidget(brightness: td.brightness),
              MapLayer.atributionWidget(),
              CircleLayer(circles: _userCirclePosition),
              // MarkerLayer(markers: _myMarkersNPi),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 120,
                  centerMarkerOnClick: false,
                  zoomToBoundsOnClick: false,
                  showPolygon: false,
                  rotate: true,
                  onClusterTap: (p0) {
                    moveMap(
                        p0.bounds.center, min(p0.zoom + 1, MapLayer.maxZoom));
                  },
                  disableClusteringAtZoom: 18,
                  size: const Size(76, 76),
                  markers: _myMarkers,
                  circleSpiralSwitchover: 6,
                  spiderfySpiralDistanceMultiplier: 1,
                  polygonOptions: PolygonOptions(
                      borderColor: td.colorScheme.primary,
                      color: td.colorScheme.primaryContainer,
                      borderStrokeWidth: 1),
                  builder: (context, markers) {
                    int tama = markers.length;
                    double sizeMarker;
                    Color intensidad;
                    int multi = Queries.layerType == LayerType.forest ? 100 : 1;
                    ColorScheme colorScheme = Theme.of(context).colorScheme;
                    if (tama <= (5 * multi)) {
                      // intensidad = Colors.lime[100]!;
                      sizeMarker = 56;
                    } else {
                      if (tama <= (8 * multi)) {
                        sizeMarker = 66;
                        // intensidad = Colors.lime;
                      } else {
                        sizeMarker = 76;
                        // intensidad = Colors.lime[800]!;
                      }
                    }
                    intensidad = colorScheme.tertiaryContainer;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(76),
                        gradient: RadialGradient(
                          tileMode: TileMode.mirror,
                          colors: [
                            Colors.transparent,
                            colorScheme.tertiary.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: sizeMarker,
                          width: sizeMarker,
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(52),
                                color: intensidad,
                                border: Border.all(
                                    color: colorScheme.tertiary, width: 2)),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: TextStyle(
                                    color: colorScheme.onTertiaryContainer),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.only(top: 15, right: 15),
          child: Align(
            alignment: Alignment.topRight,
            child: Visibility(
              visible: UserXEST.userXEST.canEdit,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SegmentedButton(
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.surfaceTint,
                    selectedForegroundColor: colorScheme.onPrimaryContainer,
                    selectedBackgroundColor: colorScheme.primaryContainer,
                  ),
                  segments: [
                    ButtonSegment<Rol>(
                        value: Rol.teacher,
                        icon: const Icon(Icons.edit),
                        tooltip: appLoca.vistaProfesor),
                    ButtonSegment<Rol>(
                      value: Rol.user,
                      icon: const Icon(Icons.edit_off),
                      tooltip: appLoca.vistaEstudiante,
                    ),
                  ],
                  selected: <Rol>{
                    UserXEST.userXEST.canEditNow ? Rol.teacher : Rol.user
                  },
                  onSelectionChanged: (Set<Rol> r) {
                    setState(() {
                      UserXEST.userXEST.crol = r.first;
                      checkMarkerType();
                      iconFabCenter();
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.only(top: 15),
          child: Wrap(
            direction: Axis.vertical,
            alignment: WrapAlignment.start,
            spacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                clipBehavior: Clip.none,
                child: SearchAnchor(
                  builder: (context, controller) => FloatingActionButton.small(
                    heroTag: Auxiliar.searchHero,
                    tooltip: appLoca.searchCity,
                    onPressed: () => _searchController.openView(),
                    child: Icon(
                      Icons.search,
                      semanticLabel: appLoca.realizaBusqueda,
                    ),
                  ),
                  searchController: _searchController,
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(
                    context,
                    controller,
                    mapController: _mapController,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width -
                        (_barraAlLado && _extendedBar ? 250 : 50)),
                child: Wrap(
                  direction: Axis.horizontal,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 5,
                  children: filterbar,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: appLoca.tipoMapa,
                  onPressed: () => Auxiliar.showMBS(
                      context,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Wrap(spacing: 10, runSpacing: 10, children: [
                              _botonMapa(
                                Layers.carto,
                                MediaQuery.of(context).platformBrightness ==
                                        Brightness.light
                                    ? 'images/basemap_gallery/estandar_claro.png'
                                    : 'images/basemap_gallery/estandar_oscuro.png',
                                appLoca.mapaEstandar,
                              ),
                              _botonMapa(
                                Layers.satellite,
                                'images/basemap_gallery/satelite.png',
                                appLoca.mapaSatelite,
                              ),
                            ]),
                          ),
                          const Divider(),
                          SwitchListTile.adaptive(
                            value: _visibleLabel,
                            onChanged: (bool newValue) {
                              setState(() => _visibleLabel = newValue);
                              Navigator.pop(context);
                              checkMarkerType();
                            },
                            title: Text(appLoca.etiquetaMarcadores),
                          ),
                        ],
                      ),
                      title: appLoca.tipoMapa),
                  // child: const Icon(Icons.layers),
                  child: Icon(
                    Icons.settings_applications,
                    semanticLabel: appLoca.ajustes,
                  ),
                ),
              ),
            ],
          ),
        ),
        Visibility(
          visible: MapData.pendingTiles > 0,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment:
                progresoAbajo ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                  valueListenable: MapData.valueNotifier,
                  builder: (BuildContext context, v, Widget? child) {
                    return v is double
                        ? LinearProgressIndicator(
                            minHeight: 15,
                            value: v == 0 ? 0.01 : v,
                            semanticsLabel:
                                'Progress of the download of feature data')
                        : Container();
                  }),
            ],
          ),
        )
      ],
    );
  }

  Widget _botonMapa(Layers layer, String image, String textLabel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MapLayer.layer == layer
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
      child: InkWell(
        onTap: MapLayer.layer != layer ? () => _changeLayer(layer) : () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              width: 100,
              height: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  image,
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
              child: Text(textLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLayer(Layers layer) async {
    setState(() {
      MapLayer.layer = layer;
      // Auxiliar.updateMaxZoom();
      if (_mapController.camera.zoom > MapLayer.maxZoom) {
        moveMap(_mapController.camera.center, MapLayer.maxZoom);
      }
    });
    if (UserXEST.userXEST.isNotGuest) {
      http
          .put(Queries.preferences(),
              headers: {
                'content-type': 'application/json',
                'Authorization':
                    'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
              },
              body: json.encode({'defaultMap': layer.name}))
          .then((_) {
        if (mounted) Navigator.pop(context);
        checkMarkerType();
      }).onError((error, stackTrace) {
        if (mounted) Navigator.pop(context);
        checkMarkerType();
      });
    } else {
      Navigator.pop(context);
      checkMarkerType();
    }
  }

  Widget widgetItineraries() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          title: Text(appLoca.itinerarios),
        ),
        SliverAppBar(
          floating: false,
          pinned: true,
          centerTitle: false,
          toolbarHeight: 48,
          title: TextField(
            controller: _controllerFilterIt,
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.search),
              hintText: appLoca.busquedaIt,
              hintMaxLines: 1,
            ),
            onChanged: (value) => setState(() => _filtroIt = value.trim()),
          ),
          actions: _filtroIt.isNotEmpty
              ? [
                  IconButton(
                      onPressed: () {
                        _controllerFilterIt.clear();
                        setState(() => _filtroIt = '');
                      },
                      icon: Icon(Icons.close))
                ]
              : null,
        ),
        SliverPadding(
          padding: EdgeInsets.only(
              left: margenLateral, right: margenLateral, top: 10, bottom: 80),
          sliver: _itineraries.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator.adaptive()))
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    Itinerary it = _itineraries[index];
                    String title = it.getALabel(lang: MyApp.currentLang);
                    String comment = it.getAComment(lang: MyApp.currentLang);
                    if (_filtroIt.isNotEmpty &&
                        !(title
                                .toLowerCase()
                                .contains(_filtroIt.toLowerCase()) ||
                            comment
                                .toLowerCase()
                                .contains(_filtroIt.toLowerCase()))) {
                      return Container();
                    }
                    return _cardIt(it);
                  }, childCount: _itineraries.length),
                ),
        ),
      ],
    );
  }

  Widget _cardIt(Itinerary it) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    String comment = it.getAComment(lang: MyApp.currentLang);
    double mLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    if (comment.length > 250) {
      comment = '${comment.substring(0, 248)}…';
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: Auxiliar.maxWidth,
          minWidth: Auxiliar.maxWidth,
        ),
        margin: EdgeInsets.only(top: mLateral),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                color: colorScheme.outline,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12))),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: mLateral / 2,
                    bottom: mLateral,
                    right: mLateral,
                    left: mLateral,
                  ),
                  width: double.infinity,
                  child: Text(
                    it.getALabel(lang: MyApp.currentLang),
                    style: textTheme.titleMedium!.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                      bottom: mLateral, right: mLateral, left: mLateral),
                  width: double.infinity,
                  child: HtmlWidget(
                    comment,
                    textStyle: textTheme.bodyMedium!.copyWith(
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                      bottom: mLateral, right: mLateral, left: mLateral),
                  width: double.infinity,
                  child: Text(
                    '${it.authorLbl!}, ${DateFormat('d MMM yyyy', appLoca.localeName).format(it.date!)}',
                    style: textTheme.bodySmall!
                        .copyWith(color: colorScheme.outline),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: mLateral,
                      bottom: mLateral / 2,
                      right: mLateral,
                      left: mLateral,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        FirebaseAuth.instance.currentUser != null &&
                                    (UserXEST.userXEST.crol == Rol.teacher &&
                                        it.author == UserXEST.userXEST.iri) ||
                                UserXEST.userXEST.crol == Rol.admin
                            ? TextButton(
                                onPressed: null,
                                // TODO Tengo que recuperar primero la información completa del it para pasar a la pantalla de edición
                                // onPressed: () async {
                                //   Itinerary? itUpdate =
                                //       await Navigator.push(
                                //           context,
                                //           MaterialPageRoute<
                                //                   Itinerary>(
                                //               builder: (BuildContext
                                //                       context) =>
                                //                   AddEditItinerary(
                                //                       it),
                                //               fullscreenDialog:
                                //                   true));
                                //   if (itUpdate != null) {
                                //     int index =
                                //         _itineraries.indexWhere(
                                //             (Itinerary oldIt) =>
                                //                 itUpdate.id ==
                                //                 oldIt.id);
                                //     setState(() {
                                //       _itineraries
                                //           .removeAt(index);
                                //       _itineraries.insert(
                                //           0, itUpdate);
                                //     });
                                //   }
                                // },
                                child: Text(appLoca.editar))
                            : Container(),
                        FirebaseAuth.instance.currentUser != null &&
                                    (UserXEST.userXEST.crol == Rol.teacher &&
                                        it.author == UserXEST.userXEST.iri) ||
                                UserXEST.userXEST.crol == Rol.admin
                            ? TextButton(
                                onPressed: () async {
                                  // Navigator.pop(context);
                                  bool? delete = await Auxiliar.deleteDialog(
                                      context,
                                      appLoca.borrarIt,
                                      appLoca.preguntaBorrarIt);
                                  if (delete != null && delete) {
                                    http.delete(Queries.deleteIt(it.id!),
                                        headers: {
                                          'Content-Type': 'application/json',
                                          'Authorization':
                                              'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                        }).then((response) {
                                      switch (response.statusCode) {
                                        case 200:
                                          setState(() => _itineraries
                                              .removeWhere((element) =>
                                                  element.id! == it.id!));
                                          break;
                                        default:
                                          if (ConfigXest.development) {
                                            debugPrint(
                                                response.statusCode.toString());
                                          }
                                      }
                                    });
                                  }
                                },
                                child: Text(appLoca.borrar))
                            : Container(),
                        FilledButton(
                            onPressed: () async {
                              if (!ConfigXest.development) {
                                FirebaseAnalytics.instance.logEvent(
                                    name: 'seeItinerary',
                                    parameters: {
                                      'iri': Auxiliar.id2shortId(it.id!)!,
                                    }).then((_) => context.push(
                                    '/home/itineraries/${Auxiliar.id2shortId(it.id!)}'));
                              } else {
                                context.push(
                                    '/home/itineraries/${Auxiliar.id2shortId(it.id!)}');
                              }
                            },
                            child: Text(appLoca.acceder))
                      ],
                    ),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<List> _getItineraries() {
    return http.get(Queries.getItineraries()).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<Map> _getFeedsUser() async {
    return http.get(
      Queries.feeds(),
      headers: {
        'Authorization':
            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
      },
    ).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Widget widgetFeeds() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double w = MediaQuery.of(context).size.width;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          title: Text(appLoca.myFeeds),
        ),
        SliverPadding(
          padding:
              EdgeInsets.symmetric(horizontal: Auxiliar.getLateralMargin(w)),
          sliver: SliverToBoxAdapter(
            child: UserXEST.userXEST.isGuest
                ? Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        minWidth: Auxiliar.maxWidth,
                      ),
                      padding: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                      margin:
                          EdgeInsets.only(top: Auxiliar.getLateralMargin(w)),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: colorScheme.tertiaryContainer),
                      child: Center(
                        child: Text(
                          appLoca.iniciaSesionCanales,
                          style: textTheme.bodyMedium!
                              .copyWith(color: colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ),
                  )
                : FeedCache.feedsIsNull
                    ? Center(child: CircularProgressIndicator.adaptive())
                    : FeedCache.feeds.isEmpty
                        ? Center(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: Auxiliar.maxWidth,
                                minWidth: Auxiliar.maxWidth,
                              ),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: colorScheme.primaryContainer),
                              padding:
                                  EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                              margin: EdgeInsets.only(
                                  top: Auxiliar.getLateralMargin(w)),
                              child: Center(
                                child: Text(
                                  appLoca.listaCanalesVacia,
                                  style: textTheme.bodyMedium!.copyWith(
                                      color: colorScheme.onPrimaryContainer),
                                ),
                              ),
                            ),
                          )
                        : _listaFeeds(),
          ),
        ),
      ],
    );
  }

  Widget _listaFeeds() {
    double mLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    List<Widget> listaFeedsActivos = [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              appLoca.canalActivo,
              style:
                  textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
          )
        ],
        listaFeedsPropios = [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              appLoca.canalesCreados,
              style:
                  textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
          )
        ],
        listaFeedsApuntado = [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              appLoca.canalesApuntado,
              style:
                  textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
          )
        ];
    if (FeedCache.feedsIsNotNull) {
      for (Feed feed in FeedCache.feeds) {
        Card cardFeed = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                color: colorScheme.outline,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.only(
                    top: mLateral / 2,
                    bottom: mLateral,
                    right: mLateral,
                    left: mLateral),
                width: double.infinity,
                child: Text(
                  feed.getALabel(lang: MyApp.currentLang),
                  style: textTheme.titleMedium!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                    bottom: mLateral, right: mLateral, left: mLateral),
                width: double.infinity,
                child: HtmlWidget(
                  feed.getAComment(lang: MyApp.currentLang),
                  textStyle: textTheme.bodyMedium!.copyWith(
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    bottom: mLateral / 2, right: mLateral, left: mLateral),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Wrap(
                    spacing: mLateral,
                    direction: Axis.horizontal,
                    runSpacing: mLateral,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      feed.owner == UserXEST.userXEST.id &&
                              UserXEST.userXEST.canEditNow
                          ? TextButton(
                              onPressed: () async {
                                bool? borraFeed = await Auxiliar.deleteDialog(
                                    context,
                                    appLoca.borrarCanal,
                                    appLoca.descripcionBorrarCanal(feed
                                        .getALabel(lang: MyApp.currentLang)));
                                if (borraFeed is bool && borraFeed) {
                                  http.delete(Queries.feed(feed.shortId),
                                      headers: {
                                        'Authorization':
                                            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                      }).then((response) async {
                                    ScaffoldMessengerState? sMState = mounted
                                        ? ScaffoldMessenger.of(context)
                                        : null;
                                    switch (response.statusCode) {
                                      case 204:
                                        if (mounted) {
                                          setState(
                                              () => FeedCache.removeFeed(feed));
                                        }
                                        if (!ConfigXest.development) {
                                          await FirebaseAnalytics.instance
                                              .logEvent(
                                            name: "deletedFeed",
                                            parameters: {"iri": feed.shortId},
                                          ).then(
                                            (value) {
                                              if (sMState != null) {
                                                sMState.clearSnackBars();
                                                sMState.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        appLoca.canalBorrado),
                                                    duration: Duration(
                                                      seconds: 10,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ).onError((error, stackTrace) {
                                            if (sMState != null) {
                                              sMState.clearSnackBars();
                                              sMState.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    appLoca.canalBorrado,
                                                  ),
                                                  duration: Duration(
                                                    seconds: 10,
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        } else {
                                          if (sMState != null) {
                                            sMState.clearSnackBars();
                                            sMState.showSnackBar(SnackBar(
                                              content: Text(
                                                appLoca.canalBorrado,
                                              ),
                                              duration: Duration(
                                                seconds: 10,
                                              ),
                                            ));
                                          }
                                        }
                                        break;
                                      default:
                                        if (sMState != null) {
                                          sMState.clearSnackBars();
                                          sMState.showSnackBar(SnackBar(
                                            content: Text(
                                              'Status code: ${response.statusCode}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onErrorContainer),
                                            ),
                                            duration: Duration(
                                              seconds: 10,
                                            ),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .errorContainer,
                                          ));
                                        }
                                    }
                                  });
                                }
                              },
                              child: Text(appLoca.borrar),
                            )
                          : Container(),
                      FilledButton(
                        onPressed: () {
                          context.push('/home/feeds/${feed.shortId}');
                        },
                        child: Text(appLoca.acceder),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
        if (UserXEST.userXEST.hasFeedEnable &&
            UserXEST.userXEST.feed == feed.id) {
          listaFeedsActivos.add(cardFeed);
        } else {
          if (feed.owner == UserXEST.userXEST.id) {
            listaFeedsPropios.add(cardFeed);
          } else {
            listaFeedsApuntado.add(cardFeed);
          }
        }
      }
      List<Widget> childrenFeeds = [];
      if (listaFeedsActivos.length > 1) {
        childrenFeeds.addAll(listaFeedsActivos);
        childrenFeeds.add(SizedBox(height: 20));
      }
      if (listaFeedsPropios.length > 1) {
        childrenFeeds.addAll(listaFeedsPropios);
        childrenFeeds.add(SizedBox(height: 20));
      }
      if (listaFeedsApuntado.length > 1) {
        childrenFeeds.addAll(listaFeedsApuntado);
        childrenFeeds.add(SizedBox(height: 20));
      }
      return Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: Auxiliar.maxWidth,
            minWidth: Auxiliar.maxWidth,
          ),
          margin: EdgeInsets.only(top: mLateral),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: childrenFeeds),
        ),
      );
    } else {
      return Center();
    }
  }

  Widget widgetProfile() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        _userIded
            ? SliverAppBar(
                pinned: true,
                stretchTriggerOffset: 300,
                expandedHeight: 200,
                backgroundColor: colorScheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    UserXEST.userXEST.alias != null
                        ? UserXEST.userXEST.alias!
                        : FirebaseAuth.instance.currentUser != null &&
                                FirebaseAuth
                                        .instance.currentUser!.displayName !=
                                    null
                            ? FirebaseAuth.instance.currentUser!.displayName!
                            : appLoca!.perfil,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: colorScheme.onPrimary),
                  ),
                  titlePadding: const EdgeInsets.only(bottom: 10),
                  collapseMode: CollapseMode.pin,
                  centerTitle: true,
                  background: FirebaseAuth.instance.currentUser!.photoURL !=
                          null
                      ? ImageNetwork(
                          image: FirebaseAuth.instance.currentUser!.photoURL!,
                          height: 96,
                          width: 96,
                          duration: 0,
                          onTap: null,
                          imageCache: CachedNetworkImageProvider(
                              FirebaseAuth.instance.currentUser!.photoURL!),
                          fitAndroidIos: BoxFit.scaleDown,
                          borderRadius: BorderRadius.circular(48),
                          onError: const Icon(Icons.person, size: 96),
                          onLoading: const CircularProgressIndicator.adaptive(),
                        )
                      : Container(),
                ),
                actions: [
                  IconButton(
                    onPressed: _userIded
                        ? () async {
                            List<UserInfo> providerData =
                                FirebaseAuth.instance.currentUser!.providerData;
                            for (UserInfo userInfo in providerData) {
                              if (userInfo.providerId
                                  .contains(AuthProviders.google.name)) {
                                await AuthFirebase.signOut(
                                    AuthProviders.google);
                              } else {
                                if (userInfo.providerId
                                    .contains(AuthProviders.apple.name)) {
                                  await AuthFirebase.signOut(
                                      AuthProviders.apple);
                                }
                              }
                            }
                            FeedCache.resetCache();
                            UserXEST.userXEST = UserXEST.guest();
                          }
                        : null,
                    tooltip: appLoca!.cerrarSes,
                    icon: Icon(
                      Icons.output,
                      color: colorScheme.onPrimary,
                    ),
                  )
                ],
              )
            : SliverAppBar(
                title: Text(
                  appLoca!.perfil,
                ),
                centerTitle: true,
              ),
        widgetCurrentUser(),
        widgetStandarOptions(),
      ],
    );
  }

  Widget widgetCurrentUser() {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    TextStyle bodyMedium = td.textTheme.bodyMedium!;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> widgets = [];
    if (!_userIded) {
      widgets.add(Container(
        constraints: const BoxConstraints(maxWidth: 420),
        height: 40,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white
                  : const Color(0xFF131314)),
          onPressed: _tryingSignIn
              ? null
              : () async {
                  setState(() => _tryingSignIn = true);
                  AuthFirebase.signInGoogle().then(
                    (bool? newUser) async {
                      signIn(newUser, AuthProviders.google);
                    },
                  ).onError((error, stackTrace) async {
                    if (ConfigXest.development) {
                      debugPrint(error.toString());
                    } else {
                      await FirebaseCrashlytics.instance
                          .recordError(error, stackTrace);
                    }
                    setState(() => _tryingSignIn = false);
                  });
                },
          // https://developers.google.com/identity/branding-guidelines
          child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12, left: 10),
                  height: 20,
                  width: 20,
                  child: Image.asset(
                    'images/g.png',
                    fit: BoxFit.scaleDown,
                  ),
                ),
                Text(appLoca!.iniciarSesionRegistro,
                    semanticsLabel: appLoca.iniciarSesionRegistro,
                    style: bodyMedium.copyWith(
                        color: Theme.of(context).brightness == Brightness.light
                            ? const Color(0xFF1F1F1F)
                            : const Color(0xFFE3E3E3)))
              ]),
        ),
      ));
      if (!kIsWeb && Platform.isIOS) {
        widgets.add(Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SignInWithAppleButton(
              onPressed: _tryingSignIn
                  ? () {}
                  : () async {
                      setState(() => _tryingSignIn = true);
                      AuthFirebase.signInApple().then((bool? newUser) async {
                        signIn(newUser, AuthProviders.apple);
                      });
                    },
              text: appLoca.iniciarSesionApple,
              style: td.brightness == Brightness.dark
                  ? SignInWithAppleButtonStyle.white
                  : SignInWithAppleButtonStyle.black,
            ),
          ),
        ));
      }

      widgets.add(const SizedBox(height: 20));
    }
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () => GoRouter.of(context)
              .push('/users/${UserXEST.userXEST.id.split('/').last}')
          : null,
      label: Text(
        appLoca!.infoGestion,
        semanticsLabel: appLoca.infoGestion,
      ),
      icon: const Icon(Icons.person),
    ));

    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () {
              GoRouter.of(context).push(
                  '/users/${UserXEST.userXEST.id.split('/').last}/settings');
            }
          : null,
      label: Text(appLoca.ajustesCHEST, semanticsLabel: appLoca.ajustesCHEST),
      icon: const Icon(Icons.settings),
    ));

    widgets.add(
      TextButton.icon(
        onPressed: _userIded
            ? () async {
                Navigator.push(
                    context,
                    MaterialPageRoute<Task>(
                      builder: (BuildContext context) => InfoAnswers(),
                      fullscreenDialog: true,
                    ));
              }
            : null,
        label: Text(
          appLoca.misRespuestas,
          semanticsLabel: appLoca.misRespuestas,
        ),
        icon: Icon(Icons.my_library_books),
      ),
    );

    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () {
              //TODO
              sMState.clearSnackBars();
              sMState.showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  content: Text(
                    appLoca.enDesarrollo,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              );
            }
          : null,
      label: Text(appLoca.ayudaOpinando, semanticsLabel: appLoca.ayudaOpinando),
      icon: const Icon(Icons.feedback),
    ));

    return SliverPadding(
      padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0 && !_userIded) {
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: widgets.elementAt(index),
            );
          }
          return Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerLeft,
            child: widgets.elementAt(index),
          );
        }, childCount: widgets.length),
      ),
    );
  }

  Widget widgetStandarOptions() {
    GlobalKey shareKey = GlobalKey();
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lst = [
      TextButton.icon(
        onPressed: () => GoRouter.of(context).push('/privacy'),
        label: Text(appLoca!.politica, semanticsLabel: appLoca.politica),
        icon: const Icon(Icons.policy),
      ),
      TextButton.icon(
        onPressed: () {
          GoRouter.of(context).push('/about');
        },
        label: Text(appLoca.masInfo, semanticsLabel: appLoca.masInfo),
        icon: const Icon(Icons.info),
      ),
      TextButton.icon(
        onPressed: () {
          GoRouter.of(context).push('/contact');
        },
        label: Text(appLoca.politicaContactoTitulo,
            semanticsLabel: appLoca.politicaContactoTitulo),
        icon: const Icon(Icons.contact_support),
      ),
      Visibility(
        visible: !kIsWeb,
        child: TextButton.icon(
          key: shareKey,
          onPressed: () async => Auxiliar.share(shareKey, ConfigXest.addClient),
          label: Text(appLoca.comparteApp, semanticsLabel: appLoca.comparteApp),
          icon: const Icon(Icons.share),
        ),
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
            (context, index) => Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                child: lst.elementAt(
                  index,
                )),
            childCount: lst.length),
      ),
    );
  }

  void iconFabCenter() {
    setState(() {
      _iconLocation = _locationON
          ? _mapCenterInUser
              ? Icons.my_location
              : Icons.location_searching
          : Icons.location_disabled;
    });
  }

  Widget? widgetFab() {
    ThemeData td = Theme.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ColorScheme colorScheme = td.colorScheme;
    switch (_currentPageIndex) {
      case 0:
        iconFabCenter();
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              visible: UserXEST.userXEST.canEditNow,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FloatingActionButton(
                  heroTag: UserXEST.userXEST.canEditNow
                      ? Auxiliar.mainFabHero
                      : null,
                  tooltip: appLoca.tNPoi,
                  onPressed: () async {
                    if (_mapController.camera.zoom < 16) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(appLoca.aumentaZum),
                        action: SnackBarAction(
                            label: appLoca.aumentaZumShort,
                            onPressed: () =>
                                moveMap(_mapController.camera.center, 16)),
                      ));
                    } else {
                      LatLng center = _mapController.camera.center;
                      Navigator.push(
                        context,
                        MaterialPageRoute<Feature>(
                          builder: (BuildContext context) => SuggestFeature(
                              center, _mapController.camera.visibleBounds),
                          fullscreenDialog: false,
                        ),
                      ).then((suggestResult) async {
                        if (suggestResult != null && mounted) {
                          Navigator.push(
                                  context,
                                  MaterialPageRoute<Feature>(
                                      builder: (BuildContext context) =>
                                          FormFeature(
                                            suggestResult,
                                            true,
                                          ),
                                      fullscreenDialog: false))
                              .then((Feature? resetFeatures) {
                            if (resetFeatures is Feature) {
                              MapData.resetLocalCache();
                              checkMarkerType();
                            }
                          });
                        }
                      });
                    }
                  },
                  child: Icon(Icons.add,
                      semanticLabel: appLoca.tNPoi,
                      color: _ini && _mapController.camera.zoom < 16
                          ? Colors.grey
                          : colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            Visibility(
              visible: kIsWeb,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 3,
                  children: [
                    FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        moveMap(
                            _mapController.camera.center,
                            min(_mapController.camera.zoom + 1,
                                MapLayer.maxZoom));
                        checkMarkerType();
                      },
                      tooltip: appLoca.aumentaZumShort,
                      child: Icon(
                        Icons.zoom_in,
                        semanticLabel: appLoca.aumentaZumShort,
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        moveMap(
                            _mapController.camera.center,
                            max(_mapController.camera.zoom - 1,
                                MapLayer.minZoom));
                        checkMarkerType();
                      },
                      tooltip: appLoca.disminuyeZum,
                      child: Icon(
                        Icons.zoom_out,
                        semanticLabel: appLoca.disminuyeZum,
                      ),
                    )
                  ],
                ),
              ),
            ),
            Visibility(
              visible: !kIsWeb && _rotationDegree != 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FloatingActionButton.small(
                  heroTag: false,
                  onPressed: () {
                    _mapController.rotate(0);
                    setState(() => _rotationDegree = 0);
                  },
                  tooltip: appLoca.brujulaNorte,
                  child: RotationTransition(
                    turns: AlwaysStoppedAnimation(_rotationDegree +
                        0.25), // Ese desfase de 90 grados es por el icono que utilizamos
                    child: Icon(
                      Icons.switch_right_sharp,
                      semanticLabel: appLoca.brujulaNorte,
                    ),
                  ),
                ),
              ),
            ),
            FloatingActionButton(
              heroTag:
                  UserXEST.userXEST.canEditNow ? null : Auxiliar.mainFabHero,
              onPressed: () => getLocationUser(true),
              mini: UserXEST.userXEST.canEditNow,
              tooltip: appLoca.mUbicacion,
              child: Icon(
                _iconLocation,
                semanticLabel: appLoca.mUbicacion,
              ),
            ),
          ],
        );
      case 1:
        return UserXEST.userXEST.canEditNow
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: () async {
                  Itinerary? newIt = await Navigator.push(
                    context,
                    MaterialPageRoute<Itinerary>(
                        builder: (BuildContext context) =>
                            AddEditItinerary.empty(
                              latLngBounds: _mapController.camera.visibleBounds,
                            ),
                        fullscreenDialog: true),
                  );
                  if (newIt != null) {
                    setState(() => _itineraries.insert(0, newIt));
                  }
                },
                label: Text(appLoca.agregarIt),
                icon: Icon(
                  Icons.add,
                  semanticLabel: appLoca.agregarIt,
                ),
                tooltip: appLoca.agregarIt,
              )
            : null;
      case 2:
        if (UserXEST.userXEST.canEditNow) {
          return FloatingActionButton.extended(
            heroTag: Auxiliar.mainFabHero,
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute<Feed?>(
                    builder: (BuildContext context) => FormFeedTeacher(Feed()),
                    fullscreenDialog: true),
              ).then((Feed? feed) {
                if (feed is Feed && mounted) {
                  GoRouter.of(context).push('/home/feeds/${feed.shortId}');
                }
              });
            },
            label: Text(appLoca.addFeed),
            icon: Icon(Icons.add, semanticLabel: appLoca.addFeed),
          );
        } else {
          if (UserXEST.userXEST.isNotGuest && FeedCache.feedsIsNotNull) {
            return FloatingActionButton.extended(
              heroTag: Auxiliar.mainFabHero,
              onPressed: () async {
                Feed? feedSubscribed = await Navigator.push(
                  context,
                  MaterialPageRoute<Feed>(
                      builder: (BuildContext context) => FormFeedSubscriber(),
                      fullscreenDialog: true),
                );
                if (feedSubscribed is Feed && mounted) {
                  GoRouter.of(context)
                      .push('/home/feeds/${feedSubscribed.shortId}');
                }
              },
              label: Text(appLoca.apuntarmeFeed),
              icon: Icon(Icons.add, semanticLabel: appLoca.apuntarmeFeed),
            );
          }
          return null;
        }
      default:
        return null;
    }
  }

  void checkMarkerType() async {
    if (_locationON) {
      setState(() => _mapCenterInUser = _mapController.camera.center.latitude ==
              _locationUser!.latitude &&
          _mapController.camera.center.longitude == _locationUser!.longitude);
    }
    checkCurrentMap(_mapController.camera.visibleBounds, false);
  }

  void checkCurrentMap(LatLngBounds? mapBounds, bool group) async {
    _myMarkers = <Marker>[];
    _currentFeatures = <Feature>[];
    addMarkers2Map(
        await MapData.checkCurrentMapSplit(mapBounds!,
            filters: _filtrosActivos.isEmpty ? null : _filtrosActivos),
        mapBounds);
  }

  void addMarkers2Map(List<Feature> features, LatLngBounds mapBounds) {
    List<Feature> visibleFeatures = <Feature>[];
    for (Feature feature in features) {
      if (mapBounds.contains(LatLng(feature.lat, feature.long))) {
        visibleFeatures.add(feature);
      }
    }
    if (visibleFeatures.isNotEmpty) {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      for (Feature feature in visibleFeatures) {
        Widget icono;
        icono = Center(
          child: Icon(
            Queries.layerType == LayerType.ch
                ? Icons.castle_outlined
                : Queries.layerType == LayerType.schools
                    ? Icons.school_outlined
                    : Icons.forest_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        );

        // TODO volver a ponerlo cuando permitamos agregar anotaciones
        // if (UserXEST.userXEST.crol == Rol.teacher ||
        //     !((feature.labelLang(MyApp.currentLang) ?? feature.labels.first.value)
        //         .contains('https://www.openstreetmap.org/')) ||
        //     Queries.layerType == LayerType.forest) {
        if (!((feature.labelLang(MyApp.currentLang) ??
                feature.labels.first.value)
            .contains('https://www.openstreetmap.org/'))) {
          _currentFeatures.add(feature);
          _myMarkers.add(CHESTMarker(context,
              feature: feature,
              icon: icono,
              visibleLabel: _visibleLabel,
              currentLayer: MapLayer.layer!,
              circleWidthBorder: 2,
              circleWidthColor: colorScheme.primary,
              circleContainerColor: colorScheme.primaryContainer,
              onTap: () async {
            bool reactivar = _locationON;
            if (_locationON) {
              _locationON = false;
              MyApp.locationUser.dispose();
            }
            _lastCenter = _mapController.camera.center;
            _lastZoom = _mapController.camera.zoom;
            if (!ConfigXest.development) {
              FirebaseAnalytics.instance.logEvent(
                name: "seenFeature",
                parameters: {"iri": feature.shortId},
              ).then((value) async {
                bool? recargarTodo = await context.push<bool>(
                    '/home/features/${feature.shortId}',
                    extra: [_locationUser, icono]);
                checkMarkerType();
                if (reactivar) {
                  getLocationUser(false);
                  _locationON = true;
                  _mapCenterInUser = false;
                }
                iconFabCenter();
                moveMap(LatLng(feature.lat, feature.long),
                    _mapController.camera.zoom);
                if (recargarTodo != null && recargarTodo) {
                  checkMarkerType();
                }
              }).onError((error, stackTrace) async {
                if (ConfigXest.development) {
                  debugPrint(error.toString());
                } else {
                  await FirebaseCrashlytics.instance
                      .recordError(error, stackTrace);
                }
                bool? recargarTodo = await GoRouter.of(context).push<bool>(
                    '/homee/features/${feature.shortId}',
                    extra: [_locationUser, icono]);
                if (reactivar) {
                  getLocationUser(false);
                  _locationON = true;
                  _mapCenterInUser = false;
                }
                moveMap(LatLng(feature.lat, feature.long),
                    _mapController.camera.zoom);
                iconFabCenter();
                if (recargarTodo != null && recargarTodo) {
                  checkMarkerType();
                }
              });
            } else {
              bool? recargarTodo = await GoRouter.of(context).push<bool>(
                  '/home/features/${feature.shortId}',
                  extra: [_locationUser, icono]);
              if (reactivar) {
                getLocationUser(false);
                _locationON = true;
                _mapCenterInUser = false;
              }
              moveMap(LatLng(feature.lat, feature.long),
                  _mapController.camera.zoom);
              iconFabCenter();
              if (recargarTodo != null && recargarTodo) {
                checkMarkerType();
              }
            }
          }));
        }
      }
    }
    setState(() {});
  }

  void funIni(MapCamera mapPos, bool vF) async {
    if (!vF && _cargaInicial) {
      _cargaInicial = false;
      checkMarkerType();
    }
  }

  Future<void> changePage(index) async {
    setState(() => _currentPageIndex = index);
    // if (index != 3) {
    //   setState(() => _currentPageIndex = index);
    // } else {
    //   ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    //   sMState.clearSnackBars();
    //   sMState.showSnackBar(
    //       SnackBar(content: Text(AppLocalizations.of(context)!.enDesarrollo)));
    // }
    if (index != 0) {
      _lastCenter = _mapController.camera.center;
      _lastZoom = _mapController.camera.zoom;
      if (_locationON) {
        _locationON = false;
        _userCirclePosition = [];
        MyApp.locationUser.dispose();
      }
    }
    switch (index) {
      case 0: // HOME
        iconFabCenter();
        checkMarkerType();
        break;
      case 1: // ITINERARIES
        //Obtengo los itinearios
        await _getItineraries().then((data) {
          _itineraries = [];
          List<Itinerary> itL = [];
          for (var element in data) {
            try {
              Itinerary itinerary = Itinerary(element);
              itL.add(itinerary);
            } catch (error) {
              //print(error);
              if (ConfigXest.development) {
                debugPrint(error.toString());
              }
            }
          }
          setState(() => _itineraries.addAll(itL));
        }).onError((error, stackTrace) {
          setState(() => _itineraries = []);
          //print(error.toString());
        });
        break;
      case 2:
        // Obtengo los feeds del usuario
        FeedCache.resetCache();
        if (UserXEST.userXEST.isNotGuest) {
          await _getFeedsUser().then((data) {
            List<Feed> feedL = [];
            if (data is Map<String, dynamic>) {
              if (data.containsKey('owner') && data['owner'] is List) {
                for (Map<String, dynamic> f in data['owner']) {
                  Feed feed = Feed.json(f);
                  feedL.add(feed);
                }
              }
              if (data.containsKey('subscribed') &&
                  data['subscribed'] is List) {
                for (Map<String, dynamic> f in data['subscribed']) {
                  Feed feed = Feed.json(f);
                  feedL.add(feed);
                }
              }
            }
            setState(() {
              FeedCache.addAll(feedL);
            });
          });
        }
        break;
      default:
    }
  }

  void getLocationUser(bool centerPosition) async {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    if (_locationON) {
      if (_mapCenterInUser) {
        //Desactivo el seguimiento
        setState(() {
          _locationON = false;
          _mapCenterInUser = false;
          _userCirclePosition = [];
          _locationUser = null;
        });
        MyApp.locationUser.dispose();
      } else {
        setState(() {
          _mapCenterInUser = true;
        });
        if (centerPosition) {
          moveMap(LatLng(_locationUser!.latitude, _locationUser!.longitude),
              _mapController.camera.zoom);
        }
      }
    } else {
      bool hasPermissions = await MyApp.locationUser.checkPermissions(context);
      if (hasPermissions) {
        MyApp.locationUser.positionUser!.listen(
          (Position point) {
            _locationUser = point;
            if (!_locationON) {
              setState(() {
                _locationON = true;
              });
              if (centerPosition) {
                moveMap(LatLng(point.latitude, point.longitude),
                    max(16, _mapController.camera.zoom));
                setState(() {
                  _mapCenterInUser = true;
                });
              }
            } else {
              if (_mapCenterInUser) {
                setState(() {
                  _mapCenterInUser = _mapController.camera.center.latitude ==
                          _locationUser!.latitude &&
                      _mapController.camera.center.longitude ==
                          _locationUser!.longitude;
                });
              }
            }
            setState(() {
              _userCirclePosition = [];
              _userCirclePosition.add(CircleMarker(
                  point: LatLng(point.latitude, point.longitude),
                  radius: max(point.accuracy, 50),
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  useRadiusInMeter: true,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2));
            });
          },
        );
      }
      checkMarkerType();
    }
  }

  void moveMap(LatLng center, double zoom, {registra = true}) async {
    _mapController.move(center, zoom);
    if (UserXEST.userXEST.isNotGuest && registra) {
      context
          .go('/home?center=${center.latitude},${center.longitude}&zoom=$zoom');
      saveLocation(center, zoom);
    } else {
      context
          .go('/home?center=${center.latitude},${center.longitude}&zoom=$zoom');
    }
  }

  void saveLocation(LatLng center, double zoom) async {
    LastPosition lp = LastPosition(
      center.latitude,
      center.longitude,
      zoom,
    );
    UserXEST.userXEST.lastMapView = lp;
    http.put(Queries.preferences(),
        headers: {
          'content-type': 'application/json',
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
        },
        body: json.encode({'lastPointView': lp.toJSON()}));
  }

  Widget iconoFotoPerfil(Icon altIcon) {
    return altIcon;
    // return (FirebaseAuth.instance.currentUser != null &&
    //         FirebaseAuth.instance.currentUser!.emailVerified &&
    //         FirebaseAuth.instance.currentUser!.photoURL != null)
    // ? ImageNetwork(
    //     image: FirebaseAuth.instance.currentUser!.photoURL!,
    //     height: 24,
    //     width: 24,
    //     duration: 0,
    //     onTap: null,
    //     borderRadius: BorderRadius.circular(12),
    //     onLoading: Container(),
    //     onError: altIcon,
    //     onLoading: const CircularProgressIndicator.adaptive(),
    //   )
    //     : altIcon;
  }

  Future<void> signIn(bool? newUser, AuthProviders authProvider) async {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextStyle bodyMedium = td.textTheme.bodyMedium!;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    setState(() => _tryingSignIn = true);
    if (newUser != null) {
      if (newUser) {
        // Creo el usuario en el servidor
        // Dependiendo dle proveedor pido más datos o no
        http
            .put(Queries.putUser(),
                headers: {
                  'content-type': 'application/json',
                  'Authorization':
                      'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                },
                body: json.encode({}))
            .then((response) async {
          switch (response.statusCode) {
            case 201:
              // Usuario creado en el servidor. Actualizo sus preferencias
              http.get(Queries.signIn(), headers: {
                'Authorization':
                    'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
              }).then((response) async {
                switch (response.statusCode) {
                  case 200:
                    Map<String, dynamic> data = json.decode(response.body);
                    UserXEST.userXEST = UserXEST(data);
                    UserXEST.userXEST.lastMapView = LastPosition(
                        _mapController.camera.center.latitude,
                        _mapController.camera.center.longitude,
                        _mapController.camera.zoom);
                    http
                        .put(Queries.preferences(),
                            headers: {
                              'content-type': 'application/json',
                              'Authorization':
                                  'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                            },
                            body: json.encode({
                              'lastPointView':
                                  UserXEST.userXEST.lastMapView.toJSON()
                            }))
                        .then((response) {
                      setState(() => _tryingSignIn = false);
                      if (!ConfigXest.development) {
                        FirebaseAnalytics.instance
                            .logSignUp(signUpMethod: authProvider.name);
                      }
                      switch (authProvider) {
                        case AuthProviders.apple:
                          break;
                        case AuthProviders.google:
                          UserXEST.allowNewUser = true;
                          GoRouter.of(context).go(
                              '/users/${FirebaseAuth.instance.currentUser!.uid}/newUser',
                              extra: [
                                _mapController.camera.center.latitude,
                                _mapController.camera.center.longitude,
                                _mapController.camera.zoom
                              ]);
                          break;
                        default:
                      }
                    }).onError((error, stackTrace) {
                      setState(() => _tryingSignIn = false);
                      if (!ConfigXest.development) {
                        FirebaseAnalytics.instance
                            .logSignUp(signUpMethod: authProvider.name);
                      }
                      switch (authProvider) {
                        case AuthProviders.apple:
                          break;
                        case AuthProviders.google:
                          UserXEST.allowNewUser = true;
                          if (mounted) {
                            GoRouter.of(context).go(
                                '/users/${FirebaseAuth.instance.currentUser!.uid}/newUser',
                                extra: [
                                  _mapController.camera.center.latitude,
                                  _mapController.camera.center.longitude,
                                  _mapController.camera.zoom
                                ]);
                          }
                          break;
                        default:
                      }
                    });
                    break;
                  default:
                    setState(() => _tryingSignIn = false);
                    FirebaseAuth.instance.signOut();
                    sMState.clearSnackBars();
                    sMState.showSnackBar(SnackBar(
                        backgroundColor: colorScheme.error,
                        content: Text(
                            'GET error!. Status code: ${response.statusCode}',
                            style: bodyMedium.copyWith(
                                color: colorScheme.onError))));
                }
              });
              break;
            default:
              setState(() => _tryingSignIn = false);
              FirebaseAuth.instance.signOut();
              sMState.clearSnackBars();
              sMState.showSnackBar(SnackBar(
                  backgroundColor: colorScheme.error,
                  content: Text(
                      'PUT error!. Status code: ${response.statusCode}',
                      style: bodyMedium.copyWith(color: colorScheme.onError))));
          }
        });
      } else {
        // Usuario previamente registrado
        http.get(Queries.signIn(), headers: {
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
        }).then((response) async {
          switch (response.statusCode) {
            case 200:
              Map<String, dynamic> data = json.decode(response.body);
              setState(() => UserXEST.userXEST = UserXEST(data));
              sMState.clearSnackBars();
              sMState.showSnackBar(SnackBar(
                  content: Text(
                      '${appLoca!.hola} ${UserXEST.userXEST.alias ?? ""}')));
              if (!ConfigXest.development) {
                FirebaseAnalytics.instance
                    .logLogin(loginMethod: authProvider.name);
              }
              break;
            default:
              AuthFirebase.signOut(authProvider);
              sMState.clearSnackBars();
              sMState.showSnackBar(SnackBar(
                  backgroundColor: colorScheme.error,
                  content: Text('GET. Status code: ${response.statusCode}',
                      style: bodyMedium.copyWith(color: colorScheme.onError))));
          }
          setState(() => _tryingSignIn = false);
        }).onError((error, stackTrace) async {
          if (ConfigXest.development) {
            debugPrint(error.toString());
          } else {
            await FirebaseCrashlytics.instance.recordError(error, stackTrace);
          }
          setState(() => _tryingSignIn = false);
        });
      }
    } else {
      setState(() => _tryingSignIn = false);
    }
  }
}
