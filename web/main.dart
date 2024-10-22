import 'dart:async';
import 'dart:html';

import 'dart:convert';
import 'package:http/http.dart';

var station = 'Leuven';

void main() async {
  document.activeElement!.addEventListener(
    'keydown',
    (event) => _handleKeyDown(
      event,
      onKeyDown: (key) {
        if (key == 'Enter') {
          showToast('Not implemented');
        }

        if (key == 'SoftRight') {
          reloadLiveboard();
        }

        if (key == 'SoftLeft') {
          station = station == 'Leuven' ? 'Brussels-Central' : 'Leuven';
          reloadLiveboard();
        }
      },
    ),
  );

  reloadLiveboard();
}

void reloadLiveboard() async {
  showToast('Refreshing trains...');

  try {
    querySelector('#header')?.text = '$station Liveboard';
    final content = querySelector('#content')!;
    content.children.clear();

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
                ..text =
                    '${departure.time.hour.toString().padLeft(2, '0')}:${departure.time.minute.toString().padLeft(2, '0')} • ${formatTime(departure.time.difference(date))}',
            ),
        )
        ..append(
          SpanElement()..classes.add('list-item-indicator__indicator'),
        );

      buffer.append(div);
    }

    content.children.addAll(buffer.children);
  } catch (e) {
    showToast('Failed to load trains');
  }
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

void _handleKeyDown(
  Event event, {
  void Function(String key)? onKeyDown,
}) {
  if (event is! KeyboardEvent || event.key == null) return;

  final move = switch (event.key) {
    'ArrowUp' => -1,
    'ArrowDown' => 1,
    'ArrowLeft' => -1,
    'ArrowRight' => 1,
    _ => null,
  };

  if (move == null) {
    return onKeyDown?.call(event.key!);
  }

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
