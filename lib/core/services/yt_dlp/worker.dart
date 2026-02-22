import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:curio/core/services/yt_dlp/platform.dart';
import 'package:flutter/services.dart';

/// Worker command types
// Removed 'execute' as it is deprecated by the Chaquopy implementation.
enum WorkerCommand { initialize, getVersion, fetchMetadata, shutdown }

/// Request sent to the worker
class WorkerRequest {
  final int id;
  final WorkerCommand command;
  final Map<String, dynamic>? args;

  WorkerRequest({required this.id, required this.command, this.args});
}

/// Response received from the worker
class WorkerResponse {
  final int id;
  final dynamic data;
  final String? error;

  WorkerResponse({required this.id, this.data, this.error});
}

class YtDlpWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _responseStreamController =
      StreamController<WorkerResponse>.broadcast();
  int _nextRequestId = 0;
  final _completers = <int, Completer<dynamic>>{};

  Future<void> initialize() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();

    // Pass the RootIsolateToken to allow platform channel access in the background isolate
    final rootToken = RootIsolateToken.instance;
    if (rootToken == null) {
      throw Exception(
        'RootIsolateToken is null. Cannot spawn background isolate with platform channels.',
      );
    }
    _isolate = await Isolate.spawn(
      _workerEntry,
      _WorkerInitData(receivePort.sendPort, rootToken),
    );
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        print('YtDlpWorker: Worker connected');
      } else if (message is WorkerResponse) {
        _responseStreamController.add(message);
        final completer = _completers.remove(message.id);
        if (completer != null) {
          if (message.error != null) {
            completer.completeError(message.error!);
          } else {
            completer.complete(message.data);
          }
        }
      }
    });
  }

  void dispose() {
    _responseStreamController.close();
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;
    }
  }

  Future<dynamic> _sendRequest(
    WorkerCommand command, [
    Map<String, dynamic>? args,
  ]) {
    if (_sendPort == null) {
      throw Exception('Worker is not initialized or connected.');
    }
    final requestId = _nextRequestId++;
    final completer = Completer<dynamic>();
    _completers[requestId] = completer;

    _sendPort!.send(WorkerRequest(id: requestId, command: command, args: args));
    return completer.future;
  }

  Future<void> shutdown() async {
    await _sendRequest(WorkerCommand.shutdown);
  }

  Future<String> getVersion() async {
    return await _sendRequest(WorkerCommand.getVersion) as String;
  }

  /// Use the dedicated method for metadata fetching, which now uses the Chaquopy Python API.
  Future<Map<String, dynamic>> fetchMetadata(String url) async {
    return await _sendRequest(WorkerCommand.fetchMetadata, {'url': url})
        as Map<String, dynamic>;
  }

  // Top-level function for the background isolate
  static void _workerEntry(_WorkerInitData initData) {
    // Allows the background isolate to use platform channels
    BackgroundIsolateBinaryMessenger.ensureInitialized(initData.rootToken);

    final workerReceivePort = ReceivePort();
    initData.sendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) async {
      if (message is WorkerRequest) {
        dynamic result;
        final YtDlpPlatformService platformService = YtDlpPlatformService();

        try {
          switch (message.command) {
            case WorkerCommand.initialize:
              await platformService.initialize();
              result = 'Worker initialized';
              break;
            case WorkerCommand.getVersion:
              result = await platformService.getVersion();
              break;
            case WorkerCommand.fetchMetadata: // ⬅️ THIS CASE IS FIXED
              final url = message.args?['url'] as String?;
              if (url == null) {
                throw Exception('URL argument missing for fetchMetadata');
              }
              // Calls the new Chaquopy-backed method that returns a decoded Map
              result = await platformService.getInfo(url);
              break;
            case WorkerCommand.shutdown:
              Isolate.exit();
          }
          initData.sendPort.send(WorkerResponse(id: message.id, data: result));
        } catch (e) {
          initData.sendPort.send(
            WorkerResponse(id: message.id, error: e.toString()),
          );
        }
      }
    });
  }
}

class _WorkerInitData {
  final SendPort sendPort;
  final RootIsolateToken rootToken;

  _WorkerInitData(this.sendPort, this.rootToken);
}
