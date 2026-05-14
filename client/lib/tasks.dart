import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_network/image_network.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';

import 'package:momoest/full_screen.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/main.dart';
import 'package:momoest/util/helpers/widget_facto.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/user_xest.dart';

class COTask extends StatefulWidget {
  final String shortIdContainer, shortIdTask;
  final Answer? answer;
  final bool preview;
  final bool userIsNear;

  const COTask(
      {required this.shortIdContainer,
      required this.shortIdTask,
      this.answer,
      this.preview = false,
      this.userIsNear = false,
      super.key});

  @override
  State<StatefulWidget> createState() => _COTask();
}

// class COTask extends StatefulWidget {
//   final Feature poi;
//   final Task task;
//   final Answer? answer;
//   final bool vistaPrevia;
//   const COTask(this.poi, this.task,
//       {required this.answer, this.vistaPrevia = false, super.key});
//   @override
//   State<StatefulWidget> createState() => _COTask();
// }

class _COTask extends State<COTask> {
  Task? task;

  late bool _selectTF, _guardado;
  late List<bool> _selectMCQ;
  late String _selectMCQR;
  late GlobalKey<FormState> _thisKey, _thisKeyMCQ;
  late Answer answer;
  late bool textoObligatorio;
  late String texto;
  late int _startTime;
  List<String> valoresMCQ = [];
  bool showMessageGoBack = false;
  PlatformFile? _selectedPdf;
  bool _uploading = false;

  @override
  void initState() {
    task = Task.empty(
        containerType: ContainerTask.spatialThing,
        idContainer: widget.shortIdContainer);
    super.initState();
  }

