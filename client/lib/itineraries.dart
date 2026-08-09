import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;

import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/helpers/providers/dbpedia.dart';
import 'package:momoest/util/helpers/providers/jcyl.dart';
import 'package:momoest/util/helpers/providers/osm.dart';
import 'package:momoest/util/helpers/providers/wikidata.dart';
import 'package:momoest/util/location_user.dart';
import 'package:momoest/util/map_layer.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:image_network/image_network.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/helpers/itineraries.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/main.dart';
import 'package:momoest/features.dart';
import 'package:momoest/tasks.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/chest_marker.dart';
import 'package:momoest/full_screen.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/util/helpers/widget_facto.dart';
import 'package:momoest/util/helpers/auxiliar_mobile.dart'
    if (dart.library.html) 'package:momoest/util/helpers/auxiliar_web.dart';
import 'package:momoest/util/helpers/track.dart';

class AddEditItinerary extends StatefulWidget {
  final Itinerary itinerary;
  final LatLngBounds? latLngBounds;

  /// Constructor para iniciar el Widget de creación o edición de un itinerario.
  /// Si [itinerary] está vacio se debe proporcionar [latLngBounds] para
  /// determinar en qué zona geográfica se quiere iniciar la creación del
  /// itinario. Si el itinerario se ha iniciado (vamos a editar) este valor se
  /// recupera de [itinerary]
  AddEditItinerary(this.itinerary, {this.latLngBounds, super.key})
      : assert((itinerary.id != null) || (latLngBounds != null));

  /// Constructor para iniciar el Widget de creación de un itinerario. Se debe
  /// proporcionar [latLngBounds] para determinar la zona geográfica donde
  ///la creación del itinario se quiere iniciar la creación del itinario.
  AddEditItinerary.empty({LatLngBounds? latLngBounds, Key? key})
      : this(Itinerary.empty(), latLngBounds: latLngBounds, key: key);

  @override
  State<StatefulWidget> createState() => _AddEditItinerary();
}

class _AddEditItinerary extends State<AddEditItinerary> {
  late LatLngBounds? _latLngBounds;
  final double _heightAppBar = 56;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription, _trackAgregado, _botonBloq;
  late String _title, _description;
  late int _step, _lastMapEventScrollWheelZoom;
  late GlobalKey<FormState> _gkS0;
  final MapController _mapController = MapController();
  late List<LatLng> _pointsTrack;
  late List<Marker> _myMarkers;
  late StreamSubscription<MapEvent> _strSubMap;
  late Itinerary _itinerary;

