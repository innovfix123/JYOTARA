String publicReadingText(String text) => text
    .replaceAll(RegExp('prokerala', caseSensitive: false), 'Jyotara')
    .replaceAll('புரோகேரளா', 'ஜோதாரா');
