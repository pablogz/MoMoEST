import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_network/image_network.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/auxiliar.dart';

class FullScreenImage extends StatelessWidget {
  final PairImage urlImagen;
  final bool local;
  final String? label;
  const FullScreenImage(
    this.urlImagen, {
    this.local = false,
    this.label,
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
          label != null
              ? Padding(
                  padding: EdgeInsetsGeometry.all(Auxiliar.compactMargin),
                  child: Text(
                    label!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : Container(),
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
      cuerpo = Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: imagen),
          label != null
              ? Padding(
                  padding: EdgeInsetsGeometry.all(Auxiliar.compactMargin),
                  child: Text(
                    label!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : Container(),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pantallaCompleta),
        actions: [
          if (!local)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: AppLocalizations.of(context)!.descargar,
              onPressed: () => _guardarImagen(context),
            ),
        ],
      ),
      body: Center(child: cuerpo),
    );
  }

  Future<void> _guardarImagen(BuildContext context) async {
    final sms = ScaffoldMessenger.of(context);
    try {
      if (kIsWeb) {
        if (!await launchUrl(
          Uri.parse(urlImagen.image),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception();
        }
      } else {
        final response = await http.get(Uri.parse(urlImagen.image));
        final dir = await getTemporaryDirectory();
        final uri = Uri.parse(urlImagen.image);
        final filename =
            uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
                ? uri.pathSegments.last
                : 'image.jpg';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: label ?? ''),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      sms.clearSnackBars();
      sms.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noLanzarURL),
        ),
      );
    }
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