  @override
  void initState() {
    _itinerary = widget.itinerary;
    _botonBloq = false;
    _step = 0;
    _gkS0 = GlobalKey<FormState>();
    _title = _itinerary.labels.isNotEmpty
        ? _itinerary.getALabel(lang: MyApp.currentLang)
        : '';
    _description = _itinerary.comments.isNotEmpty
        ? _itinerary.getAComment(lang: MyApp.currentLang)
        : '';
    _latLngBounds = _itinerary.id != null
        ? LatLngBounds(LatLng(_itinerary.maxLat, _itinerary.maxLong),
            LatLng(_itinerary.minLat, _itinerary.minLong))
        : widget.latLngBounds;
    _itinerary.type ??= ItineraryType.bag;

    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    try {
      _quillController.document =
          Document.fromDelta(HtmlToDelta().convert(_description));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _description =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
        _errorDescription = _description.trim().isEmpty;
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    _trackAgregado = false;
    _pointsTrack = [];
    _myMarkers = [];
    _lastMapEventScrollWheelZoom = 0;
    _strSubMap = _mapController.mapEventStream
        .where((event) =>
            event is MapEventMoveEnd ||
            event is MapEventDoubleTapZoomEnd ||
            event is MapEventScrollWheelZoom)
        .listen((event) {
      _latLngBounds = _mapController.camera.visibleBounds;
      if (event is MapEventScrollWheelZoom) {
        int current = DateTime.now().millisecondsSinceEpoch;
        if (_lastMapEventScrollWheelZoom + 200 < current) {
          _lastMapEventScrollWheelZoom = current;
          _createMarkers();
        }
      } else {
        _createMarkers();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _strSubMap.cancel();
    _mapController.dispose();
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final double lMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
                "${_itinerary.id == null ? appLoca.agregarIt : appLoca.editarIt}. ${_step == 0 ? appLoca.descriIt : _step == 1 ? appLoca.learningResources : appLoca.resumen}"),
            centerTitle: false,
            floating: true,
            pinned: true,
            toolbarHeight: _heightAppBar,
          ),
          SliverVisibility(
            visible: _step == 0,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: _pasoCero(),
                  ),
                ),
              ),
            ),
          ),
          SliverVisibility(visible: _step == 1, sliver: _pasoUno()),
          SliverVisibility(
            visible: _step == 2,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: _pasoDos(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoCero() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _gkS0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            maxLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '${appLoca.tituloIt}*',
              hintText: appLoca.tituloIt,
              hintMaxLines: 1,
              hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
            ),
            textCapitalization: TextCapitalization.sentences,
            initialValue: _title,
            maxLength: 120,
            onChanged: (String v) => setState(() => _title = v),
            validator: (value) => (value == null ||
                    value.trim().isEmpty ||
                    value.trim().length > 120)
                ? appLoca.tituloItError
                : null,
            autovalidateMode: AutovalidateMode.onUnfocus,
            textInputAction: TextInputAction.next,
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.fromBorderSide(
                BorderSide(
                    color: _errorDescription
                        ? colorScheme.error
                        : _hasFocus
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                    width: _hasFocus ? 2 : 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${appLoca.descriIt}*',
                    style: td.textTheme.bodySmall!.copyWith(
                      color: _errorDescription
                          ? colorScheme.error
                          : _hasFocus
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        minWidth: Auxiliar.maxWidth),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                    ),
                    child: Auxiliar.quillToolbar(_quillController, colorScheme),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: Auxiliar.maxWidth,
                    maxHeight: 300,
                    minHeight: 150,
                  ),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    config: QuillEditorConfig(
                      padding: EdgeInsets.all(5),
                    ),
                    focusNode: _focusNode,
                  ),
                ),
                Visibility(
                  visible: _errorDescription,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      appLoca.descriItError,
                      style: textTheme.bodySmall!.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 5,
              children: [
                TextButton.icon(
                  onPressed: () async => Auxiliar.showMBS(
                    context,
                    Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appLoca.typeItineraryList,
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.start,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              appLoca.typeItineraryE1,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          SizedBox(height: 5),
                          Divider(),
                          SizedBox(height: 5),
                          Text(
                            appLoca.typeItineraryBag,
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.start,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              appLoca.typeItineraryE3,
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ]),
                  ),
                  label: Text(
                    appLoca.typeItinerary,
                    style: textTheme.bodyLarge,
                  ),
                  icon: Icon(Icons.info),
                  iconAlignment: IconAlignment.end,
                ),
                SegmentedButton(
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  showSelectedIcon: true,
                  segments: [
                    ButtonSegment<ItineraryType>(
                      value: ItineraryType.bag,
                      label: Text(appLoca.typeItineraryBag),
                    ),
                    ButtonSegment<ItineraryType>(
                      value: ItineraryType.list,
                      label: Text(appLoca.typeItineraryList),
                    ),
                  ],
                  selected: <ItineraryType>{
                    _itinerary.type ?? ItineraryType.bag
                  },
                  onSelectionChanged: (Set<ItineraryType> r) {
                    setState(() {
                      _itinerary.type = r.first;
                    });
                  },
                )
              ],
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                bool titleChecked = _gkS0.currentState!.validate();
                setState(() => _errorDescription = _description.trim().isEmpty);
                if (titleChecked && !_errorDescription) {
                  _itinerary.resetLabelComment();
                  _itinerary.addLabel(PairLang(MyApp.currentLang, _title));
                  _itinerary
                      .addComment(PairLang(MyApp.currentLang, _description));
                  setState(() => _step = 1);
                }
              },
              icon: Icon(Icons.arrow_right_alt),
              label: Text(appLoca.siguiente),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoUno() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    MediaQueryData mqd = MediaQuery.of(context);
    double sizeBar = mqd.viewPadding.top;
    Size size = mqd.size;
    final double margenLateral = Auxiliar.getLateralMargin(size.width);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: size.height - (_heightAppBar + sizeBar),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white54
                  : Colors.black54,
              maxZoom: MapLayer.maxZoom,
              minZoom: MapLayer.minZoom,
              initialCameraFit: CameraFit.bounds(bounds: _latLngBounds!),
              keepAlive: false,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.scrollWheelZoom,
                pinchZoomThreshold: 2.0,
              ),
              onMapReady: () async => _createMarkers(),
            ),
            children: [
              MapLayer.tileLayerWidget(brightness: td.brightness),
              MapLayer.atributionWidget(),
              if (_pointsTrack.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pointsTrack,
                      pattern: const StrokePattern.dotted(),
                      color: MapLayer.layer != Layers.satellite
                          ? colorScheme.tertiary
                          : Colors.white,
                      strokeWidth: 5,
                    )
                  ],
                ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 120,
                  centerMarkerOnClick: false,
                  zoomToBoundsOnClick: false,
                  showPolygon: false,
                  onClusterTap: (p0) {
                    _mapController.move(
                        p0.bounds.center, min(p0.zoom + 1, MapLayer.maxZoom));
                  },
                  disableClusteringAtZoom: 18,
                  size: const Size(76, 76),
                  markers: _myMarkers,
                  circleSpiralSwitchover: 6,
                  spiderfySpiralDistanceMultiplier: 1,
                  polygonOptions: PolygonOptions(
                      borderColor: colorScheme.primary,
                      color: colorScheme.primaryContainer,
                      borderStrokeWidth: 1),
                  builder: (context, markers) {
                    int tama = markers.length;
                    int nPul = 0;
                    for (Marker marker in markers) {
                      int index = _itinerary.points.indexWhere(
                          (PointItinerary pit) =>
                              pit.feature.point == marker.point);
                      if (index > -1) {
                        ++nPul;
                      }
                    }
                    double sizeMarker;
                    int multi = Queries.layerType == LayerType.forest ? 100 : 1;
                    if (tama <= (5 * multi)) {
                      sizeMarker = 56;
                    } else {
                      if (tama <= (8 * multi)) {
                        sizeMarker = 66;
                      } else {
                        sizeMarker = 76;
                      }
                    }
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(sizeMarker),
                        border: Border.all(color: Colors.grey[900]!, width: 2),
                        color: nPul == tama
                            ? colorScheme.primary
                            : nPul == 0
                                ? Colors.grey[700]!
                                : Colors.pink[100]!,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: TextStyle(
                              color: nPul == tama
                                  ? colorScheme.onPrimary
                                  : nPul == 0
                                      ? Colors.white
                                      : Colors.black),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
          SafeArea(
            minimum: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _step = 0),
                    label: Text(appLoca.atras),
                    icon: Transform.rotate(
                      angle: math.pi,
                      child: Icon(Icons.arrow_right_alt),
                    ),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surface),
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: appLoca.tipoMapa,
                    onPressed: () async => _configurarTipoMapa(),
                    elevation: 1,
                    child: Icon(Icons.settings),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            minimum: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _step = 2),
                    icon: Icon(Icons.arrow_right_alt),
                    label: Text(appLoca.siguiente),
                    iconAlignment: IconAlignment.end,
                    style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surface),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            minimum: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                verticalDirection: VerticalDirection.up,
                children: [
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async => _addSpatialThing(),
                    label: Text(appLoca.addPOI),
                    icon: Icon(Icons.add),
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async {
                      List<Task>? newItTasks = await Navigator.push(
                          context,
                          MaterialPageRoute<List<Task>>(
                              builder: (BuildContext context) =>
                                  AddEditTasksItinerary(_itinerary.tasks),
                              fullscreenDialog: true));
                      if (newItTasks != null) {
                        if (newItTasks.length != _itinerary.tasks.length) {
                          setState(() => _itinerary.tasks = newItTasks);
                        } else {
                          bool reemplazar = false;
                          for (int index = 0, tama = newItTasks.length;
                              index < tama;
                              index++) {
                            if (_itinerary.tasks
                                        .elementAt(index)
                                        .getALabel(lang: MyApp.currentLang)
                                        .compareTo(newItTasks
                                            .elementAt(index)
                                            .getALabel(
                                                lang: MyApp.currentLang)) !=
                                    0 ||
                                _itinerary.tasks
                                        .elementAt(index)
                                        .getAComment(lang: MyApp.currentLang)
                                        .compareTo(newItTasks
                                            .elementAt(index)
                                            .getAComment(
                                                lang: MyApp.currentLang)) !=
                                    0) {
                              reemplazar = true;
                              break;
                            }
                          }
                          if (reemplazar) {
                            setState(() => _itinerary.tasks = newItTasks);
                          }
                        }
                      }
                    },
                    label: Text(appLoca.tareasItinerario),
                    tooltip: appLoca.addItineraryTaskHelp,
                    icon: Icon(Icons.list),
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: _trackAgregado
                        ? () async => _borrarTrack()
                        : () async => _cargarTrack(),
                    label: Text(appLoca.gpxTrack),
                    icon: Icon(_trackAgregado
                        ? Icons.delete_forever
                        : Icons.upload_file),
                    tooltip: _trackAgregado
                        ? appLoca.borrarGPXtext
                        : appLoca.agregarGPXtexto,
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  Visibility(
                    visible: kIsWeb,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        _mapController.move(
                            _mapController.camera.center,
                            max(_mapController.camera.zoom - 1,
                                MapLayer.minZoom));
                      },
                      elevation: 1,
                      child: Icon(Icons.zoom_out),
                    ),
                  ),
                  SizedBox(height: 3),
                  Visibility(
                    visible: kIsWeb,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        _mapController.move(
                            _mapController.camera.center,
                            min(_mapController.camera.zoom + 1,
                                MapLayer.maxZoom));
                      },
                      elevation: 1,
                      child: Icon(Icons.zoom_in),
                    ),
                  )
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _cargarTrack() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    AuxiliarFunctions.readExternalFile(validExtensions: ['gpx'])
        .then((Object? s) {
      if (s is String) {
        _itinerary.track = Track.gpx(s);
        setState(() {
          for (LatLngCHEST p in _itinerary.track!.points) {
            _pointsTrack.add(p.toLatLng);
          }
          _trackAgregado = true;
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: _pointsTrack,
              padding: const EdgeInsets.all(78),
            ),
          );
        });
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          content: Text(appLoca.agregadoGPX),
        ));
      }
    }).onError((error, stackTrace) async {
      if (error is FileExtensionException) {
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.error,
          content: Text(
            appLoca.soloGPX,
            style: textTheme.bodyMedium!.copyWith(color: colorScheme.onError),
          ),
        ));
      } else {
        if (ConfigXest.development) {
          debugPrint(error.toString());
        } else {
          await FirebaseCrashlytics.instance.recordError(error, stackTrace);
        }
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.error,
          content: Text(
            error.toString(),
            style: textTheme.bodyMedium!.copyWith(color: colorScheme.onError),
          ),
        ));
      }
    });
  }

  void _borrarTrack() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    _itinerary.track = null;
    setState(() {
      _pointsTrack = [];
      _trackAgregado = false;
    });
    smState.clearSnackBars();
    smState.showSnackBar(SnackBar(
      content: Text(appLoca.borradoGPX),
    ));
  }

  void _configurarTipoMapa() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    Auxiliar.showMBS(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              _botonMapa(
                Layers.carto,
                MediaQuery.of(context).platformBrightness == Brightness.light
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
        ],
      ),
      title: appLoca.tipoMapa,
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
        onTap: MapLayer.layer != layer
            ? () {
                setState(() {
                  MapLayer.layer = layer;
                  // Auxiliar.updateMaxZoom();
                  if (_mapController.camera.zoom > MapLayer.maxZoom) {
                    _mapController.move(
                        _mapController.camera.center, MapLayer.maxZoom);
                  }
                });
                Navigator.pop(context);
              }
            : () {},
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

  Future<void> _addSpatialThing() async {
    LatLng center = _mapController.camera.center;
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    Feature? newST = await Navigator.push(
        context,
        MaterialPageRoute<Feature>(
            builder: (BuildContext context) => FormFeature(
                  Feature.point(center.latitude, center.longitude),
                  true,
                ),
            fullscreenDialog: false));
    if (newST is Feature) {
      MapData.resetLocalCache();
      sMState.clearSnackBars();
      sMState.showSnackBar(SnackBar(content: Text(appLoca.loading)));
      setState(() => _myMarkers = []);
      _createMarkers();
    }
  }

  void _createMarkers() async {
    _myMarkers = [];
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    MapData.checkCurrentMapSplit(_latLngBounds!)
        .then((List<Feature> listFeatures) {
      for (int i = 0, tama = listFeatures.length; i < tama; i++) {
        Feature feature = listFeatures.elementAt(i);
        if (!feature
            .getALabel(lang: MyApp.currentLang)
            .contains('www.openstreetmap.org')) {
          bool seleccionado = _itinerary.points.indexWhere(
                  (PointItinerary pointItinerary) =>
                      pointItinerary.feature.id == feature.id) >
              -1;
          _myMarkers.add(CHESTMarker(context,
              feature: feature,
              icon: Icon(Icons.castle_outlined,
                  color: seleccionado
                      ? colorScheme.onPrimaryContainer
                      : Colors.black),
              currentLayer: MapLayer.layer!,
              circleWidthBorder: seleccionado ? 2 : 1,
              circleWidthColor:
                  seleccionado ? colorScheme.primary : Colors.grey,
              circleContainerColor: seleccionado
                  ? td.colorScheme.primaryContainer
                  : Colors.grey[400]!,
              textInGray: !seleccionado, onTap: () async {
            int index = _itinerary.points.indexWhere(
                (PointItinerary pointItinerary) =>
                    pointItinerary.feature.id == feature.id);
            PointItinerary pointItinerary;
            if (index >= 0) {
              pointItinerary = _itinerary.points.elementAt(index);
            } else {
              pointItinerary = PointItinerary({
                'id': feature.id,
              });
              pointItinerary.feature = feature;
            }

            PointItinerary? pIt = await Navigator.push(
              context,
              MaterialPageRoute<PointItinerary>(
                  builder: (BuildContext context) => AddEditPointItineary(
                      pointItinerary, _itinerary.type!, index < 0),
                  fullscreenDialog: true),
            );
            if (pIt is PointItinerary) {
              if (pIt.removeFromIt) {
                _itinerary.removePoint(pIt);
              } else {
                _itinerary.removePoint(pIt);

                _itinerary.addPoints(pIt);
              }
            }
            _createMarkers();
          }));
        }
      }
      setState(() {});
    });
  }

  Widget _pasoDos() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    List<Widget> lst = [
      _pasoDosInfo(),
      _pasoDosSTyTasks(),
    ];
    if (_itinerary.tasks.isNotEmpty) {
      lst.add(_pasoDosTareas());
    }
    lst.add(_botonesPasoDos());
    return SliverList.builder(
      itemBuilder: (context, index) => SafeArea(
        minimum: const EdgeInsets.all(5),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: index == 0
                      ? colorScheme.tertiaryContainer
                      : index != lst.length - 1
                          ? colorScheme.primaryContainer
                          : colorScheme.surface,
                ),
                padding: const EdgeInsets.all(10),
                child: lst[index],
              ),
            ),
          ),
        ),
      ),
      itemCount: lst.length,
    );
  }

  Widget _pasoDosInfo() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_itinerary.getALabel(lang: MyApp.currentLang),
            style: textTheme.titleLarge!.copyWith(
              color: colorScheme.onTertiaryContainer,
            )),
        SizedBox(height: 5),
        HtmlWidget(
          _itinerary.getAComment(lang: MyApp.currentLang),
          textStyle: textTheme.bodyMedium!.copyWith(
            color: colorScheme.onTertiaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _pasoDosSTyTasks() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(appLoca.sitiosTareas,
            style: textTheme.titleMedium!
                .copyWith(color: colorScheme.onPrimaryContainer)),
        _mapaPasoDos(),
        SizedBox(height: 10),
        _listaLugaresTareas(),
      ],
    );
  }

  Widget _pasoDosTareas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(appLoca.tareasItinerario,
            style: textTheme.titleMedium!
                .copyWith(color: colorScheme.onPrimaryContainer)),
        SizedBox(height: 10),
        _listaTareasItinerario(),
      ],
    );
  }

  Widget _mapaPasoDos() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    double altMap = min(MediaQuery.of(context).size.height * 0.4, 450);
    if (_itinerary.points.isEmpty) {
      return Text(appLoca.agregaLugaresEnPasoPrevio,
          style: textTheme.bodyMedium!.copyWith(
            color: colorScheme.onPrimaryContainer,
          ));
    }
    List<LatLng> points = [];
    List<Marker> markersIt = [];
    for (int i = 0, tama = _itinerary.points.length; i < tama; i++) {
      PointItinerary pIt = _itinerary.points.elementAt(i);
      points.add(pIt.feature.point);
      markersIt.add(
        CHESTMarker(
          context,
          feature: pIt.feature,
          currentLayer: MapLayer.layer!,
          icon: _itinerary.type == ItineraryType.bag
              ? Icon(Icons.castle_outlined,
                  color: colorScheme.onPrimaryContainer)
              : Center(
                  child: Text(
                    (i + 1).toString(),
                    style: textTheme.bodyLarge!
                        .copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ),
          circleWidthBorder: 1,
          circleWidthColor: colorScheme.primary,
          circleContainerColor: colorScheme.primaryContainer,
          onTap: null,
        ),
      );
    }
    List<LatLng> coordinates = [];
    coordinates.addAll(points);
    coordinates.addAll(_pointsTrack);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: altMap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FlutterMap(
            options: MapOptions(
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white54
                  : Colors.black54,
              maxZoom: MapLayer.maxZoom,
              minZoom: MapLayer.minZoom,
              initialCameraFit: CameraFit.coordinates(
                  coordinates: coordinates,
                  padding: EdgeInsets.all(
                      78)), // Un poco más del tamaño máximo del marcador
              keepAlive: false,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              MapLayer.tileLayerWidget(brightness: td.brightness),
              MapLayer.atributionWidget(),
              if (_pointsTrack.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pointsTrack,
                      pattern: const StrokePattern.dotted(),
                      color: MapLayer.layer != Layers.satellite
                          ? colorScheme.tertiary
                          : Colors.white,
                      strokeWidth: 5,
                    )
                  ],
                ),
              MarkerLayer(markers: markersIt)
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaLugaresTareas() {
    List<Widget> children = [];
    for (int i = 0, tama = _itinerary.points.length; i < tama; i++) {
      PointItinerary pIt = _itinerary.points.elementAt(i);
      children.add(_cardPointItinerary(pIt, position: i));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _cardPointItinerary(PointItinerary pIt, {int? position}) {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    String labelPoint = pIt.feature.getALabel(lang: MyApp.currentLang);
    List<Widget> labelsTasks = [];
    if (pIt.hasLstTasks) {
      for (int i = 0, tama = pIt.tasksObj.length; i < tama; i++) {
        Task task = pIt.tasksObj.elementAt(i);
        labelsTasks.add(Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(task.getALabel(lang: MyApp.currentLang),
              style: textTheme.bodyMedium!.copyWith(
                color: position != null && position.isOdd
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              )),
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        // border: Border.all(
        //   color: position != null && position.isOdd
        //       ? colorScheme.primary
        //       : colorScheme.secondary,
        // ),
        // borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: position != null && position.isOdd
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
      ),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelPoint,
            style: textTheme.titleMedium!.copyWith(
              color: position != null && position.isOdd
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: labelsTasks,
          ),
        ],
      ),
    );
  }

  Widget _listaTareasItinerario() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    List<Task> tareas = _itinerary.tasks;
    List<Widget> labelsTasks = [];

    for (int i = 0, tama = tareas.length; i < tama; i++) {
      Task task = tareas.elementAt(i);
      labelsTasks.add(Container(
        decoration: BoxDecoration(
          // border: Border.all(
          //   color: i.isOdd ? colorScheme.primary : colorScheme.secondary,
          // ),
          // borderRadius: const BorderRadius.all(Radius.circular(4)),
          color: i.isOdd
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
        ),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            task.getALabel(lang: MyApp.currentLang),
            style: textTheme.bodyMedium!.copyWith(
              color: i.isOdd
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labelsTasks,
    );
  }

  Widget _botonesPasoDos() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Wrap(
          spacing: 10,
          runSpacing: 5,
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _botonBloq ? null : () => setState(() => _step = 1),
              label: Text(appLoca.atras),
              icon: Transform.rotate(
                angle: math.pi,
                child: Icon(
                  Icons.arrow_right_alt,
                ),
              ),
              iconAlignment: IconAlignment.start,
            ),
            FilledButton.icon(
              onPressed: _botonBloq
                  ? null
                  : () async {
                      if (_itinerary.points.isEmpty) {
                        smState.clearSnackBars();
                        smState.showSnackBar(
                          SnackBar(
                            backgroundColor: td.colorScheme.error,
                            content: Text(
                              appLoca.errorSeleccionaUnPoi,
                              style: td.textTheme.bodyMedium!
                                  .copyWith(color: td.colorScheme.onError),
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _botonBloq = true);
                      Map<String, dynamic> bodyRequest = _itinerary.toMap();
                      // debugPrint(bodyRequest.toString());
                      http
                          .post(Queries.newItinerary(),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization':
                                    'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                              },
                              body: json.encode(bodyRequest))
                          .then((response) {
                        switch (response.statusCode) {
                          case 201:
                            String id = response.headers['location']!;
                            _itinerary.id = id;
                            _itinerary.author = UserXEST.userXEST.iri;
                            _itinerary.authorLbl = UserXEST.userXEST.alias;
                            _itinerary.date = DateTime.now();
                            if (!ConfigXest.development) {
                              FirebaseAnalytics.instance.logEvent(
                                  name: 'newItinerary',
                                  parameters: {
                                    'iri': Auxiliar.id2shortId(id)!,
                                    'author': _itinerary.author!
                                  }).then((_) {
                                if (context.mounted) {
                                  Navigator.pop(context, _itinerary);
                                  smState.clearSnackBars();
                                  smState.showSnackBar(
                                    SnackBar(
                                        content: Text(appLoca.infoRegistrada)),
                                  );
                                }
                              });
                            } else {
                              Navigator.pop(context, _itinerary);
                              smState.clearSnackBars();
                              smState.showSnackBar(
                                SnackBar(content: Text(appLoca.infoRegistrada)),
                              );
                            }
                            break;
                          default:
                            setState(() => _botonBloq = false);
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
                                content: Text(response.statusCode.toString())));
                        }
                      }).onError((error, stackTrace) async {
                        setState(() => _botonBloq = false);
                        smState.clearSnackBars();
                        smState.showSnackBar(
                            const SnackBar(content: Text('Error')));
                        if (ConfigXest.development) {
                          debugPrint(error.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(error, stackTrace);
                        }
                      });
                    },
              label: Text(appLoca.guardar),
              icon: Icon(Icons.publish),
            ),
          ]),
    );
  }
}

class AddEditTasksItinerary extends StatefulWidget {
  final List<Task> _tasks;
  const AddEditTasksItinerary(this._tasks, {super.key});

  @override
  State<StatefulWidget> createState() => _AddEditTasksItinerary();
}

class _AddEditTasksItinerary extends State<AddEditTasksItinerary> {
  late List<Task> _tasks;

  @override
  void initState() {
    _tasks = [];
    _tasks.addAll(widget._tasks);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final double lMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.tareasItinerario),
            centerTitle: false,
            leading: IconButton(
              onPressed: () => context.pop(_tasks),
              icon: Icon(Icons.close),
              tooltip: appLoca.close,
            ),
          ),
          SliverSafeArea(
            minimum: EdgeInsets.all(lMargin),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(appLoca.tareaItinerarioExplicacion),
                  ),
                ),
              ),
            ),
          ),
          SliverSafeArea(
            minimum: EdgeInsets.all(lMargin),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: _listaTareas(),
                ),
              ),
            ),
          ),
          SliverSafeArea(
            minimum: EdgeInsets.all(lMargin),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: _botones(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaTareas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    List<Widget> children = [];
    for (Task task in _tasks) {
      children.add(_tarjetaTarea(
          task, colorScheme.onSurface, colorScheme.surface,
          labelAction: appLoca.removeTaskFromIt,
          funAction: () => setState(() => _tasks.remove(task))));
    }
    if (children.isEmpty) {
      children.add(Text(appLoca.sinTareasAgregaIt));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _tarjetaTarea(Task task, Color color, Color background,
      {String? labelAction, VoidCallback? funAction, Key? key}) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(
            color: color,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(12))),
      color: background,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: Text(
                task.getALabel(lang: MyApp.currentLang),
                style: textTheme.titleMedium!.copyWith(color: color),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: HtmlWidget(
                task.getAComment(lang: MyApp.currentLang),
                textStyle: textTheme.bodyMedium!
                    .copyWith(overflow: TextOverflow.ellipsis, color: color),
              ),
            ),
            funAction == null || labelAction == null
                ? Container()
                : Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: funAction,
                      child: Text(
                        labelAction,
                        style: textTheme.bodyMedium!.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ),
          ]),
    );
  }

  Widget _botones() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.bottomRight,
      child: Wrap(
        spacing: 10,
        runSpacing: 5,
        alignment: WrapAlignment.end,
        direction: Axis.horizontal,
        children: [
          OutlinedButton.icon(
            onPressed: () async => _agregarTareaItinerario(),
            label: Text(appLoca.agregarTarea),
            icon: Icon(Icons.add),
          ),
          FilledButton.icon(
            onPressed: () {
              context.pop(_tasks);
            },
            label: Text(appLoca.guardar),
            icon: Icon(Icons.save),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarTareaItinerario() async {
    Task? nTask = await Navigator.push(
        context,
        MaterialPageRoute<Task>(
          builder: (BuildContext context) => FormTask(
            Task.empty(
              containerType: ContainerTask.itinerary,
            ),
          ),
          fullscreenDialog: true,
        ));
    if (nTask is Task) {
      setState(() => _tasks.add(nTask));
    }
  }
}

class AddEditPointItineary extends StatefulWidget {
  final PointItinerary pointItinerary;
  final ItineraryType itineraryType;
  final bool newPointItinerary, enableEdit;

  const AddEditPointItineary(
      this.pointItinerary, this.itineraryType, this.newPointItinerary,
      {this.enableEdit = true, super.key});

  @override
  State<StatefulWidget> createState() => _AddEditPointItinerary();
}

class _AddEditPointItinerary extends State<AddEditPointItineary> {
  late int _step;
  late bool _retrieveFeature, _enableEdit;
  late String _comment, _label;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription;
  late GlobalKey<FormState> _globalKey;
  late List<Task> _tasks;
  late PointItinerary _pointItinerary;
  late ItineraryType _itineraryType;

  @override
  void initState() {
    _enableEdit = widget.enableEdit;
    _pointItinerary = widget.pointItinerary;
    _itineraryType = widget.itineraryType;
    _step = 0;
    _retrieveFeature = widget.newPointItinerary;
    _comment = _pointItinerary.hasFeature
        ? _pointItinerary.feature.getAComment(lang: MyApp.currentLang)
        : '';
    _label = _pointItinerary.hasFeature
        ? _pointItinerary.feature.getALabel(lang: MyApp.currentLang)
        : '';
    _globalKey = GlobalKey<FormState>();

    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    try {
      _quillController.document = Document.fromDelta(HtmlToDelta().convert(
          _pointItinerary.hasFeature &&
                  _pointItinerary.feature.comments.isNotEmpty
              ? _pointItinerary.feature.getAComment(lang: MyApp.currentLang)
              : _comment));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _comment =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
      });
    });
    _quillController.readOnly = !_enableEdit;
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);

    _tasks = [];

    super.initState();
  }

  void _onFocus() => setState(() => _hasFocus = _enableEdit && !_hasFocus);

  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final double lMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.siteIt),
            centerTitle: false,
          ),
          SliverVisibility(
            visible: _step == 0,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: _stepZero(),
                  ),
                ),
              ),
            ),
          ),
          SliverVisibility(
            visible: _step == 1,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: _stepOne(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List> _getFeature(String idFeature) {
    return http.get(Queries.getFeatureInfo(idFeature)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getTasks(String shortId) {
    return http.get(Queries.getTasks(shortId)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget _stepZero() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLoca.descripcionLugar,
          style: td.textTheme.titleLarge,
        ),
        Text(_enableEdit
            ? appLoca.descripcionLugarExplica
            : appLoca.descripcionLugarExplicaNoEdicion),
        SizedBox(height: 15),
        _retrieveFeature
            ? FutureBuilder<List>(
                future: _getFeature(_pointItinerary.feature.shortId),
                builder: (context, snapshot) {
                  if (!snapshot.hasError && snapshot.hasData) {
                    for (int i = 0, tama = snapshot.data!.length;
                        i < tama;
                        i++) {
                      Map provider = snapshot.data![i];
                      Map<String, dynamic>? data = provider['data'];
                      switch (provider["provider"]) {
                        case 'osm':
                          OSM osm = OSM(data);
                          for (PairLang l in osm.labels) {
                            _pointItinerary.feature.addLabelLang(l);
                          }
                          if (osm.image != null) {
                            _pointItinerary.feature.setThumbnail(
                                osm.image!.image,
                                osm.image!.hasLicense
                                    ? osm.image!.license
                                    : null);
                          }
                          for (PairLang d in osm.descriptions) {
                            _pointItinerary.feature.addCommentLang(d);
                          }
                          _pointItinerary.feature
                              .addProvider(provider['provider'], osm);
                          break;
                        case 'wikidata':
                          Wikidata? wikidata = Wikidata(data);
                          for (PairLang label in wikidata.labels) {
                            _pointItinerary.feature.addLabelLang(label);
                          }
                          for (PairLang comment in wikidata.descriptions) {
                            _pointItinerary.feature.addCommentLang(comment);
                          }
                          for (PairImage image in wikidata.images) {
                            _pointItinerary.feature.addImage(image.image,
                                license:
                                    image.hasLicense ? image.license : null);
                          }
                          _pointItinerary.feature
                              .addProvider(provider['provider'], wikidata);
                          break;
                        case 'jcyl':
                          JCyL jcyl = JCyL(data);
                          _pointItinerary.feature
                              .addCommentLang(jcyl.description);
                          _pointItinerary.feature
                              .addProvider(provider['provider'], jcyl);
                          break;
                        case 'esDBpedia':
                        case 'dbpedia':
                          DBpedia dbpedia = DBpedia(data, provider['provider']);
                          for (PairLang comment in dbpedia.descriptions) {
                            _pointItinerary.feature.addCommentLang(comment);
                          }
                          for (PairLang label in dbpedia.labels) {
                            _pointItinerary.feature.addLabelLang(label);
                          }
                          _pointItinerary.feature
                              .addProvider(provider['provider'], dbpedia);
                          break;
                        default:
                      }
                    }
                    List<PairLang> allComments =
                        _pointItinerary.feature.comments;
                    List<PairLang> comments = [];
                    // Prioridad a la información en el idioma del usuario
                    for (PairLang comment in allComments) {
                      if (comment.hasLang &&
                          comment.lang == MyApp.currentLang) {
                        comments.add(comment);
                      }
                    }
                    // Si no hay información en su idioma se le ofrece en inglés
                    if (comments.isEmpty) {
                      for (PairLang comment in allComments) {
                        if (comment.hasLang && comment.lang == 'en') {
                          comments.add(comment);
                        }
                      }
                    }
                    // Si tampoco se tiene en inglés se le pasa el primer comentario disponible
                    if (comments.isEmpty) {
                      comments.add(allComments.first);
                    }
                    if (comments.length > 1) {
                      comments.sort((PairLang a, PairLang b) =>
                          b.value.length.compareTo(a.value.length));
                    }
                    _retrieveFeature = false;
                    _label = _pointItinerary.feature
                        .getALabel(lang: MyApp.currentLang);
                    _comment = comments.first.value;
                    _quillController.document
                        .delete(0, _quillController.document.length);
                    _quillController.document.compose(
                        HtmlToDelta().convert(_comment), ChangeSource.silent);
                    return _formularioST();
                  } else {
                    return CircularProgressIndicator.adaptive();
                  }
                })
            : _formularioST(),
      ],
    );
  }

  Widget _formularioST() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _globalKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            enabled: _enableEdit,
            maxLines: 1,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLoca.tituloSite,
                hintText: appLoca.tituloSite,
                helperText: appLoca.requerido,
                hintMaxLines: 1,
                hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            initialValue:
                _pointItinerary.feature.getALabel(lang: MyApp.currentLang),
            onChanged: (String value) => setState(() => _label = value),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return appLoca.tituloNPIExplica;
              } else {
                return null;
              }
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.fromBorderSide(
                BorderSide(
                    color: _errorDescription
                        ? colorScheme.error
                        : _enableEdit
                            ? _hasFocus
                                ? colorScheme.primary
                                : colorScheme.onSurface
                            : td.disabledColor,
                    width: _hasFocus ? 2 : 1),
              ),
              color: colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${appLoca.descrNPI}*',
                    style: td.textTheme.bodySmall!.copyWith(
                      color: _errorDescription
                          ? colorScheme.error
                          : _enableEdit
                              ? _hasFocus
                                  ? colorScheme.primary
                                  : colorScheme.onSurface
                              : td.disabledColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Visibility(
                      visible: _enableEdit,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.maxWidth,
                              minWidth: Auxiliar.maxWidth),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                          ),
                          child: Auxiliar.quillToolbar(
                              _quillController, colorScheme),
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        maxHeight: 300,
                        minHeight: 150,
                      ),
                      child: QuillEditor.basic(
                        controller: _quillController,
                        config: QuillEditorConfig(
                          padding: EdgeInsets.all(5),
                        ),
                        focusNode: _focusNode,
                      ),
                    ),
                    Visibility(
                      visible: _errorDescription,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          appLoca.descrNPIExplica,
                          style: textTheme.bodySmall!.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
                direction: Axis.horizontal,
                spacing: 10,
                runSpacing: 5,
                alignment: WrapAlignment.end,
                children: [
                  Visibility(
                    visible: !widget.newPointItinerary,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      label: Text(
                        appLoca.removeResourcesIt,
                      ),
                      icon: Icon(
                        Icons.dangerous,
                      ),
                      onPressed: () {
                        _pointItinerary.removeFromIt = true;
                        context.pop(_pointItinerary);
                      },
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      bool sigue = _globalKey.currentState!.validate();
                      setState(() {
                        _errorDescription = _comment.trim() == '';
                      });
                      if (sigue && !_errorDescription) {
                        _pointItinerary.feature.resetLabels();
                        _pointItinerary.feature.resetComments();
                        _pointItinerary.feature
                            .addLabelLang(PairLang(MyApp.currentLang, _label));
                        _pointItinerary.feature.addCommentLang(
                            PairLang(MyApp.currentLang, _comment));
                        setState(() => _step = 1);
                      }
                    },
                    child: Text(appLoca.siguiente),
                  ),
                ]),
          )
        ],
      ),
    );
  }

  Widget _stepOne() {
    return _tasks.isEmpty
        ? FutureBuilder<List>(
            future: _getTasks(_pointItinerary.feature.shortId),
            builder: (context, snapshot) {
              if (!snapshot.hasError && snapshot.hasData) {
                Object data = snapshot.data!;
                if (data is List) {
                  for (Object task in data) {
                    try {
                      _tasks.add(Task(task,
                          idContainer: _pointItinerary.id,
                          containerType: ContainerTask.spatialThing));
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }
                }
                return _listasDeTareas();
              } else {
                return CircularProgressIndicator.adaptive();
              }
            })
        : _listasDeTareas();
  }

  Widget _listasDeTareas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _listaTareasNoSeleccionadas(),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            appLoca.tareasSeleccionadasLugar,
            style: textTheme.titleLarge,
          ),
        ),
        _listaTareasSeleccionadas(),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 5,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _step = 0;
                    });
                  },
                  label: Text(appLoca.atras),
                ),
                Visibility(
                  visible: !widget.newPointItinerary,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    label: Text(
                      appLoca.removeResourcesIt,
                    ),
                    icon: Icon(
                      Icons.dangerous,
                    ),
                    onPressed: () {
                      _pointItinerary.removeFromIt = true;
                      context.pop(_pointItinerary);
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    _pointItinerary.removeFromIt = false;
                    context.pop(_pointItinerary);
                  },
                  label: Text(appLoca.addResourcesIt),
                  icon: Icon(
                    Icons.add,
                  ),
                ),
              ]),
        )
      ],
    );
  }

  Widget _listaTareasNoSeleccionadas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    List<Widget> children = [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          appLoca.tareasNoSeleccionadasLugar,
          style: textTheme.titleLarge,
        ),
      )
    ];
    if (_tasks.isEmpty) {
      children.add(Text(appLoca.sinTareasAgrega));
    } else {
      for (Task task in _tasks) {
        children.add(Visibility(
          visible: !_pointItinerary.tasks.contains(task.id),
          child: _tarjetaTarea(task, colorScheme.onSurface, colorScheme.surface,
              labelAction:
                  _enableEdit ? appLoca.addTaskToIt : appLoca.addTaskToFeed,
              funAction: () => setState(() => _pointItinerary.addTask(task))),
        ));
      }

      children.add(Visibility(
          visible: _pointItinerary.hasLstTasks &&
              _pointItinerary.tasks.length == _tasks.length,
          child: Text(appLoca.todasTareasSeleccionadas)));
    }

    if (_enableEdit) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Align(
            alignment: Alignment.bottomRight,
            child: OutlinedButton.icon(
              label: Text(appLoca.taskFor),
              icon: Icon(Icons.add),
              onPressed: () async {
                Task? newTask = await Navigator.push(
                    context,
                    MaterialPageRoute<Task>(
                        builder: (BuildContext context) => FormTask(
                              Task.empty(
                                idContainer: _pointItinerary.id,
                                containerType: ContainerTask.spatialThing,
                              ),
                            ),
                        fullscreenDialog: true));
                if (newTask != null) {
                  setState(() => _tasks = []);
                }
              },
            ),
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _listaTareasSeleccionadas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    List<Widget> tSeleccionadas = [];
    if (_pointItinerary.hasLstTasks && _pointItinerary.tasksObj.isNotEmpty) {
      for (Task task in _pointItinerary.tasksObj) {
        tSeleccionadas.add(_tarjetaTarea(
            task, colorScheme.onPrimaryContainer, colorScheme.primaryContainer,
            labelAction: _enableEdit
                ? appLoca.removeTaskFromIt
                : appLoca.removeTaskFromFeed,
            funAction: () => setState(() => _pointItinerary.removeTask(task))));
      }
    }
    return !_pointItinerary.hasLstTasks || _pointItinerary.tasksObj.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(appLoca.sinTareasSeleccionadas),
          )
        : _itineraryType == ItineraryType.list
            ? ReorderableListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  Task task = _pointItinerary.tasksObj.elementAt(index);
                  return _tarjetaTarea(task, colorScheme.onPrimaryContainer,
                      colorScheme.primaryContainer,
                      key: Key('$index'),
                      labelAction: _enableEdit
                          ? appLoca.removeTaskFromIt
                          : appLoca.removeTaskFromFeed,
                      funAction: () =>
                          setState(() => _pointItinerary.removeTask(task)));
                },
                itemCount: _pointItinerary.hasLstTasks
                    ? _pointItinerary.tasksObj.length
                    : 0,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final Task item =
                        _pointItinerary.tasksObj.removeAt(oldIndex);
                    _pointItinerary.tasksObj.insert(newIndex, item);
                  });
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: tSeleccionadas,
              );
  }

  Widget _tarjetaTarea(Task task, Color color, Color background,
      {String? labelAction, VoidCallback? funAction, Key? key}) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(
            color: color,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(12))),
      color: background,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: Text(
                task.getALabel(lang: MyApp.currentLang),
                style: textTheme.titleMedium!.copyWith(color: color),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: HtmlWidget(
                task.getAComment(lang: MyApp.currentLang),
                textStyle: textTheme.bodyMedium!
                    .copyWith(overflow: TextOverflow.ellipsis, color: color),
              ),
            ),
            funAction == null || labelAction == null
                ? Container()
                : Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: funAction,
                      child: Text(
                        labelAction,
                      ),
                    ),
                  ),
          ]),
    );
  }
}

