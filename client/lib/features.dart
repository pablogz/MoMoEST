import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:momoest/util/helpers/providers/docomomo.dart';
import 'package:momoest/util/map_layer.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_network/image_network.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:string_similarity/string_similarity.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/answers.dart';
import 'package:momoest/notes.dart';
import 'package:momoest/photo_vote.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/full_screen.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/util/helpers/widget_facto.dart';
import 'package:momoest/main.dart';
import 'package:momoest/tasks.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/chest_marker.dart';
import 'package:momoest/util/helpers/providers/dbpedia.dart';
import 'package:momoest/util/helpers/providers/jcyl.dart';
import 'package:momoest/util/helpers/providers/osm.dart';
import 'package:momoest/util/helpers/providers/wikidata.dart';
import 'package:momoest/util/helpers/providers/local_repo.dart';
// import 'package:momoest/util/helpers/auxiliar_mobile.dart'
//     if (dart.library.html) 'package:chest/util/helpers/auxiliar_web.dart';

class InfoFeature extends StatefulWidget {
  final Position? locationUser;
  final Widget? iconMarker;
  final String? shortId;

  const InfoFeature({
    required this.shortId,
    this.locationUser,
    this.iconMarker,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _InfoFeature();
}

class _InfoFeature extends State<InfoFeature>
    with SingleTickerProviderStateMixin {
  late Feature feature;
  late bool todoTexto, mostrarFabProfe, _requestTask;
  late LatLng? pointUser;
  // late StreamSubscription<Position> _strLocationUser;
  late double distance;
  late String distanceString;
  final MapController _mapController = MapController();
  final CarouselController _carouselController = CarouselController();
  int _carouselIndex = 0;
  List<Task> tasks = [];
  // Filtros de la lista de tareas: tipos de tarea y alias de autores elegidos
  final Set<AnswerType> _filterTypes = {};
  final Set<String> _filterAuthors = {};
  late List<String> tabs;
  late TabController _tabController;
  late Widget? _fab;

  @override
  void initState() {
    tabs = <String>['info', 'tasks', 'sources'];
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      _updateFab(_tabController.index);
    });
    _fab = null;
    Feature? p = MapData.getFeatureCache(widget.shortId!);
    feature = p ?? Feature.empty(widget.shortId!);
    todoTexto = false;
    _requestTask = true;
    pointUser = (widget.locationUser != null && widget.locationUser is Position)
        ? LatLng(widget.locationUser!.latitude, widget.locationUser!.longitude)
        : null;
    mostrarFabProfe = UserXEST.userXEST.crol == Rol.teacher ||
        UserXEST.userXEST.crol == Rol.admin;
    distanceString = '';
    super.initState();
    if (p == null) {
      getFeature();
    }
  }

