import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:another_typing_test/theme_colors.dart';
import 'package:another_typing_test/typing_context.dart';
import 'package:another_typing_test/word_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String data = await loadWordList();
  WordGenerator.initializeWordList(
      data.split('\n').map((word) => word.trim()).toList());
  runApp(const MyApp());
}

Future<String> loadWordList() async {
  return await rootBundle.loadString('assets/words.txt');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'another typing test',
      theme: ThemeData.from(
        colorScheme: const ColorScheme.dark(
          background: Color(0xFF222244),
        ),
        textTheme: GoogleFonts.robotoMonoTextTheme(),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late int seed = 0;
  late TypingContext typingContext = TypingContext(seed, wordListType);
  final FocusNode focusNode = FocusNode();
  WordListType wordListType = WordListType.top100;
  static const Duration testDuration = Duration(seconds: 30);
  static const Duration timerTick = Duration(seconds: 1);
  String? timeLeft;
  int? wpm;
  Timer? timer;
  bool isTestEnabled = true;

  @override
  void initState() {
    super.initState();
    refreshTypingContext();
  }

  void refreshTypingContext() {
    seed = Random().nextInt(1 << 32 - 1);
    typingContext = TypingContext(seed, wordListType);
    timer?.cancel();
    timer = null;
    timeLeft = null;
    isTestEnabled = true;
  }

  void startTimer() {
    timer = Timer.periodic(timerTick, (timer) => onTimerUpdate(timer));
    onTimerUpdate(timer!);
  }

  void onTimerUpdate(Timer timer) {
    setState(() {
      int timeLeftSeconds = (testDuration - timerTick * timer.tick).inSeconds;
      timeLeft = timeLeftSeconds.toString();
      if (timeLeftSeconds <= 0) {
        wpm = (typingContext.getTypedWordCount() / testDuration.inSeconds * 60)
            .round();
        timer.cancel();
        this.timer = null;
        timeLeft = null;
        isTestEnabled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentWordWrong =
        !typingContext.currentWord.startsWith(typingContext.enteredText);
    return RawKeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKey: (event) {
        if (isTestEnabled) {
          bool isCtrlPressed =
              Theme.of(context).platform == TargetPlatform.macOS
                  ? event.isAltPressed
                  : event.isControlPressed;
          if (event is RawKeyUpEvent) {
            return;
          }

          if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (typingContext.deleteFullWord()) {
              setState(() {});
            }
          }

          // Ignore if this is a modifier key
          if (event.isAltPressed ||
              event.isControlPressed ||
              event.isMetaPressed) {
            return;
          }

          if (event.logicalKey == LogicalKeyboardKey.space) {
            setState(() {
              typingContext.onSpacePressed();
            });
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (typingContext.deleteCharacter()) {
              setState(() {});
            }
          } else if (event.character != null) {
            if (timer == null) startTimer();
            setState(() {
              typingContext.onCharacterEntered(event.character!);
            });
          }

          focusNode.requestFocus();
        }
      },
      child: Scaffold(
        body: Center(
          child: FittedBox(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
                  child: Text('.' * TypingContext.maxLineLength,
                      style: Theme.of(context)
                          .textTheme
                          .headline4
                          ?.copyWith(color: Colors.transparent)),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8.0),
                      child: AnimatedCrossFade(
                        sizeCurve: Curves.easeOutQuad,
                        firstChild: _buildTitle(
                            wpm != null ? '$wpm WPM' : 'another typing test'),
                        secondChild: _buildTitle(timeLeft ?? ''),
                        duration: Duration(milliseconds: 300),
                        crossFadeState: timeLeft == null
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          label: const Text('Restart (tab + enter)'),
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            setState(() {
                              refreshTypingContext();
                            });
                          },
                        ),
                        TextButton.icon(
                          label: Text(wordListType == WordListType.top100
                              ? 'Top 100 words'
                              : 'Top 1000 words'),
                          icon: const Icon(Icons.notes),
                          onPressed: () {
                            setState(() {
                              if (wordListType == WordListType.top100) {
                                wordListType = WordListType.top1000;
                                refreshTypingContext();
                              } else {
                                wordListType = WordListType.top100;
                                refreshTypingContext();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (typingContext.currentLineIndex > 0) ...{
                              buildLine(typingContext.currentLineIndex - 1),
                            },
                            buildCurrentLine(context, isCurrentWordWrong),
                            buildLineAtOffset(1),
                            if (typingContext.currentLineIndex == 0)
                              buildLineAtOffset(2),
                          ],
                        ),
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: isTestEnabled ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Test completed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline4
                                        ?.copyWith(
                                            color:
                                                Theme.of(context).hintColor)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Text _buildTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headline5?.copyWith(
            color: ThemeColors.green,
          ),
    );
  }

  Widget buildLineAtOffset(int offset) {
    final nextLineStart =
        typingContext.getLineStart(typingContext.currentLineIndex + offset);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
      child: Text(
        typingContext.getLine(nextLineStart),
        style: Theme.of(context)
            .textTheme
            .headline4
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }

  Widget buildLine(int lineIndex) {
    List<TypedWord> typedWords = typingContext.getTypedLine(lineIndex);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
      child: RichText(
        text: TextSpan(
          children: [
            for (TypedWord typedWord in typedWords) ...{
              TextSpan(
                text: typedWord.value,
                style: TextStyle(
                  color:
                      typedWord.isCorrect ? ThemeColors.green : ThemeColors.red,
                ),
              ),
              if (typedWord.trailingHint != null) ...{
                TextSpan(
                  text: typedWord.trailingHint,
                  style: TextStyle(
                    color: Colors.red[200],
                  ),
                ),
              },
              if (typedWord != typedWords.last)
                TextSpan(
                  text: ' ',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  ),
                ),
            },
          ],
          style: Theme.of(context).textTheme.headline4,
        ),
      ),
    );
  }

  Stack buildCurrentLine(BuildContext context, bool isCurrentWordWrong) {
    final remainingWords = typingContext.getRemainingWords();
    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: RichText(
                text: TextSpan(
                  children: [
                    for (TypedWord typedWord in typingContext
                        .getTypedLine(typingContext.currentLineIndex)) ...{
                      TextSpan(
                        text: typedWord.value,
                      ),
                      if (typedWord.trailingHint != null) ...{
                        TextSpan(
                          text: typedWord.trailingHint,
                        ),
                      },
                      const TextSpan(
                        text: ' ',
                      ),
                    },
                    TextSpan(
                      text: typingContext.enteredText,
                    ),
                  ],
                  style: Theme.of(context)
                      .textTheme
                      .headline4
                      ?.copyWith(color: Colors.transparent),
                ),
              ),
            ),
            Text(
              '|',
              style: Theme.of(context)
                  .textTheme
                  .headline4
                  ?.copyWith(color: const Color(0xFFFAD000)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
          child: RichText(
            text: TextSpan(
              children: [
                for (TypedWord typedWord in typingContext
                    .getTypedLine(typingContext.currentLineIndex)) ...{
                  TextSpan(
                    text: typedWord.value,
                    style: TextStyle(
                      color: typedWord.isCorrect
                          ? ThemeColors.green
                          : ThemeColors.red,
                    ),
                  ),
                  if (typedWord.trailingHint != null) ...{
                    TextSpan(
                      text: typedWord.trailingHint,
                      style: TextStyle(
                        color: Colors.red[200],
                      ),
                    ),
                  },
                  TextSpan(
                    text: ' ',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                },
                TextSpan(
                  text: typingContext.enteredText,
                  style: TextStyle(
                    color: isCurrentWordWrong
                        ? ThemeColors.red
                        : ThemeColors.green,
                  ),
                ),
                if (remainingWords.isNotEmpty)
                  TextSpan(
                    text: remainingWords.first.substring(min(
                        typingContext.enteredText.length,
                        remainingWords.first.length)),
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                if (remainingWords.length > 1)
                  TextSpan(
                    text: ' ' + remainingWords.skip(1).join(' '),
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
              ],
              style: Theme.of(context).textTheme.headline4,
            ),
          ),
        ),
      ],
    );
  }
}
