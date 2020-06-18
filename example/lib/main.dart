import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:polygon_clipper/polygon_clipper.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  bool _hasSpeech = false;
  bool _animationNotTriggeredYet = true;
  bool _wasAnimationStopped = false;
  bool dontEnterHereAgain = true;
  bool drawCustomShape = false;
  int sides = 3;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String lastWordStack = "";
  String _currentLocaleId = "";
  Color backgroundColor = Colors.orange[100];
  Color logoColor = Colors.blue;
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();
  AnimationController _animationController;
  int numberOfDuplicates = 0;
  List<Widget> duplicates = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 5000,
      ),
    );

    _animationController.addStatusListener(
      (status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(
      onError: errorListener,
      onStatus: statusListener,
      debugLogging: true,
    );
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale.localeId;
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Speech to Text Canvas',
          ),
        ),
        body: Column(
          children: [
            Container(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      FlatButton(
                        child: Text('Initialize'),
                        onPressed: _hasSpeech ? null : initSpeechState,
                      ),
                    ],
                  ),
                  ActionButtons(
                    hasSpeech: _hasSpeech,
                    speech: speech,
                    startListening: startListening,
                    stopListening: stopListening,
                    cancelListening: cancelListening,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      DropdownButton(
                        onChanged: (selectedVal) => _switchLang(
                          selectedVal,
                        ),
                        value: _currentLocaleId,
                        items: _localeNames
                            .map(
                              (localeName) => DropdownMenuItem(
                                value: localeName.localeId,
                                child: Text(
                                  localeName.name,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              flex: 8,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        LastWords(
                          backgroundColor: backgroundColor,
                          lastWords: lastWords,
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: 64.0,
                            ),
                            child: AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                var lastLastWords = lastWordStack.toLowerCase();
                                var finalChild = child;
                                finalChild = _duplicate(
                                  lastLastWords,
                                  finalChild,
                                );
                                finalChild = _translate(
                                  lastLastWords,
                                  finalChild,
                                  context,
                                );
                                finalChild = _rotate(
                                  lastLastWords,
                                  finalChild,
                                );
                                finalChild = _scale(
                                  lastLastWords,
                                  finalChild,
                                );
                                _stop(
                                  lastLastWords,
                                );
                                _continue(
                                  lastLastWords,
                                );
                                if (lastLastWords.contains('reset') ||
                                    lastLastWords.contains('reiniciar')) {
                                  lastWordStack = "";
                                  _animationController.reset();
                                  _animationNotTriggeredYet = true;
                                  _wasAnimationStopped = false;
                                  numberOfDuplicates = 0;
                                  SchedulerBinding.instance
                                      .addPostFrameCallback((_) {
                                    setState(() {
                                      backgroundColor = Colors.orange[100];
                                      logoColor = Colors.blue;
                                      drawCustomShape = false;
                                      sides = 3;
                                    });
                                  });
                                  return child;
                                }
                                return finalChild;
                              },
                              child: drawCustomShape
                                  ? SizedBox(
                                      height: 125,
                                      width: 125,
                                      child: ClipPolygon(
                                        sides: sides,
                                        borderRadius: 3.0,
                                        child: Container(
                                          color: logoColor,
                                        ),
                                      ),
                                    )
                                  : FlutterLogo(
                                      colors: logoColor,
                                      size: 150,
                                    ),
                            ),
                          ),
                        ),
                        MicrophoneIcon(
                          level: level,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ErrorStatus(
              lastError: lastError,
            ),
            ListeningStatus(
              speech: speech,
            ),
          ],
        ),
      ),
    );
  }

  void _continue(String lastLastWords) {
    if (lastLastWords.contains('continue') ||
        lastLastWords.contains('continuar')) {
      lastWordStack.replaceAll(
        'continue',
        '',
      );
      lastWordStack.replaceAll(
        'continuar',
        '',
      );
      if (_wasAnimationStopped == true) {
        _animationNotTriggeredYet = true;
        _wasAnimationStopped = false;
        _animationController.forward();
        //TODO Animation gets frozen(?)
      }
    }
  }

  void _stop(String lastLastWords) {
    if (lastLastWords.contains('stop') || lastLastWords.contains('parar')) {
      lastWordStack.replaceAll('stop', '');
      lastWordStack.replaceAll('parar', '');
      if (_animationNotTriggeredYet == false) {
        _wasAnimationStopped = true;
        _animationController.stop();
      }
    }
  }

  Widget _scale(String lastLastWords, Widget finalChild) {
    if (lastLastWords.contains('scale') || lastLastWords.contains('escalar')) {
      finalChild = Transform.scale(
        scale: _animationController.value + 0.1,
        child: finalChild,
      );
      lastWordStack.replaceAll('scale', '');
      lastWordStack.replaceAll('escalar', '');
      if (_animationNotTriggeredYet == true) {
        _animationNotTriggeredYet = false;
        _animationController.forward();
      }
    }
    return finalChild;
  }

  Widget _rotate(String lastLastWords, Widget finalChild) {
    if (lastLastWords.contains('rotate') || lastLastWords.contains('rodar')) {
      finalChild = Transform.rotate(
        angle: _animationController.value * 2 * math.pi,
        child: finalChild,
      );
      lastWordStack.replaceAll('rotate', '');
      lastWordStack.replaceAll('rodar', '');
      if (_animationNotTriggeredYet == true) {
        _animationNotTriggeredYet = false;
        _animationController.forward();
      }
    }
    return finalChild;
  }

  Widget _translate(
      String lastLastWords, Widget finalChild, BuildContext context) {
    if (lastLastWords.contains('translate') ||
        lastLastWords.contains('mover')) {
      finalChild = Transform.translate(
        offset: Offset.lerp(
          Offset(
            0,
            10,
          ),
          Offset(
            MediaQuery.of(context).size.width / 2,
            10,
          ),
          lastLastWords.contains('right') || lastLastWords.contains('direita')
              ? _animationController.value
              : -_animationController.value,
        ),
        child: finalChild,
      );
      lastWordStack.replaceAll('translate', '');
      lastWordStack.replaceAll('mover', '');
      if (_animationNotTriggeredYet == true) {
        _animationNotTriggeredYet = false;
        _animationController.forward();
      }
    }
    return finalChild;
  }

  Widget _duplicate(String lastLastWords, Widget finalChild) {
    if (lastLastWords.contains('copy') || lastLastWords.contains('duplicar')) {
      if (numberOfDuplicates == 1) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 2) {
        finalChild = Wrap(
          children: [finalChild, finalChild, finalChild],
        );
      } else if (numberOfDuplicates == 3) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 4) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 5) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 6) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 7) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      } else if (numberOfDuplicates == 8) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild
          ],
        );
      } else if (numberOfDuplicates == 9) {
        finalChild = Wrap(
          children: [
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
            finalChild,
          ],
        );
      }
    }
    lastLastWords.replaceAll('copy', '');
    lastLastWords.replaceAll('duplicar', '');
    return finalChild;
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(
      onResult: resultListener,
      listenFor: Duration(seconds: 20),
      localeId: _currentLocaleId,
      onSoundLevelChange: soundLevelListener,
      cancelOnError: true,
      partialResults: false,
    );
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      lastWords =
          "${result.recognizedWords} - ${result.finalResult}".toLowerCase();

      _checkDuplicate();
      _backgroundColor();
      _shapeColor();
      _drawCustomShape(result.recognizedWords.toLowerCase());
      lastWordStack += result.recognizedWords;
    });
  }

  void _drawCustomShape(String words) {
    final triangle = words.contains('triangle') || words.contains('triângulo');
    final square = words.contains('square') || words.contains('quadrado');
    final pentagon = words.contains('pentagon') || words.contains('pentágono');
    final hexagon = words.contains('hexagon') || words.contains('hexágono');
    final heptagon = words.contains('heptagon') || words.contains('heptágono');
    final octagon = words.contains('octagon') || words.contains('octágono');
    final nonagon = words.contains('nonagon') || words.contains('nonágono');
    final decagon = words.contains('decagon') || words.contains('decágono');
    final hendecagon =
        words.contains('hendecagon') || words.contains('hendecágono');
    final dodecagon =
        words.contains('dodecagon') || words.contains('dodecágono');
    if (triangle ||
        square ||
        pentagon ||
        hexagon ||
        heptagon ||
        octagon ||
        nonagon ||
        decagon ||
        hendecagon ||
        dodecagon) {
      drawCustomShape = true;
    }
    switch (words) {
      case 'triangle':
        sides = 3;
        break;
      case 'triângulo':
        sides = 3;
        break;
      case 'square':
        sides = 4;
        break;
      case 'quadrado':
        sides = 4;
        break;
      case 'pentagon':
        sides = 5;
        break;
      case 'pentágono':
        sides = 5;
        break;
      case 'hexagon':
        sides = 6;
        break;
      case 'hexágono':
        sides = 6;
        break;
      case 'heptagon':
        sides = 7;
        break;
      case 'heptágono':
        sides = 7;
        break;
      case 'octagon':
        sides = 8;
        break;
      case 'octágono':
        sides = 8;
        break;
      case 'nonagon':
        sides = 9;
        break;
      case 'nonágono':
        sides = 9;
        break;
      case 'decagon':
        sides = 10;
        break;
      case 'decágono':
        sides = 10;
        break;
      case 'hendecagon':
        sides = 11;
        break;
      case 'hendecágono':
        sides = 11;
        break;
      case 'dodecagon':
        sides = 12;
        break;
      case 'dodecágono':
        sides = 12;
        break;
      default:
        sides = sides;
    }
  }

  void _shapeColor() {
    if (lastWords.contains('shape color') || lastWords.contains('cor figura')) {
      if (lastWords.contains('pink') || lastWords.contains('rosa'))
        logoColor = Colors.pink;
      if (lastWords.contains('blue') || lastWords.contains('azul'))
        logoColor = Colors.blue;
      if (lastWords.contains('green') || lastWords.contains('verde'))
        logoColor = Colors.green;
      if (lastWords.contains('red') || lastWords.contains('vermelho'))
        logoColor = Colors.red;
    }
  }

  void _backgroundColor() {
    if (lastWords.contains('cor de fundo') ||
        lastWords.contains('background color')) {
      if (lastWords.contains('pink') || lastWords.contains('rosa'))
        backgroundColor = Colors.pink[100];
      if (lastWords.contains('blue') || lastWords.contains('azul'))
        backgroundColor = Colors.lightBlue[100];
      if (lastWords.contains('green') || lastWords.contains('verde'))
        backgroundColor = Colors.lightGreen[100];
      if (lastWords.contains('red') || lastWords.contains('red'))
        backgroundColor = Colors.red[200];
    }
  }

  void _checkDuplicate() {
    if (lastWords.contains('copy') || lastWords.contains('duplicar')) {
      numberOfDuplicates++;
    }
  }

  void soundLevelListener(double level) {
    minSoundLevel = math.min(minSoundLevel, level);
    maxSoundLevel = math.max(maxSoundLevel, level);
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }

  void statusListener(String status) {
    setState(() {
      lastStatus = "$status";
    });
  }

  _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }
}