  @override
  void dispose() async {
    if (pointUser != null) {
      MyApp.locationUser.dispose();
    }
    _tabController.removeListener(() {
      _updateFab(_tabController.index);
    });
    _tabController.dispose();
    _mapController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> getFeature() async {
    await http
        .get(Queries.getFeatureInfo(widget.shortId!))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : null)
        .then((providers) {
      if (providers != null) {
        for (Map provider in providers) {
          Map data = provider['data'];
          feature = Feature(data);
          feature.addProvider(provider['provider'], data);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error'),
            duration: Duration(milliseconds: 1500),
          ));

          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _fab = widgetFab(index: _tabController.index);
    Size size = MediaQuery.of(context).size;
    double pLateral = size.width > Auxiliar.maxWidth
        ? (size.width - Auxiliar.maxWidth) / 2
        : 0;
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        floatingActionButton: _fab,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: widgetAppbar(size, innerBoxIsScrolled),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: tabs.map(
              (String name) {
                return SafeArea(
                  top: false,
                  bottom: false,
                  minimum: EdgeInsets.symmetric(
                      horizontal: Auxiliar.getLateralMargin(size.width)),
                  child: Builder(builder: (BuildContext context) {
                    return CustomScrollView(
                        key: PageStorageKey<String>(name),
                        slivers: [
                          SliverOverlapInjector(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(
                                right: pLateral, left: pLateral),
                            sliver: name == tabs.elementAt(0)
                                ? widgetBody(size)
                                : name == tabs.elementAt(1)
                                    // ? widgetGridTasks(size)
                                    ? widgetListTasks(size)
                                    : fuentesInfo(),
                          ),
                        ]);
                  }),
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }

  void _updateFab(int index) {
    setState(() {
      // _fab = widgetFab(index: index);
    });
  }

  Widget? widgetFab({int index = 0}) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    GlobalKey globalKey = GlobalKey();
    switch (index) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Notas personales vinculadas a este lugar: el mismo botón abre la
            // lista de notas del lugar, desde donde se pueden crear más.
            Visibility(
              visible: UserXEST.userXEST.isNotGuest,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: appLoca!.notasLugar,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => InfoNotes(
                          idPlace: feature.id,
                          labelPlace:
                              feature.getALabel(lang: MyApp.currentLang),
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.edit_note),
                ),
              ),
            ),
            Visibility(
              visible: !kIsWeb,
              child: FloatingActionButton.small(
                  key: globalKey,
                  heroTag: mostrarFabProfe ? null : Auxiliar.mainFabHero,
                  onPressed: () async => Auxiliar.share(globalKey,
                      '${ConfigXest.addClient}/home/features/${feature.shortId}'),
                  child: const Icon(Icons.share)),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == UserXEST.userXEST.iri,
              child: const SizedBox(
                height: 12,
              ),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == UserXEST.userXEST.iri,
              child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: appLoca.borrarPOI,
                  onPressed: () async => borraFeature(appLoca),
                  child: const Icon(Icons.delete)),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == UserXEST.userXEST.iri,
              child: SizedBox(
                height: 24,
              ),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == UserXEST.userXEST.iri,
              child: FloatingActionButton.extended(
                heroTag: null,
                tooltip: appLoca.editarPOI,
                onPressed: () async {
                  Feature? f = await Navigator.push(
                      context,
                      MaterialPageRoute<Feature>(
                        builder: (BuildContext context) =>
                            FormFeature(feature, false),
                        fullscreenDialog: true,
                      ));
                  if (f != null) {
                    setState(() => feature = f);
                  }
                },
                icon: const Icon(Icons.edit),
                label: Text(appLoca.editarPOI),
              ),
            ),
          ],
        );
      case 1:
        return mostrarFabProfe
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                tooltip: appLoca!.nTask,
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                      context,
                      MaterialPageRoute<Task>(
                          builder: (BuildContext context) =>
                              FormTask(Task.empty(
                                containerType: ContainerTask.spatialThing,
                                idContainer: feature.id,
                              )),
                          fullscreenDialog: true));
                },
                label: Text(appLoca.nTask),
                icon: const Icon(Icons.add))
            : null;
      default:
        return null;
    }
  }

  void borraFeature(AppLocalizations appLoca) async {
    bool? borrarFeature = await Auxiliar.deleteDialog(
        context, appLoca.borrarPOI, appLoca.preguntaBorrarPOI);
    if (borrarFeature != null && borrarFeature) {
      http.delete(Queries.deleteFeature(feature.id), headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
      }).then((response) async {
        ScaffoldMessengerState? sMState =
            mounted ? ScaffoldMessenger.of(context) : null;
        switch (response.statusCode) {
          case 200:
            // MapData.removeFeatureFromTile(feature);
            MapData.resetLocalCache();
            if (!ConfigXest.development) {
              await FirebaseAnalytics.instance.logEvent(
                name: "deletedFeature",
                parameters: {"iri": feature.shortId},
              ).then(
                (value) {
                  if (sMState != null) {
                    sMState.clearSnackBars();
                    sMState.showSnackBar(
                      SnackBar(content: Text(appLoca.poiBorrado)),
                    );
                  }
                  if (mounted) context.pop(true);
                },
              ).onError((error, stackTrace) {
                if (sMState != null) {
                  sMState.clearSnackBars();
                  sMState.showSnackBar(
                    SnackBar(
                        content: Text(
                      appLoca.poiBorrado,
                    )),
                  );
                }
                if (mounted) Navigator.pop(context, true);
              });
            } else {
              if (sMState != null) {
                sMState.clearSnackBars();
                sMState.showSnackBar(SnackBar(
                    content: Text(
                  appLoca.poiBorrado,
                )));
              }
              if (mounted) context.pop(true);
            }
            break;
          default:
            if (sMState != null) {
              sMState.clearSnackBars();
              sMState.showSnackBar(SnackBar(
                  content: Text(
                appLoca.errorBorrarPoi,
              )));
            }
        }
      });
    }
  }

  Widget widgetAppbar(Size size, bool fE) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return SliverAppBar(
      title: Text(
        feature.getALabel(lang: MyApp.currentLang),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        // textScaleFactor: 0.9,
        textScaler: const TextScaler.linear(0.9),
      ),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      pinned: true,
      forceElevated: fE,
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: appLoca!.infor),
          Tab(text: appLoca.tasks),
          Tab(text: appLoca.fuentes)
        ],
      ),
    );
  }

  Widget widgetImageRedu(Size size) {
    double mW = Auxiliar.maxWidth * 0.5;
    double mH = size.width > size.height ? size.height * 0.5 : size.height / 3;
    String? image = feature.hasThumbnail
        ? feature.thumbnail.image.contains('commons.wikimedia.org')
            ? '${feature.thumbnail.image}?width=${size.width}&height=${size.height}'
            : feature.thumbnail.image
        : null;
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        Visibility(
          visible: feature.hasThumbnail,
          child: Center(
            child: feature.hasThumbnail
                ? ImageNetwork(
                    image: image!,
                    imageCache: CachedNetworkImageProvider(image),
                    height: mH,
                    width: mW,
                    duration: 0,
                    onPointer: true,
                    fitWeb: BoxFitWeb.cover,
                    fitAndroidIos: BoxFit.cover,
                    borderRadius: BorderRadius.circular(25),
                    curve: Curves.easeIn,
                    onTap: () async {
                      // Todas las imágenes del lugar (Wikidata, etc.); si solo
                      // hay portada se pasa esa
                      List<PairImage> imagenes = feature.image.isNotEmpty
                          ? feature.image
                          : [feature.thumbnail];
                      int indice = imagenes.indexWhere((PairImage p) =>
                          p.image == feature.thumbnail.image);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                FullScreenImage.list(
                              imagenes,
                              initialIndex: indice > -1 ? indice : 0,
                              local: false,
                            ),
                            fullscreenDialog: false),
                      );
                    },
                    onError: const Icon(Icons.image_not_supported),
                    onLoading: const CircularProgressIndicator.adaptive(),
                  )
                : null,
          ),
        ),
        widgetBICCyL()
      ],
    );
  }

  Widget widgetMapa() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    MapOptions mapOptions = (pointUser != null)
        ? MapOptions(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white54
                : Colors.black54,
            maxZoom: MapLayer.maxZoom,
            initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(pointUser!, feature.point),
                padding: const EdgeInsets.all(30)),
            // boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(30)),
            // interactiveFlags:
            //     InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            // interactiveFlags: InteractiveFlag.none,
            // enableScrollWheel: false,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          )
        : MapOptions(
            initialZoom: 17,
            maxZoom: MapLayer.maxZoom,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
            initialCenter: feature.point,
          );
    List<Polyline> polylines = (pointUser != null)
        ? [
            Polyline(
              pattern: const StrokePattern.dotted(),
              points: [pointUser!, feature.point],
              gradientColors: [
                colorScheme.tertiary,
                colorScheme.tertiaryContainer,
              ],
              strokeWidth: 5,
            )
          ]
        : [];
    Marker markerFeature = Marker(
      width: 48,
      height: 48,
      point: feature.point,
      child: widget.iconMarker != null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2,
                ),
                color: colorScheme.primaryContainer,
              ),
              child: widget.iconMarker!)
          : Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: colorScheme.primary),
            ),
    );
    List<Marker> markers = pointUser != null
        ? [
            markerFeature,
            Marker(
              //user
              width: 24,
              height: 24,
              point: pointUser!,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: colorScheme.tertiary),
              ),
            ),
            Marker(
              //Distancia
              width: 60,
              height: 20,
              point: LatLng(
                ((max(feature.lat, pointUser!.latitude) -
                            min(feature.lat, pointUser!.latitude)) /
                        2) +
                    min(feature.lat, pointUser!.latitude),
                ((max(feature.long, pointUser!.longitude) -
                            min(feature.long, pointUser!.longitude)) /
                        2) +
                    min(feature.long, pointUser!.longitude),
              ),
              child: Container(
                decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    // border: Border.all(
                    //     color: colorScheme.onPrimaryContainer, width: 1),
                    borderRadius: BorderRadius.circular(2)),
                child: Center(
                  child: Text(
                    distanceString,
                    // style: const TextStyle(color: Colors.black, fontSize: 12),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: colorScheme.onPrimaryContainer),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            )
          ]
        : [markerFeature];
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: FlutterMap(
          mapController: _mapController,
          options: mapOptions,
          children: [
            MapLayer.tileLayerWidget(brightness: Theme.of(context).brightness),
            PolylineLayer(polylines: polylines),
            MapLayer.atributionWidget(),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  /// Compara identificadores admitiendo la forma completa (IRI) y la corta
  /// ('md:…'), ya que las respuestas guardan la forma corta y las tareas
  /// la completa.
  bool _sameId(String a, String b) {
    if (a == b) return true;
    String? shortA = Auxiliar.id2shortId(a);
    String? shortB = Auxiliar.id2shortId(b);
    return (shortA != null && shortA == b) ||
        (shortB != null && shortB == a) ||
        (shortA != null && shortA == shortB);
  }

  /// Respuesta guardada del usuario para una tarea, si la hay. Se busca en cada
  /// pintado y no al recuperar la lista de tareas: así la tarjeta refleja lo que
  /// el usuario acaba de hacer (responder la tarea, o retirar su fotografía de
  /// la votación) sin tener que salir del lugar y volver a entrar.
  Answer? _answerOfTask(Task task) {
    for (Answer answer in UserXEST.userXEST.answers) {
      if (answer.hasContainer &&
          _sameId(answer.idContainer, task.idContainer) &&
          answer.hasTask &&
          _sameId(answer.idTask, task.id)) {
        return answer;
      }
    }
    return null;
  }

  Widget widgetListTasks(Size size) {
    // double pLateral = size.width > Auxiliar.maxWidth
    //     ? (size.width - Auxiliar.maxWidth) / 2
    //     : 0;
    if (_requestTask) {
      return SliverPadding(
          padding: const EdgeInsets.only(bottom: 80),
          sliver: tasks.isEmpty
              ? FutureBuilder<List>(
                  future: _getTasks(feature.shortId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && !snapshot.hasError) {
                      List<dynamic>? data = snapshot.data;
                      if (data != null && data.isNotEmpty) {
                        for (var t in data) {
                          try {
                            Task task = Task(
                              t,
                              containerType: ContainerTask.spatialThing,
                              idContainer: feature.id,
                            );

                            bool muestra = true;
                            for (Task t in tasks) {
                              if (t.id == task.id) {
                                muestra = false;
                                break;
                              }
                            }
                            if (muestra) {
                              tasks.add(task);
                            }
                          } catch (error, stack) {
                            if (ConfigXest.development) {
                              debugPrint(error.toString());
                            } else {
                              FirebaseCrashlytics.instance
                                  .recordError(error, stack);
                            }
                          }
                        }
                        return _listTasks(size);
                      } else {
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child:
                                  Text(AppLocalizations.of(context)!.sinTareas),
                            ),
                          ]),
                        );
                      }
                    } else {
                      if (snapshot.hasError) {
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child:
                                  Text(AppLocalizations.of(context)!.sinTareas),
                            ),
                          ]),
                        );
                      } else {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                              (context, index) => const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Center(
                                        child: CircularProgressIndicator
                                            .adaptive()),
                                  ),
                              childCount: 1),
                        );
                      }
                    }
                  },
                )
              : _listTasks(size));
    } else {
      _requestTask = true;
      return SliverList(delegate: SliverChildListDelegate([]));
    }
  }

  /// Abre la votación de una tarea de fotografía con votación. Cada tarea tiene
  /// su propia votación, aunque varias compartan lugar.
  void _openPhotoVote(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PhotoVoteView(
          feature.shortId,
          idTask: task.id,
          labelFeature: feature.getALabel(lang: MyApp.currentLang),
          labelTask: task.hasLabel ? task.getALabel(lang: MyApp.currentLang) : null,
        ),
      ),
      // Al volver se repinta la lista: si el usuario ha retirado su fotografía,
      // la tarea vuelve a estar pendiente
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Tareas que quedan tras aplicar los filtros de tipo y de autor
  List<Task> get _tasksFiltered => tasks
      .where((Task t) =>
          (_filterTypes.isEmpty || _filterTypes.contains(t.aT)) &&
          (_filterAuthors.isEmpty ||
              (t.authorLbl != null && _filterAuthors.contains(t.authorLbl))))
      .toList();

  /// Filtros de la lista de tareas del lugar: por tipo de tarea y por alias de
  /// quien la propuso. Solo se ofrecen los valores presentes en el lugar.
  Widget _widgetTaskFilters() {
    ThemeData td = Theme.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final List<AnswerType> types = tasks.map((Task t) => t.aT).toSet().toList();
    final List<String> authors = tasks
        .map((Task t) => t.authorLbl)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    if (types.length < 2 && authors.length < 2) {
      return const SizedBox.shrink();
    }
    final bool filtering = _filterTypes.isNotEmpty || _filterAuthors.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: td.colorScheme.outline),
              const SizedBox(width: 5),
              Text(appLoca.filtrarTareas,
                  style: td.textTheme.titleSmall!
                      .copyWith(color: td.colorScheme.outline)),
              const Spacer(),
              if (filtering)
                TextButton(
                  onPressed: () => setState(() {
                    _filterTypes.clear();
                    _filterAuthors.clear();
                  }),
                  child: Text(appLoca.quitarFiltros),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (types.length > 1)
                for (AnswerType type in types)
                  FilterChip(
                    label: Text(Auxiliar.getLabelAnswerType(appLoca, type)),
                    selected: _filterTypes.contains(type),
                    onSelected: (bool selected) => setState(() => selected
                        ? _filterTypes.add(type)
                        : _filterTypes.remove(type)),
                  ),
              if (authors.length > 1)
                for (String author in authors)
                  FilterChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(author),
                    selected: _filterAuthors.contains(author),
                    onSelected: (bool selected) => setState(() => selected
                        ? _filterAuthors.add(author)
                        : _filterAuthors.remove(author)),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listTasks(Size size) {
    final List<Task> tasksFiltered = _tasksFiltered;
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(child: _widgetTaskFilters()),
      if (tasksFiltered.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context)!.sinTareasFiltro),
          ),
        ),
      SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          ThemeData td = Theme.of(context);
          ColorScheme colorSheme = td.colorScheme;
          TextTheme textTheme = td.textTheme;
          AppLocalizations appLoca = AppLocalizations.of(context)!;
          ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);

          Task task = tasksFiltered.elementAt(index);
          Answer? answerTask = _answerOfTask(task);
          String title = task.hasLabel
              ? task.getALabel(lang: MyApp.currentLang)
              : Auxiliar.getLabelAnswerType(
                  AppLocalizations.of(context), task.aT);
          String comment = (task.getAComment(lang: MyApp.currentLang))
              .replaceAll(
                  RegExp('<[^>]*>?', multiLine: true, dotAll: true), '');

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: colorSheme.outline,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(12))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    answerTask != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16, left: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 18, color: colorSheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  appLoca.tareaCompletada,
                                  style: textTheme.labelMedium!
                                      .copyWith(color: colorSheme.primary),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    Padding(
                        padding: const EdgeInsets.only(
                            top: 24, bottom: 16, right: 16, left: 16),
                        child: Wrap(
                            spacing: 4,
                            children: task.spaces.map((Space space) {
                              switch (space) {
                                case Space.physical:
                                  return const Icon(Icons.mobile_friendly,
                                      size: 18);
                                case Space.virtual:
                                  return const Icon(Icons.map, size: 18);
                                case Space.web:
                                  return const Icon(Icons.web, size: 18);
                              }
                            }).toList())),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.only(bottom: 16, right: 16, left: 16),
                  width: double.infinity,
                  child: Text(
                    title,
                    style: textTheme.titleLarge!
                        .copyWith(color: colorSheme.onSecondaryContainer),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(comment.replaceAll(RegExp('<[^>]*>'), '')),
                ),
                // El alias solo está disponible si su autor aceptó publicarlo
                if (task.authorLbl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Text(
                      appLoca.autorTarea(task.authorLbl!),
                      style: textTheme.bodySmall!
                          .copyWith(color: colorSheme.outline),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 16, bottom: 8, right: 16, left: 16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      children: [
                      // Cada tarea de votación tiene su propia galería, así que
                      // se entra a ella desde la propia tarea
                      if (task.aT == AnswerType.photoVote &&
                          UserXEST.userXEST.isNotGuest)
                        TextButton.icon(
                          onPressed: () => _openPhotoVote(task),
                          icon: const Icon(Icons.how_to_vote, size: 18),
                          label: Text(appLoca.verVotacion),
                        ),
                      ...mostrarFabProfe
                          ? task.author == UserXEST.userXEST.iri
                              ? [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      bool? borrarLista =
                                          await Auxiliar.deleteDialog(
                                              context,
                                              appLoca.borrar,
                                              appLoca.preguntaBorrarTarea);
                                      if (borrarLista != null && borrarLista) {
                                        dynamic tareaBorrada =
                                            await _deleteTask(task.id);
                                        if (tareaBorrada is bool) {
                                          if (tareaBorrada) {
                                            showSnackTaskDelete(false);
                                            setState(() {
                                              tasks.removeWhere(
                                                  (t) => t.id == task.id);
                                              // Sin la tarea no hay respuesta
                                              // que enseñar: el servidor las ha
                                              // ocultado y aquí se quitan de la
                                              // copia en memoria
                                              UserXEST.userXEST.answers
                                                  .removeWhere((Answer a) =>
                                                      a.hasTask &&
                                                      _sameId(a.idTask,
                                                          task.id));
                                              if (tasks.isEmpty) {
                                                _requestTask = false;
                                              }
                                            });
                                          } else {
                                            showSnackTaskDelete(true);
                                          }
                                        } else {
                                          showSnackTaskDelete(true);
                                        }
                                      }
                                    },
                                    child: Text(appLoca.borrar),
                                  ),
                                  // TODO
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(appLoca.editar),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      context.go(
                                          '/home/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                          extra: [
                                            null,
                                            null,
                                            null,
                                            true,
                                            false
                                          ]);
                                    },
                                    child: Text(appLoca.vistaPrevia),
                                  )
                                ]
                              : [
                                  FilledButton(
                                    onPressed: () {
                                      context.go(
                                          '/home/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                          extra: [
                                            null,
                                            null,
                                            null,
                                            true,
                                            false
                                          ]);
                                    },
                                    child: Text(appLoca.vistaPrevia),
                                  )
                                ]
                          : answerTask != null
                              ? [
                                  FilledButton.tonal(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              AnswerReadOnly(answerTask),
                                          fullscreenDialog: false,
                                        ),
                                      );
                                    },
                                    child: Text(appLoca.verRespuesta),
                                  )
                                ]
                              : [
                              FilledButton(
                                onPressed: () async {
                                  bool startTask = true;
                                  if (UserXEST.userXEST.isNotGuest) {
                                    if (UserXEST.userXEST.alias == null ||
                                        UserXEST.userXEST.alias!.isEmpty) {
                                      startTask = false;
                                      sMState.clearSnackBars();
                                      sMState.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              appLoca.aliasRequerido),
                                        ),
                                      );
                                    } else if (task.spaces.length == 1 &&
                                        task.spaces.first == Space.physical) {
                                      if (pointUser != null) {
                                        // TODO 100
                                        if (distance > 100) {
                                          startTask = false;
                                          sMState.clearSnackBars();
                                          sMState.showSnackBar(
                                            SnackBar(
                                              backgroundColor:
                                                  colorSheme.errorContainer,
                                              content: Text(
                                                appLoca.acercate,
                                                style: textTheme.bodyMedium!
                                                    .copyWith(
                                                        color: colorSheme
                                                            .onErrorContainer),
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        startTask = false;
                                        sMState.clearSnackBars();
                                        sMState.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                appLoca.activaLocalizacion),
                                            duration:
                                                const Duration(seconds: 8),
                                            action: SnackBarAction(
                                              label: appLoca.activar,
                                              onPressed: () =>
                                                  checkUserLocation(),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    startTask = false;
                                    sMState.clearSnackBars();
                                    sMState.showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(appLoca.iniciaParaRealizar),
                                        duration: const Duration(seconds: 8),
                                      ),
                                    );
                                  }

                                  if (startTask) {
                                    if (pointUser != null) {
                                      MyApp.locationUser.dispose();
                                      pointUser = null;
                                    }
                                    if (!ConfigXest.development) {
                                      FirebaseAnalytics.instance.logEvent(
                                        name: "seenTask",
                                        parameters: {
                                          "iri": Auxiliar.id2shortId(task.id)!,
                                        },
                                      );
                                    }
                                    // TODO recuperar si se ha realizado la tarea, y si es así, pintar la nueva lista
                                    context.go(
                                        '/home/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                        extra: [
                                          null,
                                          null,
                                          null,
                                          false,
                                          startTask
                                        ]);
                                  }
                                },
                                child: Text(appLoca.realizaTareaBt),
                              )
                            ],
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }, childCount: tasksFiltered.length),
      ),
      ),
    ]);
  }

  void showSnackTaskDelete(bool error) {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    sMState.clearSnackBars();
    sMState.showSnackBar(
      SnackBar(
        backgroundColor: error ? td.colorScheme.errorContainer : null,
        content: Text(
          error ? appLoca!.errorBorrarTask : appLoca!.tareaBorrada,
          style: td.textTheme.bodyMedium!.copyWith(
            color: error ? td.colorScheme.onErrorContainer : null,
          ),
        ),
      ),
    );
  }

  Future<dynamic> _deleteTask(String id) async {
    String shortIdTask = Auxiliar.id2shortId(id)!;
    return http
        .delete(Queries.deleteTask(feature.shortId, shortIdTask), headers: {
      'Content-Type': 'application/json',
      'Authorization':
          'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
    }).then((response) async {
      if (response.statusCode == 200) {
        if (!ConfigXest.development) {
          await FirebaseAnalytics.instance.logEvent(
            name: "deletedTask",
            parameters: {"iri": shortIdTask},
          );
        }
        return true;
      } else {
        return response.body;
      }
    }).onError((error, stackTrace) => false);
  }

  Future<List> _getTasks(id) async {
    // Las respuestas se refrescan al abrir el lugar: son las que deciden qué
    // tareas se marcan como completadas, y pueden haber cambiado fuera de esta
    // pantalla (en otra sesión, o porque el servidor haya ocultado alguna al
    // retirarse una fotografía o borrarse la tarea). Las dos peticiones van a
    // la vez para no retrasar la lista de tareas.
    final Future<void> answers = UserXEST.refreshAnswers();
    final http.Response response = await http.get(Queries.getTasks(id));
    await answers;
    return response.statusCode == 200 ? json.decode(response.body) : [];
  }

  void checkUserLocation() async {
    bool hasPermissions = await MyApp.locationUser.checkPermissions(context);
    if (hasPermissions) {
      MyApp.locationUser.positionUser!.listen((Position position) {
        if (mounted) {
          setState(() {
            pointUser = LatLng(position.latitude, position.longitude);
          });
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds(pointUser!, feature.point),
            padding: const EdgeInsets.all(30),
          ));
          calculateDistance();
        }
      }, cancelOnError: true);
    }
    // _strLocationUser = Geolocator.getPositionStream(
    //         locationSettings: await Auxiliar.checkPermissionsLocation(
    //             context, defaultTargetPlatform))
    //     .listen((Position? position) {
    //   if (position != null) {
    //     if (mounted) {
    //       setState(() {
    //         pointUser = LatLng(position.latitude, position.longitude);
    //       });
    //       _mapController.fitCamera(CameraFit.bounds(
    //         bounds: LatLngBounds(pointUser!, feature.point),
    //         padding: const EdgeInsets.all(30),
    //       ));
    //       calculateDistance();
    //     }
    //   }
    // }, cancelOnError: true);
  }

  void calculateDistance() {
    if (mounted) {
      distance = Auxiliar.distance(feature.point, pointUser!);
      distanceString = distance < 1000
          ? '${distance.toInt().toString()}m'
          : '${(distance / 1000).toStringAsFixed(2)}km';
    }
  }

  Widget _cuerpo(Size size) {
    List<PairLang> allComments = feature.comments;
    List<PairLang> comments = [];
    // Prioridad a la información en el idioma del usuario
    for (PairLang comment in allComments) {
      if (comment.hasLang && comment.lang == MyApp.currentLang) {
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
      comments.sort(
          (PairLang a, PairLang b) => b.value.length.compareTo(a.value.length));
    }
    PairLang comment = comments.first;
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          widgetImageRedu(size),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                  child: HtmlWidget(
                    comment.value,
                    factoryBuilder: () => MyWidgetFactory(),
                  ),
                  // child: todoTexto
                  //     ? HtmlWidget(
                  //         comment.value,
                  //         factoryBuilder: () => MyWidgetFactory(),
                  //       )
                  //     : InkWell(
                  //         onTap: () => setState(() => todoTexto = true),
                  //         child: Text(
                  //           comment.value.replaceAll(RegExp('<[^>]*>'), ''),
                  //           maxLines: 7,
                  //           overflow: TextOverflow.ellipsis,
                  //         ),
                  //       ),
                ),
              ),
              // TODO TTS
              // Align(
              //   alignment: Alignment.centerRight,
              //   child: Padding(
              //     padding: const EdgeInsets.only(bottom: 15),
              //     child: TextButton.icon(
              //       icon: Icon(
              //         _isPlaying ? Icons.stop : Icons.hearing,
              //         color: colorScheme.primary,
              //       ),
              //       label: Text(
              //         AppLocalizations.of(context)!.escuchar,
              //         style: td.textTheme.bodyMedium!.copyWith(
              //           color: colorScheme.primary,
              //         ),
              //       ),
              //       onPressed: () async {
              //         if (_isPlaying) {
              //           setState(() => _isPlaying = false);
              //           _stop();
              //         } else {
              //           setState(() => _isPlaying = true);
              //           List<String> lstTexto =
              //               Auxiliar.frasesParaTTS(comment.value);
              //           for (String leerParte in lstTexto) {
              //             await _speak(leerParte);
              //           }
              //           setState(() => _isPlaying = false);
              //         }
              //       },
              //     ),
              //   ),
              // )
            ],
          ),
          widgetMapa(),
        ],
      ),
    );
  }

  Widget _buildInfoBody(Size size) {
    Object? docObj = feature.getProvider('docomomo');
    if (docObj != null) {
      return _cuerpoDocomomo(size, (docObj as Provider).data as Docomomo);
    }
    return _cuerpo(size);
  }

  PairLang? _pickBestComment(List<PairLang> all) {
    if (all.isEmpty) return null;
    for (PairLang c in all) {
      if (c.hasLang && c.lang == MyApp.currentLang) return c;
    }
    for (PairLang c in all) {
      if (c.hasLang && c.lang == 'en') return c;
    }
    return all.first;
  }

  String _labelForUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Widget _cuerpoDocomomo(Size size, Docomomo docomomo) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    ColorScheme colorScheme = td.colorScheme;
    PairLang? comment = _pickBestComment(docomomo.comments);

    List<Widget> children = [];

    if (docomomo.media.isNotEmpty) {
      final int mediaCount = docomomo.media.length;
      double galleryHeight = size.height * 0.28;
      double itemWidth = size.width * 0.4;
      children.add(Stack(
        children: [
          SizedBox(
            height: galleryHeight,
            child: CarouselView(
              controller: _carouselController,
              itemExtent: itemWidth,
              shrinkExtent: 60.0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              onTap: (int index) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) {
                      String docomomoURL = docomomo.seeAlso.firstWhere(
                        (element) => element.contains('docomomo'),
                      );
                      return FullScreenImage.list(
                        docomomo.media
                            .map((DocomomoMedia m) =>
                                PairImage(m.link, docomomoURL))
                            .toList(),
                        initialIndex: index,
                        local: false,
                        labels: docomomo.media
                            .map((DocomomoMedia m) => m.label)
                            .toList(),
                      );
                    },
                    fullscreenDialog: false,
                  ),
                );
              },
              children: docomomo.media.map((DocomomoMedia m) {
                return ImageNetwork(
                  image: m.link,
                  imageCache: CachedNetworkImageProvider(m.link),
                  height: galleryHeight,
                  width: itemWidth,
                  duration: 0,
                  fitWeb: BoxFitWeb.cover,
                  fitAndroidIos: BoxFit.cover,
                  onError: const Icon(Icons.image_not_supported),
                  onLoading: const CircularProgressIndicator.adaptive(),
                );
              }).toList(),
            ),
          ),
          if (mediaCount > 1 && kIsWeb)
            Positioned(
              bottom: Auxiliar.compactMargin,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _carouselIndex =
                            (_carouselIndex - 1).clamp(0, mediaCount - 1);
                      });
                      _carouselController.animateToItem(_carouselIndex);
                    },
                  ),
                  const SizedBox(width: Auxiliar.mediumMargin),
                  IconButton.filled(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _carouselIndex =
                            (_carouselIndex + 1).clamp(0, mediaCount - 1);
                      });
                      _carouselController.animateToItem(_carouselIndex);
                    },
                  ),
                ],
              ),
            ),
        ],
      ));
      children.add(const SizedBox(height: Auxiliar.compactMargin));
    }

    if (comment != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: Auxiliar.compactMargin),
        child: HtmlWidget(
          comment.value,
          factoryBuilder: () => MyWidgetFactory(),
        ),
      ));
      children.add(Padding(
        padding: const EdgeInsetsGeometry.only(
            left: Auxiliar.compactMargin,
            right: Auxiliar.compactMargin,
            bottom: Auxiliar.compactMargin),
        child: Divider(),
      ));
    }

    if (docomomo.startDate != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text('${appLoca.anioInicio}: ', style: textTheme.labelLarge),
          Text(docomomo.startDate!),
        ]),
      ));
    }

    if (docomomo.endDate != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Text('${appLoca.anioFin}: ', style: textTheme.labelLarge),
          Text(docomomo.endDate!),
        ]),
      ));
    }

    if (docomomo.architects.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(appLoca.architects, style: textTheme.labelLarge),
      ));
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: Auxiliar.compactMargin),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: docomomo.architects.map((DocomomoArchitect a) {
            String label = a.name ?? _labelForUrl(a.id);
            if (a.link != null) {
              return ActionChip(
                label: Text(label),
                onPressed: () async {
                  final uri = Uri.tryParse(a.link!);
                  if (uri != null) await launchUrl(uri);
                },
              );
            }
            return Chip(label: Text(label));
          }).toList(),
        ),
      ));
    }

    if (docomomo.seeAlso.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(appLoca.enlacesExt, style: textTheme.labelLarge),
      ));
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: Auxiliar.compactMargin),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: docomomo.seeAlso.map((String url) {
            return ActionChip(
                label: Text(_labelForUrl(url)),
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri);
                });
          }).toList(),
        ),
      ));
    }

    children.add(widgetMapa());
    children.add(const SizedBox(height: 12));

    children.add(Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text('${appLoca.licenciaInfo}: ${docomomo.license}',
          style: textTheme.bodySmall!.copyWith(color: colorScheme.outline)),
    ));

    return SliverList(
      delegate: SliverChildListDelegate([
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ]),
    );
  }

  Widget widgetBody(Size size) {
    if (widget.locationUser != null && widget.locationUser is Position) {
      // checkUserLocation();
      calculateDistance();
    }
    return SliverPadding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 80,
      ),
      sliver: feature.ask4Resource
          ? _buildInfoBody(size)
          : FutureBuilder<List>(
              future: _getInfoFeature(feature.shortId),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  for (int i = 0, tama = snapshot.data!.length; i < tama; i++) {
                    Map provider = snapshot.data![i];
                    Map<String, dynamic>? data = provider['data'];
                    switch (provider["provider"]) {
                      case 'osm':
                        OSM osm = OSM(data);
                        for (PairLang l in osm.labels) {
                          feature.addLabelLang(l);
                        }
                        if (osm.image != null) {
                          feature.setThumbnail(
                              osm.image!.image,
                              osm.image!.hasLicense
                                  ? osm.image!.license
                                  : null);
                        }
                        for (PairLang d in osm.descriptions) {
                          feature.addCommentLang(d);
                        }
                        feature.addProvider(provider['provider'], osm);
                        break;
                      case 'wikidata':
                        Wikidata? wikidata = Wikidata(data);
                        for (PairLang label in wikidata.labels) {
                          feature.addLabelLang(label);
                        }
                        for (PairLang comment in wikidata.descriptions) {
                          feature.addCommentLang(comment);
                        }
                        for (PairImage image in wikidata.images) {
                          feature.addImage(image.image,
                              license: image.hasLicense ? image.license : null);
                        }
                        feature.addProvider(provider['provider'], wikidata);
                        break;
                      case 'jcyl':
                        JCyL jcyl = JCyL(data);
                        feature.addCommentLang(jcyl.description);
                        feature.addProvider(provider['provider'], jcyl);
                        break;
                      case 'esDBpedia':
                      case 'dbpedia':
                        DBpedia dbpedia = DBpedia(data, provider['provider']);
                        for (PairLang comment in dbpedia.descriptions) {
                          feature.addCommentLang(comment);
                        }
                        for (PairLang label in dbpedia.labels) {
                          feature.addLabelLang(label);
                        }
                        feature.addProvider(provider['provider'], dbpedia);
                        break;
                      case 'docomomo':
                        Docomomo docomomo = Docomomo(data);
                        for (PairLang l in docomomo.labels) {
                          feature.addLabelLang(l);
                        }
                        for (PairLang c in docomomo.comments) {
                          feature.addCommentLang(c);
                        }
                        feature.addProvider(provider['provider'], docomomo);
                        break;
                      default:
                    }
                  }
                  feature.ask4Resource = true;
                  feature.ask4Resource = MapData.updateFeatureCache(feature);
                  return _buildInfoBody(size);
                } else {
                  if (snapshot.hasError) {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  } else {
                    return SliverList(
                      delegate: SliverChildListDelegate([
                        const Center(
                            child: CircularProgressIndicator.adaptive())
                      ]),
                    );
                  }
                }
              }),
    );
  }

  Future<List> _getInfoFeature(idFeature) {
    return http.get(Queries.getFeatureInfo(idFeature)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget widgetBICCyL() {
    Object? obj = feature.getProvider('jcyl');
    if (obj != null) {
      Provider jcyl = obj as Provider;
      return Center(
        child: FilledButton.icon(
          onPressed: () async {
            if (!await launchUrl(Uri.parse(jcyl.data.url))) {
              if (ConfigXest.development) debugPrint('Url jcyl problem!');
            }
          },
          label: Text(AppLocalizations.of(context)!.bicCyL),
          icon: const Icon(Icons.favorite),
        ),
      );
    }
    return Container();
  }

  // Widget widgetGoTo() {
  //   // AppLocalizations? appLoca = AppLocalizations.of(context);
  //   List<Map<String, dynamic>> goto = [
  //     // {
  //     //   'key': datakeyFuentes,
  //     //   'textBt': appLoca!.fuentesInfo,
  //     // }
  //   ];
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 10),
  //     child: Wrap(
  //       spacing: 10,
  //       runSpacing: 10,
  //       alignment: WrapAlignment.spaceAround,
  //       runAlignment: WrapAlignment.center,
  //       children: List<OutlinedButton>.generate(goto.length, (int index) {
  //         Map<String, dynamic> gt = goto.elementAt(index);
  //         return OutlinedButton(
  //           child: Text(gt['textBt']),
  //           onPressed: () async => Scrollable.ensureVisible(
  //             gt['key'].currentContext!,
  //             duration: const Duration(milliseconds: 200),
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }

  OutlinedButton _fuentesInfoBt(
    String nameSource,
    Map<String, dynamic> infoMap,
  ) {
    switch (nameSource) {
      case 'osm':
        nameSource = 'OpenStreetMap';
        break;
      case 'wikidata':
        nameSource = 'Wikidata';
        break;
      case 'jcyl':
        nameSource = 'JCyL';
        break;
      case 'dbpedia':
        nameSource = 'DBpedia';
        break;
      case 'esDBpedia':
        nameSource = 'es.DBpedia';
        break;
      case 'localRepo':
        nameSource = AppLocalizations.of(context)!.xest;
        break;
      case 'docomomo':
        nameSource = 'Docomomo Ibérico';
        break;
      default:
    }
    return OutlinedButton(
      onPressed: () => showDialog(
          context: context,
          builder: (context) {
            ThemeData td = Theme.of(context);
            TextStyle? bodyMedium = td.textTheme.bodyMedium;
            ColorScheme colorScheme = td.colorScheme;
            List<Widget> lst = [];
            for (String k in infoMap.keys) {
              lst.add(ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: SelectableText(
                      '$k: ${infoMap[k]}',
                      style: bodyMedium!
                          .copyWith(color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                ),
              ));
            }
            return AlertDialog.adaptive(
              scrollable: true,
              actions: [
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.pop(context),
                )
              ],
              title: Text(nameSource),
              content: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 4,
                children: lst,
              ),
            );
          }),
      child: Text(nameSource),
    );
  }

  Widget fuentesInfo() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lstSources = [];
    for (Provider ele in feature.providers) {
      if (ele.data is Map) {
        lstSources.add(_fuentesInfoBt(ele.id, ele.data));
      } else {
        lstSources.add(_fuentesInfoBt(ele.id, ele.data.toSourceInfo()));
      }
    }

    if (feature.getProvider('docomomo') != null) {
      List<Widget> lst = [
        Text(AppLocalizations.of(context)!.fuentesInfo,
            style: Theme.of(context).textTheme.titleLarge),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: Wrap(
              runAlignment: WrapAlignment.spaceEvenly,
              alignment: WrapAlignment.center,
              runSpacing: Auxiliar.compactMargin / 2,
              spacing: Auxiliar.compactMargin,
              children: lstSources,
            ),
          ),
        ),
      ];
      return SliverPadding(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) => lst[index],
              childCount: lst.length),
        ),
      );
    }

    String cLabel = feature.getALabel(lang: MyApp.currentLang);
    List<PairLang> allComments = feature.comments;
    List<PairLang> comments = [];
    // Prioridad a la información en el idioma del usuario
    for (PairLang comment in allComments) {
      if (comment.hasLang && comment.lang == MyApp.currentLang) {
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
    if (comments.isEmpty && allComments.isNotEmpty) {
      comments.add(allComments.first);
    }
    if (comments.length > 1) {
      comments.sort(
          (PairLang a, PairLang b) => b.value.length.compareTo(a.value.length));
    }
    String cComment = comments.isNotEmpty ? comments.first.value : '';

    bool mainProvOSM = true;
    bool imgWikidata = false;
    bool isBic = false;
    String? labelSource, commentSource;
    for (Provider provider in feature.providers) {
      switch (provider.id) {
        case 'osm':
          OSM data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'OpenStreetMap';
            }
          }
          for (PairLang pl in data.labels) {
            if (pl.value == cComment) {
              commentSource = 'OpenStreetMap';
            }
          }
          break;
        case 'wikidata':
          Wikidata data = provider.data;
          imgWikidata = feature.hasThumbnail && data.images.isNotEmpty;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'Wikidata';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'Wikidata';
            }
          }
          isBic = data.idBIC != null;
          break;
        case 'esDBpedia':
          DBpedia data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'es.DBpedia';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'es.DBpedia';
            }
          }
          break;
        case 'dbpedia':
          DBpedia data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'DBpedia';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'DBpedia';
            }
          }
          break;
        case 'jcyl':
          JCyL data = provider.data;
          if (data.label.value == cLabel) {
            labelSource = appLoca!.gobcyl;
          }
          if (data.description.value == cComment) {
            commentSource = appLoca!.gobcyl;
          }
          break;
        case 'localRepo':
          LocalRepo data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = appLoca!.usuariosxest;
            }
          }
          for (PairLang pl in data.comments) {
            if (pl.value == cComment) {
              commentSource = appLoca!.usuariosxest;
            }
          }
          mainProvOSM = false;
          break;
        default:
      }
      if (feature.hasThumbnail) {
        if (provider.id == 'wikidata' &&
            (provider.data as Wikidata).images.isNotEmpty) {
          imgWikidata = true;
        }
      }
    }
    List<Widget> lstTextoFuentes = [
      Text('${appLoca!.obtLbl} $labelSource.'),
      feature.hasThumbnail
          ? Text(
              '${appLoca.obtImg} ${imgWikidata ? 'Wikidata' : 'OpenStreetMap'}.')
          : Container(),
      isBic ? Text('${appLoca.obtBic}.') : Container(),
      isBic ? Text('${appLoca.obtEnlBic} ${appLoca.gobcyl}.') : Container(),
      Text('${appLoca.obtCom} $commentSource.'),
      Text(
          '${appLoca.obtCoor} ${mainProvOSM ? 'OpenStreetMap' : appLoca.usuariosxest}.'),
    ];
    if (feature.hasThumbnail) {
      // Wikidata or OSM?
    }
    List<Widget> lst = [
      // Título:
      Text(
        AppLocalizations.of(context)!.fuentesInfo,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      // Frases:
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Auxiliar.mediumMargin,
          vertical: Auxiliar.compactMargin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lstTextoFuentes,
        ),
      ),
      // Fuentes:
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Wrap(
            runAlignment: WrapAlignment.spaceEvenly,
            alignment: WrapAlignment.center,
            runSpacing: Auxiliar.compactMargin / 2,
            spacing: Auxiliar.compactMargin,
            children: lstSources,
          ),
        ),
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 80,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) => lst[index],
            childCount: lst.length),
      ),
    );
  }
}

