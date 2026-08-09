import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/config_xest.dart';

/// Herramientas disponibles en el editor de dibujo
enum DrawTool { free, line, text }

/// Elemento pintable del lienzo. Cada trazo/línea/texto es un elemento
/// independiente para poder deshacer trazo a trazo.
abstract class DrawElement {
  void paintOn(Canvas canvas);
}

/// Trazo libre: lista de puntos capturados durante el gesto
class StrokeElement extends DrawElement {
  final List<Offset> points;
  final Color color;
  final double width;

  StrokeElement(this.points, this.color, this.width);

  @override
  void paintOn(Canvas canvas) {
    if (points.isEmpty) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (points.length == 1) {
      canvas.drawPoints(ui.PointMode.points, points, paint);
      return;
    }
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }
}

/// Línea recta entre dos puntos
class LineElement extends DrawElement {
  final Offset start;
  Offset end;
  final Color color;
  final double width;

  LineElement(this.start, this.end, this.color, this.width);

  @override
  void paintOn(Canvas canvas) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, paint);
  }
}

/// Texto colocado sobre el lienzo
class TextElement extends DrawElement {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  TextElement(this.text, this.position, this.color, this.fontSize);

  @override
  void paintOn(Canvas canvas) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }
}

class _DrawPainter extends CustomPainter {
  final ui.Image? background;
  final List<DrawElement> elements;
  final DrawElement? current;

  _DrawPainter({
    required this.background,
    required this.elements,
    this.current,
  });

  /// Pinta el estado completo del lienzo sobre [canvas]. Método compartido
  /// entre la vista interactiva y la exportación a imagen.
  static void paintAll(
    Canvas canvas,
    Size size,
    ui.Image? background,
    List<DrawElement> elements,
    DrawElement? current,
  ) {
    // Fondo blanco para que la exportación no sea transparente
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    if (background != null) {
      // Imagen de fondo ajustada al lienzo manteniendo la proporción
      final Size imageSize =
          Size(background.width.toDouble(), background.height.toDouble());
      final FittedSizes fitted =
          applyBoxFit(BoxFit.contain, imageSize, size);
      final Rect inputSubrect = Alignment.center
          .inscribe(fitted.source, Offset.zero & imageSize);
      final Rect outputSubrect =
          Alignment.center.inscribe(fitted.destination, Offset.zero & size);
      canvas.drawImageRect(background, inputSubrect, outputSubrect, Paint());
    }
    for (final DrawElement element in elements) {
      element.paintOn(canvas);
    }
    current?.paintOn(canvas);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintAll(canvas, size, background, elements, current);
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => true;
}

/// Editor de dibujo construido sobre el Canvas de Flutter (CustomPainter +
/// GestureDetector), sin paquetes de dibujo de terceros. Devuelve el PNG del
/// resultado mediante Navigator.pop.
///
/// Modos: lienzo en blanco, o lienzo con la imagen indicada en
/// [backgroundUrl] como fondo (se pinta primero en el Canvas y los trazos van
/// encima). Con [initialElements] se puede continuar editando un dibujo.
class DrawEditor extends StatefulWidget {
  final String? backgroundUrl;

  /// Imagen de fondo ya descargada (p.ej. el dibujo previo de una nota)
  final Uint8List? backgroundBytes;
  final List<DrawElement>? initialElements;

  const DrawEditor({
    this.backgroundUrl,
    this.backgroundBytes,
    this.initialElements,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _DrawEditor();
}

/// Resultado del editor: el PNG exportado y los elementos por si se quiere
/// seguir editando después.
class DrawResult {
  final Uint8List pngBytes;
  final List<DrawElement> elements;
  DrawResult(this.pngBytes, this.elements);
}

class _DrawEditor extends State<DrawEditor> {
  static const List<Color> _palette = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.brown,
  ];

  ui.Image? _background;
  bool _loadingBackground = false;
  bool _exporting = false;
  late List<DrawElement> _elements;
  DrawTool _tool = DrawTool.free;
  Color _color = Colors.black;
  double _strokeWidth = 4;
  StrokeElement? _currentStroke;
  LineElement? _currentLine;
  String? _pendingText;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    _elements = List<DrawElement>.from(widget.initialElements ?? []);
    if (widget.backgroundBytes != null ||
        (widget.backgroundUrl != null && widget.backgroundUrl!.isNotEmpty)) {
      _loadingBackground = true;
      _loadBackground();
    }
    super.initState();
  }