  Future<Map> _getLearningTask() async {
    Map data = await http
        .get(Queries.getTask(widget.shortIdContainer, widget.shortIdTask))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : {})
        .onError((error, stackTrace) => {});
    return data;
  }

  Future<List> _getFeature() async {
    List data = await http
        .get(Queries.getFeatureInfo(widget.shortIdContainer))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : [])
        .onError((error, stackTrace) => []);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.preview ? appLoca!.vistaPrevia : appLoca!.realizaTarea),
        centerTitle: false,
      ),
      body: task!.isEmpty
          ? FutureBuilder(
              future: _getLearningTask(),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  if (snapshot.data != null &&
                      (snapshot.data as Map).isNotEmpty) {
                    Map<String, dynamic> tdata =
                        snapshot.data as Map<String, dynamic>;
                    tdata['task'] = Auxiliar.shortId2Id(widget.shortIdTask);
                    task = Task(
                      snapshot.data!,
                      containerType: ContainerTask.spatialThing,
                      idContainer: Auxiliar.shortId2Id(
                        widget.shortIdContainer,
                      )!,
                    );
                    if (UserXEST.userXEST.crol != Rol.teacher) {
                      if (!task!.spaces.contains(Space.physical) ||
                          (task!.spaces.contains(Space.physical) &&
                              task!.spaces.length > 1)) {
                        showMessageGoBack = false;
                      } else {
                        showMessageGoBack = !widget.userIsNear;
                      }
                    }

                    _initValues();
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: _showTask()));
                  } else {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: [
                          SliverToBoxAdapter(
                            child: Text(appLoca.tareaNoEncontrada),
                          )
                        ]));
                  }
                } else {
                  if (snapshot.hasError) {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: [
                          SliverToBoxAdapter(
                            child: Text(appLoca.tareaNoEncontrada),
                          )
                        ]));
                  } else {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: const CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            )
                          ],
                        ));
                  }
                }
              })
          : SafeArea(
              top: false,
              bottom: false,
              minimum: EdgeInsets.symmetric(
                  horizontal: Auxiliar.getLateralMargin(size.width)),
              child: CustomScrollView(slivers: _showTask())),
    );
  }

  void _initValues() {
    _thisKey = GlobalKey<FormState>();
    _thisKeyMCQ = GlobalKey<FormState>();
    _guardado = false;
    _startTime = DateTime.now().millisecondsSinceEpoch;

    Set<AnswerType> atRT = {
      AnswerType.multiplePhotosText,
      AnswerType.photoText,
      AnswerType.text,
      AnswerType.videoText
    };
    textoObligatorio = atRT.contains(task!.aT);

    if (widget.answer == null) {
      answer = Answer.withoutAnswer({
        'idContainer': widget.shortIdContainer,
        'idTask': widget.shortIdTask,
        'answerType': task!.aT,
      });
      // TODO faltaría agregar el objGeo. ¿Lo traigo desde la pantalla anterior? ¿Hago la consulta al servidor?
      // answer.poi = widget.poi;
      answer.task = task!;
      switch (task!.aT) {
        case AnswerType.mcq:
          int tama = task!.distractors.length + task!.correctMCQ.length;
          _selectMCQ = task!.singleSelection
              ? List<bool>.generate(tama, (index) => index == 0)
              : List<bool>.filled(tama, false);
          for (PairLang ele in task!.distractors) {
            valoresMCQ.add(ele.value);
          }
          for (PairLang ele in task!.correctMCQ) {
            valoresMCQ.add(ele.value);
          }
          valoresMCQ.shuffle();
          _selectMCQR = valoresMCQ.first;
          break;
        case AnswerType.tf:
          _selectTF = Random.secure().nextBool();

          break;
        default:
      }
      texto = '';
    } else {
      answer = widget.answer!;
      answer.task = task!;
      switch (answer.answerType) {
        case AnswerType.mcq:
        case AnswerType.multiplePhotos:
        case AnswerType.noAnswer:
        case AnswerType.photo:
        case AnswerType.tf:
        case AnswerType.video:
          if (answer.hasAnswer && answer.hasExtraText) {
            texto = answer.answer['extraText'];
          } else {
            texto = '';
          }
          break;
        case AnswerType.multiplePhotosText:
        case AnswerType.photoText:
        case AnswerType.text:
        case AnswerType.videoText:
          if (answer.hasAnswer) {
            texto = answer.answer['answer'];
          } else {
            texto = '';
          }
          break;
        default:
          texto = '';
      }
    }
  }

  List<Widget> _showTask() {
    List<Widget> out = [_widgetInfoTask(), _widgetSolveTask()];
    if (showMessageGoBack) {
      out.add(_goBack());
    }
    out.add(_widgetButtons());
    return out;
    // return SliverList(
    //     delegate: SliverChildBuilderDelegate(
    //   (context, index) => lstWidgetTask.elementAt(index),
    //   childCount: lstWidgetTask.length,
    // ));
  }

  Widget _widgetInfoTask() {
    ThemeData td = Theme.of(context);
    List<Widget> lst = [
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HtmlWidget(
                task!.getAComment(lang: MyApp.currentLang),
                factoryBuilder: () => MyWidgetFactory(),
                textStyle: td.textTheme.titleMedium,
              ),
              // Padding(
              //   padding: const EdgeInsets.only(top: 5),
              //   child: Align(
              //     alignment: Alignment.centerRight,
              //     child: TextButton.icon(
              //       icon: Icon(
              //         _isPlaying ? Icons.stop : Icons.hearing,
              //         color: colorScheme.primary,
              //       ),
              //       label: Text(
              //         AppLocalizations.of(context)!.escuchar,
              //         style: td.textTheme.bodyMedium!.copyWith(
              //           color: colorScheme.primary,
              //         ),
              //       ),
              //       onPressed: () async {
              //         if (_isPlaying) {
              //           setState(() => _isPlaying = false);
              //           _stop();
              //         } else {
              //           setState(() => _isPlaying = true);
              //           List<String> lstTexto = Auxiliar.frasesParaTTS(
              //               task!.getAComment(lang: MyApp.currentLang));
              //           for (String leerParte in lstTexto) {
              //             await _speak(leerParte);
              //           }
              //           setState(() => _isPlaying = false);
              //         }
              //       },
              //     ),
              //   ),
              // )
            ],
          ),
        ),
      ),
    ];
    if (task!.image is PairImage) {
      Size size = MediaQuery.of(context).size;
      double mW = Auxiliar.maxWidth * 0.5;
      double mH =
          size.width > size.height ? size.height * 0.5 : size.height / 3;
      lst.add(
        ImageNetwork(
          image: task!.image!.image,
          height: mH,
          width: mW,
          duration: 0,
          onPointer: true,
          fitWeb: BoxFitWeb.cover,
          fitAndroidIos: BoxFit.cover,
          borderRadius: BorderRadius.circular(25),
          curve: Curves.easeIn,
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      FullScreenImage(task!.image!, local: false),
                  fullscreenDialog: false),
            );
          },
          onError: const Icon(Icons.image_not_supported),
          onLoading: const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 35, bottom: 15),
      sliver: SliverList.builder(
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: lst.elementAt(index),
          );
        },
        itemCount: lst.length,
      ),
    );
  }

  Widget _widgetSolveTask() {
    List<Widget> lista = [];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    Widget cuadrotexto = Form(
      key: _thisKey,
      child: TextFormField(
        maxLines: textoObligatorio ? 5 : 2,
        initialValue: texto,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: textoObligatorio
                ? appLoca!.respondePreguntaTextualLabel
                : appLoca!.notasOpcionalesLabel,
            hintText: textoObligatorio
                ? appLoca.respondePreguntaTextual
                : appLoca.notasOpcionales,
            hintMaxLines: 2,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.text,
        validator: (value) {
          if (value != null) {
            if (textoObligatorio) {
              if (value.trim().isNotEmpty) {
                texto = value.trim();
                return null;
              } else {
                return appLoca.respondePreguntaTextual;
              }
            } else {
              texto = value.trim();
              return null;
            }
          } else {
            return appLoca.respondePreguntaTextual;
          }
        },
      ),
    );

    switch (task!.aT) {
      case AnswerType.mcq:
        List<Widget> widgetsMCQ = [];
        if (task!.singleSelection) {
          for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
            String valor = valoresMCQ[i];
            bool falsa = task!.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RadioListTile<String>.adaptive(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    value: valor,
                    groupValue: _selectMCQR,
                    onChanged: !_guardado
                        ? (String? v) {
                            setState(() {
                              _selectMCQR = v!;
                            });
                          }
                        : null,
                  ),
                ),
              ),
            );
          }
        } else {
          for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
            String valor = valoresMCQ[i];
            bool falsa = task!.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: CheckboxListTile.adaptive(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    value: _selectMCQ[i],
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    onChanged: (value) => setState(() {
                      _selectMCQ[i] = !_selectMCQ[i];
                    }),
                    enabled: !_guardado,
                  ),
                ),
              ),
            );
          }
        }
        lista.add(
          Form(
            key: _thisKeyMCQ,
            child: Column(mainAxisSize: MainAxisSize.min, children: widgetsMCQ),
          ),
        );
        break;
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
        // TODO Visor de fotos
        break;
      case AnswerType.tf:
        bool? rC = task!.hasCorrectTF ? task!.correctTF : null;
        Widget extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RadioListTile<bool>.adaptive(
                    tileColor: _guardado
                        ? task!.hasCorrectTF
                            ? !rC!
                                ? td.colorScheme.error
                                : td.colorScheme.primary
                            : null
                        : null,
                    title: Text(
                      appLoca.rbVFVNTVLabel,
                      style: _guardado
                          ? task!.hasCorrectTF
                              ? td.textTheme.bodyLarge!.copyWith(
                                  color: !rC!
                                      ? td.colorScheme.onError
                                      : td.colorScheme.onPrimary,
                                )
                              : td.textTheme.bodyLarge
                          : td.textTheme.bodyLarge,
                    ),
                    value: true,
                    groupValue: _selectTF,
                    onChanged: (bool? v) {
                      setState(() => _selectTF = v!);
                    }),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: RadioListTile<bool>.adaptive(
                  tileColor: _guardado
                      ? task!.hasCorrectTF
                          ? rC!
                              ? td.colorScheme.error
                              : td.colorScheme.primary
                          : null
                      : null,
                  title: Text(
                    appLoca.rbVFFNTLabel,
                    style: _guardado
                        ? task!.hasCorrectTF
                            ? td.textTheme.bodyLarge!.copyWith(
                                color: rC!
                                    ? td.colorScheme.onError
                                    : td.colorScheme.onPrimary,
                              )
                            : td.textTheme.bodyLarge
                        : td.textTheme.bodyLarge,
                  ),
                  value: false,
                  groupValue: _selectTF,
                  onChanged: (bool? v) {
                    setState(() => _selectTF = v!);
                  }),
            ),
            const SizedBox(
              height: 10,
            )
          ],
        );
        lista.add(extra);
        break;
      case AnswerType.video:
      case AnswerType.videoText:
        // TODO Visor de vídeo
        break;
      case AnswerType.uploadFile:
        lista.add(_widgetPickPdf());
        break;
      default:
    }

    if (task!.aT != AnswerType.uploadFile) lista.add(cuadrotexto);

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: lista.elementAt(index),
            ),
          ),
          childCount: lista.length,
        ),
      ),
    );
  }

  Future<void> _saveUploadFile(
      ScaffoldMessengerState smState, AppLocalizations? appLoca) async {
    if (_selectedPdf == null) {
      smState.showSnackBar(
          SnackBar(content: Text(appLoca!.sinFicheroSeleccionado)));
      return;
    }
    if (mounted) setState(() => _uploading = true);
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      answer.time2Complete = now - _startTime;
      answer.timestamp = now;
      answer.commentTask = task!.getAComment(lang: MyApp.currentLang);

      final Feature feature =
          Feature.providers(widget.shortIdContainer, await _getFeature());
      final String featureLabel = feature.getALabel(lang: MyApp.currentLang);
      answer.labelContainer = featureLabel.isNotEmpty
          ? featureLabel
          : task!.getALabel(lang: MyApp.currentLang);

      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final request = http.MultipartRequest('POST', Queries.uploadAnswerFile());
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['idContainer'] = answer.idContainer;
      request.fields['idTask'] = answer.idTask;
      request.fields['answerMetadata'] = json.encode({
        'hasOptionalText': false,
        'finishClient': now,
        'time2Complete': answer.time2Complete,
      });
      request.fields['labelContainer'] = answer.labelContainer;
      request.fields['commentTask'] = answer.commentTask;

      if (_selectedPdf!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _selectedPdf!.bytes!,
          filename: _selectedPdf!.name,
        ));
      } else if (_selectedPdf!.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _selectedPdf!.path!,
          filename: _selectedPdf!.name,
        ));
      } else {
        smState
            .showSnackBar(SnackBar(content: Text(appLoca!.errorSubirFichero)));
        return;
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 201) {
        final shortId = response.headers['location']!.split('/').last;
        answer.id = shortId;
        answer.answer = {
          'file': '$shortId.pdf',
          'originalName': _selectedPdf!.name,
          'timestamp': now,
        };
        UserXEST.userXEST.answers.add(answer);

        if (UserXEST.userXEST.hasFeedEnable) {
          final idAnswerFeed = shortId;
          await http.put(
            Queries.feedAnswer(
              Auxiliar.id2shortId(UserXEST.userXEST.feed)!,
              UserXEST.userXEST.id,
              idAnswerFeed,
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({}),
          );
        }

        smState.clearSnackBars();
        smState
            .showSnackBar(SnackBar(content: Text(appLoca!.respuestaGuardada)));
        if (!ConfigXest.development) {
          await FirebaseAnalytics.instance.logEvent(
            name: "taskCompleted",
            parameters: {
              "feature": widget.shortIdContainer,
              "task": widget.shortIdTask,
            },
          );
        }
        if (mounted) setState(() => _guardado = true);
        if (mounted) GoRouter.of(context).pop();
      } else if (response.statusCode == 413) {
        smState.showSnackBar(SnackBar(
            content: Text(
                appLoca!.ficheroDemasiadoGrande(ConfigXest.maxFileSizeMB))));
      } else {
        smState
            .showSnackBar(SnackBar(content: Text(appLoca!.errorSubirFichero)));
      }
    } catch (error) {
      smState.clearSnackBars();
      smState.showSnackBar(SnackBar(content: Text(appLoca!.errorSubirFichero)));
      if (!ConfigXest.development) {
        // ignore: use_rethrow_when_possible
        await FirebaseCrashlytics.instance.recordError(error, null);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _widgetPickPdf() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _guardado || _uploading
              ? null
              : () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                    allowMultiple: false,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final f = result.files.first;
                    if (f.size > ConfigXest.maxFileSizeMB * 1024 * 1024) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(appLoca.ficheroDemasiadoGrande(
                              ConfigXest.maxFileSizeMB)),
                        ));
                      }
                      return;
                    }
                    setState(() => _selectedPdf = f);
                  }
                },
          icon: const Icon(Icons.upload_file),
          label: Text(appLoca.seleccionarPDF),
        ),
        if (_selectedPdf != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _selectedPdf!.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _goBack() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    return SliverToBoxAdapter(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(Auxiliar.mediumMargin),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          padding: const EdgeInsets.all(Auxiliar.mediumMargin),
          color: colorScheme.tertiaryContainer,
          child: Center(
            child: TextButton(
              child: Text(
                AppLocalizations.of(context)!.goBackForLocation,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
              onPressed: () => setState(
                () => context.go('/home/features/${widget.shortIdContainer}'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _widgetButtons() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> botones = [];
    switch (task!.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones.add(Padding(
          padding: const EdgeInsets.only(right: 10),
          child: OutlinedButton.icon(
            onPressed: null,
            //  () async {
            //   // List<CameraDescription> cameras = await availableCameras();
            //   // await Navigator.push(
            //   //     context,
            //   //     MaterialPageRoute<Task>(
            //   //         builder: (BuildContext context) {
            //   //           return TakePhoto(cameras.first);
            //   //         },
            //   //         fullscreenDialog: true));
            //   await availableCameras()
            //       .then((cameras) async => await Navigator.push(
            //           context,
            //           MaterialPageRoute<Task>(
            //               builder: (BuildContext context) {
            //                 return TakePhoto(cameras.first);
            //               },
            //               fullscreenDialog: true)));
            // },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLoca!.abrirCamara),
          ),
        ));
        break;
      default:
    }
    botones.add(FilledButton.icon(
      onPressed: widget.preview
          ? null
          : showMessageGoBack
              ? null
              : _uploading
                  ? null
                  : _guardado
                      ? () {
                          switch (answer.answerType) {
                            case AnswerType.mcq:
                            case AnswerType.tf:
                              Navigator.pop(context);
                              break;
                            default:
                          }
                        }
                      : () async {
                          if (answer.answerType == AnswerType.uploadFile) {
                            await _saveUploadFile(smState, appLoca);
                            return;
                          }
                          if (_thisKey.currentState!.validate()) {
                            try {
                              int now = DateTime.now().millisecondsSinceEpoch;
                              answer.time2Complete = now - _startTime;
                              answer.timestamp = now;
                              switch (answer.answerType) {
                                case AnswerType.mcq:
                                  String answ = "";
                                  if (task!.singleSelection) {
                                    answ = _selectMCQR;
                                  } else {
                                    List<String> a = [];
                                    for (int i = 0, tama = _selectMCQ.length;
                                        i < tama;
                                        i++) {
                                      if (_selectMCQ[i]) {
                                        a.add(valoresMCQ[i]);
                                      }
                                    }
                                    answ = a.toString();
                                  }
                                  if (texto.trim().isNotEmpty) {
                                    answer.answer = {
                                      'answer': answ,
                                      'timestamp':
                                          DateTime.now().millisecondsSinceEpoch,
                                      'extraText': texto.trim()
                                    };
                                  } else {
                                    answer.answer = answ;
                                  }
                                  UserXEST.userXEST.answers.add(answer);
                                  setState(() => _guardado = true);
                                  break;
                                case AnswerType.multiplePhotos:
                                  break;
                                case AnswerType.multiplePhotosText:
                                  break;
                                case AnswerType.noAnswer:
                                  break;
                                case AnswerType.photo:
                                  break;
                                case AnswerType.photoText:
                                  break;
                                case AnswerType.text:
                                  answer.answer = {
                                    'answer': texto.trim(),
                                    'timestamp':
                                        DateTime.now().millisecondsSinceEpoch,
                                  };
                                  break;
                                case AnswerType.tf:
                                  if (texto.trim().isNotEmpty) {
                                    answer.answer = {
                                      'answer': _selectTF,
                                      'timestamp':
                                          DateTime.now().millisecondsSinceEpoch,
                                      'extraText': texto.trim()
                                    };
                                  } else {
                                    answer.answer = _selectTF;
                                  }
                                  UserXEST.userXEST.answers.add(answer);
                                  setState(() => _guardado = true);
                                  break;
                                case AnswerType.video:
                                  break;
                                case AnswerType.videoText:
                                  break;
                                default:
                              }
                              answer.commentTask =
                                  task!.getAComment(lang: MyApp.currentLang);

                              Feature feature = Feature.providers(
                                  widget.shortIdContainer, await _getFeature());

                              answer.labelContainer =
                                  feature.getALabel(lang: MyApp.currentLang);
                              http
                                  .post(Queries.newAnswer(),
                                      headers: {
                                        'Content-Type': 'application/json',
                                        'Authorization':
                                            'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                      },
                                      body: json.encode(answer.toMap()))
                                  .then((response) async {
                                switch (response.statusCode) {
                                  case 201:
                                    String idAnswer =
                                        response.headers['location']!;
                                    answer.id = idAnswer;
                                    if (UserXEST.userXEST.hasFeedEnable) {
                                      String idAnswerFeed =
                                          idAnswer.split('/').last;
                                      http
                                          .put(
                                              Queries.feedAnswer(
                                                  Auxiliar.id2shortId(
                                                      UserXEST.userXEST.feed)!,
                                                  UserXEST.userXEST.id,
                                                  idAnswerFeed),
                                              headers: {
                                                'Content-Type':
                                                    'application/json',
                                                'Authorization':
                                                    'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                              },
                                              body: json.encode({}))
                                          .then(
                                        (value) async {
                                          smState.clearSnackBars();
                                          smState.showSnackBar(SnackBar(
                                            content: Text(
                                                appLoca!.respuestaGuardada),
                                          ));
                                          setState(() {
                                            _guardado = true;
                                          });
                                          if (!ConfigXest.development) {
                                            await FirebaseAnalytics.instance
                                                .logEvent(
                                              name: "taskCompleted",
                                              parameters: {
                                                "feature":
                                                    widget.shortIdContainer,
                                                "task": widget.shortIdTask
                                              },
                                            ).then((__) {
                                              FirebaseAnalytics.instance
                                                  .logEvent(
                                                name: "answerAddedFeed",
                                                parameters: {
                                                  "idFeed": Auxiliar.id2shortId(
                                                      UserXEST.userXEST.feed)!,
                                                  "idStudent":
                                                      UserXEST.userXEST.id,
                                                  "idAnswer": idAnswerFeed
                                                },
                                              ).then((_) {
                                                if (task!.aT !=
                                                        AnswerType.mcq &&
                                                    mounted) {
                                                  GoRouter.of(context).pop();
                                                }
                                              });
                                            });
                                          } else {
                                            if (task!.aT != AnswerType.mcq) {
                                              GoRouter.of(context).pop();
                                            }
                                          }
                                        },
                                      );
                                    } else {
                                      smState.clearSnackBars();
                                      smState.showSnackBar(SnackBar(
                                        content:
                                            Text(appLoca!.respuestaGuardada),
                                      ));
                                      setState(() {
                                        _guardado = true;
                                      });
                                      if (!ConfigXest.development) {
                                        await FirebaseAnalytics.instance
                                            .logEvent(
                                          name: "taskCompleted",
                                          parameters: {
                                            "feature": widget.shortIdContainer,
                                            "task": widget.shortIdTask
                                          },
                                        ).then((_) {
                                          if (task!.aT != AnswerType.mcq &&
                                              mounted) {
                                            GoRouter.of(context).pop();
                                          }
                                        });
                                      } else {
                                        if (task!.aT != AnswerType.mcq) {
                                          GoRouter.of(context).pop();
                                        }
                                      }
                                    }
                                    break;
                                  default:
                                }
                              }).onError((error, stackTrace) async {
                                if (ConfigXest.development) {
                                  debugPrint(error.toString());
                                } else {
                                  await FirebaseCrashlytics.instance
                                      .recordError(error, stackTrace);
                                }
                              });
                            } catch (error) {
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                content: Text(error.toString()),
                              ));
                            }
                          }
                        },
      label: _uploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : _guardado
              ? Text(appLoca!.finRevision)
              : Text(appLoca!.guardar),
      icon: _uploading
          ? const SizedBox.shrink()
          : _guardado
              ? const Icon(Icons.navigate_next)
              : const Icon(Icons.save),
    ));
    // TODO REMOVE
    switch (task!.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.multiplePhotosText:
      case AnswerType.photo:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones = [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.camera_alt),
              label: Text(appLoca!.abrirCamara),
            ),
          ),
          FilledButton.icon(
            onPressed: null,
            label: Text(appLoca.guardar),
            icon: const Icon(Icons.save),
          ),
        ];
        break;
      default:
    }
    List<Widget> lista = [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: botones,
      )
    ];
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: lista.elementAt(index),
            ),
          ),
          childCount: lista.length,
        ),
      ),
    );
  }
}

