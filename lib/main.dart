import 'dart:math';
import 'dart:io' show Platform;

import 'package:another_typing_test/theme_colors.dart';
import 'package:another_typing_test/typing_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.from(
        colorScheme: ColorScheme.dark(
          background: Color(0xFF222244),
        ),
        // primarySwatch: Colors.orange,
        // // Use monospace font
        // fontFamily: 'Roboto Mono',
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

class WordGenerator {
  final List<String> words = [
    'apple',
    'banana',
    'cherry',
    'durian',
    'elderberry',
    'fig',
    'grape',
    'honeydew',
    'jackfruit',
    'kiwi',
    'lemon',
    'mango',
    'nectarine',
    'orange',
    'papaya',
    'quince',
    'raspberry',
    'strawberry',
    'tangerine',
    'watermelon',
  ];

  static String nextWord() {
    final random = Random();
    final index = random.nextInt(WordGenerator().words.length);
    return WordGenerator().words[index];
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final TypingContext typingContext = TypingContext();
  final FocusNode focusNode = FocusNode();
  final TextEditingController controller = TextEditingController();
  String enteredText = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 100; i++) {
      typingContext.addWord(WordGenerator.nextWord());
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentWordWrong =
        !typingContext.currentWord.startsWith(enteredText);
    return RawKeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKey: (event) {
        bool isCtrlPressed = Theme.of(context).platform == TargetPlatform.macOS
            ? event.isAltPressed
            : event.isControlPressed;
        if (event is RawKeyUpEvent) {
          return;
        }

        if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.backspace) {
          // Delete whole word

          if (enteredText.isNotEmpty) {
            setState(() {
              enteredText = '';
            });
          } else {
            // Try to delete previous word.
            String? previousWord = typingContext.popWord();
            if (previousWord != null) {
              setState(() {});
            }
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
            typingContext.onWordTyped(enteredText);
            enteredText = '';
          });
        } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
          if (enteredText.isNotEmpty) {
            setState(() {
              enteredText = enteredText.substring(0, enteredText.length - 1);
            });
          } else {
            // Try to pop previous word in line
            String? previousWord = typingContext.popWord();
            if (previousWord != null) {
              setState(() {
                enteredText = previousWord;
              });
            }
          }
        } else if (event.character != null) {
          setState(() {
            enteredText += event.character!.toLowerCase();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (typingContext.currentLineIndex > 0) ...{
                buildLine(typingContext.currentLineIndex - 1),
              },
              buildCurrentLine(context, isCurrentWordWrong),
              buildNextLine(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNextLine() {
    return Text(
      typingContext.lines[typingContext.currentLineIndex + 1].join(' '),
      style: TextStyle(fontSize: 50, color: Theme.of(context).hintColor),
    );
  }

  Widget buildLine(int lineIndex) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 20),
      child: RichText(
        text: TextSpan(
          children: [
            for (TypedWord typedWord
                in typingContext.getTypedLine(lineIndex)) ...{
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
              TextSpan(
                text: ' ',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                ),
              ),
            },
          ],
          style: TextStyle(fontSize: 50),
        ),
      ),
    );
  }

  Stack buildCurrentLine(BuildContext context, bool isCurrentWordWrong) {
    return Stack(
      alignment: Alignment.centerLeft,
      // mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: RichText(
                text: TextSpan(
                  children: [
                    for (TypedWord typedWord in typingContext
                        .getTypedLine(typingContext.currentLineIndex)) ...{
                      TextSpan(
                        text: typedWord.value + (typedWord.trailingHint ?? ' '),
                      ),
                    },
                    TextSpan(
                      text: enteredText,
                    ),
                  ],
                  style: TextStyle(fontSize: 50, color: Colors.transparent),
                ),
              ),
            ),
            Text(
              '|',
              style: TextStyle(fontSize: 50, color: Color(0xFFFAD000)),
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
                  text: enteredText,
                  style: TextStyle(
                    color: isCurrentWordWrong
                        ? ThemeColors.red
                        : ThemeColors.green,
                  ),
                ),
                TextSpan(
                  text: typingContext.remainingWords.substring(min(
                      enteredText.length, typingContext.remainingWords.length)),
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
              style: TextStyle(fontSize: 50),
            ),
          ),
        ),
      ],
    );
  }
}
