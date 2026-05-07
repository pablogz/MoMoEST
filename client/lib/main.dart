import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:momoest/contact.dart';
import 'package:momoest/itineraries.dart';
import 'package:momoest/util/auth/firebase.dart';
import 'package:momoest/util/location_user.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/features.dart';
import 'package:momoest/tasks.dart';
import 'package:momoest/util/firebase_options.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/main_screen.dart';
import 'package:momoest/more_info.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/landing_page.dart';
import 'package:momoest/privacy.dart';
import 'package:momoest/settings.dart';
import 'package:momoest/bajas.dart';
import 'package:momoest/users.dart';
import 'package:momoest/util/theme.dart';
import 'package:momoest/feed.dart';
import 'package:momoest/study_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // bool conectado =
  //     await Connectivity().checkConnectivity() != ConnectivityResult.none;
  // if (conectado) {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = (errorDetails) =>
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    if (FirebaseAuth.instance.currentUser != null &&
        UserXEST.userXEST.rol.contains(Rol.guest)) {
      //Recupero la información del servidor
      await http.get(Queries.signIn(), headers: {
        'Authorization':
            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
      }).then((data) async {
        switch (data.statusCode) {
          case 200:
            Map<String, dynamic> j = json.decode(data.body);
            UserXEST.userXEST = UserXEST(j);
            if (!ConfigXest.development) {
              List<UserInfo> providerData =
                  FirebaseAuth.instance.currentUser!.providerData;
              for (UserInfo userInfo in providerData) {
                if (userInfo.providerId.contains(AuthProviders.google.name)) {
                  await FirebaseAnalytics.instance
                      .logLogin(loginMethod: AuthProviders.google.name)
                      .onError((error, stackTrace) async {
                    if (ConfigXest.development) {
                      debugPrint(error.toString());
                    } else {
                      await FirebaseCrashlytics.instance
                          .recordError(error, stackTrace);
                    }
                  });
                } else {
                  if (userInfo.providerId.contains(AuthProviders.apple.name)) {
                    await FirebaseAnalytics.instance
                        .logLogin(loginMethod: AuthProviders.apple.name)
                        .onError((error, stackTrace) async {
                      if (ConfigXest.development) {
                        debugPrint(error.toString());
                      } else {
                        await FirebaseCrashlytics.instance
                            .recordError(error, stackTrace);
                      }
                    });
                  }
                }
              }
            }
            break;
          default:
            FirebaseAuth.instance.signOut();
        }
      }).onError((error, stackTrace) {
        FirebaseAuth.instance.signOut();
      });
    }
  } catch (e) {
    if (ConfigXest.development) debugPrint(e.toString());
  }
  // setPathUrlStrategy();
  usePathUrlStrategy();
  // debugRepaintRainbowEnabled = true;
  // Permite que los context.push cambien la URL: https://github.com/flutter/flutter/issues/131083
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp(conectado: true));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.conectado});

  //Idioma app
  static String currentLang = UserXEST.userXEST.lang;
  static final List<String> langs = ["es", "en"];
  static Locale locale = const Locale('en', 'US');
  static LocationUser locationUser = LocationUser(defaultTargetPlatform);
  final bool? conectado;
  static final Future<SharedPreferencesWithCache> preferencesWithCache =
      SharedPreferencesWithCache.create(
          cacheOptions:
              const SharedPreferencesWithCacheOptions(allowList: {'tiles'}));
  static const String TILES_KEY = 'tiles';
  @override
  Widget build(BuildContext context) {
    //Idioma de la aplicación
    String aux = Platform.localeName;
    if (aux.contains("_")) {
      aux = aux.split("_")[0];
    } else {
      if (aux.contains("-")) {
        aux = aux.split("-")[0];
      }
    }
    if (langs.contains(aux)) {
      currentLang = aux;
    }

    locale = currentLang == 'es'
        ? const Locale('es', 'ES')
        : const Locale('en', 'US');
    final GoRouter router = GoRouter(
      initialLocation: '/',
      // TODO RECUERDA QUE LAS RUTAS COMPARTEN EXTRA!!!
      // PUEDE QUE SEA MEJOR IDEA EN EL 0 METER UN MAPA Y BUSCAR POR CLAVE
      routes: [
        GoRoute(
          caseSensitive: false,
          path: '/',
          builder: (context, state) => const LandingPage(),
          redirect: (context, state) => UserXEST.userXEST.isNotGuest
              ? UserXEST.userXEST.lastMapView.init
                  ? '/home?center=${UserXEST.userXEST.lastMapView.lat!},${UserXEST.userXEST.lastMapView.long!}&zoom=${UserXEST.userXEST.lastMapView.zoom!}'
                  : '/home'
              : null,
        ),
        // GoRoute(
        //     path: '/sparql',
        //     caseSensitive: false,
        //     redirect: (context, state) async {
        //       await launchUrl(
        //         state.uri,
        //         mode: kIsWeb
        //             ? LaunchMode.platformDefault
        //             : LaunchMode.inAppBrowserView,
        //       );
        //       return '/home';
        //     }),
        GoRoute(
            caseSensitive: false,
            path: '/home',
            builder: (context, state) => MyMap(
                  center: state.uri.queryParameters['center'],
                  zoom: state.uri.queryParameters['zoom'],
                ),
            routes: [
              GoRoute(
                  caseSensitive: false,
                  path: 'features/:shortId',
                  builder: (context, state) {
                    if (state.extra != null && state.extra is List) {
                      List extra = state.extra as List;
                      return InfoFeature(
                        shortId: state.pathParameters['shortId'],
                        locationUser: extra[0],
                        iconMarker: extra[1],
                      );
                    } else {
                      return InfoFeature(
                        shortId: state.pathParameters['shortId'],
                      );
                    }
                  },
                  routes: [
                    GoRoute(
                        caseSensitive: false,
                        path: 'tasks/:taskId',
                        builder: (context, state) {
                          if (state.extra != null && state.extra is List) {
                            List extra = state.extra as List;
                            return COTask(
                              shortIdContainer:
                                  state.pathParameters['shortId']!,
                              shortIdTask: state.pathParameters['taskId']!,
                              answer: extra[2],
                              preview: extra[3],
                              userIsNear: extra[4],
                            );
                          } else {
                            return COTask(
                              shortIdContainer:
                                  state.pathParameters['shortId']!,
                              shortIdTask: state.pathParameters['taskId']!,
                            );
                          }
                        })
                  ]),
              GoRoute(
                caseSensitive: false,
                path: '/itineraries/:idIt',
                builder: (context, state) =>
                    InfoItinerary(state.pathParameters['idIt']!),
              ),
              GoRoute(
                caseSensitive: false,
                path: '/feeds/:idFeed',
                builder: (context, state) =>
                    InfoFeed(state.pathParameters['idFeed']!),
              )
            ]),
        GoRoute(
          caseSensitive: false,
          path: '/about',
          builder: (context, state) => const MoreInfo(),
        ),
        GoRoute(
          caseSensitive: false,
          path: '/privacy',
          builder: (context, state) => const Privacy(),
        ),
        GoRoute(
          caseSensitive: false,
          path: '/contact',
          builder: (context, state) => const Contact(),
        ),
        GoRoute(
          caseSensitive: false,
          path: '/bajas',
          builder: (context, state) => const InfoBajas(),
        ),
        GoRoute(
          caseSensitive: false,
          path: '/studyInfo',
          builder: (context, state) => const StudyInfo(),
        ),
        GoRoute(
            caseSensitive: false,
            path: '/users/:idUser',
            builder: (context, state) => const InfoUser(),
            routes: [
              GoRoute(
                caseSensitive: false,
                path: 'newUser',
                builder: (context, state) {
                  if (state.extra != null && state.extra is List) {
                    List extra = state.extra as List;
                    return NewUser(
                      lat: extra[0],
                      long: extra[1],
                      zoom: extra[2],
                    );
                  } else {
                    return const NewUser();
                  }
                },
                redirect: (BuildContext context, GoRouterState state) {
                  if (!UserXEST.allowNewUser) {
                    return UserXEST.userXEST.isNotGuest &&
                            UserXEST.userXEST.lastMapView.init
                        ? '/home?center=${UserXEST.userXEST.lastMapView.lat!},${UserXEST.userXEST.lastMapView.long!}&zoom=${UserXEST.userXEST.lastMapView.zoom!}'
                        : '/home';
                  }
                  return null;
                },
              ),
              GoRoute(
                caseSensitive: false,
                path: 'deleteUser',
                builder: (context, state) => const MoreInfo(),
              ),
              GoRoute(
                caseSensitive: false,
                path: 'editUser',
                builder: (context, state) => const EditUser(),
                redirect: (context, state) {
                  if (!UserXEST.allowManageUser) {
                    return '/map';
                  }
                  return null;
                },
              ),
              GoRoute(
                caseSensitive: false,
                path: 'settings',
                builder: (context, state) => const Settings(),
                redirect: (context, state) {
                  return UserXEST.userXEST.isNotGuest &&
                          state.uri
                              .toString()
                              .contains(UserXEST.userXEST.id.split('/').last)
                      ? null
                      : '/map';
                },
              )
            ])
      ],
    );

    TextTheme textTheme =
        Auxiliar.createTextTheme(context, "Manrope", "Manrope");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp.router(
      title: ConfigXest.nameApp,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      theme: theme.light(),
      darkTheme: theme.dark(),
      highContrastTheme: theme.lightHighContrast(),
      highContrastDarkTheme: theme.darkHighContrast(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

class SinConexion extends StatelessWidget {
  const SinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SelectableText(
          "Offline :(",
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
    );
  }
}
