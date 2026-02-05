import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/auxiliar_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';
import 'package:http/http.dart' as http;

enum ImageSource { device, url }

class PruebaImagen extends StatefulWidget {
  const PruebaImagen({super.key});
  @override
  State<PruebaImagen> createState() => _PruebaImagen();
}

class _PruebaImagen extends State<PruebaImagen> {
  late bool _fotoSubida, _urlEscrita, _showImage;
  late Uint8List? _uriFoto1, _uriFoto2;
  late String? _urlText;
  late ImageSource _imageSource;

  @override
  void initState() {
    _showImage = false;
    _fotoSubida = false;
    _urlEscrita = false;
    _uriFoto1 = null;
    _uriFoto2 = null;
    _urlText = null;
    _imageSource = ImageSource.device;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    Size size = MediaQuery.of(context).size;
    double mW = Auxiliar.maxWidth * 0.5;
    double mH = size.width > size.height ? size.height * 0.5 : size.height / 3;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text("Prueba"),
            centerTitle: false,
          ),
          SliverSafeArea(
            minimum: EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton(
                        multiSelectionEnabled: false,
                        emptySelectionAllowed: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          foregroundColor: colorScheme.surfaceTint,
                          selectedForegroundColor:
                              colorScheme.onPrimaryContainer,
                          selectedBackgroundColor: colorScheme.primaryContainer,
                        ),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment<ImageSource>(
                            value: ImageSource.device,
                            icon: const Icon(Icons.devices),
                            label: Text(appLoca.fromDevice),
                            tooltip: appLoca.fromDevice,
                          ),
                          ButtonSegment<ImageSource>(
                            value: ImageSource.url,
                            icon: const Icon(Icons.link),
                            label: Text(appLoca.withLink),
                            tooltip: appLoca.withLink,
                          )
                        ],
                        selected: <ImageSource>{_imageSource},
                        onSelectionChanged: (Set<ImageSource> r) {
                          setState(() {
                            _imageSource = r.first;
                          });
                        },
                      ),
                      SizedBox(height: 10),
                      Visibility(
                        visible: _imageSource == ImageSource.device,
                        child: OutlinedButton.icon(
                          onPressed: _urlEscrita
                              ? null
                              : _fotoSubida
                                  ? _removeImageFile
                                  : _loadImageFile,
                          label: Text(_fotoSubida
                              ? appLoca.removeImage
                              : appLoca.addImage),
                          icon: Icon(_fotoSubida
                              ? Icons.image_not_supported
                              : Icons.add_photo_alternate),
                        ),
                      ),
                      Visibility(
                        visible: _imageSource == ImageSource.url,
                        child: TextFormField(
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: appLoca.urlImage,
                            hintText:
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/LOD_Cloud_-_2024-12-31.png/960px-LOD_Cloud_-_2024-12-31.png',
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis),
                          ),
                          autovalidateMode: AutovalidateMode.onUnfocus,
                          enabled: !_fotoSubida,
                          onChanged: (value) {
                            setState(() {
                              _showImage = false;
                              _urlText = value.trim();
                              _urlEscrita = value.trim().isNotEmpty;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 10),
                      Visibility(
                        visible: _imageSource == ImageSource.url,
                        child: OutlinedButton.icon(
                          onPressed: _urlEscrita
                              ? () async {
                                  try {
                                    if (Auxiliar.validURL(_urlText!)) {
                                      http.Response response =
                                          await http.get(Uri.parse(_urlText!));
                                      debugPrint(
                                          response.statusCode.toString());
                                      setState(() => _showImage =
                                          response.statusCode == 200);
                                    } else {
                                      setState(() => _showImage = false);
                                    }
                                  } catch (error) {
                                    if (ConfigXest.development) {
                                      debugPrint(error.toString());
                                      setState(() => _showImage = false);
                                    }
                                  }
                                }
                              : null,
                          icon: Icon(Icons.check),
                          label: Text(appLoca.check),
                        ),
                      ),
                      SizedBox(height: _uriFoto1 != null ? 10 : 0),
                      _uriFoto1 != null
                          ? Center(
                              child: Container(
                                constraints:
                                    BoxConstraints(maxHeight: mH, maxWidth: mW),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _uriFoto1!,
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                      SizedBox(height: _uriFoto2 != null ? 10 : 0),
                      _uriFoto2 != null
                          ? Center(
                              child: Container(
                                  constraints: BoxConstraints(
                                      maxHeight: mH, maxWidth: mW),
                                  child: Image.memory(
                                    _uriFoto2!,
                                  )),
                            )
                          : Container(),
                      SizedBox(height: _showImage ? 10 : 0),
                      _showImage
                          ? ImageNetwork(
                              image: _urlText!,
                              height: mH,
                              width: mW,
                              onLoading: CircularProgressIndicator.adaptive(),
                              fitWeb: BoxFitWeb.contain,
                              fitAndroidIos: BoxFit.contain,
                            )
                          : Container()
                    ],
                    // Tengo que comprobar el estado del servidor ya que no puedo hacer la comprobación dentro del ImageNetwork
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  _removeImageFile() async {
    setState(() {
      _fotoSubida = false;
      _uriFoto1 = null;
      _uriFoto2 = null;
    });
  }

  _loadImageFile() async {
    Object? f = await AuxiliarFunctions.readExternalFile(
        validExtensions: ['jpeg', 'jpg', 'png'], uint8List: true);

    if (f is Uint8List) {
      Uint8List f2 = await Auxiliar.comprimeImagen(f);
      setState(() {
        _uriFoto1 = f;
        _uriFoto2 = f2;
        _fotoSubida = true;
      });
    }
  }
}
