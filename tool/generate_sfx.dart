// Generates short PCM WAV SFX for Arrow Drift.
// Run: dart run tool/generate_sfx.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final dir = Directory('assets/sounds');
  dir.createSync(recursive: true);

  File('${dir.path}/tap_ok.wav').writeAsBytesSync(
    _wav(_tone(freq: 920, ms: 70, volume: 0.28, fadeOut: true)),
  );
  File('${dir.path}/tap_wrong.wav').writeAsBytesSync(
    _wav(
      _mix([
        _tone(freq: 160, ms: 120, volume: 0.32, fadeOut: true),
        _tone(freq: 120, ms: 120, volume: 0.18, fadeOut: true),
      ]),
    ),
  );
  File('${dir.path}/level_win.wav').writeAsBytesSync(
    _wav(
      _concat([
        _tone(freq: 523.25, ms: 90, volume: 0.26, fadeOut: true),
        _tone(freq: 659.25, ms: 90, volume: 0.26, fadeOut: true),
        _tone(freq: 783.99, ms: 140, volume: 0.30, fadeOut: true),
      ]),
    ),
  );
  File('${dir.path}/ui_tap.wav').writeAsBytesSync(
    _wav(_tone(freq: 1400, ms: 35, volume: 0.18, fadeOut: true)),
  );

  stdout.writeln('Wrote SFX to ${dir.path}');
}

const _sampleRate = 22050;

Float64List _tone({
  required double freq,
  required int ms,
  required double volume,
  bool fadeOut = false,
}) {
  final n = (_sampleRate * ms / 1000).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _sampleRate;
    var amp = volume;
    if (fadeOut) {
      final p = i / (n - 1);
      amp *= (1 - p) * (1 - p); // ease-out
    }
    // Soft sine with tiny 2nd harmonic for a less toy-like click.
    out[i] = amp *
        (math.sin(2 * math.pi * freq * t) +
            0.18 * math.sin(2 * math.pi * freq * 2 * t));
  }
  return out;
}

Float64List _mix(List<Float64List> parts) {
  final n = parts.map((p) => p.length).reduce(math.max);
  final out = Float64List(n);
  for (final part in parts) {
    for (var i = 0; i < part.length; i++) {
      out[i] += part[i];
    }
  }
  return out;
}

Float64List _concat(List<Float64List> parts) {
  final n = parts.fold<int>(0, (s, p) => s + p.length);
  final out = Float64List(n);
  var o = 0;
  for (final part in parts) {
    out.setRange(o, o + part.length, part);
    o += part.length;
  }
  return out;
}

Uint8List _wav(Float64List samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final s = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, s, Endian.little);
  }
  final pcm = data.buffer.asUint8List();
  final header = ByteData(44);
  void str(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits
  str(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}
