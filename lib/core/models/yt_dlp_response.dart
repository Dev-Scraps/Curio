class YtDlpResponse<T> {
  final T? data;
  final String? error;
  final bool success;
  final String? message;

  YtDlpResponse({this.data, this.error, required this.success, this.message});

  factory YtDlpResponse.success(T data, {String? message}) {
    return YtDlpResponse(data: data, success: true, message: message);
  }

  factory YtDlpResponse.error(String error, {String? message}) {
    return YtDlpResponse(error: error, success: false, message: message);
  }

  factory YtDlpResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final bool isError = json['error'] == true;
    if (isError) {
      return YtDlpResponse.error(
        json['message']?.toString() ?? 'Unknown error',
        message: json['message']?.toString(),
      );
    }

    try {
      // If the data is nested in a specific key, we might need to handle it.
      // But usually, the whole object is the data unless there's an error.
      return YtDlpResponse.success(fromJsonT(json));
    } catch (e) {
      return YtDlpResponse.error('Parsing error: $e');
    }
  }

  @override
  String toString() =>
      'YtDlpResponse(success: $success, error: $error, data: $data)';
}
