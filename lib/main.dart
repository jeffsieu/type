import 'dart:async';
import 'dart:math';

import 'package:another_typing_test/input_listener.dart';
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
    data.split('\n').map((word) => word.trim()).toList(),
  );
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
      ).copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const Duration testDuration = Duration(seconds: 30);
  static const Duration timerTick = Duration(seconds: 1);
  static const Duration cursorFadeDuration = Duration(milliseconds: 750);

  final FocusNode focusNode = FocusNode();
  late final AnimationController cursorAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // Settings
  WordListType wordListType = WordListType.top200;

  // Test-specific variables
  late int seed = 0;
  late TypingContext typingContext = TypingContext(seed, wordListType);
  String? timeLeft;
  int? wpm;
  Timer? timer;
  Timer? cursorResetTimer;
  bool isTestEnabled = true;

  @override
  void initState() {
    super.initState();
    cursorAnimation.repeat(reverse: true);
    refreshTypingContext();
  }

  @override
  void dispose() {
    cursorAnimation.dispose();
    super.dispose();
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

  void resetCursor() {
    cursorAnimation.value = 1;
    cursorResetTimer?.cancel();
    cursorResetTimer = Timer(cursorFadeDuration, () {
      cursorAnimation.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentWordWrong =
        !typingContext.currentWord.startsWith(typingContext.enteredText);
    return InputListener(
      focusNode: focusNode,
      enabled: isTestEnabled,
      onSpacePressed: () {
        setState(() {
          typingContext.onSpacePressed();
          resetCursor();
        });
      },
      onCtrlBackspacePressed: () {
        if (typingContext.deleteFullWord()) {
          setState(() {
            resetCursor();
          });
        }
      },
      onBackspacePressed: () {
        if (typingContext.deleteCharacter()) {
          setState(() {
            resetCursor();
          });
        }
      },
      onCharacterInput: (String character) {
        if (timer == null) startTimer();
        setState(() {
          typingContext.onCharacterEntered(character);
          resetCursor();
        });
      },
      child: Scaffold(
        body: Center(
          child: FittedBox(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
                  child: Text(
                    '.' * TypingContext.maxLineLength,
                    style: Theme.of(context)
                        .textTheme
                        .headline4
                        ?.copyWith(color: Colors.transparent),
                  ),
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
                          wpm != null ? '$wpm WPM' : 'another typing test',
                        ),
                        secondChild: _buildTitle(timeLeft ?? ''),
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: timeLeft == null
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          label: const Text('Restart (tab + enter)'),
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            setState(() {
                              refreshTypingContext();
                            });
                          },
                        ),
                        OutlinedButton.icon(
                          label: Text('Top ${wordListType.count} words'),
                          icon: const Icon(Icons.notes),
                          onPressed: () {
                            setState(() {
                              wordListType = wordListType.next;
                              refreshTypingContext();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: const Interval(0.0, 0.5),
                          switchOutCurve: const Interval(0.5, 1.0),
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                              alignment: Alignment.topLeft,
                            );
                          },
                          child: Column(
                            key: ValueKey(seed),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (typingContext.currentLineIndex > 0) ...{
                                buildLine(typingContext.currentLineIndex - 1),
                              },
                              buildCurrentLine(isCurrentWordWrong),
                              buildLineAtOffset(1),
                              if (typingContext.currentLineIndex == 0)
                                buildLineAtOffset(2),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: isTestEnabled ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Test completed',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headline4
                                      ?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget buildCurrentLine(bool isCurrentWordWrong) {
    final remainingWords = typingContext.getRemainingWords();
    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
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
              AnimatedBuilder(
                animation: cursorAnimation
                    .drive(CurveTween(curve: Curves.easeInOutQuint)),
                builder: (context, child) {
                  return Opacity(
                    opacity: cursorAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 4,
                  color: ThemeColors.yellow,
                ),
              ),
            ],
          ),
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
                    text: remainingWords.first.substring(
                      min(
                        typingContext.enteredText.length,
                        remainingWords.first.length,
                      ),
                    ),
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
