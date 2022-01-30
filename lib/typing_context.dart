import 'dart:math';

import 'package:another_typing_test/word_generator.dart';

class TypedWord {
  const TypedWord.correct(this.value)
      : trailingHint = null,
        isCorrect = true,
        displayedLength = value.length;
  const TypedWord.incorrect(this.value, this.trailingHint)
      : isCorrect = false,
        displayedLength = value.length + (trailingHint?.length ?? 0);

  final String value;
  final String? trailingHint;
  final bool isCorrect;
  final int displayedLength;
}

class TypingContext {
  TypingContext(this.seed, WordListType wordListType)
      : wordGenerator = WordGenerator(seed, wordListType) {
    for (int i = 0; i < wordBufferLength; i++) {
      addWord(wordGenerator.nextWord());
    }
  }

  final WordGenerator wordGenerator;

  final List<String> words = [];
  final Map<int, String> misspelledWords = {};
  final List<int> lineStarts = [];
  static const int maxLineLength = 50;
  static const int maxWordLength = 20;
  static const int wordBufferLength = maxLineLength;
  final int seed;
  String _enteredText = '';

  String get enteredText => _enteredText;
  set enteredText(String value) {
    bool previouslyOvershot = _enteredText.length > currentWord.length;
    bool currentlyOvershot = value.length > currentWord.length;

    if (value.length > maxWordLength) {
      return;
    } else {
      int typedLength = getTypedLine(currentLineIndex)
              .map((w) => w.displayedLength)
              .fold<int>(0, (a, b) => a + b + 1) +
          value.length;
      if (typedLength > maxLineLength) {
        return;
      }
    }
    _enteredText = value;
    if (previouslyOvershot || currentlyOvershot) {
      // If the user has entered a word that is one character off,
      // recalculate remaining words
      lineStarts.removeRange(currentLineIndex + 1, lineStarts.length);
    }
  }

  int get currentLineIndex => _currentLineIndex;

  int _currentLineIndex = 0;
  int _currentWordIndex = 0;

  int get currentWordIndex => _currentWordIndex;

  set currentWordIndex(int value) {
    _currentWordIndex = value;
    int lineStart = getLineStart(currentLineIndex);
    int wordCount = _getWordsInLine(currentLineStart);

    if (currentWordIndex >= lineStart + wordCount) {
      _currentLineIndex++;
    } else if (currentWordIndex < lineStart) {
      _currentLineIndex--;
    }

    if (currentWordIndex + wordBufferLength > lineStarts.length) {
      for (int i = 0; i < wordBufferLength; i++) {
        addWord(wordGenerator.nextWord());
      }
    }
  }

  String get currentWord => words[currentWordIndex];

  List<String> getRemainingWords() {
    int currentLineStart = getLineStart(currentLineIndex);
    assert(
      currentWordIndex >= currentLineStart,
      '$currentWordIndex < $currentLineStart',
    );
    return words
        .skip(currentLineStart)
        .take(_getWordsInLine(currentLineStart))
        .skip(currentWordIndex - currentLineStart)
        .toList();
  }

  String getLine(int lineStart) {
    return words.skip(lineStart).take(_getWordsInLine(lineStart)).join(' ');
  }

  int get currentLineStart => getLineStart(currentLineIndex);

  int _getWordsInLine(int lineStart) {
    int charCount = -1;
    int wordCount = 0;
    while (charCount <= maxLineLength) {
      if (lineStart >= words.length) {
        break;
      }
      int wordIndex = lineStart + wordCount;
      if (wordIndex == currentWordIndex) {
        charCount += max(currentWord.length, enteredText.length) + 1;
      } else {
        charCount += getTypedWord(lineStart + wordCount).displayedLength + 1;
      }
      wordCount++;
    }
    return wordCount - 1;
  }

  String? popWord() {
    if (currentWordIndex > 0) {
      String poppedWord = getTypedWord(currentWordIndex - 1).value;
      currentWordIndex--;
      return poppedWord;
    }
  }

  TypedWord getTypedWord(int wordIndex) {
    // assert(wordIndex <= currentWordIndex);
    String correctWord = words[wordIndex];
    String? misspelledWord = misspelledWords[wordIndex];
    if (misspelledWord != null) {
      String hint =
          correctWord.substring(min(correctWord.length, misspelledWord.length));
      return TypedWord.incorrect(misspelledWord, hint);
    } else {
      return TypedWord.correct(correctWord);
    }
  }

  /// Deletes the previous word. Returns true if a word was deleted.
  bool deleteFullWord() {
    // Delete whole word
    if (enteredText.isNotEmpty) {
      enteredText = '';
      return true;
    } else {
      // Try to delete previous word.
      String? previousWord = popWord();
      if (previousWord != null) {
        return true;
      }
    }
    return false;
  }

  void onSpacePressed() {
    onWordTyped(enteredText);
  }

  bool deleteCharacter() {
    if (enteredText.isNotEmpty) {
      enteredText = enteredText.substring(0, enteredText.length - 1);
      return true;
    } else {
      // Try to pop previous word in line
      String? previousWord = popWord();
      if (previousWord != null) {
        enteredText = previousWord;
        return true;
      }
    }
    return false;
  }

  void onCharacterEntered(String character) {
    enteredText += character;
  }

  int getLineStart(int lineIndex) {
    if (lineIndex < lineStarts.length) {
      return lineStarts[lineIndex];
    } else {
      // Calculate line start
      while (lineIndex >= lineStarts.length) {
        if (lineStarts.isEmpty) {
          lineStarts.add(0);
        } else {
          lineStarts.add(lineStarts.last + _getWordsInLine(lineStarts.last));
        }
      }
      return lineStarts[lineIndex];
    }
  }

  List<TypedWord> getTypedLine(int lineIndex) {
    assert(lineIndex <= currentLineIndex);
    final List<TypedWord> typedWords = [];
    final int lineStart = getLineStart(lineIndex);
    final int lineLength = _getWordsInLine(lineStart);
    for (int i = 0; i < lineLength; i++) {
      if (lineStart + i >= currentWordIndex) {
        break;
      }
      typedWords.add(getTypedWord(lineStart + i));
    }
    return typedWords;
    // String typedLine = typedWords.join(' ');
    // return typedLine.isNotEmpty ? typedLine + ' ' : '';
  }

  double getTypedWordCount() {
    // Calculate the number of words typed
    int correctCharacterCount = 0;
    int incorrectCharacterCount = 0;
    for (int i = 0; i < currentWordIndex; i++) {
      TypedWord typedWord = getTypedWord(i);
      if (typedWord.isCorrect) {
        correctCharacterCount += typedWord.value.length;
      } else {
        incorrectCharacterCount += typedWord.value.length;
      }
    }
    return (correctCharacterCount + 0.2 * incorrectCharacterCount) / 5;
  }

  void addWord(String word) {
    // words.add(word);
    // if ([...lines[lines.length - 1], word].join(' ').length > maxLineLength) {
    //   lines.add([]);
    // }
    // lines[lines.length - 1].add(word);
    words.add(word);
  }

  void onWordTyped(String word) {
    if (currentWord != word) {
      // misspelledWords.putIfAbsent(currentLineIndex, () => {});
      // misspelledWords[currentLineIndex]![currentWordIndex] = word;
      misspelledWords[currentWordIndex] = word;
    } else {
      misspelledWords.remove(currentWordIndex);
    }
    enteredText = '';
    currentWordIndex++;
  }
}
