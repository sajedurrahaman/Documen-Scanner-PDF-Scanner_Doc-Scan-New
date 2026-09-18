class Language{
  final int id;
  final String name;
  final String languageCode;

  Language(this.id, this.name, this.languageCode);

  static List<Language> languageList() {
    return <Language>[
      Language(1, 'Arabic', 'ar'),
      Language(2, 'Bengali', 'bn'),
      Language(3, 'Chinese', 'zh'),
      Language(4, 'English', 'en'),
      Language(5, 'French', 'fr'),
      Language(6, 'Hindi', 'hi'),
      Language(7, 'Indonesian', 'id'),
      Language(8, 'Japanese', 'ja'),
      Language(9, 'Korean', 'ko'),
      Language(10, 'Russian', 'ru'),
      Language(11, 'Spanish', 'es'),
      Language(12, 'Turkiye', 'tr'),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Language && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
