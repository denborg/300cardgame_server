import 'package:card300_server/helpers/card_data.dart';
import 'package:card300_server/models/playing_card.dart';

List<PlayingCard> getNewShuffledDeck() {
  // return List.generate(
  //     12,
  //     (index) => PlayingCard(
  //         suit: 'spades',
  //         value: 'queen',
  //         multiplier: 3,
  //         score: 30,
  //         endSelfScore: 0,
  //         cardGivingDirection: 0,
  //         givesCards: 0));
  return CARD_DATA.map((e) => PlayingCard.fromJson(e)).toList()..shuffle();
}
