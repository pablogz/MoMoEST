import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:momoest/answers.dart';
import 'package:momoest/draw_editor.dart';
import 'package:momoest/full_screen.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/note.dart';
import 'package:momoest/util/queries.dart';

/// Espacio ocupado por las notas de la cuenta y cuota disponible.
class NotesUsage {
  final int used, quota, maxDrawing;

  const NotesUsage(this.used, this.quota, this.maxDrawing);

  factory NotesUsage.fromMap(dynamic data) {
    if (data is Map) {
      return NotesUsage(
        data['used'] is int ? data['used'] : 0,
        data['quota'] is int ? data['quota'] : 0,
        data['maxDrawing'] is int ? data['maxDrawing'] : 0,
      );
    }
    return const NotesUsage(0, 0, 0);
  }

  int get free => quota > used ? quota - used : 0;
  double get ratio => quota > 0 ? (used / quota).clamp(0.0, 1.0) : 0;
  bool get isKnown => quota > 0;
}

/// Formatea un tamaño en bytes de forma legible y acorde al idioma en uso.
String formatSize(BuildContext context, int bytes) {
  final String locale = Localizations.localeOf(context).toString();
  if (bytes < 1024) {
    return '$bytes B';
  }
  final double kb = bytes / 1024;
  if (kb < 1024) {
    return '${NumberFormat('#,##0', locale).format(kb)} KB';
  }
  return '${NumberFormat('#,##0.0', locale).format(kb / 1024)} MB';
}

/// Respuesta del servidor al listar las notas.
class _NotesResponse {
  final List<Note> notes;
  final NotesUsage usage;

  const _NotesResponse(this.notes, this.usage);
}

/// Pantalla "Mis notas": lista las notas privadas del estudiante con un
/// filtro por lugar, y permite crear, editar y borrar notas.
///
/// Si se indica [idPlace] la pantalla se abre acotada a ese lugar: muestra solo
/// sus notas (sin selector de filtro) y las notas nuevas quedan vinculadas a él.
class InfoNotes extends StatefulWidget {
  final String? idPlace, labelPlace;

  const InfoNotes({this.idPlace, this.labelPlace, super.key});

  @override
  State<StatefulWidget> createState() => _InfoNotes();
}

class _InfoNotes extends State<InfoNotes> {
  // Las notas se guardan en el estado, no solo en el Future, para poder
  // reflejar de inmediato un borrado sin esperar a la recarga del servidor.
  List<Note>? _notes;
  NotesUsage _usage = const NotesUsage(0, 0, 0);
  // Filtro por lugar; null = todas
  String? _filterPlace;

  /// True cuando la pantalla está acotada a un lugar concreto.
  bool get _fixedPlace => widget.idPlace != null;

  @override
  void initState() {
    _filterPlace = widget.idPlace;
    _load();
    super.initState();
  }

  Future<_NotesResponse> _getNotes() async {
    try {
      final response = await http.get(Queries.notes(), headers: {
        'Authorization':
            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
      });
      if (response.statusCode != 200) {
        return const _NotesResponse([], NotesUsage(0, 0, 0));
      }
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      // El servidor devuelve {notes, usage}; se admite también la lista suelta
      // que devolvían versiones anteriores.
      final dynamic rawNotes = data is Map ? data['notes'] : data;
      final NotesUsage usage = data is Map
          ? NotesUsage.fromMap(data['usage'])
          : const NotesUsage(0, 0, 0);
      final List<Note> notes = [];
      if (rawNotes is List) {
        for (var ele in rawNotes) {
          try {
            notes.add(Note(ele));
          } catch (error) {
            if (ConfigXest.development) debugPrint(error.toString());
          }
        }
      }
      return _NotesResponse(notes, usage);
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      return const _NotesResponse([], NotesUsage(0, 0, 0));
    }
  }

  /// Recarga la lista desde el servidor. [silent] mantiene en pantalla las
  /// notas que ya se están mostrando mientras llega la respuesta.
  Future<void> _load({bool silent = false}) async {
    if (!silent && _notes != null) {
      setState(() => _notes = null);
    }
    final _NotesResponse data = await _getNotes();
    if (!mounted) return;
    setState(() {
      _notes = data.notes;
      _usage = data.usage;
    });
  }

