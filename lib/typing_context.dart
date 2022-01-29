import 'dart:math';

class TypedWord {
  const TypedWord.correct(this.value)
      : trailingHint = null,
        isCorrect = true;
  const TypedWord.incorrect(this.value, this.trailingHint) : isCorrect = false;

  final String value;
  final String? trailingHint;
  final bool isCorrect;
}

class TypingContext {
  final List<String> words = [];
  final List<List<String>> lines = [[]];
  final Map<int, Map<int, String>> misspelledWords = {};
  final int maxLineLength = 20;
  int currentLineIndex = 0;
  // int currentIndex = 0;
  int currentWordIndex = 0;

  String get currentWord => lines[currentLineIndex][currentWordIndex];
  // String get currentLine => lines[currentLineIndex];
  String get remainingWords =>
      lines[currentLineIndex].skip(currentWordIndex).join(' ');

  String? popWord() {
    if (currentWordIndex > 0) {
      // There is a word on the current line.
      String poppedWord =
          getTypedWord(currentLineIndex, currentWordIndex - 1).value;
      currentWordIndex--;
      return poppedWord;
    } else {
      // Try to pop a word from the previous line.
      if (currentLineIndex > 0) {
        currentLineIndex--;
        currentWordIndex = lines[currentLineIndex].length;
        return popWord();
      } else {
        return null;
      }
    }
  }

  TypedWord getTypedWord(int lineIndex, int wordIndex) {
    assert(lineIndex < currentLineIndex || wordIndex <= currentWordIndex);
    String correctWord = lines[lineIndex][wordIndex];
    String? misspelledWord = misspelledWords[lineIndex]?[wordIndex];
    if (misspelledWord != null) {
      String hint =
          correctWord.substring(min(correctWord.length, misspelledWord.length));
      return TypedWord.incorrect(misspelledWord, hint);
    } else {
      return TypedWord.correct(correctWord);
    }
  }

  List<TypedWord> getTypedLine(int lineIndex) {
    assert(lineIndex <= currentLineIndex);
    final List<TypedWord> typedWords = [];
    final int lineLength = lines[lineIndex].length;
    for (int i = 0; i < lineLength; i++) {
      if (lineIndex == currentLineIndex && i >= currentWordIndex) {
        break;
      }
      typedWords.add(getTypedWord(lineIndex, i));
    }
    return typedWords;
    // String typedLine = typedWords.join(' ');
    // return typedLine.isNotEmpty ? typedLine + ' ' : '';
  }

  void addWord(String word) {
    // words.add(word);
    if ([...lines[lines.length - 1], word].join(' ').length > maxLineLength) {
      lines.add([]);
    }
    lines[lines.length - 1].add(word);
  }

  void onWordTyped(String word) {
    if (currentWord != word) {
      misspelledWords.putIfAbsent(currentLineIndex, () => {});
      misspelledWords[currentLineIndex]![currentWordIndex] = word;
    } else {
      misspelledWords[currentLineIndex]?.remove(currentWordIndex);
    }
    currentWordIndex++;
    if (currentWordIndex >= lines[currentLineIndex].length) {
      currentLineIndex++;
      currentWordIndex = 0;
    }
  }
}
