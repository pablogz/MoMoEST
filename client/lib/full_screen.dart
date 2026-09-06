import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_network/image_network.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/helpers/save_file.dart';
import 'package:momoest/util/auxiliar.dart';

/// Visor de imágenes en pantalla completa. Acepta una lista de imágenes por
/// las que se puede navegar deslizando lateralmente, manteniendo el zoom por
/// imagen. [labels] es opcional y posicional respecto a [images].
class FullScreenImage extends StatefulWidget {
  final List<PairImage> images;
  final int initialIndex;
  final bool local;
  final List<String?>? labels;

  FullScreenImage(
    PairImage image, {
    this.local = false,
    String? label,
    super.key,
  })  : images = [image],
        initialIndex = 0,
        labels = label != null ? [label] : null;

  const FullScreenImage.list(
    this.images, {
    this.initialIndex = 0,
    this.local = false,
    this.labels,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _FullScreenImage();
}

class _FullScreenImage extends State<FullScreenImage> {
  late PageController _pageController;
  late int _index;

  @override
  void initState() {
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PairImage get _current => widget.images.elementAt(_index);

  String? get _currentLabel =>
      widget.labels != null && _index < widget.labels!.length
          ? widget.labels!.elementAt(_index)
          : null;

  Widget _pagina(BuildContext context, int index) {
    Size size = MediaQuery.of(context).size;
    PairImage pairImage = widget.images.elementAt(index);
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 12,
      child: widget.local
          ? Image.asset(pairImage.image)
          : ImageNetwork(
              image: pairImage.image,
              imageCache: CachedNetworkImageProvider(pairImage.image),
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
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    bool several = widget.images.length > 1;
    Widget visor = PageView.builder(
      controller: _pageController,
      itemCount: widget.images.length,
      onPageChanged: (int i) => setState(() => _index = i),
      itemBuilder: _pagina,
    );

    List<Widget> pie = [];
    if (_currentLabel != null) {
      pie.add(Padding(
        padding: EdgeInsetsGeometry.all(Auxiliar.compactMargin),
        child: Text(
          _currentLabel!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ));
    }
    if (_current.hasLicense) {
      pie.add(TextButton.icon(
          onPressed: () async {
            ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
            try {
              if (!await launchUrl(Uri.parse(_current.license))) {
                throw Exception();
              }
            } catch (error) {
              sms.clearSnackBars();
              sms.showSnackBar(
                SnackBar(
                  content: Text(appLoca.noLanzarURL),
                ),
              );
            }
          },
          label: Text(appLoca.licenciaLabel),
          icon: const Icon(Icons.local_police)));
    }

    Widget cuerpo = Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: several
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    visor,
                    Positioned(
                      left: 0,
                      child: Visibility(
                        visible: _index > 0,
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_left),
                          tooltip: appLoca.imagenAnterior,
                          onPressed: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Visibility(
                        visible: _index < widget.images.length - 1,
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_right),
                          tooltip: appLoca.imagenSiguiente,
                          onPressed: () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : visor,
        ),
        ...pie,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(several
            ? '${appLoca.pantallaCompleta} (${_index + 1}/${widget.images.length})'
            : appLoca.pantallaCompleta),
        actions: [
          if (!widget.local)
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
    final appLoca = AppLocalizations.of(context)!;
    // Anchor rect para el popover del share sheet en iPad: sin él,
    // share_plus falla en iPad aunque funcione en iPhone.
    final box = context.findRenderObject() as RenderBox?;
    final Rect sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, 100);
    final PairImage imagen = _current;
    try {
      if (kIsWeb) {
        if (!await launchUrl(
          Uri.parse(imagen.image),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception();
        }
        return;
      }
      final response = await http.get(Uri.parse(imagen.image));
      if (response.statusCode != 200) {
        throw Exception('Status code: ${response.statusCode}');
      }
      final uri = Uri.parse(imagen.image);
      final filename =
          uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
              ? uri.pathSegments.last
              : 'image.jpg';
      final SaveResult resultado = await SaveFile.save(
        bytes: response.bodyBytes,
        fileName: filename,
        subject: _currentLabel ?? '',
        sharePositionOrigin: sharePositionOrigin,
      );
      sms.clearSnackBars();
      final String? aviso = mensajeGuardado(appLoca, resultado);
      if (aviso != null) sms.showSnackBar(SnackBar(content: Text(aviso)));
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

/// Visor a pantalla completa para imágenes ya descargadas en memoria
/// (p.ej. ficheros que requieren autenticación para su descarga).
class FullScreenImageBytes extends StatelessWidget {
  final Uint8List bytes;
  final String? label;
  final String fileName;

  const FullScreenImageBytes(
    this.bytes, {
    this.fileName = 'image.png',
    this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(appLoca.pantallaCompleta),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: appLoca.descargar,
              onPressed: () => _guardar(context),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 12,
                child: Center(child: Image.memory(bytes)),
              ),
            ),
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
        ),
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    final sms = ScaffoldMessenger.of(context);
    final appLoca = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    final Rect sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, 100);
    final SaveResult resultado = await SaveFile.save(
      bytes: bytes,
      fileName: fileName,
      mime: 'image/png',
      subject: label ?? '',
      sharePositionOrigin: sharePositionOrigin,
    );
    sms.clearSnackBars();
    final String? aviso = mensajeGuardado(appLoca, resultado);
    if (aviso != null) sms.showSnackBar(SnackBar(content: Text(aviso)));
  }
}

/// Aviso que se enseña tras pedir la descarga de una imagen. Devuelve null
/// cuando el usuario ya ha visto la hoja de compartir y no hace falta decir
/// nada más.
String? mensajeGuardado(AppLocalizations appLoca, SaveResult resultado) {
  switch (resultado) {
    case SaveResult.downloads:
      return appLoca.imagenGuardadaDescargas;
    case SaveResult.appFiles:
      return appLoca.imagenGuardadaArchivos;
    case SaveResult.shared:
      return null;
    case SaveResult.error:
      return appLoca.noLanzarURL;
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
