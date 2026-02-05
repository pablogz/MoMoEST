import 'package:flutter/material.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/util/auxiliar.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _Settings();
}

class _Settings extends State<Settings> {
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
      TextButton(
        onPressed: () => MapData.resetLocalCache(),
        child: Text(appLoca.reiniciarCache),
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
}
