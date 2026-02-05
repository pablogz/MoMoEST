import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/auxiliar.dart';

class FullScreenImage extends StatelessWidget {
  final PairImage urlImagen;
  final bool local;
  const FullScreenImage(
    this.urlImagen, {
    this.local = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Widget imagen = InteractiveViewer(
      minScale: 0.5,
      maxScale: 12,
      child: local
          ? Image.asset(urlImagen.image)
          : ImageNetwork(
              image: urlImagen.image,
              imageCache: CachedNetworkImageProvider(urlImagen.image),
              height: size.height,
              width: size.width,
              duration: 0,
              fitWeb: BoxFitWeb.contain,
              fitAndroidIos: BoxFit.contain,
              onTap: null,
              onError: const Icon(Icons.image_not_supported),
              onLoading: const CircularProgressIndicator.adaptive(),
            ),
    );
    Widget cuerpo;
    if (urlImagen.hasLicense) {
      cuerpo = Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: imagen),
          TextButton.icon(
              onPressed: () async {
                ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
                try {
                  if (!await launchUrl(Uri.parse(urlImagen.license))) {
                    throw Exception();
                  }
                } catch (error) {
                  sms.clearSnackBars();
                  sms.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Error",
                      ),
                    ),
                  );
                }
              },
              label: Text(AppLocalizations.of(context)!.licenciaLabel),
              icon: const Icon(Icons.local_police)),
        ],
      );
    } else {
      cuerpo = imagen;
    }
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Theme.of(context).primaryColorDark,
        // leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.pantallaCompleta),
      ),
      body: Center(child: cuerpo),
    );
  }
}

class FullScreenQR extends StatelessWidget {
  final String dataQr;
  const FullScreenQR(this.dataQr, {super.key});
  @override
  Widget build(BuildContext context) {
    double size = MediaQuery.of(context).size.shortestSide * 0.9;
    ThemeData td = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text("QR"),
            centerTitle: false,
          ),
          SliverPadding(
            padding: EdgeInsets.all(Auxiliar.getLateralMargin(size)),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: QrImageView(
                  data: dataQr,
                  size: size,
                  version: QrVersions.auto,
                  gapless: false,
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: td.brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: td.brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
