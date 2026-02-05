import 'package:flutter/material.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';

class Privacy extends StatelessWidget {
  const Privacy({super.key});

  @override
  Widget build(BuildContext context) {
    TextTheme textTheme = Theme.of(context).textTheme;
    TextStyle titulo = textTheme.titleLarge!;
    TextStyle cuerpo = textTheme.bodyMedium!;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    List<String> lstWidget = [
      appLoca.politicaDatosTitulo,
      appLoca.politicaDatos,
      appLoca.politicaLocalizacionTitulo,
      appLoca.politicaLocalizacion,
      appLoca.politicaContactoTitulo,
      appLoca.politicaContacto,
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.politica),
            centerTitle: false,
            floating: true,
            pinned: true,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              vertical: 40,
              horizontal:
                  Auxiliar.getLateralMargin(MediaQuery.of(context).size.width),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                      padding: EdgeInsets.only(
                        top: index.isEven ? 0 : 10,
                        bottom: index.isEven ? 0 : 20,
                      ),
                      child: SelectableText(
                        lstWidget.elementAt(index),
                        style: index.isEven ? titulo : cuerpo,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  );
                },
                childCount: lstWidget.length,
              ),
            ),
          )
        ],
      ),
    );
  }
}
