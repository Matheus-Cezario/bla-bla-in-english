/// Writes a small, hand-authored `dictionary.db` — no API key, no cost.
///
///   dart run tool/seed_sample_dictionary.dart
///
/// This exists so the app is runnable and demoable before anyone spends money
/// on a real generation run. The words are deliberately polysemous: they are
/// the cases where the "near miss" option has something real to be near, which
/// is what `tool/generate_dictionary.dart` has to reproduce at scale.
library;

import 'dart:io';

import 'package:bla_bla_in_english/data/dictionary_assets.dart';

import 'dictionary_content.dart';
import 'write_dictionary.dart';

/// (sentence, correct, near, wrong)
typedef Row = (String, String, String, String);

const Map<String, List<Row>> sample = {
  'book': [
    (
      'She left her #book# open on the kitchen table.',
      'a set of printed pages bound together to be read',
      'a set of blank pages bound together to be written in',
      'a container with a lid, used for carrying tools',
    ),
    (
      'We should #book# the tickets before the price goes up.',
      'to arrange and pay for something in advance',
      'to look up the price of something before buying it',
      'to fold a piece of paper along a straight line',
    ),
    (
      'The restaurant is fully #booked# for Saturday night.',
      'having no places left, because all were reserved',
      'having no places left, because the building is closed',
      'covered in a thin layer of ice',
    ),
    (
      'The referee #booked# two players in the first half.',
      'to officially record a player who broke the rules',
      'to send a player off the field for the rest of the game',
      'to praise someone publicly for good work',
    ),
    (
      'By the #book#, every request needs a written approval.',
      'following the official rules exactly',
      'following the advice of an experienced person',
      'happening once every year at the same time',
    ),
  ],
  'light': [
    (
      'The #light# from the window woke him early.',
      'the brightness that lets us see things',
      'the warmth that comes from the sun',
      'a sudden loud noise that startles someone',
    ),
    (
      'This jacket is #light# enough to carry all day.',
      'not weighing much',
      'not costing much',
      'not lasting very long',
    ),
    (
      'Could you #light# the candles before the guests arrive?',
      'to make something start burning',
      'to move something into a brighter place',
      'to count a group of things one by one',
    ),
    (
      'She wore a #light# blue dress to the ceremony.',
      'pale, closer to white than to black',
      'bright and strong in colour',
      'made of two different materials',
    ),
    (
      'It was a #light# meal, just soup and bread.',
      'small and easy to digest',
      'prepared quickly and without care',
      'served at a very high temperature',
    ),
  ],
  'run': [
    (
      'He tries to #run# five kilometres every morning.',
      'to move quickly on foot, faster than walking',
      'to travel a distance on foot, at any speed',
      'to lie down and rest after physical effort',
    ),
    (
      'She #runs# a small bakery near the station.',
      'to be in charge of a business',
      'to work for a business owned by someone else',
      'to buy goods in order to sell them again',
    ),
    (
      'The engine will not #run# without oil.',
      'to work or operate as intended',
      'to start after several attempts',
      'to make a low continuous sound',
    ),
    (
      'The play had a six-month #run# in London.',
      'a period during which something is performed',
      'a period during which something is prepared',
      'a sudden increase in the price of something',
    ),
    (
      'Tears began to #run# down her face.',
      'to flow steadily in a stream',
      'to appear suddenly and then stop',
      'to dry out and disappear completely',
    ),
  ],
  'bank': [
    (
      'I need to go to the #bank# before it closes.',
      'a business that keeps and lends money',
      'a place where goods are stored before being sold',
      'a building where trains stop to pick up passengers',
    ),
    (
      'They sat on the #bank# and watched the river go by.',
      'the raised ground along the side of a river',
      'a small wooden platform built over water',
      'a wide road that runs beside the sea',
    ),
    (
      'You can #bank# the cheque tomorrow morning.',
      'to put money into an account',
      'to exchange money for a different currency',
      'to write your name at the bottom of a document',
    ),
    (
      'A #bank# of dark cloud moved in from the west.',
      'a large mass of something, gathered together',
      'a thin layer of something spread across a surface',
      'a narrow opening between two tall objects',
    ),
    (
      'Do not #bank# on him arriving on time.',
      'to depend on something happening',
      'to make a guess about something uncertain',
      'to complain about something repeatedly',
    ),
  ],
  'play': [
    (
      'The children #play# in the garden after school.',
      'to do things for enjoyment, with no serious purpose',
      'to take part in an organised sport',
      'to study something outside of normal school hours',
    ),
    (
      'She can #play# the violin surprisingly well.',
      'to produce music with an instrument',
      'to listen to and understand music',
      'to repair a damaged instrument',
    ),
    (
      'We saw a #play# by Shakespeare last night.',
      'a story performed by actors on a stage',
      'a story told in a book, divided into chapters',
      'a piece of music written for an orchestra',
    ),
    (
      'Our team #plays# Liverpool on Sunday.',
      'to compete against someone in a game',
      'to be a member of a particular team',
      'to watch a game without taking part',
    ),
    (
      'There is too much #play# in this steering wheel.',
      'unwanted free movement in a mechanical part',
      'unwanted noise coming from a mechanical part',
      'the effort needed to move something heavy',
    ),
  ],
  'right': [
    (
      'Turn #right# at the end of the street.',
      'towards the side of your body opposite the left',
      'towards the side your writing hand is on, when facing away',
      'towards the point where two roads meet',
    ),
    (
      'Your answer was exactly #right#.',
      'correct, with no mistakes',
      'close to correct, but not exact',
      'given faster than anyone expected',
    ),
    (
      'Everyone has the #right# to a fair trial.',
      'something you are allowed to have by law',
      'something you are expected to do by law',
      'a decision made by a group of judges',
    ),
    (
      'It would not be #right# to take the money.',
      'morally acceptable',
      'legally permitted',
      'financially sensible',
    ),
    (
      'I will be #right# back.',
      'immediately, without delay',
      'probably, but not certainly',
      'quietly, without being noticed',
    ),
  ],
};

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : dictionaryAssetPath;

  var rank = 0;
  final entries = [
    for (final entry in sample.entries)
      WordEntry(
        word: entry.key,
        frequencyRank: ++rank,
        sentences: [
          for (final (text, correct, near, wrong) in entry.value)
            GeneratedSentence(
              text: text,
              correct: correct,
              near: near,
              wrong: wrong,
            ),
        ],
      ),
  ];

  // The seed is hand-written, but it has to satisfy exactly the same contract
  // as generated content — otherwise it would hide bugs the real data hits.
  for (final entry in entries) {
    final problems = entry.validate();
    if (problems.isNotEmpty) {
      stderr.writeln('Sample word "${entry.word}" is invalid: '
          '${problems.join('; ')}');
      exit(1);
    }
  }

  writeDictionary(entries, path);
}
