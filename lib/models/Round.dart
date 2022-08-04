import 'dart:convert';

import 'package:card300_server/helpers/deck.dart';
import 'package:card300_server/models/player.dart';
import 'package:card300_server/models/playing_card.dart';

class Round {
  String gameId;
  List<Player> participants = [];
  List<Player> spectators = [];
  List<PlayingCard> deck;
  List<PlayingCard> discard = [];
  PlayingCard get topCard => discard.last;
  int _currentPlayerIndex = 0;
  Player get currentPlayer => participants[_currentPlayerIndex];
  bool _cardPlayed = false;
  bool _cardTaken = false;
  bool get canPlayCards => !_cardPlayed || topCard.value == 'eight';
  bool get canEndTurn =>
      (_cardPlayed || _cardTaken) &&
      topCard.value != 'eight' &&
      !waitingForSuitChange;
  bool ended = false;
  int multiplier = 1;
  int indexChange = 1;
  bool waitingForSuitChange = false;
  String customSuit;
  bool isCustomSuit;
  Function endCallback;
  Function notifyAllCallback;
  Round({this.participants, this.gameId, this.endCallback, this.spectators});

  bool playCard(String playerName, int cardIndex) {
    var card =
        participants.firstWhere((e) => e.name == playerName).hand[cardIndex];
    if (ended) return false;
    if (currentPlayer.name != playerName) return false;
    if (!canPlayCards) return false;
    if (!canPlayCard(card)) return false;
    currentPlayer.hand.remove(card);
    discard.add(card);
    _cardPlayed = true;
    isCustomSuit = false;
    customSuit = '';
    if (topCard.value == 'six') {
      giveCardsToPlayer(2, 1);
      indexChange += 1;
    }
    if (topCard.value == 'seven') {
      giveCardsToPlayer(1, -1);
    }
    if (topCard.value == 'queen') {
      if (currentPlayer.hand.isNotEmpty) {
        waitingForSuitChange = true;
        currentPlayer.sink.add('changeSuit');
      }
    }
    if (topCard.value == 'king' && topCard.suit == 'spades') {
      giveCardsToPlayer(4, 1);
    }
    if (topCard.value == 'ace') {
      indexChange += 1;
    }
    syncGameDataWithEveryone();
    if (currentPlayer.hand.isEmpty && topCard.value != 'eight') {
      var scoreChanges = {}
        ..addEntries(participants.map((e) => MapEntry(e.name, 0)));
      multiplier *= topCard.multiplier;
      currentPlayer.score += topCard.endSelfScore * multiplier;
      scoreChanges[currentPlayer.name] = topCard.endSelfScore * multiplier;
      for (Player player in participants) {
        for (PlayingCard card in player.hand) {
          player.score += card.score * multiplier;
          scoreChanges[player.name] += card.score * multiplier;
        }
      }
      endCallback(scoreChanges);
      ended = true;
    }
    if (!canPlayCards && !waitingForSuitChange) {
      endTurn(playerName);
    }
    //syncGameDataWithEveryone();
    return true;
  }

  bool endTurn(String playerName) {
    if (ended) return false;
    if (currentPlayer.name != playerName) return false;
    if (!canEndTurn) return false;
    _cardPlayed = false;
    _cardTaken = false;
    _currentPlayerIndex =
        (_currentPlayerIndex + indexChange) % participants.length;
    indexChange = 1;
    syncGameDataWithEveryone();
    return true;
  }

  bool takeCard(String playerName) {
    if (ended) return false;
    if (currentPlayer.name != playerName) return false;
    if (_cardTaken && topCard.value != "eight") return false;
    if (deck.isEmpty) {
      deck = discard.reversed.toList();
      discard = []..add(deck.removeAt(0));
      multiplier += 1;
    }
    currentPlayer.hand.add(deck.removeLast());
    if (deck.isEmpty) {
      deck = discard.reversed.toList();
      discard = []..add(deck.removeAt(0));
      multiplier += 1;
    }
    _cardTaken = true;
    syncGameDataWithEveryone();
    return true;
  }

  bool giveCardsToPlayer(int numberOfCards, int direction) {
    if (deck.isEmpty) {
      deck = discard.reversed.toList();
      discard = []..add(deck.removeAt(0));
      multiplier += 1;
    }
    var targetIndex = _currentPlayerIndex + direction;
    if (targetIndex < 0) targetIndex = participants.length - 1;
    targetIndex %= participants.length;
    var targetPlayer = participants[targetIndex];
    for (int i = 0; i < numberOfCards; i++) {
      if (deck.isEmpty) {
        deck = discard.reversed.toList();
        discard = []..add(deck.removeAt(0));
        multiplier += 1;
      }
      targetPlayer.hand.add(deck.removeLast());
      if (deck.isEmpty) {
        deck = discard.reversed.toList();
        discard = []..add(deck.removeAt(0));
        multiplier += 1;
      }
    }
    syncGameDataWithEveryone();
    return true;
  }

  bool changeSuit(String playerName, String suit) {
    if (currentPlayer.name != playerName) return false;
    if (!waitingForSuitChange) return false;
    customSuit = suit;
    isCustomSuit = true;
    waitingForSuitChange = false;
    currentPlayer.fakeHand = false;
    if (!canPlayCards) {
      endTurn(playerName);
    }
    syncGameDataWithEveryone();
    return true;
  }

  bool canPlayCard(PlayingCard card) {
    if (waitingForSuitChange) return false;
    if (discard.isEmpty) return true;
    if (isCustomSuit) return card.suit == customSuit || card.value == 'queen';
    //if (topCard.value == 'ace') return card.value == 'ace';
    return topCard.suit == card.suit ||
        topCard.value == card.value ||
        card.value == 'queen';
  }

  void syncGameDataWithEveryone() {
    for (Player player in participants) {
      var data = {
        'started': true,
        'gameId': gameId,
        'deckSize': deck.length,
        'topCard': '${topCard.suit}_${topCard.value}',
        'players': participants
            .where((e) => e.name != player.name)
            .map((e) => e.otherData)
            .toList(),
        'hand':
            participants.firstWhere((e) => e.name == player.name).stringHand,
        'score': participants.firstWhere((e) => e.name == player.name).score,
        'currentPlayer': currentPlayer.name,
        if (isCustomSuit) 'customSuit': customSuit,
      };
      player.sink.add('gameData ${jsonEncode(data)}');
    }
    for (Player spectator in spectators) {
      var data = {
        'started': true,
        'gameId': gameId,
        'deckSize': deck.length,
        'topCard': '${topCard.suit}_${topCard.value}',
        'players': participants.map((e) => e.otherData).toList(),
        'hand': [],
        'score': spectator.score,
        'currentPlayer': currentPlayer.name,
        if (isCustomSuit) 'customSuit': customSuit,
        'lost': true
      };
      spectator.sink.add('gameData ${jsonEncode(data)}');
    }
  }

  void startRound(bool firstRound, String startingPlayer) {
    deck = getNewShuffledDeck();
    for (int i = 0; i < 3; i++) {
      for (Player player in participants) {
        player.hand.add(deck.removeLast());
      }
    }
    _currentPlayerIndex =
        participants.indexWhere((e) => e.name == startingPlayer);
    if (currentPlayer.hand.last.value == 'queen') {
      currentPlayer.fakeHand = true;
    }
    playCard(currentPlayer.name, currentPlayer.hand.length - 1);
    syncGameDataWithEveryone();
  }
}
