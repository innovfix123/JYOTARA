part of 'discovery_screens.dart';

extension _PremiumMatchingEntry on _MatchingScreenState {
  Widget _entry() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 7, 18, 20),
    children: [
      Text(
        local('YOUR CONNECTION', 'உங்கள் இணைப்பு'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: matchGold,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        local('Who’s on your mind?', 'உங்கள் மனதில் யார்?'),
        textAlign: TextAlign.center,
        style: matchHeading(28).copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 7),
      Text(
        local(
          'A little spark. A little discovery.',
          'ஒரு சிறு ஈர்ப்பு. ஒரு புதிய புரிதல்.',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: matchMuted, fontSize: 13),
      ),
      const SizedBox(height: 8),
      MatchingSceneArt(
        type: connectionType,
        key: const Key('matchingSceneArt'),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, bounds) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < matchContexts.length; i++)
              SizedBox(
                width: (bounds.maxWidth - 8) / 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 10,
                    ),
                    backgroundColor: connectionType == matchContexts[i]
                        ? BronzePalette.accent
                        : matchField,
                    foregroundColor: connectionType == matchContexts[i]
                        ? BronzePalette.onAccent
                        : matchInk,
                    side: BorderSide(
                      color: connectionType == matchContexts[i]
                          ? BronzePalette.accent
                          : BronzePalette.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _selectContext(matchContexts[i]),
                  icon: Icon(
                    [
                      Icons.favorite_border,
                      Icons.handshake_outlined,
                      Icons.sentiment_satisfied_alt,
                      Icons.diamond_outlined,
                    ][i],
                    size: 18,
                  ),
                  label: Text(
                    local(
                      matchContexts[i],
                      [
                        'என் விருப்பமானவர்',
                        'என் துணை',
                        'என் நண்பர்',
                        'திருமணம்',
                      ][i],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ListenableBuilder(
        listenable: Listenable.merge([
          profileSession,
          if (boy != null) boy!.session,
          if (girl != null) girl!.session,
        ]),
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final first in [true, false]) ...[
              if (!first) const SizedBox(width: 10),
              Expanded(child: _personCard(first)),
            ],
          ],
        ),
      ),
      if (details(true)?['exactTime'] == false ||
          details(false)?['exactTime'] == false)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            local(
              'Birth time unknown: result is provisional.',
              'பிறந்த நேரம் தெரியாததால் இது தோராயமான முடிவு.',
            ),
            style: const TextStyle(color: matchGold, fontSize: 12),
          ),
        ),
      const SizedBox(height: 7),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        value: consent,
        onChanged: _selectConsent,
        activeColor: BronzePalette.accent,
        checkColor: BronzePalette.onAccent,
        title: Text(
          local(
            'I have permission to use both birth profiles.',
            'இருவரின் பிறப்பு விவரங்களைப் பயன்படுத்த அனுமதி உள்ளது.',
          ),
          style: const TextStyle(fontSize: 12, color: matchMuted),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: UiText(error!),
        ),
      const SizedBox(height: 5),
      FilledButton.icon(
        onPressed: _match,
        icon: const Icon(Icons.north_east, size: 17),
        iconAlignment: IconAlignment.end,
        label: const UiText('See our match'),
      ),
      const SizedBox(height: 9),
      Text(
        local(
          '${coinWalletEnabled ? remoteConfig.cost('matching', 20) : 20} coins per match · 8 chart factors',
          'ஒரு பொருத்தத்திற்கு ${coinWalletEnabled ? remoteConfig.cost('matching', 20) : 20} நாணயங்கள் · 8 காரணிகள்',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: matchMuted, fontSize: 11),
      ),
      const SizedBox(height: 5),
      TextButton.icon(
        onPressed: openHistory,
        icon: const Icon(Icons.bookmark_border, size: 17),
        label: Text(local('Saved matches', 'சேமித்த பொருத்தங்கள்')),
      ),
      if (result != null)
        OutlinedButton(
          onPressed: () => openReport(result!),
          child: Text(local('View last result', 'கடைசி முடிவைப் பார்க்க')),
        ),
    ],
  );

  Widget _personCard(bool first) {
    final rasi = _rasi(first);
    final rasiIndex = SouthIndianChart.signIndex(rasi);
    final name = details(first)?['nickname']?.toString();
    final saved = first ? boy : girl;
    final draft = first ? boyDraft : girlDraft;
    return InkWell(
      key: ValueKey(first ? 'matching-first' : 'matching-second'),
      onTap: () => choosePerson(first),
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: matchField,
          border: Border.all(color: BronzePalette.border),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.edit_outlined, size: 14, color: matchGold),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  RasiEmblem(index: rasiIndex, size: 58),
                  const SizedBox(height: 7),
                  Text(
                    name == null
                        ? local(
                            first ? 'Your profile' : 'Their profile',
                            first ? 'உங்கள் விவரங்கள்' : 'அவரது விவரங்கள்',
                          )
                        : readingLanguage(context) == 'ta'
                        ? tamilDisplayName(name)
                        : name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: matchInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (rasiIndex >= 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${uiText(context, SouthIndianChart.signs[rasiIndex])} ${local('Rasi', 'ராசி')}${details(first)?['exactTime'] == false ? local(' · Approximate', ' · தோராயமானது') : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: matchGold, fontSize: 12),
                    ),
                  ] else if (details(first) != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      draft != null &&
                              _pendingRasi.contains(matchingBirthKey(draft))
                          ? local('Loading Rasi…', 'ராசி பெறப்படுகிறது…')
                          : local('Rasi unavailable', 'ராசி கிடைக்கவில்லை'),
                      key: ValueKey('matching-rasi-status-$first'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: matchMuted, fontSize: 12),
                    ),
                    if (draft != null &&
                        !_pendingRasi.contains(matchingBirthKey(draft)))
                      TextButton(
                        key: ValueKey('matching-rasi-retry-$first'),
                        onPressed: busy || _removingPerson
                            ? null
                            : () => _resolveRasi(draft),
                        child: Text(
                          local('Retry Rasi', 'ராசியை மீண்டும் பெறு'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    local(
                      details(first) == null
                          ? 'Add birth details'
                          : first
                          ? 'Your profile'
                          : 'Their profile',
                      details(first) == null
                          ? 'பிறப்பு விவரங்களைச் சேர்க்கவும்'
                          : first
                          ? 'உங்கள் விவரங்கள்'
                          : 'அவரது விவரங்கள்',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: matchMuted, fontSize: 11),
                  ),
                  if (draft != null ||
                      (saved != null &&
                          saved.id != 'personal' &&
                          !identical(saved.session, profileSession)))
                    TextButton.icon(
                      key: ValueKey(
                        'matching-delete-selected-${first ? 'first' : 'second'}',
                      ),
                      onPressed: _removingPerson
                          ? null
                          : () => draft != null
                                ? _removeDraftPerson(draft)
                                : _removeSavedPerson(saved!),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        foregroundColor: BronzePalette.avoid,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(
                        local('Delete person', 'நபரை நீக்கு'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