class SuggestFeature extends StatefulWidget {
  final LatLng point;
  final LatLngBounds bounds;
  const SuggestFeature(this.point, this.bounds, {super.key});

  @override
  State<StatefulWidget> createState() => _SuggestFeature();
}

class _SuggestFeature extends State<SuggestFeature> {
  late List<FeatureDistance> featuresCache;
  @override
  void initState() {
    featuresCache = MapData.getNearCacheFeature(
      widget.point,
      maxFeatures: 100,
      maxDistance: 5000,
    );
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appLoca!.addPOI),
          centerTitle: false,
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.near_me)),
              Tab(icon: Icon(Icons.public)),
              Tab(icon: Icon(Icons.draw)),
            ],
          ),
        ),
        body: TabBarView(children: [
          widgetNearFeatures(),
          widgetLODFeatures(),
          widgetFeatureScraft()
        ]),
      ),
    );
  }

  Widget widgetNearFeatures() {
    List<FeatureDistance> features =
        featuresCache.sublist(0, min(featuresCache.length, 20));

    AppLocalizations? appLoca = AppLocalizations.of(context)!;
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(
                    appLoca.poiCercanos,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(appLoca.puntosYaExistentesEx),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              childCount: features.length,
              (context, index) {
                Feature feature = features[index].feature;
                return cardSpatialThing(
                    feature.getALabel(lang: MyApp.currentLang),
                    distance: '${features[index].distance} m', fun: () async {
                  if (!ConfigXest.development) {
                    FirebaseAnalytics.instance.logEvent(
                        name: "seenFeature",
                        parameters: {
                          "iri": feature.shortId
                        }).then((value) async {
                      if (mounted) {
                        context.pop();
                        context.push<bool>('/home/features/${feature.shortId}');
                      }
                    }).onError((error, stackTrace) {
                      if (mounted) {
                        context.pop();
                        context.push<bool>('/home/features/${feature.shortId}');
                      }
                    });
                  } else {
                    context.pop();
                    context.push<bool>('/home/features/${feature.shortId}');
                  }
                });
              },
            ),
          ),
          SliverToBoxAdapter(
            child: features.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: Text(appLoca.sinCosasEspaciales),
                      ),
                    ),
                  )
                : Container(),
          )
        ],
      ),
    );
  }

  Widget widgetLODFeatures() {
    AppLocalizations? appLoca = AppLocalizations.of(context)!;
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(
                    appLoca.basadosLOD,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: Text(appLoca.lodPoiEx)),
              ),
            ),
          ),
          FutureBuilder<List>(
              future: _getFeaturesLod(widget.point, widget.bounds),
              builder: ((context, snapshot) {
                if (snapshot.hasData) {
                  List<Feature> featuresLOD = [];
                  List<dynamic> data = snapshot.data!;
                  for (var d in data) {
                    try {
                      d['author'] = UserXEST.userXEST.id;
                      // TODO Cambiar el segundo elemento por el shortId
                      d['shortId'] = Auxiliar.id2shortId(d['id']);
                      if (d['label'] == null) {
                        continue;
                      }
                      d['labels'] = d['label'];
                      d['long'] = d['lng'];
                      // TODO Cambiar por la fuente
                      d['source'] = d['id'];
                      Feature p = Feature(d);
                      featuresLOD.add(p);
                    } catch (e, stack) {
                      if (ConfigXest.development) {
                        debugPrint(e.toString());
                      } else {
                        FirebaseCrashlytics.instance.recordError(e, stack);
                      }
                    }
                  }
                  List<Feature> features = [];
                  for (Feature f in featuresLOD) {
                    bool encontrado = false;
                    for (FeatureDistance fd in featuresCache) {
                      if (StringSimilarity.compareTwoStrings(
                              fd.feature.getALabel(), f.getALabel()) >
                          0.6) {
                        encontrado = true;
                        break;
                      }
                    }
                    if (!encontrado) {
                      features.add(f);
                    }
                  }
                  if (features.isNotEmpty) {
                    List<FeatureDistance> fa = [];
                    for (Feature feature in features) {
                      fa.add(FeatureDistance(feature,
                          Auxiliar.distance(widget.point, feature.point)));
                    }
                    fa.sort((FeatureDistance a, FeatureDistance b) =>
                        a.distance.compareTo(b.distance));

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                          childCount: fa.length, (context, index) {
                        Feature p = fa[index].feature;
                        String distanceSrting = '${fa[index].distance} m';
                        return InkWell(
                          child: cardSpatialThing(
                              p.getALabel(lang: MyApp.currentLang),
                              subtitle: p.getAComment(lang: MyApp.currentLang),
                              distance: distanceSrting, fun: () {
                            Navigator.pop(context, p);
                          }),
                        );
                      }),
                    );
                  } else {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  }
                } else {
                  if (snapshot.hasError) {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  } else {
                    return SliverList(
                      delegate: SliverChildListDelegate([
                        const Center(
                            child: CircularProgressIndicator.adaptive())
                      ]),
                    );
                  }
                }
              })),
        ],
      ),
    );
  }

  Widget widgetFeatureScraft() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 20),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Text(
                  appLoca.sinAyuda,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 20),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Text(appLoca.nPoiEx),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: FilledButton(
              onPressed: () async {
                Navigator.pop(
                  context,
                  Feature.point(widget.point.latitude, widget.point.longitude),
                );
              },
              child: Text(AppLocalizations.of(context)!.addPOI),
            ),
          ),
        ),
      ]),
    );
  }

  Future<List> _getFeaturesLod(LatLng point, LatLngBounds bounds) {
    return http.get(Queries.getFeaturesLod(point, bounds)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget cardSpatialThing(
    String title, {
    String? subtitle,
    String? distance,
    Function()? fun,
  }) {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    TextStyle txtLbl =
        textTheme.labelMedium!.copyWith(color: colorScheme.onPrimaryContainer);
    TextStyle txtTitle =
        textTheme.bodyLarge!.copyWith(color: colorScheme.onPrimaryContainer);
    TextStyle txtComment =
        textTheme.bodyMedium!.copyWith(color: colorScheme.onPrimaryContainer);
    return Center(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colorScheme.primaryContainer,
        ),
        child: InkWell(
          onTap: fun,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              distance != null
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        distance,
                        style: txtLbl,
                      ),
                    )
                  : Container(),
              Text(
                title,
                style: txtTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        subtitle,
                        style: txtComment,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }
}

class FormFeature extends StatefulWidget {
  final Feature feature;
  final bool newFeature;

  const FormFeature(this.feature, this.newFeature, {super.key});

  @override
  State<StatefulWidget> createState() => _FormFeature();
}

// // TODO terminar para la carga de las imágenes
// class _FormFeature2 extends State<FormFeature> {
//   late Feature _feature;
//   late int _step;
//   late String _label, _comment;
//   late String? _urlText;
//   late GlobalKey<FormState> _keyStep0;
//   late MapController _mapController;
//   late FocusNode _focusNode;
//   late QuillController _quillController;
//   late bool _hasFocus,
//       _errorDescription,
//       _newFeature,
//       _btEnable,
//       _fotoSubida,
//       _urlEscrita,
//       _showImage;
//   late Uint8List? _imageUint8List;
//   late List<Marker> _markers;
//   late SpatialThingType? _stt;
//   late ImageSourceXEST _imageSource;

//   @override
//   void initState() {
//     _feature = widget.feature;
//     _newFeature = widget.newFeature;
//     _keyStep0 = GlobalKey<FormState>();
//     _mapController = MapController();
//     _label = _feature.getALabel(lang: MyApp.currentLang);
//     _comment = _feature.getAComment(lang: MyApp.currentLang);
//     _markers = [];
//     _focusNode = FocusNode();
//     _quillController = QuillController.basic();
//     _btEnable = true;
//     _step = 0;
//     _showImage = _feature.image.isNotEmpty;
//     _fotoSubida = false;
//     _urlEscrita = _feature.image.isNotEmpty;
//     _imageUint8List = null;
//     _urlText = null;
//     _imageSource = ImageSourceXEST.device;

//     super.initState();
//     _stt = _feature.spatialThingTypes != null &&
//             _feature.spatialThingTypes!.isNotEmpty
//         ? _feature.spatialThingTypes!.first
//         : null;
//     try {
//       _quillController.document =
//           Document.fromDelta(HtmlToDelta().convert(_comment));
//     } catch (error) {
//       _quillController.document = Document();
//     }
//     _quillController.document.changes.listen((DocChange onData) {
//       setState(() {
//         _comment =
//             Auxiliar.quillDelta2Html(_quillController.document.toDelta());
//       });
//     });
//     _hasFocus = false;
//     _errorDescription = false;
//     _focusNode.addListener(_onFocus);
//   }

//   void _onFocus() => setState(() => _hasFocus = !_hasFocus);

//   @override
//   void dispose() {
//     _mapController.dispose();
//     _focusNode.removeListener(_onFocus);
//     _quillController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     Size size = MediaQuery.of(context).size;
//     double mLateral = Auxiliar.getLateralMargin(size.width);
//     return Scaffold(
//       body: CustomScrollView(slivers: [
//         SliverAppBar(
//           title: Text(_newFeature ? appLoca.tNPoi : appLoca.editarPOI),
//           centerTitle: false,
//           pinned: true,
//         ),
//         // Parámetros obligatorios
//         SliverVisibility(
//           visible: _step == 0,
//           sliver: SliverPadding(
//             padding: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Center(
//                 child: Container(
//                   constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                   child: _stepZero(),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         // Parámetros opcionales
//         SliverVisibility(
//           visible: _step == 1,
//           sliver: SliverPadding(
//             padding: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Center(
//                 child: Container(
//                   constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                   child: _stepOne(),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         // Resumen
//         SliverVisibility(
//           visible: _step == 2,
//           sliver: SliverPadding(
//             padding: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Center(
//                 child: Container(
//                   constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                   child: _stepTwo(),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ]),
//     );
//   }

//   Widget _stepZero() {
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     ThemeData td = Theme.of(context);
//     ColorScheme colorScheme = td.colorScheme;
//     TextTheme textTheme = td.textTheme;
//     Size size = MediaQuery.of(context).size;
//     List<DropdownMenuItem<SpatialThingType>> lstDME = [];
//     List<Map<String, dynamic>> l = [];
//     for (SpatialThingType stt in SpatialThingType.values) {
//       if (Auxiliar.getSpatialThingTypeNameLoca(appLoca, stt) != null) {
//         l.add({
//           'v': stt,
//           't': Auxiliar.getSpatialThingTypeNameLoca(appLoca, stt)!
//         });
//       }
//     }
//     l.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
//         (a['t'] as String).compareTo(b['t'] as String));
//     for (Map<String, dynamic> stt in l) {
//       lstDME.add(DropdownMenuItem(
//         value: stt['v'],
//         child: Text(stt['t']),
//       ));
//     }
//     return Form(
//       key: _keyStep0,
//       child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             DropdownButtonFormField(
//               decoration: InputDecoration(
//                 border: const OutlineInputBorder(),
//                 labelText: '${appLoca.selectTipoLugar}*',
//                 hintText: appLoca.selectTipoLugar,
//               ),
//               value: _stt,
//               items: lstDME,
//               onChanged: (SpatialThingType? v) {
//                 setState(() => _stt = v);
//               },
//               autovalidateMode: AutovalidateMode.onUserInteraction,
//               validator: (SpatialThingType? v) {
//                 return v == null ? appLoca.selectTipoLugarError : null;
//               },
//             ),
//             SizedBox(height: 20),
//             TextFormField(
//               maxLines: 1,
//               decoration: InputDecoration(
//                   border: const OutlineInputBorder(),
//                   labelText: appLoca.tituloNPI,
//                   hintText: appLoca.tituloNPI,
//                   helperText: appLoca.requerido,
//                   hintMaxLines: 1,
//                   hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//               maxLength: 80,
//               textCapitalization: TextCapitalization.sentences,
//               keyboardType: TextInputType.text,
//               enabled: _btEnable,
//               initialValue: _label,
//               onChanged: (String value) => setState(() => _label = value),
//               validator: (value) => (value == null ||
//                       value.trim().isEmpty ||
//                       value.trim().length > 80)
//                   ? appLoca.tituloNPIExplica
//                   : null,
//             ),
//             const SizedBox(height: 10),
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: const BorderRadius.all(Radius.circular(4)),
//                 border: Border.fromBorderSide(
//                   BorderSide(
//                       color: _errorDescription
//                           ? colorScheme.error
//                           : _hasFocus
//                               ? colorScheme.primary
//                               : colorScheme.onSurface,
//                       width: _hasFocus ? 2 : 1),
//                 ),
//                 color: colorScheme.surface,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8),
//                     child: Text(
//                       '${appLoca.descrNPI}*',
//                       style: td.textTheme.bodySmall!.copyWith(
//                         color: _errorDescription
//                             ? colorScheme.error
//                             : _hasFocus
//                                 ? colorScheme.primary
//                                 : colorScheme.onSurface,
//                       ),
//                     ),
//                   ),
//                   Column(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Center(
//                         child: Container(
//                           constraints: const BoxConstraints(
//                               maxWidth: Auxiliar.maxWidth,
//                               minWidth: Auxiliar.maxWidth),
//                           decoration: BoxDecoration(
//                             color: colorScheme.primaryContainer,
//                           ),
//                           child: Auxiliar.quillToolbar(_quillController),
//                         ),
//                       ),
//                       Container(
//                         constraints: const BoxConstraints(
//                           maxWidth: Auxiliar.maxWidth,
//                           maxHeight: 300,
//                           minHeight: 150,
//                         ),
//                         child: QuillEditor.basic(
//                           controller: _quillController,
//                           config: QuillEditorConfig(
//                             padding: EdgeInsets.all(5),
//                           ),
//                           focusNode: _focusNode,
//                         ),
//                       ),
//                       Visibility(
//                         visible: _errorDescription,
//                         child: Padding(
//                           padding: const EdgeInsets.all(8),
//                           child: Text(
//                             appLoca.descrNPIExplica,
//                             style: textTheme.bodySmall!.copyWith(
//                               color: colorScheme.error,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   '${appLoca.currentPosition}: (${_feature.lat.toStringAsFixed(4)}, ${_feature.long.toStringAsFixed(4)})',
//                 ),
//               ),
//             ),
//             Container(
//               constraints: BoxConstraints(
//                 maxWidth: Auxiliar.maxWidth,
//                 maxHeight: min(400, size.height / 3),
//               ),
//               child: Stack(children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(5),
//                   child: Tooltip(
//                     message: appLoca.arrastrarMarcadorCambiarPosicion,
//                     child: FlutterMap(
//                       mapController: _mapController,
//                       options: MapOptions(
//                           backgroundColor: td.brightness == Brightness.light
//                               ? Colors.white54
//                               : Colors.black54,
//                           maxZoom: MapLayer.maxZoom,
//                           minZoom: MapLayer.maxZoom - 4,
//                           initialCenter: _feature.point,
//                           initialZoom: MapLayer.maxZoom - 2,
//                           interactionOptions: _btEnable
//                               ? const InteractionOptions(
//                                   flags: InteractiveFlag.drag |
//                                       InteractiveFlag.pinchZoom |
//                                       InteractiveFlag.doubleTapZoom |
//                                       InteractiveFlag.scrollWheelZoom,
//                                 )
//                               : const InteractionOptions(
//                                   flags: InteractiveFlag.none),
//                           onMapReady: () {
//                             setState(() {
//                               _markers = [
//                                 CHESTMarker(
//                                   context,
//                                   feature: _feature,
//                                   icon: const Icon(Icons.adjust),
//                                   visibleLabel: false,
//                                   currentLayer: MapLayer.layer!,
//                                   circleWidthBorder: 2,
//                                   circleWidthColor: colorScheme.primary,
//                                   circleContainerColor:
//                                       colorScheme.primaryContainer,
//                                 )
//                               ];
//                             });
//                           },
//                           onMapEvent: (event) {
//                             if (event is MapEventMove ||
//                                 event is MapEventDoubleTapZoomEnd ||
//                                 event is MapEventScrollWheelZoom) {
//                               setState(() {
//                                 LatLng p1 = _mapController.camera.center;
//                                 _feature.lat = p1.latitude;
//                                 _feature.long = p1.longitude;
//                                 _markers = [
//                                   CHESTMarker(
//                                     context,
//                                     feature: _feature,
//                                     icon: const Icon(Icons.adjust),
//                                     visibleLabel: false,
//                                     currentLayer: MapLayer.layer!,
//                                     circleWidthBorder: 2,
//                                     circleWidthColor: colorScheme.primary,
//                                     circleContainerColor:
//                                         colorScheme.primaryContainer,
//                                   )
//                                 ];
//                               });
//                             }
//                           }),
//                       children: [
//                         MapLayer.tileLayerWidget(
//                             brightness: Theme.of(context).brightness),
//                         MapLayer.atributionWidget(),
//                         MarkerLayer(
//                           markers: _markers,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8, left: 8),
//                   child: FloatingActionButton.small(
//                     heroTag: null,
//                     onPressed: () => Auxiliar.showMBS(
//                         context,
//                         Column(
//                           mainAxisSize: MainAxisSize.min,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Center(
//                               child:
//                                   Wrap(spacing: 10, runSpacing: 10, children: [
//                                 _botonMapa(
//                                   Layers.carto,
//                                   MediaQuery.of(context).platformBrightness ==
//                                           Brightness.light
//                                       ? 'images/basemap_gallery/estandar_claro.png'
//                                       : 'images/basemap_gallery/estandar_oscuro.png',
//                                   appLoca.mapaEstandar,
//                                 ),
//                                 _botonMapa(
//                                   Layers.satellite,
//                                   'images/basemap_gallery/satelite.png',
//                                   appLoca.mapaSatelite,
//                                 ),
//                               ]),
//                             ),
//                           ],
//                         ),
//                         title: appLoca.tipoMapa),
//                     child: Icon(
//                       Icons.settings_applications,
//                       semanticLabel: appLoca.ajustes,
//                     ),
//                   ),
//                 ),
//               ]),
//             ),
//             const SizedBox(height: 20),
//             Align(
//               alignment: Alignment.bottomRight,
//               child: FilledButton.icon(
//                 onPressed: () {
//                   bool noError = _keyStep0.currentState!.validate();
//                   if (_comment.trim().isEmpty) {
//                     setState(() => _errorDescription = true);
//                   } else {
//                     setState(() => _errorDescription = false);
//                     if (noError) {
//                       _feature.setLabels([PairLang(MyApp.currentLang, _label)]);
//                       _feature
//                           .setComments([PairLang(MyApp.currentLang, _comment)]);
//                       _feature.spatialThingTypes = _stt;
//                       setState(() => _step = 1);
//                     }
//                   }
//                 },
//                 label: Text(appLoca.siguiente),
//                 icon: Icon(Icons.arrow_right_alt),
//                 iconAlignment: IconAlignment.end,
//               ),
//             )
//           ]),
//     );
//   }

//   Widget _botonMapa(Layers layer, String image, String textLabel) {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: MapLayer.layer == layer
//               ? Theme.of(context).colorScheme.primary
//               : Colors.transparent,
//           width: 2,
//         ),
//       ),
//       margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
//       child: InkWell(
//         onTap: MapLayer.layer != layer ? () => _changeLayer(layer) : () {},
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Container(
//               margin: const EdgeInsets.all(10),
//               width: 100,
//               height: 100,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: Image.asset(
//                   image,
//                   fit: BoxFit.fill,
//                 ),
//               ),
//             ),
//             Container(
//               margin: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
//               child: Text(textLabel),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _changeLayer(Layers layer) async {
//     setState(() {
//       MapLayer.layer = layer;
//       // Auxiliar.updateMaxZoom();
//       if (_mapController.camera.zoom > MapLayer.maxZoom) {
//         _mapController.move(_mapController.camera.center, MapLayer.maxZoom);
//       }
//     });
//     if (UserXEST.userXEST.isNotGuest) {
//       http
//           .put(Queries.preferences(),
//               headers: {
//                 'content-type': 'application/json',
//                 'Authorization':
//                     'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
//               },
//               body: json.encode({'defaultMap': layer.name}))
//           .then((_) {
//         if (mounted) Navigator.pop(context);
//       }).onError((error, stackTrace) {
//         if (mounted) Navigator.pop(context);
//       });
//     } else {
//       Navigator.pop(context);
//     }
//   }

//   Widget _stepOne() {
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     ThemeData td = Theme.of(context);
//     ColorScheme colorScheme = td.colorScheme;
//     Size size = MediaQuery.of(context).size;
//     double mW = Auxiliar.maxWidth * 0.5;
//     double mH = size.width > size.height ? size.height * 0.5 : size.height / 3;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SegmentedButton(
//           multiSelectionEnabled: false,
//           emptySelectionAllowed: false,
//           style: SegmentedButton.styleFrom(
//             backgroundColor: colorScheme.surface,
//             foregroundColor: colorScheme.surfaceTint,
//             selectedForegroundColor: colorScheme.onPrimaryContainer,
//             selectedBackgroundColor: colorScheme.primaryContainer,
//           ),
//           showSelectedIcon: false,
//           segments: [
//             ButtonSegment<ImageSourceXEST>(
//               value: ImageSourceXEST.device,
//               icon: const Icon(Icons.devices),
//               label: Text(appLoca.fromDevice),
//               tooltip: appLoca.fromDevice,
//             ),
//             ButtonSegment<ImageSourceXEST>(
//               value: ImageSourceXEST.url,
//               icon: const Icon(Icons.link),
//               label: Text(appLoca.withLink),
//               tooltip: appLoca.withLink,
//             )
//           ],
//           selected: <ImageSourceXEST>{_imageSource},
//           onSelectionChanged: (Set<ImageSourceXEST> r) {
//             setState(() {
//               _imageSource = r.first;
//             });
//           },
//         ),
//         SizedBox(height: 10),
//         Visibility(
//           visible: _imageSource == ImageSourceXEST.device,
//           child: OutlinedButton.icon(
//             onPressed: _urlEscrita
//                 ? null
//                 : _fotoSubida
//                     ? _removeImageFile
//                     : _loadImageFile,
//             label: Text(_fotoSubida ? appLoca.removeImage : appLoca.addImage),
//             icon: Icon(_fotoSubida
//                 ? Icons.image_not_supported
//                 : Icons.add_photo_alternate),
//           ),
//         ),
//         Visibility(
//           visible: _imageSource == ImageSourceXEST.url,
//           child: TextFormField(
//             decoration: InputDecoration(
//               border: const OutlineInputBorder(),
//               labelText: appLoca.urlImage,
//               hintText:
//                   'https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/LOD_Cloud_-_2024-12-31.png/960px-LOD_Cloud_-_2024-12-31.png',
//               hintMaxLines: 1,
//               hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
//             ),
//             enabled: !_fotoSubida,
//             initialValue: _urlText,
//             onChanged: (value) {
//               setState(() {
//                 _showImage = false;
//                 _urlText = value.trim();
//                 _urlEscrita = value.trim().isNotEmpty;
//               });
//             },
//           ),
//         ),
//         SizedBox(height: 10),
//         Visibility(
//           visible: _imageSource == ImageSourceXEST.url,
//           child: OutlinedButton(
//             onPressed: _urlEscrita
//                 ? () async {
//                     try {
//                       if (Auxiliar.validURL(_urlText!)) {
//                         http.Response response =
//                             await http.get(Uri.parse(_urlText!));
//                         setState(() => _showImage = response.statusCode == 200);
//                       } else {
//                         setState(() => _showImage = false);
//                       }
//                     } catch (error) {
//                       if (ConfigXest.development) {
//                         debugPrint(error.toString());
//                         setState(() => _showImage = false);
//                       }
//                     }
//                   }
//                 : null,
//             child: Text(appLoca.check),
//           ),
//         ),
//         SizedBox(height: _imageUint8List != null ? 10 : 0),
//         _imageUint8List != null
//             ? Center(
//                 child: Container(
//                   constraints: BoxConstraints(maxHeight: mH, maxWidth: mW),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: Image.memory(
//                       _imageUint8List!,
//                     ),
//                   ),
//                 ),
//               )
//             : Container(),
//         _showImage
//             ? ImageNetwork(
//                 image: _urlText!,
//                 borderRadius: BorderRadius.circular(10),
//                 height: mH,
//                 width: mW,
//                 onLoading: CircularProgressIndicator.adaptive(),
//                 fitWeb: BoxFitWeb.contain,
//                 fitAndroidIos: BoxFit.contain,
//               )
//             : Container(),
//         SizedBox(height: 20),
//         Align(
//           alignment: Alignment.bottomRight,
//           child: Wrap(
//               spacing: 10,
//               runSpacing: 5,
//               direction: Axis.horizontal,
//               children: [
//                 TextButton.icon(
//                   onPressed: () => setState(() => _step = 0),
//                   label: Text(appLoca.atras),
//                   icon: Transform.rotate(
//                     angle: math.pi,
//                     child: Icon(Icons.arrow_right_alt),
//                   ),
//                 ),
//                 FilledButton.icon(
//                   onPressed: _urlEscrita && !_showImage
//                       ? null
//                       : () {
//                           if (_fotoSubida) {
//                             _feature.rawImage = _imageUint8List!;
//                           } else {
//                             _feature.resetRawImage();
//                           }
//                           if (_urlEscrita) {
//                             _feature.setImage(_urlText!);
//                           } else {
//                             _feature.image.clear();
//                             _feature.setThumbnail('', null);
//                           }
//                           setState(() {
//                             _step = 2;
//                           });
//                         },
//                   label: Text(appLoca.siguiente),
//                   icon: Icon(Icons.arrow_right_alt),
//                   iconAlignment: IconAlignment.end,
//                 ),
//               ]),
//         )
//       ],
//     );
//   }

//   _removeImageFile() async {
//     setState(() {
//       _fotoSubida = false;
//       _imageUint8List = null;
//     });
//   }

//   _loadImageFile() async {
//     Object? f = await AuxiliarFunctions.readExternalFile(
//         validExtensions: ['jpeg', 'jpg', 'png'], uint8List: true);

//     if (f is Uint8List) {
//       Uint8List f2 = await Auxiliar.comprimeImagen(f);
//       setState(() {
//         _imageUint8List = f2;
//         _fotoSubida = true;
//       });
//     }
//   }

//   Widget _stepTwo() {
//     AppLocalizations appLoca = AppLocalizations.of(context)!;

//     return Align(
//       alignment: Alignment.bottomRight,
//       child: Wrap(
//           spacing: 10,
//           runSpacing: 5,
//           direction: Axis.horizontal,
//           children: [
//             TextButton.icon(
//               onPressed: () => setState(() => _step = 1),
//               label: Text(appLoca.atras),
//               icon: Transform.rotate(
//                 angle: math.pi,
//                 child: Icon(Icons.arrow_right_alt),
//               ),
//             ),
//             FilledButton.icon(
//               onPressed: () {
//                 String body = json.encode(_feature.toJson());
//                 debugPrint(body);
//               },
//               label: Text(appLoca.siguiente),
//               icon: Icon(Icons.arrow_right_alt),
//               iconAlignment: IconAlignment.end,
//             ),
//           ]),
//     );
//   }
// }

class _FormFeature extends State<FormFeature> {
  late Feature _feature;
  String? image, licenseImage;
  late String _labelFeature, _commentFeature;
  late GlobalKey<FormState> _thisKey;
  late MapController _mapController;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription, _newFeature;
  late List<Marker> _markers;
  late bool _pasoUno, _btEnable;
  late SpatialThingType? _stt;

  @override
  void initState() {
    _feature = widget.feature;
    _newFeature = widget.newFeature;
    _thisKey = GlobalKey<FormState>();
    _mapController = MapController();
    _labelFeature = _feature.getALabel(lang: MyApp.currentLang);
    _commentFeature = _feature.getAComment(lang: MyApp.currentLang);
    _markers = [];
    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    _pasoUno = true;
    _btEnable = true;
    _stt = _feature.spatialThingTypes != null &&
            _feature.spatialThingTypes!.isNotEmpty
        ? _feature.spatialThingTypes!.first
        : null;
    try {
      _quillController.document =
          Document.fromDelta(HtmlToDelta().convert(_commentFeature));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _commentFeature =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    super.initState();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          title: Text(appLoca.tNPoi),
          centerTitle: false,
          pinned: true,
        ),
        SliverSafeArea(minimum: const EdgeInsets.all(10), sliver: _formNP()),
        SliverVisibility(
          visible: _feature.categories.isNotEmpty && !_pasoUno,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(
                [
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          appLoca.categories,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverVisibility(
          visible: _feature.categories.isNotEmpty && !_pasoUno,
          sliver: SliverSafeArea(
              minimum: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              sliver: _categoriesNP()),
        ),
        SliverPadding(padding: const EdgeInsets.all(10), sliver: _buttonNP())
      ]),
    );
  }

  Widget _formNP() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    Size size = MediaQuery.of(context).size;
    List<DropdownMenuItem<SpatialThingType>> lstDME = [];
    List<Map<String, dynamic>> l = [];
    for (SpatialThingType stt in SpatialThingType.values) {
      if (Auxiliar.getSpatialThingTypeNameLoca(appLoca, stt) != null) {
        l.add({
          'v': stt,
          't': Auxiliar.getSpatialThingTypeNameLoca(appLoca, stt)!
        });
      }
    }
    l.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['t'] as String).compareTo(b['t'] as String));
    for (Map<String, dynamic> stt in l) {
      lstDME.add(DropdownMenuItem(
        value: stt['v'],
        child: Text(stt['t']),
      ));
    }
    return SliverToBoxAdapter(
      child: Form(
        key: _thisKey,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Visibility(
                  visible: _pasoUno,
                  child: TextFormField(
                    maxLines: 1,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appLoca.tituloNPI,
                        hintText: appLoca.tituloNPI,
                        helperText: appLoca.requerido,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis)),
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.text,
                    enabled: _btEnable,
                    initialValue: _labelFeature,
                    onChanged: (String value) =>
                        setState(() => _labelFeature = value),
                    validator: (value) => (value == null ||
                            value.trim().isEmpty ||
                            value.trim().length > 120)
                        ? appLoca.tituloNPIExplica
                        : null,
                  ),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: const SizedBox(height: 10),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: Container(
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
                                  : _hasFocus
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
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
                ),
                Visibility(
                  visible: _pasoUno,
                  child: const SizedBox(height: 20),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${appLoca.currentPosition}: (${_feature.lat.toStringAsFixed(4)}, ${_feature.long.toStringAsFixed(4)})',
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: Auxiliar.maxWidth,
                      maxHeight: min(400, size.height / 3),
                    ),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Tooltip(
                          message: appLoca.arrastrarMarcadorCambiarPosicion,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                                backgroundColor:
                                    td.brightness == Brightness.light
                                        ? Colors.white54
                                        : Colors.black54,
                                maxZoom: MapLayer.maxZoom,
                                minZoom: MapLayer.maxZoom - 4,
                                initialCenter: _feature.point,
                                initialZoom: MapLayer.maxZoom - 2,
                                interactionOptions: _btEnable
                                    ? const InteractionOptions(
                                        flags: InteractiveFlag.drag |
                                            InteractiveFlag.pinchZoom |
                                            InteractiveFlag.doubleTapZoom |
                                            InteractiveFlag.scrollWheelZoom,
                                      )
                                    : const InteractionOptions(
                                        flags: InteractiveFlag.none),
                                onMapReady: () {
                                  setState(() {
                                    _markers = [
                                      CHESTMarker(
                                        context,
                                        feature: _feature,
                                        icon: const Icon(Icons.adjust),
                                        visibleLabel: false,
                                        currentLayer: MapLayer.layer!,
                                        circleWidthBorder: 2,
                                        circleWidthColor: colorScheme.primary,
                                        circleContainerColor:
                                            colorScheme.primaryContainer,
                                      )
                                    ];
                                  });
                                },
                                onMapEvent: (event) {
                                  if (event is MapEventMove ||
                                      event is MapEventDoubleTapZoomEnd ||
                                      event is MapEventScrollWheelZoom) {
                                    setState(() {
                                      LatLng p1 = _mapController.camera.center;
                                      _feature.lat = p1.latitude;
                                      _feature.long = p1.longitude;
                                      _markers = [
                                        CHESTMarker(
                                          context,
                                          feature: _feature,
                                          icon: const Icon(Icons.adjust),
                                          visibleLabel: false,
                                          currentLayer: MapLayer.layer!,
                                          circleWidthBorder: 2,
                                          circleWidthColor: colorScheme.primary,
                                          circleContainerColor:
                                              colorScheme.primaryContainer,
                                        )
                                      ];
                                    });
                                  }
                                }),
                            children: [
                              MapLayer.tileLayerWidget(
                                  brightness: Theme.of(context).brightness),
                              MapLayer.atributionWidget(),
                              MarkerLayer(
                                markers: _markers,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8),
                        child: FloatingActionButton.small(
                          heroTag: null,
                          onPressed: () => Auxiliar.showMBS(
                              context,
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _botonMapa(
                                            Layers.carto,
                                            MediaQuery.of(context)
                                                        .platformBrightness ==
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
                          child: Icon(
                            Icons.settings_applications,
                            semanticLabel: appLoca.ajustes,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: const SizedBox(height: 10),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: DropdownButtonFormField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '${appLoca.selectTipoLugar}*',
                      hintText: appLoca.selectTipoLugar,
                    ),
                    value: _stt,
                    items: lstDME,
                    onChanged: (SpatialThingType? v) {
                      setState(() => _stt = v);
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (SpatialThingType? v) {
                      return v == null ? appLoca.selectTipoLugarError : null;
                    },
                  ),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: const SizedBox(height: 10),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: TextFormField(
                    //Fuente de información
                    //Tengo que soportar que se puedan agregar más de una fuente de información
                    maxLines: 1,
                    enabled: _btEnable,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appLoca.fuentesNPI,
                        hintText: appLoca.fuentesNPI,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis)),
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    readOnly: _feature.hasSource,
                    initialValue: _feature.hasSource ? _feature.source : '',
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (v.trim().isEmpty) {
                          return appLoca.fuentesNPIExplica;
                        } else {
                          if (!_feature.hasSource) {
                            _feature.source = v.trim();
                          }
                          return null;
                        }
                      } else {
                        return null;
                      }
                    },
                  ),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: const SizedBox(height: 10),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: TextFormField(
                    enabled: _btEnable,
                    maxLines: 1,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLoca.imagenLabel,
                      hintText: appLoca.imagenLabel,
                      hintMaxLines: 1,
                      hintStyle:
                          const TextStyle(overflow: TextOverflow.ellipsis),
                    ),
                    initialValue:
                        _feature.hasThumbnail ? _feature.thumbnail.image : "",
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (Auxiliar.isUriResource(v.trim())) {
                          image = v.trim();
                          return null;
                        } else {
                          return appLoca.imagenExplica;
                        }
                      } else {
                        return null;
                      }
                    },
                  ),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: const SizedBox(height: 10),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: TextFormField(
                    enabled: _btEnable,
                    maxLines: 1,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLoca.licenciaLabel,
                      hintText: appLoca.licenciaLabel,
                      hintMaxLines: 1,
                      hintStyle:
                          const TextStyle(overflow: TextOverflow.ellipsis),
                    ),
                    initialValue: _feature.hasThumbnail
                        ? _feature.thumbnail.hasLicense
                            ? _feature.thumbnail.license
                            : ''
                        : "",
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        licenseImage = v.trim();
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoriesNP() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final int nBroader = _feature.categories[index].broader.length;
          final String vCategory = _feature.categories[index].label.first.value;
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: ListTile(
                title:
                    Text(nBroader > 0 ? '$vCategory ($nBroader)' : vCategory),
              ),
            ),
          );
        },
        childCount: _feature.categories.length,
      ),
    );
  }

  Widget _buttonNP() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceAround,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Visibility(
                  visible: !_pasoUno,
                  child: TextButton(
                    onPressed: _btEnable
                        ? () async {
                            setState(() {
                              _pasoUno = true;
                            });
                          }
                        : null,
                    child: Text(appLoca!.atras),
                  ),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: TextButton(
                    onPressed: _btEnable
                        ? _labelFeature.isNotEmpty
                            ? _commentFeature.isNotEmpty
                                ? () {
                                    setState(() {
                                      _pasoUno = false;
                                      _errorDescription = false;
                                    });
                                  }
                                : () => setState(() => _errorDescription = true)
                            : null
                        : null,
                    child: Text(appLoca.siguiente),
                  ),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(appLoca.enviarNPI),
                    onPressed: _btEnable
                        ? () async {
                            bool noError = _thisKey.currentState!.validate();
                            if (noError) {
                              setState(() => _btEnable = false);
                              _feature.setLabels(
                                  PairLang(MyApp.currentLang, _labelFeature));
                              _feature.setComments(PairLang(
                                  MyApp.currentLang, _commentFeature.trim()));
                              if (image != null) {
                                _feature.setThumbnail(
                                    image!.replaceAll('?width=300', ''),
                                    licenseImage);
                              }
                              _feature.spatialThingTypes = _stt;
                              Map<String, dynamic> bodyRequest = {
                                'lat': _feature.lat,
                                'long': _feature.long,
                                'comment': _feature.comments2List(),
                                'label': _feature.labels2List(),
                              };
                              if (image != null) {
                                _feature.setThumbnail(image!, licenseImage);
                                bodyRequest['image'] = _feature.thumbnail2Map();
                              }
                              if (_feature.categories.isNotEmpty) {
                                bodyRequest['categories'] =
                                    _feature.categoriesToList();
                              }
                              if (_feature.spatialThingTypes != null &&
                                  _feature.spatialThingTypes!.isNotEmpty) {
                                List<String> t = [];
                                for (SpatialThingType stt
                                    in _feature.spatialThingTypes!) {
                                  t.add(stt.name);
                                }
                                if (t.isNotEmpty) {
                                  bodyRequest['type'] = t;
                                }
                              }
                              if (_newFeature) {
                                http
                                    .post(
                                  Queries.newFeature(),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization':
                                        'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}',
                                  },
                                  body: json.encode(bodyRequest),
                                )
                                    .then((response) async {
                                  ScaffoldMessengerState? sMState = mounted
                                      ? ScaffoldMessenger.of(context)
                                      : null;
                                  switch (response.statusCode) {
                                    case 201:
                                      String idFeature =
                                          response.headers['location']!;
                                      _feature.id = Uri.decodeFull(idFeature);
                                      _feature.shortId =
                                          Auxiliar.id2shortId(_feature.id)!;
                                      setState(() => _btEnable = true);
                                      if (!ConfigXest.development) {
                                        await FirebaseAnalytics.instance
                                            .logEvent(
                                          name: "newFeature",
                                          parameters: {"iri": _feature.shortId},
                                        ).then(
                                          (value) {
                                            _feature.author =
                                                UserXEST.userXEST.iri;
                                            if (sMState != null) {
                                              sMState.clearSnackBars();
                                              sMState.showSnackBar(SnackBar(
                                                  content: Text(
                                                      appLoca.infoRegistrada)));
                                            }
                                            if (mounted) {
                                              Navigator.pop(context, _feature);
                                            }
                                          },
                                        ).onError((error, stackTrace) {
                                          _feature.author =
                                              UserXEST.userXEST.iri;
                                          if (sMState != null) {
                                            sMState.clearSnackBars();
                                            sMState.showSnackBar(SnackBar(
                                                content: Text(
                                                    appLoca.infoRegistrada)));
                                          }
                                          if (mounted) {
                                            Navigator.pop(context, _feature);
                                          }
                                        });
                                      } else {
                                        _feature.author = UserXEST.userXEST.iri;
                                        if (sMState != null) {
                                          sMState.clearSnackBars();
                                          sMState.showSnackBar(SnackBar(
                                              content: Text(
                                                  appLoca.infoRegistrada)));
                                        }
                                        if (mounted) {
                                          Navigator.pop(context, _feature);
                                        }
                                      }

                                      break;
                                    default:
                                      setState(() => _btEnable = true);
                                      if (sMState != null) {
                                        sMState.clearSnackBars();
                                        sMState.showSnackBar(SnackBar(
                                            content: Text(response.statusCode
                                                .toString())));
                                      }
                                      if (mounted) {
                                        Navigator.pop(context, _feature);
                                      }
                                  }
                                }).onError((error, stackTrace) async {
                                  setState(() => _btEnable = true);
                                  if (ConfigXest.development) {
                                    debugPrint(error.toString());
                                  } else {
                                    await FirebaseCrashlytics.instance
                                        .recordError(error, stackTrace);
                                  }
                                });
                              } else {
                                // TODO Edición
                                http.put(
                                    Queries.getFeatureInfo(_feature.shortId));
                              }
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  }
}