// FOR PAINTING POLYGONS
class ShapePainter extends CustomPainter {
  final double sides;
  final double radius;
  final double radians;
  final Color color;
  ShapePainter({
    @required this.sides,
    @required this.radius,
    @required this.radians,
    @required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var path = Path();

    var angle = (math.pi * 2) / sides;

    Offset center = Offset(
      size.width / 2,
      size.height / 2,
    );
    Offset startPoint = Offset(
      math.cos(radians) * 5,
      math.sin(radians) * 10,
    );

    path.moveTo(
      startPoint.dx + center.dx,
      startPoint.dy + center.dy,
    );

    for (int i = 1; i <= sides; i++) {
      double x = radius * math.cos(radians + angle * i) + center.dx;
      double y = radius * math.sin(radians + angle * i) + center.dy;
      path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class ActionButtons extends StatelessWidget {
  const ActionButtons({
    Key key,
    @required bool hasSpeech,
    @required this.speech,
    @required this.startListening,
    @required this.cancelListening,
    @required this.stopListening,
  })  : _hasSpeech = hasSpeech,
        super(key: key);

  final bool _hasSpeech;
  final SpeechToText speech;
  final VoidCallback startListening, stopListening, cancelListening;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        FlatButton(
          child: Text('Start'),
          onPressed: !_hasSpeech || speech.isListening ? null : startListening,
        ),
        FlatButton(
          child: Text('Stop'),
          onPressed: speech.isListening ? stopListening : null,
        ),
        FlatButton(
          child: Text('Cancel'),
          onPressed: speech.isListening ? cancelListening : null,
        ),
      ],
    );
  }
}

class LastWords extends StatelessWidget {
  const LastWords({
    Key key,
    @required this.backgroundColor,
    @required this.lastWords,
  }) : super(key: key);

