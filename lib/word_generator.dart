import 'dart:math';

enum WordListType {
  top100,
  top200,
  top500,
  top1000,
}

extension NextWordListType on WordListType {
  WordListType get next {
    switch (this) {
      case WordListType.top100:
        return WordListType.top200;
      case WordListType.top200:
        return WordListType.top500;
      case WordListType.top500:
        return WordListType.top1000;
      case WordListType.top1000:
        return WordListType.top100;
    }
  }

  int get count {
    switch (this) {
      case WordListType.top100:
        return 100;
      case WordListType.top200:
        return 200;
      case WordListType.top500:
        return 500;
      case WordListType.top1000:
        return 1000;
    }
  }
}

class WordGenerator {
  WordGenerator(this.seed, WordListType wordListType)
      : random = Random(seed),
        modulo = wordListType.count;

  final int seed;
  final Random random;
  final int modulo;

  static List<String> _words = [];

  static void initializeWordList(List<String> words) {
    WordGenerator._words = List.from(words);
  }

  String nextWord() {
    final index = random.nextInt(modulo);
    return WordGenerator._words[index];
  }
}
