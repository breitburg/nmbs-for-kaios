import 'dart:async';
import 'dart:html';

import 'dart:convert';
import 'package:http/http.dart';

void main() async {
  document.activeElement!.addEventListener('keydown', _handleDPad);

  final station = 'Leuven';
  querySelector('#header')?.text = '$station Liveboard';
  final liveboard = await fetchLiveboard(station);

  final date = DateTime.now();
  final buffer = DivElement();

  for (var departure in liveboard.sortedDepartures) {
    final div = DivElement()
      ..classes.addAll(['list-item-icon', 'focusable'])
      ..setAttribute('tabindex', '0')
      ..append(
        DivElement()
          ..classes.add('platform-square')
          ..append(
            ParagraphElement()
              ..classes.add('list-item__text')
              ..text = departure.platform,
          ),
      )
      ..append(
        DivElement()
          ..classes.add('list-item-icon__text-container')
          ..append(
            ParagraphElement()
              ..classes.add('list-item-icon__text')
              ..text = departure.station,
          )
          ..append(
            ParagraphElement()
              ..classes.add('list-item-icon__subtext')
              ..text = formatTime(departure.time.difference(date)),
          ),
      );

    buffer.append(div);
  }

  querySelector('#content')?.replaceWith(buffer);
}

String formatTime(Duration duration) {
  if (duration.isNegative) {
    return 'Departed';
  }

  if (duration.inDays > 0) {
    return 'In ${duration.inDays} day(s)';
  } else if (duration.inHours > 0) {
    return 'In ${duration.inHours} hour(s)';
  } else if (duration.inMinutes > 0) {
    return 'In ${duration.inMinutes} minute(s)';
  } else {
    return 'In ${duration.inSeconds} second(s)';
  }
}

void showToast(String body) {
  final toast = querySelector('.toast')!
    ..classes.add('toast--on')
    ..text = body;

  Future.delayed(
    const Duration(seconds: 3),
    () => toast.classes.remove('toast--on'),
  );
}

void _handleDPad(Event event) {
  if (event is! KeyboardEvent) return;

  print('Key: ${event.key}');

  final move = switch (event.key) {
    'ArrowUp' => -1,
    'ArrowDown' => 1,
    'ArrowLeft' => -1,
    'ArrowRight' => 1,
    _ => 0,
  };

  final items = document.querySelectorAll('.focusable');
  final next = items.indexOf(document.activeElement) + move;

  if (next < 0 || next >= items.length) return;
  items.elementAt(next).focus();
}

Future<Liveboard> fetchLiveboard(String station) async {
  final response = await get(
    Uri.https(
      'api.irail.be',
      '/liveboard/',
      {'station': station, 'format': 'json'},
    ),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to load trains');
  }

  return Liveboard.fromJson(jsonDecode(response.body));
}

class Liveboard {
  final List<Departure> departures;

  Liveboard({required this.departures});

  List<Departure> get sortedDepartures {
    return List.from(departures)..sort((a, b) => a.time.compareTo(b.time));
  }

  factory Liveboard.fromJson(Map<String, dynamic> json) {
    var list = json['departures']['departure'] as List;
    List<Departure> departuresList =
        list.map((i) => Departure.fromJson(i)).toList();
    return Liveboard(departures: departuresList);
  }
}

class Departure {
  final String station;
  final DateTime time;
  final String platform;
  final String vehicle;

  Departure(
      {required this.station,
      required this.time,
      required this.platform,
      required this.vehicle});

  factory Departure.fromJson(Map<String, dynamic> json) {
    return Departure(
      station: json['station'],
      time: DateTime.fromMillisecondsSinceEpoch(int.parse(json['time']) * 1000),
      platform: json['platform'],
      vehicle: json['vehicle'],
    );
  }
}
