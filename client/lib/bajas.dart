import 'package:flutter/material.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';

class InfoBajas extends StatelessWidget {
  const InfoBajas({super.key});

  @override
  Widget build(BuildContext context) {
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    debugPrint(margenLateral.toString());
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(appLoca.bajasTitulo)),
          SliverSafeArea(
            minimum: EdgeInsets.symmetric(
              horizontal: margenLateral,
              vertical: 20,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(appLoca.bajasTexto),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
