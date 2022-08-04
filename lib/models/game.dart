import 'dart:convert';

import 'package:card300_server/models/Round.dart';
import 'package:card300_server/models/player.dart';
import 'package:card300_server/models/playing_card.dart';

class Game {
  String id;
  List<Player> players = [];
  List<Player> spectators = [];
  Round currentRound;
  String leader;
  bool started = false;
  Map get shortData => {'players': players.length, 'started': started};
  Function endCallback;
  Game({this.id, this.endCallback});
  DateTime lastAction = DateTime.now();

  void joinGame(username, sink) {
    if (players.isEmpty) leader = username;
    players.add(Player(name: username, sink: sink));
    syncGameDataWithEveryone();
    lastAction = DateTime.now();
  }

  void startGame() {
    if (players.length <= 1) {
      return;
    }
    currentRound = Round(
        participants: players,
        gameId: id,
        spectators: spectators,
        endCallback: roundFinished);
    currentRound.startRound(true, leader);
    started = true;
    lastAction = DateTime.now();
  }

  void syncGameDataWithEveryone() {
    for (Player player in players) {
      var data = {
        'leader': leader,
        'gameId': id,
        'deckSize': 0,
        'topCard': '',
        'players': players
            .where((e) => e.name != player.name)
            .map((e) => e.otherData)
            .toList(),
        'hand': [],
        'score': players.firstWhere((e) => e.name == player.name).score,
        'currentPlayer': '',
        'started': started
        //if (isCustomSuit) 'customSuit': customSuit,
      };
      player.sink.add('gameData ${jsonEncode(data)}');
    }
  }

  void gameActionHandler(args) {
    // 0 - username
    // 1 - action
    // 2-... - arguments
    lastAction = DateTime.now();
    var username = args[0];
    var action = args[1];
    switch (action) {
      case 'changeSuit':
        currentRound.changeSuit(username, args[2]);
        break;
      case 'playCard':
        currentRound.playCard(username, int.parse(args[2]));
        break;
      case 'takeCard':
        currentRound.takeCard(username);
        break;
      case 'endTurn':
        currentRound.endTurn(username);
        break;
      default:
    }
  }

  void roundFinished(Map scoreChanges) {
    lastAction = DateTime.now();
    var winner = players.firstWhere((e) => e.hand.isEmpty);
    emptyHands();
    for (Player player in players) {
      if (player == winner) {
        player.sink.add(
            'infoMessage Ура! Вы только что выиграли раунд. Гордитесь!${scoreChanges[player.name] != 0 ? " Так же ваш счёт уменьшился на ${scoreChanges[player.name] * -1} очков." : ""}');
      } else {
        player.sink.add(
            'infoMessage Блин! А раунд то закончился. Вам в ебло прилетело ${scoreChanges[player.name]} очков(');
      }
      if (player.score == 300) {
        player.score = 0;
        player.sink.add(
            'infoMessage Пиздец! Вы только что набрали 300 очков и обнулились!');
      }
      if (player.score > 300) {
        spectators.add(player);
        player.sink.add(
            'infoMessage Пиздец!!! Вы набрали больше 300 очков и проебали!!!!!!');
      }
    }
    players.removeWhere((e) => spectators.contains(e));
    currentRound.ended = true;
    currentRound = null;
    if (players.length < 2) {
      endGame();
      return;
    }
    currentRound = Round(
        participants: players,
        gameId: id,
        spectators: spectators,
        endCallback: roundFinished);
    currentRound.startRound(false, winner.name);
  }

  void emptyHands() {
    for (Player player in players) {
      player.hand.clear();
    }
  }

  void endGame() {
    players.first.sink.add('infoMessage Ура! Игра закончена. Вы подебили!');
    spectators.forEach((e) => e.sink.add(
        'infoMessage Информация Игра закончена. Победитель: ${players.first.name}'));
    endCallback(this);
  }

  void disconnectEveryone() {
    players.forEach((element) => element.disconnectFromGame());
    spectators.forEach((element) => element.disconnectFromGame());
  }
}