class InfoItinerary extends StatefulWidget {
  final String shortId;
  const InfoItinerary(this.shortId, {super.key});

  @override
  State<StatefulWidget> createState() => _InfoItinerary();
}

class _InfoItinerary extends State<InfoItinerary> {
  Future<Map<String, dynamic>> _getItinerary(idIt) {
    return http.get(Queries.getItinerary(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Future<Map<String, dynamic>> _getItineraryFeatures(idIt) {
    return http.get(Queries.getItineraryFeatures(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Future<List> _getItineraryTrack(idIt) {
    return http.get(Queries.getItineraryTrack(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getItineraryTasks(idIt) {
    return http.get(Queries.getItineraryTask(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getTasksFeature(idIt, idFeature) {
    return http.get(Queries.getTasksFeatureIt(idIt, idFeature)).then(
        (response) =>
            response.statusCode == 200 ? json.decode(response.body) : []);
  }

  final MapController _mapController = MapController();
  late Itinerary itinerary;
  late GlobalKey globalKey;
  late String? id;

  @override
  void initState() {
    // itinerary = Itinerary.empty();
    globalKey = GlobalKey();
    // itinerary.id = Auxiliar.shortId2Id(widget.shortId);
    id = Auxiliar.shortId2Id(widget.shortId);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widgetBody(),
      floatingActionButton: Visibility(
        key: globalKey,
        visible: !kIsWeb,
        child: FloatingActionButton.small(
            heroTag: Auxiliar.mainFabHero,
            onPressed: () async => Auxiliar.share(globalKey,
                '${ConfigXest.addClient}/home/itineraries/${widget.shortId}'),
            child: const Icon(Icons.share)),
      ),
    );
  }

  Widget widgetBody() {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    ColorScheme colorScheme = td.colorScheme;
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);

    if (id == null) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(AppLocalizations.of(context)!.noEncontrado))
        ],
      );
    }
    return FutureBuilder(
        future: _getItinerary(id),
        builder: (context, snapshot) {
          if (!snapshot.hasError && snapshot.hasData) {
            Object? bodyItinerary = snapshot.data;
            if (bodyItinerary != null &&
                bodyItinerary is Map<String, dynamic>) {
              if (bodyItinerary.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                        title: Text(AppLocalizations.of(context)!.noEncontrado))
                  ],
                );
              }
              bodyItinerary['id'] = id;
              itinerary = Itinerary(bodyItinerary);

              return CustomScrollView(slivers: [
                SliverAppBar(
                  title: Text(itinerary.getALabel(lang: MyApp.currentLang)),
                  floating: true,
                  centerTitle: false,
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 40),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(20),
                        margin: EdgeInsets.symmetric(horizontal: margenLateral),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: HtmlWidget(
                                itinerary.getAComment(lang: MyApp.currentLang),
                                textStyle: textTheme.bodyMedium!.copyWith(
                                    color: colorScheme.onSecondaryContainer),
                                factoryBuilder: () => MyWidgetFactory(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: margenLateral,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: FutureBuilder(
                            future: _getItineraryFeatures(itinerary.id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasError && snapshot.hasData) {
                                Object? bodyFeatures = snapshot.data;
                                if (bodyFeatures != null &&
                                    bodyFeatures is Map &&
                                    (bodyFeatures as Map<String, dynamic>)
                                        .containsKey('feature')) {
                                  if (bodyFeatures['feature'] is Map) {
                                    bodyFeatures['feature'] = [
                                      bodyFeatures['feature']
                                    ];
                                  }
                                  if (bodyItinerary.containsKey('track')) {
                                    return FutureBuilder(
                                        future:
                                            _getItineraryTrack(itinerary.id),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasError &&
                                              snapshot.hasData) {
                                            Object? bodyTrack = snapshot.data;
                                            if (bodyTrack != null &&
                                                bodyTrack is List) {
                                              return _generaMapa(
                                                  bodyItinerary: bodyItinerary,
                                                  bodyFeatures: bodyFeatures,
                                                  track: bodyTrack);
                                            } else {
                                              return Container();
                                            }
                                          } else {
                                            return snapshot.hasError
                                                ? Container()
                                                : const CircularProgressIndicator
                                                    .adaptive();
                                          }
                                        });
                                  } else {
                                    return _generaMapa(
                                        bodyItinerary: bodyItinerary,
                                        bodyFeatures: bodyFeatures);
                                  }
                                } else {
                                  return Container();
                                }
                              } else {
                                return snapshot.hasError
                                    ? Container()
                                    : const CircularProgressIndicator
                                        .adaptive();
                              }
                            }),
                      ),
                    ),
                  ),
                ),
              ]);

              // return FutureBuilder(
              //     future: _getItineraryFeatures(itinerary.id),
              //     builder: (context, snapshot) {
              //       if (!snapshot.hasError && snapshot.hasData) {
              //         Object? bodyFeatures = snapshot.data;
              //         if (bodyFeatures != null &&
              //             bodyFeatures is Map &&
              //             (bodyFeatures as Map<String, dynamic>)
              //                 .containsKey('feature')) {
              //           if (bodyFeatures['feature'] is Map) {
              //             bodyFeatures['feature'] = [bodyFeatures['feature']];
              //           }
              //           if (bodyItinerary.containsKey('track')) {
              //             return FutureBuilder(
              //                 future: _getItineraryTrack(itinerary.id),
              //                 builder: (context, snapshot) {
              //                   if (!snapshot.hasError && snapshot.hasData) {
              //                     Object? bodyTrack = snapshot.data;
              //                     if (bodyTrack != null && bodyTrack is List) {
              //                       return _generaMapa(
              //                           bodyItinerary: bodyItinerary,
              //                           bodyFeatures: bodyFeatures,
              //                           track: bodyTrack);
              //                     } else {
              //                       return Container();
              //                     }
              //                   } else {
              //                     return snapshot.hasError
              //                         ? Container()
              //                         : const CircularProgressIndicator
              //                             .adaptive();
              //                   }
              //                 });
              //           } else {
              //             return _generaMapa(
              //                 bodyItinerary: bodyItinerary,
              //                 bodyFeatures: bodyFeatures);
              //           }
              //         } else {
              //           return Container();
              //         }
              //       } else {
              //         return snapshot.hasError
              //             ? Container()
              //             : const CircularProgressIndicator.adaptive();
              //       }
              //     });
            } else {
              return CustomScrollView(
                  slivers: [SliverToBoxAdapter(child: Container())]);
            }
          } else {
            return snapshot.hasError
                ? CustomScrollView(
                    slivers: [SliverToBoxAdapter(child: Container())])
                : const CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child:
                            Center(child: CircularProgressIndicator.adaptive()))
                  ]);
          }
        });
  }

  Widget _generaMapa({
    required Map<String, dynamic> bodyItinerary,
    required Map<String, dynamic> bodyFeatures,
    List? track,
  }) {
    List points = bodyFeatures['feature'];
    List<PointItinerary> featuresIt = [];
    List<CHESTMarker> markers = [];
    List<LatLng> trackPoints = [];
    double sup = -90, inf = 90, izq = 180, der = -180;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    for (Map<String, dynamic> point in points) {
      PointItinerary pointItinerary = PointItinerary({'id': point['id']});
      pointItinerary.feature = Feature(point);
      sup = pointItinerary.feature.lat > sup ? pointItinerary.feature.lat : sup;
      inf = pointItinerary.feature.lat < inf ? pointItinerary.feature.lat : inf;
      izq =
          pointItinerary.feature.long < izq ? pointItinerary.feature.long : izq;
      der =
          pointItinerary.feature.long > der ? pointItinerary.feature.long : der;
      // if (point.containsKey('commentAlt')) {
      //   pointItinerary.altComments = point['commentAlt'];
      // }
      featuresIt.add(pointItinerary);
      markers.add(CHESTMarker(
        context,
        feature: pointItinerary.feature,
        icon: Center(
          child: Icon(
            Auxiliar.getIcon(pointItinerary.feature.spatialThingTypes),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        currentLayer: MapLayer.layer!,
        circleWidthBorder: 1,
        circleWidthColor: colorScheme.primary,
        circleContainerColor: colorScheme.primaryContainer,
      ));
    }
    if (track != null) {
      Track trackIt = Track.server({'track': track});
      trackIt.calculateBounds();
      itinerary.track = trackIt;
      for (var p in track) {
        if (p is Map<String, dynamic> &&
            p.containsKey('lat') &&
            p.containsKey('long')) {
          trackPoints.add(LatLng(p['lat'], p['long']));
        }
      }
      sup = itinerary.track!.northWest.latitude;
      inf = itinerary.track!.southEast.latitude;
      izq = itinerary.track!.northWest.longitude;
      der = itinerary.track!.southEast.longitude;
    }
    List<Widget> columnLstTasks = [];
    for (int i = 0, tama = featuresIt.length; i < tama; i++) {
      PointItinerary pointItinerary = featuresIt.elementAt(i);
      columnLstTasks.add(Container(
        padding: const EdgeInsets.all(20),
        margin: i != 0
            ? const EdgeInsets.symmetric(vertical: 5)
            : const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          // border: Border.all(color: colorScheme.tertiary),
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: FutureBuilder(
            future:
                _getTasksFeature(itinerary.id, pointItinerary.feature.shortId),
            builder: (context, snapshot) {
              if (!snapshot.hasError && snapshot.hasData) {
                Object? objTasks = snapshot.data;
                if (objTasks != null) {
                  if (objTasks is Map) {
                    objTasks = [objTasks];
                  }
                  if (objTasks is List) {
                    List<Task> lstTask = [];
                    for (Map o in objTasks) {
                      try {
                        Task t = Task(o);
                        lstTask.add(t);
                        featuresIt.elementAt(i).addTask(t);
                      } catch (error, stackTrace) {
                        if (ConfigXest.development) {
                          debugPrint(error.toString());
                        } else {
                          FirebaseCrashlytics.instance
                              .recordError(error, stackTrace);
                        }
                      }
                    }
                    itinerary.addPoints(featuresIt.elementAt(i));
                    List<Widget> lstTasks = [];
                    lstTasks.add(SizedBox(
                      width: double.infinity,
                      child: Text(
                        pointItinerary.feature
                            .getALabel(lang: MyApp.currentLang),
                        style: td.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ));
                    if (lstTask.isNotEmpty) {
                      lstTasks.add(Text(
                        '${AppLocalizations.of(context)!.nTaskAso}: ${lstTask.length}',
                        style: td.textTheme.bodyMedium!.copyWith(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ));
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lstTasks,
                      );
                    } else {
                      List<Widget> lstTasks = [];
                      lstTasks.add(Text(
                        pointItinerary.feature
                            .getALabel(lang: MyApp.currentLang),
                        style: td.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ));
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lstTasks,
                      );
                    }
                  }
                }
                return Container();
              } else {
                return snapshot.hasError
                    ? Container()
                    : const CircularProgressIndicator.adaptive();
              }
            }),
      ));
    }
    Size size = MediaQuery.of(context).size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 20),
          constraints: BoxConstraints(
            maxWidth: Auxiliar.maxWidth,
            maxHeight: 0.5 * size.height,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(alignment: Alignment.bottomRight, children: [
              FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: td.brightness == Brightness.light
                        ? Colors.white54
                        : Colors.black54,
                    maxZoom: MapLayer.maxZoom,
                    minZoom: MapLayer.minZoom,
                    initialCenter: const LatLng(41.662319, -4.705917),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                      pinchZoomThreshold: 2.0,
                    ),
                    onMapReady: () {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds(
                            LatLng(sup, izq),
                            LatLng(inf, der),
                          ),
                          padding: const EdgeInsets.all(48),
                        ),
                      );
                    },
                  ),
                  children: [
                    MapLayer.tileLayerWidget(brightness: td.brightness),
                    MapLayer.atributionWidget(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trackPoints,
                          pattern: const StrokePattern.dotted(),
                          color: MapLayer.layer != Layers.satellite
                              ? colorScheme.tertiary
                              : Colors.white,
                          strokeWidth: 5,
                        )
                      ],
                    ),
                    MarkerLayer(
                      markers: markers,
                      rotate: true,
                    ),
                  ]),
              Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 10, top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: UserXEST.userXEST.isNotGuest &&
                              UserXEST.userXEST.crol == Rol.user
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      CarryOutIt(itinerary),
                                  fullscreenDialog: true,
                                ),
                              );
                            }
                          : UserXEST.userXEST.isGuest
                              ? () {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .iniciaParaRealizar),
                                  ));
                                }
                              : () {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .cambiaEstudiante),
                                  ));
                                },
                      label: Text(AppLocalizations.of(context)!.iniciar),
                      icon: Icon(Icons.play_arrow_rounded,
                          color: colorScheme.onPrimaryContainer),
                    ),
                    bodyItinerary.containsKey('tasksIt')
                        ? widgetTasksIt()
                        : Container(),
                  ],
                ),
              ),
            ]),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnLstTasks,
        ),
      ],
    );
  }

  Widget widgetTasksIt() {
    return FutureBuilder(
      future: _getItineraryTasks(itinerary.id),
      builder: ((context, snapshot) {
        if (!snapshot.hasError && snapshot.hasData) {
          Object? bodyTasksIt = snapshot.data;
          if (bodyTasksIt != null) {
            if (bodyTasksIt is Map) {
              bodyTasksIt = [bodyTasksIt];
            }
            if (bodyTasksIt is List) {
              List<Task> tasksIt = [];
              for (Map b in bodyTasksIt) {
                try {
                  Task t = Task(
                    b,
                    containerType: ContainerTask.itinerary,
                    idContainer: itinerary.id,
                  );
                  tasksIt.add(t);
                  itinerary.addTask(t);
                } catch (error, stackTrace) {
                  if (ConfigXest.development) {
                    debugPrint(error.toString());
                  } else {
                    FirebaseCrashlytics.instance.recordError(error, stackTrace);
                  }
                }
              }
              ThemeData td = Theme.of(context);
              ColorScheme colorScheme = td.colorScheme;
              TextTheme textTheme = td.textTheme;
              AppLocalizations appLoca = AppLocalizations.of(context)!;
              List<Widget> widgetMBS = [];
              for (Task t in tasksIt) {
                widgetMBS.add(
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.getALabel(lang: MyApp.currentLang),
                              style: textTheme.bodyMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          HtmlWidget(
                            t.getAComment(lang: MyApp.currentLang),
                            factoryBuilder: () => MyWidgetFactory(),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
              return FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => Auxiliar.showMBS(
                  context,
                  DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.2,
                    maxChildSize: 1,
                    expand: false,
                    builder: (context, controller) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            itemCount: widgetMBS.length,
                            itemBuilder: ((context, index) =>
                                widgetMBS.elementAt(index)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                label: Text(appLoca.tareasTodoIt),
              );
            }
          }
        }
        return Container();
      }),
    );
  }
}

class CarryOutIt extends StatefulWidget {
  final Itinerary itinerary;
  const CarryOutIt(this.itinerary, {super.key});
  @override
  State<CarryOutIt> createState() => _CarryOutIt();
}

class _CarryOutIt extends State<CarryOutIt> {
  final MapController _mapController = MapController();
  late List<Marker> _markers;
  late List<CircleMarker> _userCirclePostion;
  late List<LatLng> _pointsTrack;
  late LatLng _locationUser;
  // StreamSubscription<Position>? _strLocationUser;
  late List<double> _distances;
  final double _distanciaTarea = 50;
  late List<Widget> _widgetMBS;

  late bool _tareaPulsada;

  @override
  void initState() {
    super.initState();
    _locationUser = LocationUser.lastPosition is Position
        ? LatLng(LocationUser.lastPosition!.latitude,
            LocationUser.lastPosition!.longitude)
        : const LatLng(0, 0);
    _markers = [];
    _userCirclePostion = [];
    _pointsTrack = [];
    _distances = [];

    _tareaPulsada = false;

    for (int i = 0, tama = widget.itinerary.points.length; i < tama; i++) {
      _distances.add(double.infinity);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    _widgetMBS = [];
    for (Task t in widget.itinerary.tasks) {
      _widgetMBS.add(
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.getALabel(lang: MyApp.currentLang),
                    style: td.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                HtmlWidget(
                  t.getAComment(lang: MyApp.currentLang),
                  factoryBuilder: () => MyWidgetFactory(),
                )
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itinerary.getALabel(lang: MyApp.currentLang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
      ),
      body: Stack(
        alignment: Alignment.bottomRight,
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                maxZoom: MapLayer.maxZoom,
                minZoom: MapLayer.minZoom,
                initialCameraFit: CameraFit.bounds(
                  bounds: widget.itinerary.latLngBounds,
                  padding: const EdgeInsets.all(48),
                ),
                keepAlive: false,
                onMapReady: () {
                  _askLocation();
                  _pintaMarcadores();
                  // Size size = MediaQuery.of(context).size;
                  // double mW = Auxiliar.maxWidth * 0.5;
                  // double mH = size.width > size.height
                  //     ? size.height * 0.5
                  //     : size.height / 3;
                  // for (int i = 0, tama = widget.itinerary.points.length;
                  //     i < tama;
                  //     i++) {
                  //   PointItinerary pi = widget.itinerary.points.elementAt(i);
                  //   List<Widget> lstCardTareas = [];
                  //   if (pi.hasLstTasks) {
                  //     List<String> ids = [];
                  //     for (Task t in pi.tasksObj) {
                  //       if (!ids.contains(t.id)) {
                  //         ids.add(t.id);
                  //         lstCardTareas.add(
                  //           Card(
                  //             elevation: 0,
                  //             shape: RoundedRectangleBorder(
                  //                 side: BorderSide(
                  //                   color: td.colorScheme.outline,
                  //                 ),
                  //                 borderRadius: const BorderRadius.all(
                  //                     Radius.circular(12))),
                  //             child: Column(
                  //               mainAxisSize: MainAxisSize.min,
                  //               crossAxisAlignment: CrossAxisAlignment.start,
                  //               children: [
                  //                 Container(
                  //                   padding: const EdgeInsets.only(
                  //                       top: 24,
                  //                       bottom: 16,
                  //                       right: 16,
                  //                       left: 16),
                  //                   child: Text(
                  //                       t.getALabel(lang: MyApp.currentLang)),
                  //                 ),
                  //                 Align(
                  //                   alignment: Alignment.centerRight,
                  //                   child: Padding(
                  //                     padding: const EdgeInsets.only(
                  //                         top: 16,
                  //                         bottom: 8,
                  //                         right: 16,
                  //                         left: 16),
                  //                     child: FilledButton(
                  //                       onPressed: () {
                  //                         GoRouter.of(context).go(
                  //                             '/home/features/${pi.feature.shortId}/tasks/${Auxiliar.id2shortId(t.id)}',
                  //                             extra: [
                  //                               null,
                  //                               null,
                  //                               null,
                  //                               false,
                  //                               true
                  //                             ]);
                  //                       },
                  //                       child: Text(
                  //                           AppLocalizations.of(context)!
                  //                               .realizaTareaBt),
                  //                     ),
                  //                   ),
                  //                 )
                  //               ],
                  //             ),
                  //           ),
                  //         );
                  //       }
                  //     }
                  //   }
                  //   _markers.add(CHESTMarker(
                  //     context,
                  //     feature: pi.feature,
                  //     icon: Center(
                  //       child: Icon(
                  //         Auxiliar.getIcon(pi.feature.spatialThingTypes),
                  //         color: colorScheme.onPrimaryContainer,
                  //       ),
                  //     ),
                  //     circleWidthBorder: 2,
                  //     circleWidthColor: colorScheme.primary,
                  //     circleContainerColor: colorScheme.primaryContainer,
                  //     currentLayer: MapLayer.layer!,
                  //     onTap: () {
                  //       Auxiliar.showMBS(
                  //         context,
                  //         DraggableScrollableSheet(
                  //           initialChildSize: 0.7,
                  //           minChildSize: 0.2,
                  //           maxChildSize: 1,
                  //           expand: false,
                  //           builder: (context, controller) => Column(
                  //             mainAxisSize: MainAxisSize.min,
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               Expanded(
                  //                 child: ListView.builder(
                  //                   controller: controller,
                  //                   itemCount: 5,
                  //                   itemBuilder: (context, index) => Padding(
                  //                     padding:
                  //                         const EdgeInsets.only(bottom: 10),
                  //                     child: [
                  //                       Text(
                  //                         pi.feature.getALabel(
                  //                             lang: MyApp.currentLang),
                  //                         style: td.textTheme.titleLarge!,
                  //                         textAlign: TextAlign.center,
                  //                       ),
                  //                       pi.feature.hasThumbnail
                  //                           ? ImageNetwork(
                  //                               image:
                  //                                   pi.feature.thumbnail.image,
                  //                               height: mH,
                  //                               width: mW,
                  //                               duration: 0,
                  //                               onPointer: true,
                  //                               fitWeb: BoxFitWeb.cover,
                  //                               fitAndroidIos: BoxFit.cover,
                  //                               borderRadius:
                  //                                   BorderRadius.circular(25),
                  //                               curve: Curves.easeIn,
                  //                               onTap: () async {
                  //                                 Navigator.push(
                  //                                   context,
                  //                                   MaterialPageRoute<void>(
                  //                                       builder: (BuildContext
                  //                                               context) =>
                  //                                           FullScreenImage(
                  //                                               pi.feature
                  //                                                   .thumbnail,
                  //                                               local: false),
                  //                                       fullscreenDialog:
                  //                                           false),
                  //                                 );
                  //                               },
                  //                               onError: const Icon(
                  //                                   Icons.image_not_supported),
                  //                               onLoading:
                  //                                   const CircularProgressIndicator
                  //                                       .adaptive(),
                  //                             )
                  //                           : Container(),
                  //                       Column(
                  //                         mainAxisSize: MainAxisSize.min,
                  //                         crossAxisAlignment:
                  //                             CrossAxisAlignment.start,
                  //                         children: [
                  //                           HtmlWidget(
                  //                             pi.feature.getAComment(
                  //                                 lang: MyApp.currentLang),
                  //                             factoryBuilder: () =>
                  //                                 MyWidgetFactory(),
                  //                           ),
                  //                           // TODO TTS
                  //                           // Padding(
                  //                           //   padding:
                  //                           //       const EdgeInsets.only(top: 5),
                  //                           //   child: Align(
                  //                           //     alignment:
                  //                           //         Alignment.centerRight,
                  //                           //     child: TextButton(
                  //                           //       child: Text(
                  //                           //         AppLocalizations.of(
                  //                           //                 context)!
                  //                           //             .escuchar,
                  //                           //         style: td
                  //                           //             .textTheme.bodyMedium!
                  //                           //             .copyWith(
                  //                           //           color:
                  //                           //               colorScheme.primary,
                  //                           //         ),
                  //                           //       ),
                  //                           //       onPressed: () async {
                  //                           //         if (_isPlaying) {
                  //                           //           setState(() =>
                  //                           //               _isPlaying = false);
                  //                           //           _stop();
                  //                           //         } else {
                  //                           //           setState(() =>
                  //                           //               _isPlaying = true);
                  //                           //           List<String> lstTexto =
                  //                           //               Auxiliar.frasesParaTTS(pi
                  //                           //                   .feature
                  //                           //                   .getAComment(
                  //                           //                       lang: MyApp
                  //                           //                           .currentLang));
                  //                           //           for (String leerParte
                  //                           //               in lstTexto) {
                  //                           //             await _speak(leerParte);
                  //                           //           }
                  //                           //           setState(() =>
                  //                           //               _isPlaying = false);
                  //                           //         }
                  //                           //       },
                  //                           //     ),
                  //                           //   ),
                  //                           // )
                  //                         ],
                  //                       ),
                  //                       Visibility(
                  //                         visible: Auxiliar.distance(
                  //                                 pi.feature.point,
                  //                                 _locationUser) >
                  //                             _distanciaTarea,
                  //                         child: Text(
                  //                           appLoca.distanceItTask(
                  //                               Auxiliar.distance(
                  //                                           pi.feature.point,
                  //                                           _locationUser) >
                  //                                       1000
                  //                                   ? ((Auxiliar.distance(
                  //                                                   pi.feature
                  //                                                       .point,
                  //                                                   _locationUser) -
                  //                                               _distanciaTarea) /
                  //                                           1000)
                  //                                       .toStringAsFixed(2)
                  //                                   : Auxiliar.distance(
                  //                                           pi.feature.point,
                  //                                           _locationUser) -
                  //                                       _distanciaTarea,
                  //                               Auxiliar.distance(
                  //                                           pi.feature.point,
                  //                                           _locationUser) >
                  //                                       1000
                  //                                   ? 'km'
                  //                                   : 'm'),
                  //                           style: td.textTheme.bodyMedium!
                  //                               .copyWith(
                  //                                   fontWeight:
                  //                                       FontWeight.bold),
                  //                         ),
                  //                       ),
                  //                       Visibility(
                  //                         visible: Auxiliar.distance(
                  //                                 pi.feature.point,
                  //                                 _locationUser) <=
                  //                             _distanciaTarea,
                  //                         child: Column(
                  //                           mainAxisSize: MainAxisSize.min,
                  //                           children: lstCardTareas,
                  //                         ),
                  //                       ),
                  //                     ].elementAt(index),
                  //                   ),
                  //                 ),
                  //               )
                  //             ],
                  //           ),
                  //         ),
                  //       );
                  //     },
                  //   ));
                  // }
                  if (widget.itinerary.track != null) {
                    for (LatLngCHEST d in widget.itinerary.track!.points) {
                      _pointsTrack.add(d.toLatLng);
                    }
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  pinchZoomThreshold: 2.0,
                ),
              ),
              children: [
                MapLayer.tileLayerWidget(brightness: td.brightness),
                MapLayer.atributionWidget(),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pointsTrack,
                      pattern: const StrokePattern.dotted(),
                      color: MapLayer.layer != Layers.satellite
                          ? colorScheme.tertiary
                          : Colors.white,
                      strokeWidth: 5,
                    )
                  ],
                ),
                CircleLayer(circles: _userCirclePostion),
                MarkerLayer(
                  markers: _markers,
                  rotate: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 10, top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: null,
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
                        ],
                      ),
                      title: appLoca.tipoMapa),
                  // child: const Icon(Icons.layers),
                  child: Icon(
                    Icons.settings_applications,
                    semanticLabel: appLoca.ajustes,
                  ),
                ),
                const Visibility(
                  visible: kIsWeb,
                  child: SizedBox(height: 10),
                ),
                Visibility(
                  visible: kIsWeb,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () {
                      _mapController.move(
                          _mapController.camera.center,
                          min(_mapController.camera.zoom + 1,
                              MapLayer.maxZoom));
                    },
                    tooltip: appLoca.aumentaZumShort,
                    child: Icon(
                      Icons.zoom_in,
                      semanticLabel: appLoca.aumentaZumShort,
                    ),
                  ),
                ),
                const Visibility(
                  visible: kIsWeb,
                  child: SizedBox(height: 5),
                ),
                Visibility(
                  visible: kIsWeb,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () {
                      _mapController.move(
                          _mapController.camera.center,
                          max(_mapController.camera.zoom - 1,
                              MapLayer.minZoom));
                    },
                    tooltip: appLoca.disminuyeZum,
                    child: Icon(
                      Icons.zoom_out,
                      semanticLabel: appLoca.disminuyeZum,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    _mapController.move(
                        _locationUser, _mapController.camera.zoom);
                  },
                  child: const Icon(Icons.location_searching),
                ),
                const SizedBox(height: 10),
                _widgetMBS.isNotEmpty
                    ? FloatingActionButton.extended(
                        heroTag: null,
                        onPressed: () => Auxiliar.showMBS(
                          context,
                          DraggableScrollableSheet(
                            initialChildSize: 0.7,
                            minChildSize: 0.2,
                            maxChildSize: 1,
                            expand: false,
                            builder: (context, controller) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: controller,
                                    itemCount: _widgetMBS.length,
                                    itemBuilder: ((context, index) =>
                                        _widgetMBS.elementAt(index)),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        label: Text(AppLocalizations.of(context)!.tareasTodoIt),
                      )
                    : Container()
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _askLocation() async {
    // LocationSettings locationSettings =
    //     await Auxiliar.checkPermissionsLocation(context, defaultTargetPlatform);
    bool hasPermissions = await MyApp.locationUser.checkPermissions(context);
    if (hasPermissions) {
      MyApp.locationUser.positionUser!.listen((Position point) {
        setState(() {
          _locationUser = LatLng(point.latitude, point.longitude);
          _distances = _calculeDistances();
          _userCirclePostion = [];
          _userCirclePostion.add(CircleMarker(
              point: _locationUser,
              radius: _distanciaTarea,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              useRadiusInMeter: true,
              borderColor: Colors.white,
              borderStrokeWidth: 2));
        });
      }, cancelOnError: true);
    }
    // Geolocator.getPositionStream(locationSettings: locationSettings)
    //     .listen((Position? point) async {
    //   setState(() {
    //     _locationUser = LatLng(point!.latitude, point.longitude);
    //     _distances = _calculeDistances();
    //     _userCirclePostion = [];
    //     _userCirclePostion.add(CircleMarker(
    //         point: _locationUser,
    //         radius: _distanciaTarea,
    //         color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
    //         useRadiusInMeter: true,
    //         borderColor: Colors.white,
    //         borderStrokeWidth: 2));
    //   });
    // });
  }

  List<double> _calculeDistances() {
    List<double> out = [];
    for (int i = 0, tama = widget.itinerary.points.length; i < tama; i++) {
      Feature f = widget.itinerary.points.elementAt(i).feature;
      out.add(Auxiliar.distance(f.point, _locationUser));
    }
    return out;
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

  //TODO Volver a pintar los marcadores
  void _changeLayer(Layers layer) async {
    setState(() {
      MapLayer.layer = layer;
      // Auxiliar.updateMaxZoom();
      if (_mapController.camera.zoom > MapLayer.maxZoom) {
        _mapController.move(_mapController.camera.center, MapLayer.maxZoom);
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
      }).onError((error, stackTrace) {
        if (mounted) Navigator.pop(context);
      });
    } else {
      Navigator.pop(context);
    }
    _pintaMarcadores();
  }

  void _pintaMarcadores() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    Size size = MediaQuery.of(context).size;
    double mW = Auxiliar.maxWidth * 0.5;
    double mH = size.width > size.height ? size.height * 0.5 : size.height / 3;
    List<CHESTMarker> markers = [];
    for (int i = 0, tama = widget.itinerary.points.length; i < tama; i++) {
      PointItinerary pi = widget.itinerary.points.elementAt(i);
      List<Widget> lstCardTareas = [];
      if (pi.hasLstTasks) {
        List<String> ids = [];
        for (Task t in pi.tasksObj) {
          if (!ids.contains(t.id)) {
            ids.add(t.id);
            lstCardTareas.add(
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: td.colorScheme.outline,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(12))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                          top: 24, bottom: 16, right: 16, left: 16),
                      child: Text(t.getALabel(lang: MyApp.currentLang)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 16, bottom: 8, right: 16, left: 16),
                        child: FilledButton(
                          onPressed: _tareaPulsada
                              ? null
                              : () async {
                                  ScaffoldMessengerState smState =
                                      ScaffoldMessenger.of(context);
                                  setState(() => _tareaPulsada = true);
                                  Map mapTask = await _getLearningTask(
                                      shortIdTask: Auxiliar.id2shortId(t.id)!,
                                      shortIdFeature: pi.feature.shortId);
                                  mapTask['task'] = t.id;
                                  setState(() => _tareaPulsada = false);
                                  if (mapTask.isNotEmpty && context.mounted) {
                                    Task task = Task(mapTask,
                                        containerType:
                                            ContainerTask.spatialThing,
                                        idContainer: pi.feature.id);
                                    Navigator.pop(context);
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              COTaskItinerary(pi.feature, task),
                                          fullscreenDialog: true),
                                    );
                                  } else {
                                    smState.clearSnackBars();
                                    smState.showSnackBar(SnackBar(
                                      content: Text(appLoca.tareaNoEncontrada),
                                    ));
                                  }
                                },
                          child: Text(
                              AppLocalizations.of(context)!.realizaTareaBt),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        }
      }
      markers.add(CHESTMarker(
        context,
        feature: pi.feature,
        icon: Center(
          child: Icon(
            Auxiliar.getIcon(pi.feature.spatialThingTypes),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        circleWidthBorder: 2,
        circleWidthColor: colorScheme.primary,
        circleContainerColor: colorScheme.primaryContainer,
        currentLayer: MapLayer.layer!,
        onTap: () {
          Auxiliar.showMBS(
            context,
            DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.2,
              maxChildSize: 1,
              expand: false,
              builder: (context, controller) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: 5,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: [
                          Text(
                            pi.feature.getALabel(lang: MyApp.currentLang),
                            style: td.textTheme.titleLarge!,
                            textAlign: TextAlign.center,
                          ),
                          pi.feature.hasThumbnail
                              ? ImageNetwork(
                                  image: pi.feature.thumbnail.image,
                                  height: mH,
                                  width: mW,
                                  duration: 0,
                                  onPointer: true,
                                  fitWeb: BoxFitWeb.cover,
                                  fitAndroidIos: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(25),
                                  curve: Curves.easeIn,
                                  onTap: () async {
                                    List<PairImage> imagenes =
                                        pi.feature.image.isNotEmpty
                                            ? pi.feature.image
                                            : [pi.feature.thumbnail];
                                    int indice = imagenes.indexWhere(
                                        (PairImage p) =>
                                            p.image ==
                                            pi.feature.thumbnail.image);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              FullScreenImage.list(
                                                imagenes,
                                                initialIndex:
                                                    indice > -1 ? indice : 0,
                                                local: false,
                                              ),
                                          fullscreenDialog: false),
                                    );
                                  },
                                  onError:
                                      const Icon(Icons.image_not_supported),
                                  onLoading: const CircularProgressIndicator
                                      .adaptive(),
                                )
                              : Container(),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HtmlWidget(
                                pi.feature.getAComment(lang: MyApp.currentLang),
                                factoryBuilder: () => MyWidgetFactory(),
                              ),
                              // TODO TTS
                              // Padding(
                              //   padding:
                              //       const EdgeInsets.only(top: 5),
                              //   child: Align(
                              //     alignment:
                              //         Alignment.centerRight,
                              //     child: TextButton(
                              //       child: Text(
                              //         AppLocalizations.of(
                              //                 context)!
                              //             .escuchar,
                              //         style: td
                              //             .textTheme.bodyMedium!
                              //             .copyWith(
                              //           color:
                              //               colorScheme.primary,
                              //         ),
                              //       ),
                              //       onPressed: () async {
                              //         if (_isPlaying) {
                              //           setState(() =>
                              //               _isPlaying = false);
                              //           _stop();
                              //         } else {
                              //           setState(() =>
                              //               _isPlaying = true);
                              //           List<String> lstTexto =
                              //               Auxiliar.frasesParaTTS(pi
                              //                   .feature
                              //                   .getAComment(
                              //                       lang: MyApp
                              //                           .currentLang));
                              //           for (String leerParte
                              //               in lstTexto) {
                              //             await _speak(leerParte);
                              //           }
                              //           setState(() =>
                              //               _isPlaying = false);
                              //         }
                              //       },
                              //     ),
                              //   ),
                              // )
                            ],
                          ),
                          Visibility(
                            visible: Auxiliar.distance(
                                    pi.feature.point, _locationUser) >
                                _distanciaTarea,
                            child: Text(
                              appLoca.distanceItTask(
                                  Auxiliar.distance(
                                              pi.feature.point, _locationUser) >
                                          1000
                                      ? ((Auxiliar.distance(pi.feature.point,
                                                      _locationUser) -
                                                  _distanciaTarea) /
                                              1000)
                                          .toStringAsFixed(2)
                                      : Auxiliar.distance(
                                              pi.feature.point, _locationUser) -
                                          _distanciaTarea,
                                  Auxiliar.distance(
                                              pi.feature.point, _locationUser) >
                                          1000
                                      ? 'km'
                                      : 'm'),
                              style: td.textTheme.bodyMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Visibility(
                            visible: Auxiliar.distance(
                                    pi.feature.point, _locationUser) <=
                                _distanciaTarea,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: lstCardTareas,
                            ),
                          ),
                        ].elementAt(index),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ));
    }
    setState(() => _markers = markers);
  }

  @override
  void dispose() {
    MyApp.locationUser.dispose();
    super.dispose();
  }

  Future<Map> _getLearningTask(
      {required String shortIdFeature, required String shortIdTask}) async {
    Map data = await http
        .get(Queries.getTask(shortIdFeature, shortIdTask))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : {})
        .onError((error, stackTrace) => {});
    return data;
  }
}