  final Color backgroundColor;
  final String lastWords;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      color: backgroundColor,
      child: Text(
        lastWords,
      ),
    );
  }
}

class ListeningStatus extends StatelessWidget {
  const ListeningStatus({
    Key key,
    @required this.speech,
  }) : super(key: key);

  final SpeechToText speech;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      color: Theme.of(context).backgroundColor,
      child: Center(
        child: speech.isListening
            ? Text(
                "I'm listening...",
                style: TextStyle(fontWeight: FontWeight.bold),
              )
            : Text(
                'Not listening',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

class ErrorStatus extends StatelessWidget {
  const ErrorStatus({
    Key key,
    @required this.lastError,
  }) : super(key: key);

  final String lastError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(
        8.0,
      ),
      child: Text(
        'Error Status $lastError',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class MicrophoneIcon extends StatelessWidget {
  const MicrophoneIcon({
    Key key,
    @required this.level,
  }) : super(key: key);

  final double level;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      bottom: 30,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                blurRadius: .26,
                spreadRadius: level * 1.5,
                color: Colors.black.withOpacity(
                  .05,
                ),
              )
            ],
            color: Colors.white,
            borderRadius: BorderRadius.all(
              Radius.circular(
                50,
              ),
            ),
          ),
          child: Icon(
            Icons.mic,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
