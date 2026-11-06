import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/map_place_service.dart';

/// Address labels only: never changes the coordinate, GPS stream or route.
class ReadablePlaceText extends StatefulWidget {
  const ReadablePlaceText(
    this.address, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.suffix = '',
    this.showCoordinateFallback = true,
    this.lookup,
  });
  final String address;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final String suffix;
  final bool showCoordinateFallback;
  final Future<String?> Function(LatLng)? lookup;
  static final _coordinates = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  );

  static LatLng? coordinates(String value) {
    final match = _coordinates.firstMatch(value);
    if (match == null) return null;
    final lat = double.parse(match[1]!);
    final lon = double.parse(match[2]!);
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  @override
  State<ReadablePlaceText> createState() => _ReadablePlaceTextState();
}

class _ReadablePlaceTextState extends State<ReadablePlaceText> {
  Future<String?>? _result;
  Timer? _retry;
  int _generation = 0, _attempts = 0;
  String? _key(String address) {
    final point = ReadablePlaceText.coordinates(address);
    return point == null
        ? null
        : '${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReadablePlaceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_key(oldWidget.address) != _key(widget.address) ||
        oldWidget.lookup != widget.lookup) {
      _attempts = 0;
      _load();
    }
  }

  void _load({bool force = false}) {
    _retry?.cancel();
    final generation = ++_generation;
    final point = ReadablePlaceText.coordinates(widget.address);
    if (point == null) {
      _result = null;
      return;
    }
    _attempts++;
    _result = () async {
      String? address;
      try {
        address = widget.lookup != null
            ? await widget.lookup!(point)
            : (await MapPlaceService.instance.placeFromCoordinates(
                point,
                forceRefresh: force,
              )).address;
        if (address == null ||
            address.trim().isEmpty ||
            ReadablePlaceText.coordinates(address) != null) {
          address = null;
        }
      } catch (_) {
        address = null;
      }
      if (mounted &&
          generation == _generation &&
          address == null &&
          _attempts < 3) {
        _retry = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => _load());
        });
      }
      return address;
    }();
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget label(String value) => Text(
      '$value${widget.suffix}',
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
    if (ReadablePlaceText.coordinates(widget.address) == null) {
      return label(widget.address);
    }
    return FutureBuilder<String?>(
      key: ValueKey(_key(widget.address)),
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.hasData) return label(snapshot.data!);
        if (widget.showCoordinateFallback) return label(widget.address);
        if (snapshot.connectionState != ConnectionState.done) {
          return label('Finding location name…');
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: label('Location name unavailable')),
            IconButton(
              tooltip: 'Retry location name',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => setState(() {
                _attempts = 0;
                _load(force: true);
              }),
            ),
          ],
        );
      },
    );
  }
}
