import 'package:card300_server/models/playing_card.dart';

class Player {
  String name;
  int score = 0;
  List<PlayingCard> hand = [];
  List<String> get stringHand => !fakeHand
      ? hand.map((e) => e.string).toList()
      : ['diamonds_ace', 'diamonds_three', 'diamonds_three', 'diamonds_seven'];
  bool fakeHand = false;
  dynamic sink;
  Player({this.name, this.sink});

  Map get selfData => {
        'name': name,
        'score': score,
        'hand': !fakeHand
            ? hand.map((e) => e.string).toList()
            : [
                'diamonds_one',
                'diamonds_three',
                'diamonds_three',
                'diamonds_seven'
              ]
      };
  Map get otherData =>
      {'name': name, 'score': score, 'numberOfCards': hand.length};

  void disconnectFromGame() {
    sink.add('disconnect');
  }
}
