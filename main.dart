import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:card300_server/models/game.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

Map<String, dynamic> connections = {};
Map<String, String> connectionIdToUsername = {};
Map<String, Game> games = {};
void main() {
  var handler = webSocketHandler((webSocket) {
    var connId = generateRandomString(7);
    while (connectionIdToUsername.containsKey(connId)) {
      connId = generateRandomString(7);
    }
    webSocket.sink.add('connect $connId');
    webSocket.stream.listen((message) {
      print(message);
      if (message.startsWith('login')) {
        login(message, webSocket.sink);
      }
      handleCommand(message);
    }, onDone: () {
      if (connectionIdToUsername.containsKey(connId)) {
        print('disconnected $connId');
        connections.remove(connectionIdToUsername[connId]);
        connectionIdToUsername.remove(connId);
      }
    });
  });

  var gameCleaner = Timer.periodic(Duration(seconds: 15), (timer) {
    for (Game game in games.values) {
      var diff = DateTime.now().difference(game.lastAction);
      if (diff.inSeconds >= 300) {
        game.disconnectEveryone();
        games.remove(game.id);
      }
    }
  });

  var env = Platform.environment;

  var port = env.entries.firstWhere((element) => element.key == 'PORT',
      orElse: () => MapEntry('PORT', '8080'));
  shelf_io.serve(handler, '0.0.0.0', int.parse(port.value)).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}

void handleCommand(message) {
  var splitCommand = message.toString().split(' ');
  var command = splitCommand.removeAt(0);
  print('SPLIT COMMAND: ${splitCommand} ;COMMAND: ${command};');
  switch (command) {
    case 'getGames':
      getGames(splitCommand);
      break;
    case 'createGame':
      createGame(splitCommand);
      break;
    case 'joinGame':
      joinGame(splitCommand);
      break;
    case 'startGame':
      startGame(splitCommand);
      break;
    case 'gameAction':
      gameAction(splitCommand);
      break;
    default:
  }
}

void createGame(args) {
  var gameId = '';
  var username = args[0];
  while (gameId == '' || games.keys.contains(gameId)) {
    gameId = generateRandomString(5);
  }
  games[gameId] = Game(id: gameId, endCallback: gameEnded);
  connections[username].add('createGame ok ${gameId}');
}

void getGames(args) {
  var username = args[0];
  var gameList = games.keys.map((k) {
    var v = games[k];
    var data = v.shortData;
    data['gameId'] = k;
    return data;
  }).toList();
  connections[username].add('getGames ${jsonEncode(gameList)}');
}

void joinGame(args) {
  var username = args[0];
  var gameId = args[1];
  if (!games.keys.contains(gameId)) {
    return connections[username].add('joinGame noSuchGame');
  }
  if (games[gameId].players.length >= 6) {
    return connections[username].add('joinGame full');
  }
  games[gameId].joinGame(username, connections[username]);
  connections[username].add('joinGame ok');
}

void startGame(args) {
  var username = args[0];
  var gameId = args[1];
  if (username == games[gameId].leader) games[gameId].startGame();
}

void gameAction(args) {
  var argc = args.toList();
  var username = argc[0];
  var gameId = argc.removeAt(1);
  var gameAction = argc[1];
  if (!games.containsKey(gameId)) return;
  if (!games[gameId].started) return;
  if (games[gameId].currentRound == null) return;
  games[gameId].gameActionHandler(argc);
}

void login(message, sink) {
  var login = message.split(' ')[1];
  var connId = message.split(' ')[2];
  if (connections.keys.contains(login)) {
    sink.add('login exists');
    return;
  }
  connectionIdToUsername[connId] = login;
  connections[login] = sink;
  sink.add('login ok');
}

void gameEnded(Game game) {
  games.remove(game.id);
}

String generateRandomString(int len) {
  var r = Random();
  const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  return List.generate(len, (index) => _chars[r.nextInt(_chars.length)]).join();
}