  Future<void> _loadBackground() async {
    try {
      Uint8List bytes;
      if (widget.backgroundBytes != null) {
        bytes = widget.backgroundBytes!;
      } else {
        final response = await http.get(Uri.parse(widget.backgroundUrl!));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw Exception('Status code: ${response.statusCode}');
        }
        bytes = response.bodyBytes;
      }
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _background = frame.image;
          _loadingBackground = false;
        });
      }
      return;
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      if (mounted) {
        setState(() => _loadingBackground = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorCargarFondo),
          ),
        );
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    switch (_tool) {
      case DrawTool.free:
        setState(() {
          _currentStroke =
              StrokeElement([details.localPosition], _color, _strokeWidth);
        });
        break;
      case DrawTool.line:
        setState(() {
          _currentLine = LineElement(
              details.localPosition, details.localPosition, _color,
              _strokeWidth);
        });
        break;
      case DrawTool.text:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final Offset point = Offset(
      details.localPosition.dx.clamp(0, _canvasSize.width),
      details.localPosition.dy.clamp(0, _canvasSize.height),
    );
    switch (_tool) {
      case DrawTool.free:
        setState(() => _currentStroke?.points.add(point));
        break;
      case DrawTool.line:
        setState(() => _currentLine?.end = point);
        break;
      case DrawTool.text:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentStroke != null) {
        _elements.add(_currentStroke!);
        _currentStroke = null;
      }
      if (_currentLine != null) {
        _elements.add(_currentLine!);
        _currentLine = null;
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (_tool == DrawTool.text && _pendingText != null) {
      setState(() {
        _elements.add(TextElement(
          _pendingText!,
          details.localPosition,
          _color,
          _strokeWidth * 5 + 8,
        ));
        _pendingText = null;
      });
    }
  }

  Future<void> _selectTextTool() async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    String texto = '';
    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLoca.herramientaTexto),
        content: TextFormField(
          autofocus: true,
          maxLines: 3,
          maxLength: 120,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appLoca.textoDibujo,
          ),
          onChanged: (v) => texto = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(appLoca.cancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, texto.trim()),
            child: Text(appLoca.guardar),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _tool = DrawTool.text;
        _pendingText = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.colocaTexto),
            duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _selectColor() async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final Color? selected = await showModalBottomSheet<Color>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appLoca.colorTrazo,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _palette
                    .map((c) => InkWell(
                          onTap: () => Navigator.pop(ctx, c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c == _color
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.outline,
                                width: c == _color ? 3 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _color = selected);
    }
  }

  Future<Uint8List?> _exportPng() async {
    if (_canvasSize == Size.zero) return null;
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      // Un dibujo de línea sobre lienzo blanco comprime muy bien en PNG, así
      // que se exporta al doble de resolución para ganar nitidez. Sobre una
      // fotografía de fondo el PNG es mucho más pesado, así que ahí se exporta
      // a tamaño real y se limita el lado mayor, para no agotar la cuota del
      // usuario con una sola nota.
      const double maxSide = 2000;
      double scale = _background == null ? 2 : 1;
      final double longest =
          _canvasSize.width > _canvasSize.height ? _canvasSize.width : _canvasSize.height;
      if (longest * scale > maxSide) {
        scale = maxSide / longest;
      }
      canvas.scale(scale);
      _DrawPainter.paintAll(canvas, _canvasSize, _background, _elements, null);
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(
        (_canvasSize.width * scale).round(),
        (_canvasSize.height * scale).round(),
      );
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(appLoca.editorDibujo),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: appLoca.guardarDibujo,
            onPressed: _exporting
                ? null
                : () async {
                    setState(() => _exporting = true);
                    final Uint8List? png = await _exportPng();
                    if (!mounted) return;
                    setState(() => _exporting = false);
                    if (png != null) {
                      Navigator.pop(context, DrawResult(png, _elements));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(appLoca.errorExportarDibujo)),
                      );
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _loadingBackground
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _canvasSize = Size(
                            constraints.maxWidth, constraints.maxHeight);
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: td.colorScheme.outline),
                          ),
                          child: ClipRect(
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              onTapUp: _onTapUp,
                              child: CustomPaint(
                                size: _canvasSize,
                                painter: _DrawPainter(
                                  background: _background,
                                  elements: _elements,
                                  current: _currentStroke ?? _currentLine,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Icon(Icons.line_weight,
                          size: 18, color: td.colorScheme.onSurface),
                      Expanded(
                        child: Slider.adaptive(
                          value: _strokeWidth,
                          min: 1,
                          max: 20,
                          label: appLoca.grosorTrazo,
                          onChanged: (v) =>
                              setState(() => _strokeWidth = v),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.gesture),
                        tooltip: appLoca.herramientaLapiz,
                        isSelected: _tool == DrawTool.free,
                        onPressed: () =>
                            setState(() => _tool = DrawTool.free),
                      ),
                      IconButton(
                        icon: const Icon(Icons.timeline),
                        tooltip: appLoca.herramientaLinea,
                        isSelected: _tool == DrawTool.line,
                        onPressed: () =>
                            setState(() => _tool = DrawTool.line),
                      ),
                      IconButton(
                        icon: const Icon(Icons.title),
                        tooltip: appLoca.herramientaTexto,
                        isSelected: _tool == DrawTool.text,
                        onPressed: _selectTextTool,
                      ),
                      IconButton(
                        icon: Icon(Icons.circle, color: _color),
                        tooltip: appLoca.colorTrazo,
                        onPressed: _selectColor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.undo),
                        tooltip: appLoca.deshacer,
                        onPressed: _elements.isEmpty
                            ? null
                            : () => setState(() => _elements.removeLast()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep),
                        tooltip: appLoca.borrarTodo,
                        onPressed: _elements.isEmpty
                            ? null
                            : () => setState(() => _elements.clear()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
