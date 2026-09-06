import 'package:flutter/material.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/locale_manager.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _Settings();
}

class _Settings extends State<Settings> {
  String? _selectedLang;

  @override
  void initState() {
    super.initState();
    _loadSavedLang();
  }

  Future<void> _loadSavedLang() async {
    final saved = await LocaleManager.getSavedLang();
    if (mounted) setState(() => _selectedLang = saved);
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.ajustes),
            centerTitle: false,
          ),
          bodyWidget(),
        ],
      ),
    );
  }

  Widget bodyWidget() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double widthScreen = MediaQuery.of(context).size.width;
    List<Widget> lstBody = [
      _langSelector(appLoca),
      Padding(
        padding: EdgeInsetsGeometry.only(top: 16),
        child: OutlinedButton.icon(
          onPressed: () {
            MapData.resetLocalCache();
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(appLoca.resetCache),
              duration: const Duration(milliseconds: 1500),
            ));
          },
          icon: Icon(Icons.delete),
          label: Text(appLoca.reiniciarCache),
        ),
      ),
    ];

    return SliverList.builder(
      itemCount: lstBody.length,
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          alignment: Alignment.topLeft,
          child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 5,
                horizontal: Auxiliar.getLateralMargin(widthScreen),
              ),
              child: lstBody.elementAt(index)),
        ),
      ),
    );
  }

  /// Cada idioma se muestra escrito en su propio idioma, para que se reconozca
  /// aunque la aplicación esté en una lengua que no se entienda.
  static const Map<String, String> _langNames = {
    'es': 'Español',
    'en': 'English',
    'pt': 'Português',
    'it': 'Italiano',
  };

  Widget _langSelector(AppLocalizations appLoca) {
    ThemeData td = Theme.of(context);
    List<String?> langs = [null, ..._langNames.keys];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            appLoca.idiomaApp,
            style: td.textTheme.titleSmall,
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: td.colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: RadioGroup<String?>(
            groupValue: _selectedLang,
            onChanged: (String? value) {
              setState(() => _selectedLang = value);
              LocaleManager.applyLocale(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: langs
                  .map((String? lang) => RadioListTile<String?>.adaptive(
                        value: lang,
                        title: Text(
                          lang == null
                              ? appLoca.idiomaDispositivo
                              : _langNames[lang]!,
                          style: td.textTheme.bodyLarge,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