  Future<void> _openForm({Note? note, NotesUsage? usage}) async {
    final bool? changed = await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => NoteForm(
          note: note,
          idPlace: widget.idPlace,
          labelPlace: widget.labelPlace,
          usage: usage,
        ),
        fullscreenDialog: true,
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteNote(Note note) async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final bool? confirmed = await Auxiliar.deleteDialog(
        context, appLoca.borrarNota, appLoca.confirmarBorrarNota);
    if (confirmed == true) {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.delete(
        Queries.note(note.id),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 204) {
        // La nota desaparece de inmediato, sin esperar al servidor, y después
        // se recarga en segundo plano para refrescar el espacio ocupado
        setState(() => _notes?.removeWhere((n) => n.id == note.id));
        await _load(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${response.statusCode}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final List<Note>? notes = _notes;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async => _openForm(usage: _usage),
        icon: const Icon(Icons.add),
        label: Text(appLoca.nuevaNota),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(_fixedPlace
                ? (widget.labelPlace ?? appLoca.notasLugar)
                : appLoca.misNotas),
            centerTitle: false,
          ),
          if (notes == null)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            )
          else
            _widgetNotes(notes),
        ],
      ),
    );
  }

  /// Barra con el espacio que ocupan las notas de la cuenta y el que queda
  /// libre, para que el estudiante pueda decidir qué borrar.
  Widget _widgetUsage(NotesUsage usage) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    final bool lleno = usage.ratio >= 0.9;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sd_storage_outlined,
                  size: 18,
                  color: lleno ? td.colorScheme.error : td.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  appLoca.espacioNotas(formatSize(context, usage.used),
                      formatSize(context, usage.quota)),
                  style: td.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usage.ratio,
                minHeight: 8,
                color: lleno ? td.colorScheme.error : td.colorScheme.primary,
              ),
            ),
          ),
          Text(
            appLoca.espacioNotasLibre(formatSize(context, usage.free)),
            style: td.textTheme.bodySmall,
          ),
          if (lleno)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                appLoca.espacioNotasCasiLleno,
                style: td.textTheme.bodySmall!
                    .copyWith(color: td.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _widgetNotes(List<Note> notes) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);

    // Lugares disponibles para el filtro
    final Map<String, String> places = {};
    for (Note note in notes) {
      if (note.hasPlace) {
        places[note.idPlace!] = note.labelPlace ?? note.idPlace!;
      }
    }
    if (!_fixedPlace &&
        _filterPlace != null &&
        !places.containsKey(_filterPlace)) {
      _filterPlace = null;
    }

    final List<Note> visibles = _filterPlace == null
        ? notes
        : notes.where((n) => n.idPlace == _filterPlace).toList();

    List<Widget> children = [];
    // El consumo es de toda la cuenta, así que se muestra siempre
    if (_usage.isKnown) {
      children.add(_widgetUsage(_usage));
    }
    if (places.isNotEmpty && !_fixedPlace) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String?>(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appLoca.filtrarPorLugar,
          ),
          initialValue: _filterPlace,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(appLoca.todasNotas),
            ),
            ...places.entries.map(
              (e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (String? v) => setState(() => _filterPlace = v),
        ),
      ));
    }

    if (visibles.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          _fixedPlace ? appLoca.sinNotasLugar : appLoca.sinNotas,
          style: td.textTheme.bodyLarge,
        ),
      ));
    }

    for (Note note in visibles) {
      final String date = DateFormat('H:mm d/M/y')
          .format(DateTime.fromMillisecondsSinceEpoch(note.lastUpdate));
      children.add(Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: td.colorScheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.size > 0 ? formatSize(context, note.size) : '',
                      style: td.textTheme.labelMedium,
                    ),
                  ),
                  Text(date, style: td.textTheme.labelMedium),
                ],
              ),
              if (note.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(note.title!, style: td.textTheme.titleMedium),
                ),
              if (note.hasPlace && !_fixedPlace)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          note.labelPlace ?? note.idPlace!,
                          style: td.textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (note.text != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    note.text!,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              NoteDrawing(note, maxHeight: 180),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 5,
                  children: [
                    TextButton(
                      onPressed: () async => _deleteNote(note),
                      style: TextButton.styleFrom(
                          foregroundColor: td.colorScheme.error),
                      child: Text(appLoca.borrar),
                    ),
                    FilledButton.tonal(
                      onPressed: () async =>
                          _openForm(note: note, usage: _usage),
                      child: Text(appLoca.editar),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    children.add(const SizedBox(height: 90));

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra el dibujo de una nota, venga de un fichero del servidor, de una
/// nota antigua con el PNG incrustado o de un dibujo recién hecho.
class NoteDrawing extends StatelessWidget {
  final Note note;
  final double maxHeight;

  const NoteDrawing(this.note, {this.maxHeight = 180, super.key});

  @override
  Widget build(BuildContext context) {
    if (note.hasDrawingFile) {
      return AuthImage(
        Queries.noteFile(note.drawingFile!),
        fileName: note.drawingFile!,
        label: note.title,
        maxHeight: maxHeight,
      );
    }
    final Uint8List? bytes = note.pendingDrawing ??
        (note.hasDrawingLegacy ? note.legacyBytes : null);
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (BuildContext context) => FullScreenImageBytes(
              bytes,
              fileName: 'note_${note.hasId ? note.id : 'nueva'}.png',
              label: note.title,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Formulario de creación/edición de una nota. Con [idPlace]/[labelPlace] la
/// nueva nota queda vinculada a ese lugar. Devuelve true por Navigator.pop si
/// ha habido cambios.
class NoteForm extends StatefulWidget {
  final Note? note;
  final String? idPlace, labelPlace;
  final NotesUsage? usage;

  const NoteForm(
      {this.note, this.idPlace, this.labelPlace, this.usage, super.key});

  @override
  State<StatefulWidget> createState() => _NoteForm();
}

class _NoteForm extends State<NoteForm> {
  late Note _note;
  late bool _sending;
  bool _loadingDrawing = false;

  @override
  void initState() {
    _note = widget.note ?? Note.empty();
    if (widget.note == null) {
      _note.idPlace = widget.idPlace;
      _note.labelPlace = widget.labelPlace;
    }
    _sending = false;
    super.initState();
  }

  /// Bytes del dibujo actual, descargándolo del servidor si hace falta, para
  /// poder seguir dibujando encima en el editor.
  Future<Uint8List?> _currentDrawingBytes() async {
    if (_note.pendingDrawing != null) {
      return _note.pendingDrawing;
    }
    if (_note.hasDrawingLegacy) {
      return _note.legacyBytes;
    }
    if (!_note.hasDrawingFile) {
      return null;
    }
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.get(
        Queries.noteFile(_note.drawingFile!),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
    }
    return null;
  }

  Future<void> _openEditor() async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    setState(() => _loadingDrawing = true);
    Uint8List? background;
    try {
      background = await _currentDrawingBytes();
      if (_note.hasDrawing && background == null) {
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(content: Text(appLoca.errorCargarDibujo)));
        return;
      }
    } finally {
      if (mounted) setState(() => _loadingDrawing = false);
    }
    if (!mounted) return;
    DrawResult? result = await Navigator.push(
      context,
      MaterialPageRoute<DrawResult>(
        builder: (BuildContext context) =>
            DrawEditor(backgroundBytes: background),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _note.setDrawing(result.pngBytes));
    }
  }

  /// Mensaje de error a partir de la respuesta del servidor, para que quede
  /// claro por qué no se ha podido guardar (sobre todo si es por espacio).
  String _errorMessage(AppLocalizations appLoca, http.Response response) {
    if (response.statusCode == 413) {
      try {
        final dynamic body = json.decode(response.body);
        if (body is Map && body['error'] == 'drawingTooBig') {
          return appLoca.dibujoDemasiadoGrande(
              formatSize(context, body['maxDrawing'] is int ? body['maxDrawing'] : 0));
        }
        if (body is Map && body['error'] == 'quotaExceeded') {
          final int used = body['used'] is int ? body['used'] : 0;
          final int quota = body['quota'] is int ? body['quota'] : 0;
          final int size = body['size'] is int ? body['size'] : 0;
          return appLoca.notasSinEspacio(
            formatSize(context, size),
            formatSize(context, quota > used ? quota - used : 0),
            formatSize(context, quota),
          );
        }
      } catch (error) {
        if (ConfigXest.development) debugPrint(error.toString());
      }
      return appLoca.notasSinEspacioSimple;
    }
    if (response.statusCode == 415) {
      return appLoca.errorCargarDibujo;
    }
    return appLoca.errorGuardarNota;
  }

  /// Envía la nota. Sin dibujo nuevo basta con JSON; con dibujo nuevo se sube
  /// como fichero en multipart, para no incrustarlo en el documento.
  Future<http.Response> _send(String token) async {
    final Uri uri = _note.hasId ? Queries.note(_note.id) : Queries.notes();
    if (_note.pendingDrawing == null) {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final String body = json.encode(_note.toFields());
      return _note.hasId
          ? http.put(uri, headers: headers, body: body)
          : http.post(uri, headers: headers, body: body);
    }
    final request = http.MultipartRequest(_note.hasId ? 'PUT' : 'POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(_note.toFields())
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        _note.pendingDrawing!,
        filename: 'note.png',
      ));
    return http.Response.fromStream(await request.send());
  }

  Future<void> _save() async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    if (_note.isEmpty) {
      smState.clearSnackBars();
      smState.showSnackBar(SnackBar(content: Text(appLoca.notaVacia)));
      return;
    }
    setState(() => _sending = true);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final http.Response response = await _send(token!);
      smState.clearSnackBars();
      if (response.statusCode == 201 || response.statusCode == 204) {
        smState.showSnackBar(SnackBar(content: Text(appLoca.notaGuardada)));
        if (mounted) Navigator.pop(context, true);
      } else {
        smState.showSnackBar(SnackBar(
          content: Text(_errorMessage(appLoca, response)),
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      smState.clearSnackBars();
      smState.showSnackBar(SnackBar(content: Text(appLoca.errorGuardarNota)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    double margen =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    final NotesUsage? usage = widget.usage;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
                widget.note == null ? appLoca.nuevaNota : appLoca.editarNota),
            centerTitle: false,
            pinned: true,
          ),
          SliverSafeArea(
            minimum: EdgeInsets.all(margen),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_note.hasPlace)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place, size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _note.labelPlace ?? _note.idPlace!,
                                  style: td.textTheme.labelLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        enabled: !_sending,
                        maxLines: 1,
                        maxLength: 80,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.tituloNota,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        initialValue: _note.title ?? '',
                        onChanged: (v) =>
                            _note.title = v.trim().isEmpty ? null : v.trim(),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        enabled: !_sending,
                        minLines: 4,
                        maxLines: 12,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.textoNota,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        initialValue: _note.text ?? '',
                        onChanged: (v) =>
                            _note.text = v.trim().isEmpty ? null : v.trim(),
                      ),
                      const SizedBox(height: 15),
                      if (_note.hasDrawing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NoteDrawing(_note, maxHeight: 220),
                        ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _sending || _loadingDrawing ? null : _openEditor,
                            icon: _loadingDrawing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(_note.hasDrawing
                                    ? Icons.edit
                                    : Icons.draw),
                            label: Text(_note.hasDrawing
                                ? appLoca.editarDibujo
                                : appLoca.agregarDibujo),
                          ),
                          if (_note.hasDrawing)
                            OutlinedButton.icon(
                              onPressed: _sending
                                  ? null
                                  : () =>
                                      setState(() => _note.setDrawing(null)),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(appLoca.quitarDibujo),
                            ),
                        ],
                      ),
                      if (usage != null && usage.isKnown)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            appLoca.espacioNotasLibre(
                                formatSize(context, usage.free)),
                            style: td.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 25),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _save,
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: Text(appLoca.guardar),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
