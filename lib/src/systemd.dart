import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

class SystemdConfig {
  SystemdConfig(this.unit,
      {this.dartPath = '/usr/lib/dart/bin/dart',
      this.execPath = 'main.dart',
      this.runAfter = const [
        'nginx.service',
        'postgres.service',
      ],
      this.requires = const ['postgresql.service'],
      this.sdPath = '/etc/systemd/system',
      this.rsyslogPath = '/etc/rsyslog.d'});
  final List<String> runAfter;
  final List<String> requires;
  final String unit;
  final String dartPath;
  final String execPath;
  final String sdPath;
  final String rsyslogPath;
}

class Systemd {
  Systemd(this.args, this.config) {
    args.addFlag('systemd-generate', abbr: 'G', defaultsTo: null);
  }
  final ArgParser args;
  final SystemdConfig config;
  final String cd = Directory.current.absolute.path;

  Future<void> process(ArgResults res) async {
    if (res['systemd-generate'] != null) {
      try {
        await _generateSystemDScript();
        print('File ${config.sdPath}/${config.unit}.service created');
      } on Exception catch (e) {
        print('Unable to create ${config.unit}.service:\n $e');
        exit(1);
      }
      try {
        await _generateRsyslogScript();
        print('File ${config.rsyslogPath}/${config.unit}.conf created');
      } on Exception catch (e) {
        print('Unable to create ${config.unit}.conf:\n $e');
        exit(2);
      }
    } else {
      return;
    }
    exit(0);
  }

  Future<void> _generateSystemDScript() async {
    final afterBuf = StringBuffer();
    for (var after in config.runAfter) {
      afterBuf.writeln('After=$after');
    }
    final requiresBuf = StringBuffer();
    for (var req in config.requires) {
      afterBuf.writeln('Requires=$req');
    }
    final afters = afterBuf.toString();
    final requires = requiresBuf.toString();
    final conf = '''[Unit]
Description=${config.unit}
$afters
$requires

[Service]
WorkingDirectory=$cd

OOMScoreAdjust=-1000

ExecStart=${config.dartPath} $cd/${config.execPath}

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${config.unit}

[Install]
WantedBy=multi-user.target
''';

    final out = File('${config.sdPath}/${config.unit}.service');
    if (out.existsSync()) {
      try {
        await out.delete();
      } on Exception catch (e) {
        print('Cannot remove file ${out.path}:\n$e');
      }
    }
    await out.writeAsString(conf);
    try {
      await out.create();
    } on Exception catch (e) {
      print('Cannot create file ${out.path}:\n$e');
    }
  }

  Future<void> _generateRsyslogScript() async {
    final fRsyslogConf = File('${config.rsyslogPath}/${config.unit}.conf');
    final logFile = File('${cd}/${config.unit}.log');
    try {
      await fRsyslogConf.writeAsString(
          """if \$programname == '${config.unit}' then ${logFile.path}
        & stop""");
    } on Exception catch (e) {
      print('Cannot create file ${fRsyslogConf.path}:\n $e');
    }
    if (!logFile.existsSync()) {
      await logFile.create();
    }
    await Process.run('chown', ['syslog', logFile.path]);
  }
}

/*
systemctl status myunit
systemctl enable myunit
systemctl start myunit
systemctl -l status myunit
systemctl daemon-reload
*/