import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_waves/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

const int linesInGraph = 400; // 400
const int peaksPosition = 100; // 125
const double maxRmsLevel = 75.0; // 100.0

const double baseHeight = 100.0; // 200.0
const double lineHeight = 50.0; // 200.0
const double baseWidth = 3.0; // 3.0

const String streamUrl = "https://online.radioroks.ua/RadioROKS_HardnHeavy";

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SafeArea(
        child: Scaffold(
          backgroundColor: AppColors.mainBg,
          body: Center(
            child: Visualiser(),
          ),
        ),
      ),
    );
  }
}

class Visualiser extends StatefulWidget {
  const Visualiser({super.key});

  @override
  State<Visualiser> createState() => _VisualiserState();
}

class _VisualiserState extends State<Visualiser> {
  StreamedResponse? response;
  StreamSubscription? subscription;

  Map<String, double> peaks = {
    "f0": 0.0,
    "f1": 0.0,
    "f2": 0.0,
    "f3": 0.0,
    "f4": 0.0,
    "f5": 0.0,
    "f6": 0.0,
    "f7": 0.0,
    "f8": 0.0,
    "f9": 0.0,
  };
  Map<String, List<double>> freqs = {
    "f0": List.filled(linesInGraph, 0.0),
    "f1": List.filled(linesInGraph, 0.0),
    "f2": List.filled(linesInGraph, 0.0),
    "f3": List.filled(linesInGraph, 0.0),
    "f4": List.filled(linesInGraph, 0.0),
    "f5": List.filled(linesInGraph, 0.0),
    "f6": List.filled(linesInGraph, 0.0),
    "f7": List.filled(linesInGraph, 0.0),
    "f8": List.filled(linesInGraph, 0.0),
    "f9": List.filled(linesInGraph, 0.0),
  };
  List<int> savedBytes = [];
  DateTime? lastTick;

  static const Map<String, String> valuesFreq = {
    //105 240 355 800 1500 4500 9000 13000 15000
    "f0": "f0: 0-105 Hz",
    "f1": "f1: 105-240 Hz",
    "f2": "f2: 240-355 Hz",
    "f3": "f3: 355-800 Hz",
    "f4": "f4: 800-1500 Hz",
    "f5": "f5: 1500-4500 Hz",
    "f6": "f6: 4500-9000 Hz",
    "f7": "f7: 9000-13000 Hz",
    "f8": "f8: 13000-15000 Hz",
    "f9": "f9: 15000-20000 Hz",
  };

