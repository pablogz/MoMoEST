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

  Widget _langSelector(AppLocalizations appLoca) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            appLoca.idiomaApp,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SegmentedButton<String?>(
          segments: [
            ButtonSegment(
              value: null,
              label: Text(appLoca.idiomaDispositivo),
            ),
            const ButtonSegment(
              value: 'es',
              label: Text('Español'),
            ),
            const ButtonSegment(
              value: 'en',
              label: Text('English'),
            ),
            const ButtonSegment(
              value: 'pt',
              label: Text('Português'),
            ),
            const ButtonSegment(
              value: 'it',
              label: Text('Italiano'),
            ),
          ],
          selected: {_selectedLang},
          onSelectionChanged: (selection) {
            final lang = selection.first;
            setState(() => _selectedLang = lang);
            LocaleManager.applyLocale(lang);
          },
        ),
      ],
    );
  }
}
