import 'package:args/args.dart';
import 'package:systemd_gen/systemd_gen.dart';

///
/// Entry point for app
///
Future main(List<String> args) async {
  final parser = ArgParser();
  final sd = Systemd(parser, SystemdConfig('unit_name', execPath: 'bin/main.dart -p 9060'));
  final result = parser.parse(args);
  await sd.process(result);
}