  @override
  void initState() {
    super.initState();

    FFmpegKitConfig.setSessionHistorySize(500);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 64),
                ElevatedButton(
                  onPressed: () async {
                    Request req = Request(
                      "GET",
                      Uri.parse(streamUrl),
                    );
                    req.persistentConnection = false;

                    StreamedResponse res = await req.send();

                    if (res.statusCode >= 200 && res.statusCode < 300) {
                      setState(
                        () {
                          subscription = res.stream.listen(
                            (bytes) async {
                              DateTime now = DateTime.now();

                              File file = File(
                                "chunks/chunk_${now.microsecondsSinceEpoch}.mp3",
                              );

                              await file.writeAsBytes(bytes);

                              await FFmpegKit.executeAsync(
                                "-i ${file.path} -filter_complex 'acrossover=split=105 240 355 800 1500 4500 9000 13000 15000:order=6th[f0][f1][f2][f3][f4][f5][f6][f7][f8][f9]' -ab 128k"
                                " -map '[f0]' 'chunks/chunk_f0_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f1]' 'chunks/chunk_f1_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f2]' 'chunks/chunk_f2_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f3]' 'chunks/chunk_f3_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f4]' 'chunks/chunk_f4_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f5]' 'chunks/chunk_f5_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f6]' 'chunks/chunk_f6_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f7]' 'chunks/chunk_f7_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f8]' 'chunks/chunk_f8_${now.microsecondsSinceEpoch}.wav'"
                                " -map '[f9]' 'chunks/chunk_f9_${now.microsecondsSinceEpoch}.wav'",
                                (session) async {
                                  ReturnCode? returnCode;
                                  try {
                                    returnCode = await session.getReturnCode();
                                  } catch (ex) {
                                    returnCode = ReturnCode(999);
                                  }

                                  if (returnCode?.getValue() != 0) {
                                    debugPrint(
                                      "ReturnCode :: ${returnCode?.getValue()}. Execution stopped",
                                    );
                                    await file.delete(recursive: true);
                                    return;
                                  }

                                  for (String fileType in const [
                                    "f0",
                                    "f1",
                                    "f2",
                                    "f3",
                                    "f4",
                                    "f5",
                                    "f6",
                                    "f7",
                                    "f8",
                                    "f9",
                                  ]) {
                                    File file = File(
                                      "chunks/chunk_${fileType}_${now.microsecondsSinceEpoch}.wav",
                                    );

                                    await FFprobeKit.executeAsync(
                                      //  WORKS   '-v error -f lavfi -i "amovie=${file.path},asetnsamples=44100,astats=metadata=1:reset=1" -show_entries frame_tags=lavfi.astats.Overall.RMS_level -of json',
                                      '-v quiet -f lavfi -i "amovie=${file.path},asetnsamples=44100,astats=metadata=1:reset=0" -show_entries frame_tags=lavfi.astats.Overall.RMS_level -of json',
                                      (session) async {
                                        ReturnCode? returnCode;
                                        try {
                                          returnCode =
                                              await session.getReturnCode();
                                        } catch (ex) {
                                          returnCode = ReturnCode(999);
                                        }

                                        if (returnCode?.getValue() != 0) {
                                          debugPrint(
                                            "ReturnCode :: ${returnCode?.getValue()}. Execution stopped",
                                          );
                                          await file.delete(recursive: true);
                                          return;
                                        }

                                        String output =
                                            await session.getOutput() ?? "";

                                        Map map = {};

                                        List<String> temp = output.split("\n");
                                        temp.removeWhere(
                                            (s) => s.contains("mp3float"));
                                        output = temp.join("\n");

                                        try {
                                          map = json.decode(output);
                                        } catch (ex) {
                                          await file.delete(recursive: true);
                                          return;
                                        }

                                        if (map["frames"] == null) {
                                          await file.delete(recursive: true);
                                          return;
                                        }

                                        for (var frame in map["frames"]) {
                                          double value = double.parse(
                                            frame["tags"][
                                                "lavfi.astats.Overall.RMS_level"],
                                          );

                                          if ((freqs[fileType]?.length ?? 0) >=
                                              linesInGraph) {
                                            freqs[fileType] =
                                                freqs[fileType]?.sublist(1) ??
                                                    [];
                                          }

                                          value = value
                                                  .abs()
                                                  .clamp(0.0, maxRmsLevel) /
                                              maxRmsLevel;

                                          value =
                                              (value * 100).roundToDouble() /
                                                  100;

                                          freqs[fileType] = [
                                            ...(freqs[fileType] ?? []),
                                            value,
                                          ];

                                          if ((freqs[fileType]?.length ?? 0) >
                                              peaksPosition) {
                                            peaks[fileType] = freqs[fileType]![
                                                freqs[fileType]!.length -
                                                    peaksPosition];
                                          }
                                        }
                                        setState(() {});
                                        await file.delete(recursive: true);
                                      },
                                      (logs) {},
                                    );
                                  }
                                  await file.delete(recursive: true);
                                },
                                (logs) {},
                              );
                            },
                          );
                        },
                      );
                    }
                  },
                  child: const Text("Start"),
                ),
                const SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: () async {
                    await subscription?.cancel();
                    subscription = null;
                    response = null;
                  },
                  child: const Text("Stop"),
                ),
                const Expanded(child: SizedBox.shrink()),
                Container(
                  color: AppColors.mainBg,
                  child: SizedBox(
                    height: baseHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: () {
                        List<Widget> widgets = [];

                        for (int i = 0; i < peaks.length; i++) {
                          for (int j = 0; j < 3; j++) {
                            double peak = peaks.values.elementAt(i);

                            if (j == 0 && i > 0) {
                              peak =
                                  (peak * 2 + peaks.values.elementAt(i - 1)) /
                                      3;
                            }
                            if (j == 2 && i < peaks.length - 1) {
                              peak =
                                  (peak * 2 + peaks.values.elementAt(i + 1)) /
                                      3;
                            }

                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.all(baseWidth / 2),
                                child: Container(
                                  width: baseWidth * 2,
                                  height: baseHeight,
                                  decoration: const BoxDecoration(
                                    color: AppColors.mainBgLight,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(baseWidth),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: baseWidth * 2,
                                      height: (baseHeight * peak)
                                          .clamp(1.0, baseHeight),
                                      decoration: const BoxDecoration(
                                        color: AppColors.main,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(baseWidth),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        return widgets;
                      }(),
                    ),
                  ),
                ),
                const SizedBox(width: 128),
                Container(
                  color: AppColors.mainBg,
                  child: SizedBox(
                    height: baseHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: () {
                        List<Widget> widgets = [];

                        for (String key in peaks.keys) {
                          for (int i = 0; i < 3; i++) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.all(baseWidth / 2),
                                child: Container(
                                  width: baseWidth * 2,
                                  height: baseHeight,
                                  decoration: const BoxDecoration(
                                    color: AppColors.mainBgLight,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(baseWidth),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: baseWidth * 2,
                                      height: (baseHeight * peaks[key]!)
                                          .clamp(1.0, baseHeight),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: const [
                                            Colors.red,
                                            Colors.yellow,
                                            // Colors.yellow,
                                            // Colors.purple,
                                            // Colors.purple,
                                            Colors.green,
                                            // Colors.green,
                                            // Colors.white,
                                            // Colors.white,
                                          ],
                                          // stops: [
                                          //   0.2,
                                          //   0.21,
                                          //   0.4,
                                          //   0.41,
                                          //   0.6,
                                          //   0.61,
                                          //   0.8,
                                          //   0.81,
                                          //   1.0,
                                          // ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          transform: MyTransform(peaks[key]!),
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(baseWidth),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        return widgets;
                      }(),
                    ),
                  ),
                ),
                const SizedBox(width: 128),
              ],
            ),
            const SizedBox(height: 16),
            ...() {
              List<Widget> list = [];

              for (String key in freqs.keys) {
                list.addAll(
                  [
                    Text(
                      valuesFreq[key] ?? "",
                      style: const TextStyle(color: Colors.white),
                    ),
                    Container(
                      color: AppColors.mainBg,
                      child: SizedBox(
                        width: linesInGraph * baseWidth,
                        height: baseHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: List.generate(
                            freqs[key]!.length,
                            (index) {
                              Widget line = Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: baseWidth,
                                  height: (lineHeight * freqs[key]![index])
                                      .clamp(1.0, lineHeight),
                                  color: AppColors.main1,
                                ),
                              );

                              if (index == freqs[key]!.length - peaksPosition) {
                                line = Container(
                                  width: baseWidth,
                                  height: lineHeight,
                                  color: Colors.white,
                                  child: line,
                                );
                              }

                              return line;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return list;
            }(),
          ],
        ),
      ),
    );
  }
}

class MyTransform implements GradientTransform {
  const MyTransform(this.lineValue);

  final double lineValue;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (lineValue == 0) {
      return Matrix4(
        // column 0
        1.0,
        0.0,
        0.0,
        0.0,
        // column 1
        0.0,
        1.0,
        0.0,
        0.0,
        // column 2
        0.0,
        0.0,
        1.0,
        0.0,
        // column 3
        0.0,
        0.0,
        0.0,
        1.0,
      );
    }
    double val = (baseHeight * (lineValue - 1.0)) / lineValue * 1.625;

    return Matrix4(
      // column 0
      1.0,
      0.0,
      0.0,
      0.0,
      // column 1
      0.0,
      (1.0 / lineValue),
      0.0,
      0.0,
      // column 2
      0.0,
      0.0,
      1.0,
      0.0,
      // column 3
      0.0,
      val,
      0.0,
      1.0,
    );
  }
}