class TakePhoto extends StatefulWidget {
  final CameraDescription cameraDescription;
  const TakePhoto(this.cameraDescription, {super.key});
  @override
  State<StatefulWidget> createState() => _TakePhoto();
}

class _TakePhoto extends State<TakePhoto> {
  late CameraController _cameraController;
  late Future<void> _cameraFuture;
  @override
  void initState() {
    _cameraController =
        CameraController(widget.cameraDescription, ResolutionPreset.medium);
    _cameraFuture = _cameraController.initialize();
    super.initState();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder<void>(
      future: _cameraFuture,
      builder: ((context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_cameraController);
        } else {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
      }),
    ));
  }
}

class FormTask extends StatefulWidget {
  final Task task;
  const FormTask(this.task, {super.key});
  @override
  State<StatefulWidget> createState() => _FormTask();
}

class _FormTask extends State<FormTask> {
  late GlobalKey<FormState> _thisKey;
  late String? drop, _imageLic, _image;
  List<PairLang> distractors = [];
  AnswerType? answerType;
  late bool _rgtf, _spaFis, _spaVir, errorEspacios, _mcqmu, _pasoUno, _btEnable;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription;
  List<Widget> widgetDistractors = [], widgetCorrects = [];
  late String textoTask;

  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    drop = null;
    _image = null;
    _imageLic = null;
    _rgtf = widget.task.hasCorrectTF
        ? widget.task.correctTF
        : Random.secure().nextBool();
    _mcqmu = Random.secure().nextBool();
    if (widget.task.distractors.isNotEmpty) {
      distractors.addAll(widget.task.distractors);
    }
    for (var element in distractors) {
      widget.task.removeDistractor(element);
    }
    _spaFis = widget.task.spaces.isEmpty
        ? false
        : widget.task.spaces.contains(Space.physical);
    _spaVir = widget.task.spaces.isEmpty
        ? false
        : widget.task.spaces.contains(Space.virtual);
    errorEspacios = false;
    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    textoTask = widget.task.getAComment(lang: MyApp.currentLang);
    try {
      _quillController.document =
          Document.fromDelta(HtmlToDelta().convert(textoTask));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        textoTask =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    _pasoUno = true;
    _btEnable = true;
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    const EdgeInsets margenes = EdgeInsets.only(top: 15, right: 10, left: 10);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.nTask),
        centerTitle: false,
      ),
      body: Form(
        key: _thisKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 50, right: 10, left: 10),
                child: widgetComun(size),
              ),
              Padding(
                padding: margenes,
                child:
                    Visibility(visible: !_pasoUno, child: widgetVariable(size)),
              ),
              Padding(
                padding: margenes,
                child: Visibility(visible: !_pasoUno, child: widgetSpaces()),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: buttonAddTask(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget widgetComun(Size size) {
    ThemeData td = Theme.of(context);
    ColorScheme cS = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    List<String?> selects =
        widget.task.containerType! == ContainerTask.spatialThing
            ? [
                null,
                AnswerType.mcq.name,
                AnswerType.tf.name,
                AnswerType.text.name,
                AnswerType.uploadFile.name,
                AnswerType.draw.name,
              ]
            : [
                null,
                AnswerType.text.name,
              ];
    Map<AnswerType, String> atString =
        widget.task.containerType! == ContainerTask.spatialThing
            ? {
                AnswerType.mcq: appLoca.selectTipoRespuestaMcq,
                AnswerType.tf: appLoca.selectTipoRespuestaVF,
                AnswerType.text: appLoca.selectTipoRespuestaTexto,
                AnswerType.uploadFile: appLoca.selectTipoRespuestaUploadFile,
                AnswerType.draw: appLoca.selectTipoRespuestaDraw,
              }
            : {
                AnswerType.text: appLoca.selectTipoRespuestaTexto,
              };
    List<Widget> listaForm = [
      Visibility(
        visible: _pasoUno,
        child: TextFormField(
          maxLines: 1,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appLoca.tituloNTLabel,
            hintText: appLoca.tituloNT,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
          ),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.text,
          initialValue: widget.task.hasLabel
              ? widget.task.labels.isEmpty
                  ? ''
                  : widget.task.getALabel(lang: MyApp.currentLang)
              : '',
          onChanged: (value) {
            widget.task
                .setLabels({'lang': MyApp.currentLang, 'value': value.trim()});
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return appLoca.tituloNT;
            } else {
              return null;
            }
          },
        ),
      ),
      Visibility(
        visible: _pasoUno,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.fromBorderSide(
              BorderSide(
                  color: _errorDescription
                      ? cS.error
                      : _hasFocus
                          ? cS.primary
                          : cS.onSurface,
                  width: _hasFocus ? 2 : 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  appLoca.textAsociadoNTLabel,
                  style: textTheme.bodySmall!.copyWith(
                      color: _errorDescription
                          ? cS.error
                          : _hasFocus
                              ? cS.primary
                              : cS.onSurface),
                ),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(
                      maxWidth: Auxiliar.maxWidth, minWidth: Auxiliar.maxWidth),
                  decoration: BoxDecoration(
                    color: cS.primaryContainer,
                  ),
                  child: Auxiliar.quillToolbar(_quillController, cS),
                ),
              ),
              Container(
                constraints: const BoxConstraints(
                  maxWidth: Auxiliar.maxWidth,
                  maxHeight: 300,
                  minHeight: 150,
                ),
                child: QuillEditor.basic(
                  controller: _quillController,
                  // configurations: const QuillEditorConfigurations(
                  //   padding: EdgeInsets.all(5),
                  // ),
                  config: QuillEditorConfig(
                    padding: EdgeInsets.all(5),
                  ),
                  focusNode: _focusNode,
                ),
              ),
              Visibility(
                visible: _errorDescription,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    appLoca.textoAsociadoNT,
                    style: textTheme.bodySmall!.copyWith(
                      color: cS.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Visibility(
        visible: !_pasoUno,
        child: DropdownButtonFormField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appLoca.selectTipoRespuestaLabel,
            hintText: appLoca.selectTipoRespuestaEnunciado,
          ),
          value: drop,
          onChanged: (String? nv) {
            setState(() {
              drop = nv;
              setState(() {
                if (drop != null) {
                  for (var value in AnswerType.values) {
                    if (drop == value.name) {
                      answerType = value;
                      break;
                    }
                  }
                } else {
                  answerType = null;
                }
              });
            });
          },
          items: selects.map<DropdownMenuItem<String>>((String? value) {
            late AnswerType aTTextUser;
            if (value != null) {
              for (var v in AnswerType.values) {
                if (value == v.name) {
                  aTTextUser = v;
                  break;
                }
              }
            }
            return DropdownMenuItem(
              value: value,
              child:
                  value == null ? const Text('') : Text(atString[aTTextUser]!),
            );
          }).toList(),
          validator: (v) {
            if (v == null) {
              return appLoca.selectTipoRespuestaEnunciado;
            } else {
              for (var at in AnswerType.values) {
                if (at.name == v) {
                  widget.task.aT = at;
                  break;
                }
              }
              return null;
            }
          },
        ),
      ),
      Visibility(
        visible: !_pasoUno,
        child: TextFormField(
            enabled: _btEnable,
            maxLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLoca.imagenLabel,
              hintText: appLoca.imagenLabel,
              hintMaxLines: 1,
              hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
            ),
            initialValue:
                widget.task.image is PairImage ? widget.task.image!.image : '',
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (Auxiliar.isUriResource(value.trim())) {
                  _image = Uri.parse(value.trim()).toString();
                  return null;
                } else {
                  return appLoca.imagenExplica;
                }
              } else {
                return null;
              }
            }),
      ),
      Visibility(
        visible: !_pasoUno,
        child: TextFormField(
            enabled: _btEnable,
            maxLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLoca.licenciaLabel,
              hintText: appLoca.licenciaLabel,
              hintMaxLines: 1,
              hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
            ),
            initialValue:
                widget.task.image is PairImage ? widget.task.image!.image : '',
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                _imageLic = value.trim();
              }
              return null;
            }),
      ),
    ];
    return ListView.builder(
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: listaForm.elementAt(index),
          ),
        ),
      ),
      itemCount: listaForm.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  // Widget _showURLDialog(String selectText, int indexS, int lengthS) {
  //   AppLocalizations appLoca = AppLocalizations.of(context)!;
  //   ThemeData td = Theme.of(context);
  //   TextTheme textTheme = td.textTheme;
  //   String uri = '';
  //   GlobalKey<FormState> formEnlace = GlobalKey<FormState>();
  //   return Padding(
  //     padding: EdgeInsets.only(
  //       bottom: MediaQuery.of(context).viewInsets.bottom + 20,
  //       left: 10,
  //       right: 10,
  //     ),
  //     child: Form(
  //       key: formEnlace,
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(
  //             appLoca.agregaEnlace,
  //             style: textTheme.titleMedium,
  //           ),
  //           const SizedBox(height: 20),
  //           TextFormField(
  //             maxLines: 1,
  //             decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: "${appLoca.enlace}*",
  //               // hintText: appLoca.hintEnlace,
  //               hintText: 'https://example.com',
  //               helperText: appLoca.requerido,
  //               hintMaxLines: 1,
  //             ),
  //             textInputAction: TextInputAction.next,
  //             keyboardType: TextInputType.url,
  //             validator: (value) {
  //               if (value != null && value.isNotEmpty) {
  //                 uri = value.trim();
  //                 return null;
  //               }
  //               return appLoca.errorEnlace;
  //             },
  //           ),
  //           const SizedBox(height: 10),
  //           Wrap(
  //             alignment: WrapAlignment.end,
  //             spacing: 10,
  //             direction: Axis.horizontal,
  //             children: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: Text(appLoca.cancelar),
  //               ),
  //               FilledButton(
  //                 onPressed: () async {
  //                   if (formEnlace.currentState!.validate()) {
  //                     quillEditorController
  //                         .setSelectionRange(indexS, lengthS)
  //                         .then(
  //                       (value) {
  //                         quillEditorController
  //                             .getSelectedText()
  //                             .then((textoSeleccionado) async {
  //                           if (textoSeleccionado != null &&
  //                               textoSeleccionado is String &&
  //                               textoSeleccionado.isNotEmpty) {
  //                             quillEditorController.setFormat(
  //                                 format: 'link', value: uri);
  //                             if (mounted) Navigator.of(context).pop();
  //                             setState(() {
  //                               focusQuillEditorController = true;
  //                             });
  //                             quillEditorController.focus();
  //                           }
  //                         });
  //                       },
  //                     );
  //                   }
  //                 },
  //                 child: Text(appLoca.insertarEnlace),
  //               )
  //             ],
  //           )
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget widgetVariable(Size size) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    List<Widget> wV;
    if (answerType != null) {
      switch (answerType) {
        case AnswerType.mcq:
          wV = [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(appLoca.elEstudianteVaAPoder),
            ),
            RadioListTile<bool>.adaptive(
                contentPadding: const EdgeInsets.all(0),
                title: Text(appLoca.unaComoVerdadera),
                value: false,
                groupValue: _mcqmu,
                onChanged: (bool? v) {
                  setState(() => _mcqmu = v!);
                }),
            RadioListTile<bool>.adaptive(
                contentPadding: const EdgeInsets.all(0),
                title: Text(appLoca.variasComoVerdaderas),
                // title: Text(AppLocalizations.of(context)!.rbVFVNTVLabel),
                value: true,
                groupValue: _mcqmu,
                onChanged: (bool? v) {
                  setState(() => _mcqmu = v!);
                }),
            const SizedBox(height: 15),
            TextFormField(
                maxLines: 1,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: appLoca.rVMCQLabel,
                  hintText: appLoca.rVMCQ,
                  hintMaxLines: 1,
                  hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
                ),
                textCapitalization: TextCapitalization.sentences,
                initialValue:
                    '', //widget.task.hasCorrectMCQ ? widget.task.correctMCQ : '', //TODO
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return appLoca.rVMCQ;
                  }
                  widget.task.addCorrectMCQ(v.trim(), lang: MyApp.currentLang);
                  return null;
                }),
            Column(children: widgetCorrects),
            TextButton(
                onPressed: _mcqmu
                    ? () async {
                        setState(() {
                          Key randomKey = UniqueKey();
                          widgetCorrects.add(
                            Column(
                              key: randomKey,
                              children: [
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                          maxWidth: min(
                                              MediaQuery.of(context)
                                                      .size
                                                      .width -
                                                  80,
                                              Auxiliar.maxWidth - 80)),
                                      child: TextFormField(
                                          maxLines: 1,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(),
                                            labelText: appLoca.rVMCQLabel,
                                            hintText: appLoca.rVMCQ,
                                            hintMaxLines: 1,
                                            hintStyle: const TextStyle(
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          initialValue: '',
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return appLoca.rVMCQ;
                                            }
                                            widget.task.addCorrectMCQ(v.trim(),
                                                lang: MyApp.currentLang);
                                            return null;
                                          }),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () async {
                                        setState(() {
                                          widgetCorrects.removeWhere(
                                              (Widget element) =>
                                                  element.key == randomKey);
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle),
                                    )
                                  ],
                                )
                              ],
                            ),
                          );
                        });
                      }
                    : null,
                child: Text(appLoca.addrV)),
            const SizedBox(height: 15),
            TextFormField(
                maxLines: 1,
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: appLoca.rDMCQLable,
                    hintText: appLoca.rDMCQ,
                    hintMaxLines: 1,
                    hintStyle:
                        const TextStyle(overflow: TextOverflow.ellipsis)),
                textCapitalization: TextCapitalization.sentences,
                initialValue: '',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return appLoca.rDMCQ;
                  }
                  // widget.task.distractors.add(v.trim());
                  widget.task
                      .addDistractor(PairLang(MyApp.currentLang, v.trim()));
                  return null;
                }),
            Column(children: widgetDistractors),
            TextButton(
                onPressed: () async {
                  setState(() {
                    Key randomKey = UniqueKey();
                    widgetDistractors.add(
                      Column(
                        key: randomKey,
                        children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                    maxWidth: min(
                                        MediaQuery.of(context).size.width - 80,
                                        Auxiliar.maxWidth - 80)),
                                child: TextFormField(
                                    maxLines: 1,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: appLoca.rDMCQLable,
                                      hintText: appLoca.rDMCQ,
                                      hintMaxLines: 1,
                                      hintStyle: const TextStyle(
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    initialValue: '',
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return appLoca.rDMCQ;
                                      }
                                      widget.task.addDistractor(PairLang(
                                          MyApp.currentLang, v.trim()));
                                      return null;
                                    }),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              IconButton(
                                  onPressed: () async {
                                    setState(() => widgetDistractors
                                        .removeWhere((Widget element) =>
                                            element.key == randomKey));
                                  },
                                  icon: const Icon(Icons.remove_circle))
                            ],
                          )
                        ],
                      ),
                    );
                  });
                },
                child: Text(appLoca.addrD)),
          ];
          break;
        case AnswerType.tf:
          widget.task.correctTF = _rgtf;
          wV = [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                appLoca.verdaderoNTDivLabel,
              ),
            ),
            RadioListTile<bool>.adaptive(
                contentPadding: const EdgeInsets.all(0),
                title: Text(appLoca.rbVFVNTVLabel),
                value: true,
                groupValue: _rgtf,
                onChanged: (bool? v) {
                  setState(() => _rgtf = v!);
                  widget.task.correctTF = true;
                }),
            RadioListTile<bool>.adaptive(
                contentPadding: const EdgeInsets.all(0),
                title: Text(appLoca.rbVFFNTLabel),
                value: false,
                groupValue: _rgtf,
                onChanged: (bool? v) {
                  setState(() => _rgtf = v!);
                  widget.task.correctTF = false;
                })
          ];
          break;
        default:
          wV = [Container()];
      }
    } else {
      wV = [Container()];
    }
    return ListView.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: wV.elementAt(index),
        ),
      ),
      itemCount: wV.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  widgetSpaces() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;

    List<Widget> lstW = [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(appLoca.cbEspacioDivLabel),
      ),
      Visibility(
        visible: errorEspacios,
        child: const SizedBox(height: 20),
      ),
      Visibility(
        visible: errorEspacios,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            appLoca.cbEspacioDivError,
            style: textTheme.bodySmall!.copyWith(color: colorScheme.error),
          ),
        ),
      ),
      const SizedBox(height: 20),
      CheckboxListTile.adaptive(
          contentPadding: const EdgeInsets.all(0),
          value: _spaFis,
          onChanged: (v) {
            setState(() => _spaFis = v!);
          },
          title: Text(appLoca.rbEspacio1Label)),
      CheckboxListTile.adaptive(
          contentPadding: const EdgeInsets.all(0),
          value: _spaVir,
          onChanged: (v) {
            setState(() {
              _spaVir = v!;
            });
          },
          title: Text(appLoca.rbEspacio2Label)),
    ];
    return ListView.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: lstW.elementAt(index),
        ),
      ),
      itemCount: lstW.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  Widget buttonAddTask() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceAround,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Visibility(
                  visible: !_pasoUno,
                  child: TextButton(
                    onPressed: _btEnable
                        ? () async {
                            setState(() => _pasoUno = true);
                            setState(() {});
                          }
                        : null,
                    child: Text(appLoca.atras),
                  ),
                ),
                Visibility(
                  visible: _pasoUno,
                  child: TextButton(
                    onPressed: _btEnable
                        ? widget.task.hasLabel
                            ? textoTask.isNotEmpty
                                ? () {
                                    widget.task.setComments({
                                      'value': textoTask.trim(),
                                      'lang': MyApp.currentLang
                                    });
                                    setState(() {
                                      _errorDescription = false;
                                      _pasoUno = false;
                                    });
                                  }
                                : () {
                                    setState(() => _errorDescription = true);
                                  }
                            : null
                        : null,
                    child: Text(appLoca.siguiente),
                  ),
                ),
                Visibility(
                  visible: !_pasoUno,
                  child: FilledButton.icon(
                    onPressed: () async {
                      bool noError = _thisKey.currentState!.validate();
                      setState(() {
                        // errorTaskStatement = textoTask.trim().isEmpty;
                        errorEspacios = !(_spaVir || _spaFis);
                      });
                      if (noError && !errorEspacios && !_errorDescription) {
                        // if (_spaFis || _spaVir) {
                        // setState(() => errorEspacios = false);
                        setState(() => _btEnable = false);
                        // textoTask = Auxiliar.quill2Html(textoTask);
                        // quillEditorController.setText(textoTask);
                        // widget.task.addComment(
                        //     {'lang': MyApp.currentLang, 'value': textoTask});
                        List<String> inSpace = [];
                        List<Space> spaces = [];
                        if (_spaFis) {
                          inSpace.add(Space.physical.name);
                          spaces.add(Space.physical);
                        }
                        if (_spaVir) {
                          inSpace.add(Space.virtual.name);
                          spaces.add(Space.virtual);
                        }
                        widget.task.setSpaces(spaces);

                        if (_image != null) {
                          if (_imageLic != null) {
                            widget.task.image = PairImage(_image, _imageLic!);
                          } else {
                            widget.task.image =
                                PairImage.withoutLicense(_image);
                          }
                        }

                        Map<String, dynamic> bodyRequest = {
                          'aT': widget.task.aT.name,
                          'inSpace': inSpace,
                          'label': widget.task.labels2List(),
                          'comment': widget.task.comments2List(),
                          'hasFeature': widget.task.idContainer
                        };
                        switch (widget.task.aT) {
                          case AnswerType.mcq:
                            if (widget.task.distractors.isNotEmpty) {
                              if (widget.task.hasCorrectMCQ) {
                                if (_mcqmu) {
                                  bodyRequest['correct'] =
                                      widget.task.correctsMCQ2List();
                                } else {
                                  bodyRequest['correct'] =
                                      widget.task.correctsMCQ2List().first;
                                }
                                widget.task.singleSelection = !_mcqmu;
                                bodyRequest['singleSelection'] = !_mcqmu;
                              }
                              bodyRequest['distractors'] =
                                  widget.task.distractorsMCQ2List();
                            }
                            break;
                          case AnswerType.tf:
                            if (widget.task.hasCorrectTF) {
                              bodyRequest['correct'] = widget.task.correctTF;
                            }
                            break;
                          default:
                        }
                        if (widget.task.image is PairImage) {
                          bodyRequest['image'] = widget.task.image!.toMap();
                        }
                        if (widget.task.containerType ==
                            ContainerTask.itinerary) {
                          setState(() => _btEnable = true);
                          widget.task.isEmpty = false;
                          Navigator.pop(context, widget.task);
                        } else {
                          http
                              .post(
                            Queries.newTask(
                                Auxiliar.id2shortId(widget.task.idContainer)!),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization':
                                  'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                            },
                            body: json.encode(bodyRequest),
                          )
                              .then((response) async {
                            setState(() => _btEnable = true);
                            switch (response.statusCode) {
                              case 201:
                              case 202:
                                widget.task.id = response.headers['location']!;
                                if (!ConfigXest.development) {
                                  await FirebaseAnalytics.instance.logEvent(
                                    name: "newTask",
                                    parameters: {
                                      "iri": widget.task.id.split('/').last
                                    },
                                  ).then(
                                    (value) {
                                      widget.task.id =
                                          response.headers['location']!;
                                      if (mounted) {
                                        Navigator.pop(context, widget.task);
                                      }
                                      smState.clearSnackBars();
                                      smState.showSnackBar(SnackBar(
                                          content:
                                              Text(appLoca.infoRegistrada)));
                                    },
                                  ).onError((error, stackTrace) async {
                                    if (ConfigXest.development) {
                                      debugPrint(error.toString());
                                    } else {
                                      await FirebaseCrashlytics.instance
                                          .recordError(error, stackTrace);
                                    }
                                    widget.task.id =
                                        response.headers['location']!;
                                    if (mounted) {
                                      Navigator.pop(context, widget.task);
                                    }
                                    smState.clearSnackBars();
                                    smState.showSnackBar(SnackBar(
                                        content: Text(appLoca.infoRegistrada)));
                                  });
                                } else {
                                  // Devuelvo a la pantalla anterior la tarea que se acaba de crear para reprsentarla
                                  widget.task.id =
                                      response.headers['location']!;
                                  Navigator.pop(context, widget.task);
                                  smState.clearSnackBars();
                                  smState.showSnackBar(SnackBar(
                                      content: Text(appLoca.infoRegistrada)));
                                }
                                break;
                              default:
                                smState.clearSnackBars();
                                smState.showSnackBar(SnackBar(
                                  backgroundColor: colorScheme.error,
                                  content: Text(
                                    response.statusCode.toString(),
                                    style: td.textTheme.bodyMedium!.copyWith(
                                      color: colorScheme.onError,
                                    ),
                                  ),
                                ));
                            }
                          }).onError((error, stackTrace) async {
                            setState(() => _btEnable = true);
                            if (ConfigXest.development) {
                              debugPrint(error.toString());
                            } else {
                              await FirebaseCrashlytics.instance
                                  .recordError(error, stackTrace);
                            }
                            //print(error.toString());
                          });
                          // }
                          // else {
                          //   setState(() => errorEspacios = true);
                          // }
                        }
                        // else {
                        //   if (_spaFis || _spaVir) {
                        //     setState(() => errorEspacios = false);
                        //   } else {
                        //     setState(() => errorEspacios = true);
                        //   }
                        // }
                      }
                    },
                    label: Text(AppLocalizations.of(context)!.enviarTask),
                    icon: const Icon(Icons.publish),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 500),
      ],
    );
  }
}

