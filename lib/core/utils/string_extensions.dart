extension StringCapitalization on String {
  /// Capitalizes the first letter of each word in a string.
  /// Example: "rachit saraf" -> "Rachit Saraf"
  String toTitleCase() {
    if (trim().isEmpty) return this;
    return trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
