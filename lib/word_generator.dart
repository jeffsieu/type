import 'dart:math';

enum WordListType {
  top100,
  top1000,
}

class WordGenerator {
  WordGenerator(this.seed, WordListType wordListType)
      : random = Random(seed),
        modulo = wordListType == WordListType.top100 ? 100 : 1000;

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