class COTaskItinerary extends StatefulWidget {
  final Feature feature;
  final Task task;

  const COTaskItinerary(this.feature, this.task, {super.key});

  @override
  State<StatefulWidget> createState() => _COTaskItinerary();
}

class _COTaskItinerary extends State<COTaskItinerary> {
  late Task _task;
  late Feature _feature;

  late bool _selectTF, _guardado, _textoObligatorio;
  late List<bool> _selectMCQ;
  late String _selectMCQR;
  late GlobalKey<FormState> _thisKey, _thisKeyMCQ;
  late Answer _answer;
  late String _texto;
  late int _startTime;
  late List<String> _valoresMCQ;

  @override
  void initState() {
    _feature = widget.feature;
    _task = widget.task;

    _valoresMCQ = [];
    _thisKey = GlobalKey<FormState>();
    _thisKeyMCQ = GlobalKey<FormState>();
    _guardado = false;
    _startTime = DateTime.now().millisecondsSinceEpoch;

    Set<AnswerType> atRT = {
      AnswerType.multiplePhotosText,
      AnswerType.photoText,
      AnswerType.text,
      AnswerType.videoText
    };

    _textoObligatorio = atRT.contains(_task.aT);

    _answer = Answer.withoutAnswer({
      'idContainer': _feature.shortId,
      'idTask': Auxiliar.id2shortId(_task.id),
      'answerType': _task.aT,
    });

    switch (_task.aT) {
      case AnswerType.mcq:
        int tama = _task.distractors.length + _task.correctMCQ.length;
        _selectMCQ = _task.singleSelection
            ? List<bool>.generate(tama, (index) => index == 0)
            : List<bool>.filled(tama, false);
        for (PairLang ele in _task.distractors) {
          _valoresMCQ.add(ele.value);
        }
        for (PairLang ele in _task.correctMCQ) {
          _valoresMCQ.add(ele.value);
        }
        _valoresMCQ.shuffle();
        _selectMCQR = _valoresMCQ.first;
        break;
      case AnswerType.tf:
        _selectTF = Random.secure().nextBool();
        break;
      default:
    }
    _texto = '';

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(appLoca.realizaTarea),
        centerTitle: false,
      ),
      body: SafeArea(
          top: false,
          bottom: false,
          minimum: EdgeInsets.symmetric(
              horizontal: Auxiliar.getLateralMargin(size.width)),
          child: CustomScrollView(slivers: _showTask())),
    );
  }

  List<Widget> _showTask() {
    List<Widget> out = [_widgetInfoTask(), _widgetSolveTask()];
    out.add(_widgetButtons());
    return out;
  }

  Widget _widgetInfoTask() {
    ThemeData td = Theme.of(context);
    List<Widget> lst = [
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HtmlWidget(
                _task.getAComment(lang: MyApp.currentLang),
                factoryBuilder: () => MyWidgetFactory(),
                textStyle: td.textTheme.titleMedium,
              ),
              // Padding(
              //   padding: const EdgeInsets.only(top: 5),
              //   child: Align(
              //     alignment: Alignment.centerRight,
              //     child: TextButton.icon(
              //       icon: Icon(
              //         _isPlaying ? Icons.stop : Icons.hearing,
              //         color: colorScheme.primary,
              //       ),
              //       label: Text(
              //         AppLocalizations.of(context)!.escuchar,
              //         style: td.textTheme.bodyMedium!.copyWith(
              //           color: colorScheme.primary,
              //         ),
              //       ),
              //       onPressed: () async {
              //         if (_isPlaying) {
              //           setState(() => _isPlaying = false);
              //           _stop();
              //         } else {
              //           setState(() => _isPlaying = true);
              //           List<String> lstTexto = Auxiliar.frasesParaTTS(
              //               task!.getAComment(lang: MyApp.currentLang));
              //           for (String leerParte in lstTexto) {
              //             await _speak(leerParte);
              //           }
              //           setState(() => _isPlaying = false);
              //         }
              //       },
              //     ),
              //   ),
              // )
            ],
          ),
        ),
      ),
    ];
    if (_task.image is PairImage) {
      Size size = MediaQuery.of(context).size;
      double mW = Auxiliar.maxWidth * 0.5;
      double mH =
          size.width > size.height ? size.height * 0.5 : size.height / 3;
      lst.add(
        ImageNetwork(
          image: _task.image!.image,
          height: mH,
          width: mW,
          duration: 0,
          onPointer: true,
          fitWeb: BoxFitWeb.cover,
          fitAndroidIos: BoxFit.cover,
          borderRadius: BorderRadius.circular(25),
          curve: Curves.easeIn,
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      FullScreenImage(_task.image!, local: false),
                  fullscreenDialog: false),
            );
          },
          onError: const Icon(Icons.image_not_supported),
          onLoading: const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 35, bottom: 15),
      sliver: SliverList.builder(
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: lst.elementAt(index),
          );
        },
        itemCount: lst.length,
      ),
    );
  }

  Widget _widgetSolveTask() {
    List<Widget> lista = [];
    AppLocalizations? appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    Widget cuadrotexto = Form(
      key: _thisKey,
      child: TextFormField(
        maxLines: _textoObligatorio ? 5 : 2,
        initialValue: _texto,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _textoObligatorio
                ? appLoca.respondePreguntaTextualLabel
                : appLoca.notasOpcionalesLabel,
            hintText: _textoObligatorio
                ? appLoca.respondePreguntaTextual
                : appLoca.notasOpcionales,
            hintMaxLines: 2,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        validator: (value) {
          if (value != null) {
            if (_textoObligatorio) {
              if (value.trim().isNotEmpty) {
                _texto = value.trim();
                return null;
              } else {
                return appLoca.respondePreguntaTextual;
              }
            } else {
              _texto = value.trim();
              return null;
            }
          } else {
            return appLoca.respondePreguntaTextual;
          }
        },
      ),
    );

    switch (_task.aT) {
      case AnswerType.mcq:
        List<Widget> widgetsMCQ = [];
        if (_task.singleSelection) {
          for (int i = 0, tama = _valoresMCQ.length; i < tama; i++) {
            String valor = _valoresMCQ[i];
            bool falsa = _task.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RadioListTile<String>.adaptive(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    value: valor,
                    groupValue: _selectMCQR,
                    onChanged: !_guardado
                        ? (String? v) {
                            setState(() {
                              _selectMCQR = v!;
                            });
                          }
                        : null,
                  ),
                ),
              ),
            );
          }
        } else {
          for (int i = 0, tama = _valoresMCQ.length; i < tama; i++) {
            String valor = _valoresMCQ[i];
            bool falsa = _task.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: CheckboxListTile.adaptive(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    value: _selectMCQ[i],
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    onChanged: (value) => setState(() {
                      _selectMCQ[i] = !_selectMCQ[i];
                    }),
                    enabled: !_guardado,
                  ),
                ),
              ),
            );
          }
        }
        lista.add(
          Form(
            key: _thisKeyMCQ,
            child: Column(mainAxisSize: MainAxisSize.min, children: widgetsMCQ),
          ),
        );
        break;
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
        // TODO Visor de fotos
        break;
      case AnswerType.tf:
        bool? rC = _task.hasCorrectTF ? _task.correctTF : null;
        Widget extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RadioListTile<bool>.adaptive(
                    tileColor: _guardado
                        ? _task.hasCorrectTF
                            ? !rC!
                                ? td.colorScheme.error
                                : td.colorScheme.primary
                            : null
                        : null,
                    title: Text(
                      appLoca.rbVFVNTVLabel,
                      style: _guardado
                          ? _task.hasCorrectTF
                              ? td.textTheme.bodyLarge!.copyWith(
                                  color: !rC!
                                      ? td.colorScheme.onError
                                      : td.colorScheme.onPrimary,
                                )
                              : td.textTheme.bodyLarge
                          : td.textTheme.bodyLarge,
                    ),
                    value: true,
                    groupValue: _selectTF,
                    onChanged: (bool? v) {
                      setState(() => _selectTF = v!);
                    }),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: RadioListTile<bool>.adaptive(
                  tileColor: _guardado
                      ? _task.hasCorrectTF
                          ? rC!
                              ? td.colorScheme.error
                              : td.colorScheme.primary
                          : null
                      : null,
                  title: Text(
                    appLoca.rbVFFNTLabel,
                    style: _guardado
                        ? _task.hasCorrectTF
                            ? td.textTheme.bodyLarge!.copyWith(
                                color: rC!
                                    ? td.colorScheme.onError
                                    : td.colorScheme.onPrimary,
                              )
                            : td.textTheme.bodyLarge
                        : td.textTheme.bodyLarge,
                  ),
                  value: false,
                  groupValue: _selectTF,
                  onChanged: (bool? v) {
                    setState(() => _selectTF = v!);
                  }),
            ),
            const SizedBox(
              height: 10,
            )
          ],
        );
        lista.add(extra);
        break;
      case AnswerType.video:
      case AnswerType.videoText:
        // TODO Visor de vídeo
        break;
      default:
    }

    lista.add(cuadrotexto);

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: lista.elementAt(index),
            ),
          ),
          childCount: lista.length,
        ),
      ),
    );
  }

  Widget _widgetButtons() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> botones = [];
    switch (_task.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones.add(Padding(
          padding: const EdgeInsets.only(right: 10),
          child: OutlinedButton.icon(
            onPressed: null,
            //  () async {
            //   // List<CameraDescription> cameras = await availableCameras();
            //   // await Navigator.push(
            //   //     context,
            //   //     MaterialPageRoute<Task>(
            //   //         builder: (BuildContext context) {
            //   //           return TakePhoto(cameras.first);
            //   //         },
            //   //         fullscreenDialog: true));
            //   await availableCameras()
            //       .then((cameras) async => await Navigator.push(
            //           context,
            //           MaterialPageRoute<Task>(
            //               builder: (BuildContext context) {
            //                 return TakePhoto(cameras.first);
            //               },
            //               fullscreenDialog: true)));
            // },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLoca!.abrirCamara),
          ),
        ));
        break;
      default:
    }
    botones.add(FilledButton.icon(
      onPressed: _guardado
          ? () {
              switch (_answer.answerType) {
                case AnswerType.mcq:
                case AnswerType.tf:
                  Navigator.pop(context);
                  break;
                default:
              }
            }
          : () async {
              if (_thisKey.currentState!.validate()) {
                try {
                  int now = DateTime.now().millisecondsSinceEpoch;
                  _answer.time2Complete = now - _startTime;
                  _answer.timestamp = now;
                  switch (_answer.answerType) {
                    case AnswerType.mcq:
                      String answ = "";
                      if (_task.singleSelection) {
                        answ = _selectMCQR;
                      } else {
                        List<String> a = [];
                        for (int i = 0, tama = _selectMCQ.length;
                            i < tama;
                            i++) {
                          if (_selectMCQ[i]) {
                            a.add(_valoresMCQ[i]);
                          }
                        }
                        answ = a.toString();
                      }
                      if (_texto.trim().isNotEmpty) {
                        _answer.answer = {
                          'answer': answ,
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                          'extraText': _texto.trim()
                        };
                      } else {
                        _answer.answer = answ;
                      }
                      UserXEST.userXEST.answers.add(_answer);
                      setState(() => _guardado = true);
                      break;
                    case AnswerType.multiplePhotos:
                      break;
                    case AnswerType.multiplePhotosText:
                      break;
                    case AnswerType.noAnswer:
                      break;
                    case AnswerType.photo:
                      break;
                    case AnswerType.photoText:
                      break;
                    case AnswerType.text:
                      _answer.answer = {
                        'answer': _texto.trim(),
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      };
                      break;
                    case AnswerType.tf:
                      if (_texto.trim().isNotEmpty) {
                        _answer.answer = {
                          'answer': _selectTF,
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                          'extraText': _texto.trim()
                        };
                      } else {
                        _answer.answer = _selectTF;
                      }
                      UserXEST.userXEST.answers.add(_answer);
                      setState(() => _guardado = true);
                      break;
                    case AnswerType.video:
                      break;
                    case AnswerType.videoText:
                      break;
                    default:
                  }
                  _answer.commentTask =
                      _task.getAComment(lang: MyApp.currentLang);

                  // Feature feature = Feature.providers(
                  //     widget.shortIdContainer, await _getFeature());

                  _answer.labelContainer =
                      _feature.getALabel(lang: MyApp.currentLang);
                  http
                      .post(Queries.newAnswer(),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization':
                                'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                          },
                          body: json.encode(_answer.toMap()))
                      .then((response) async {
                    switch (response.statusCode) {
                      case 201:
                        String idAnswer = response.headers['location']!;
                        _answer.id = idAnswer;
                        if (UserXEST.userXEST.hasFeedEnable) {
                          String idAnswerFeed = idAnswer.split('/').last;
                          http
                              .put(
                                  Queries.feedAnswer(
                                      Auxiliar.id2shortId(
                                          UserXEST.userXEST.feed)!,
                                      UserXEST.userXEST.id,
                                      idAnswerFeed),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization':
                                        'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                  },
                                  body: json.encode({}))
                              .then(
                            (value) async {
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                content: Text(appLoca!.respuestaGuardada),
                              ));
                              setState(() {
                                _guardado = true;
                              });
                              if (!ConfigXest.development) {
                                await FirebaseAnalytics.instance.logEvent(
                                  name: "taskCompleted",
                                  parameters: {
                                    "feature": _feature.shortId,
                                    "task": Auxiliar.id2shortId(_task.id)!
                                  },
                                ).then((__) {
                                  FirebaseAnalytics.instance.logEvent(
                                    name: "answerAddedFeed",
                                    parameters: {
                                      "idFeed": Auxiliar.id2shortId(
                                          UserXEST.userXEST.feed)!,
                                      "idStudent": UserXEST.userXEST.id,
                                      "idAnswer": idAnswer
                                    },
                                  ).then((_) {
                                    if (_task.aT != AnswerType.mcq && mounted) {
                                      Navigator.pop(context);
                                    }
                                  });
                                });
                              } else {
                                if (_task.aT != AnswerType.mcq) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                          );
                        } else {
                          smState.clearSnackBars();
                          smState.showSnackBar(SnackBar(
                            content: Text(appLoca!.respuestaGuardada),
                          ));
                          setState(() {
                            _guardado = true;
                          });
                          if (!ConfigXest.development) {
                            await FirebaseAnalytics.instance.logEvent(
                              name: "taskCompleted",
                              parameters: {
                                "feature": _feature.shortId,
                                "task": Auxiliar.id2shortId(_task.id)!,
                              },
                            ).then((_) {
                              if (_task.aT != AnswerType.mcq && mounted) {
                                Navigator.pop(context);
                              }
                            });
                          } else {
                            if (_task.aT != AnswerType.mcq) {
                              Navigator.pop(context);
                            }
                          }
                        }
                        break;
                      default:
                    }
                  }).onError((error, stackTrace) async {
                    if (ConfigXest.development) {
                      debugPrint(error.toString());
                    } else {
                      await FirebaseCrashlytics.instance
                          .recordError(error, stackTrace);
                    }
                  });
                } catch (error) {
                  smState.clearSnackBars();
                  smState.showSnackBar(SnackBar(
                    content: Text(error.toString()),
                  ));
                }
              }
            },
      label: _guardado ? Text(appLoca!.finRevision) : Text(appLoca!.guardar),
      icon:
          _guardado ? const Icon(Icons.navigate_next) : const Icon(Icons.save),
    ));
    // TODO REMOVE
    switch (_task.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.multiplePhotosText:
      case AnswerType.photo:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones = [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.camera_alt),
              label: Text(appLoca.abrirCamara),
            ),
          ),
          FilledButton.icon(
            onPressed: null,
            label: Text(appLoca.guardar),
            icon: const Icon(Icons.save),
          ),
        ];
        break;
      default:
    }
    List<Widget> lista = [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: botones,
      )
    ];
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: lista.elementAt(index),
            ),
          ),
          childCount: lista.length,
        ),
      ),
    );
  }
}
