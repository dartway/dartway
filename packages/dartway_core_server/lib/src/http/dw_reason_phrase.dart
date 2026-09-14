import 'dart:io';

import 'package:meta/meta.dart';

/// The reason phrases of RFC 9110 (and 429/431 of RFC 6585), by status.
///
/// `dart:io` knows phrases only for the statuses of RFC 2616 and writes
/// `Status 422` for the rest — among them three the server answers every day:
/// `422` (a refusal), `426` (update the app) and `429` (too many requests). A
/// status line a proxy or a person reads should say what the status means.
const Map<int, String> _reasonPhrases = {
  100: 'Continue',
  101: 'Switching Protocols',
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  203: 'Non-Authoritative Information',
  204: 'No Content',
  205: 'Reset Content',
  206: 'Partial Content',
  300: 'Multiple Choices',
  301: 'Moved Permanently',
  302: 'Found',
  303: 'See Other',
  304: 'Not Modified',
  305: 'Use Proxy',
  307: 'Temporary Redirect',
  308: 'Permanent Redirect',
  400: 'Bad Request',
  401: 'Unauthorized',
  402: 'Payment Required',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  406: 'Not Acceptable',
  407: 'Proxy Authentication Required',
  408: 'Request Timeout',
  409: 'Conflict',
  410: 'Gone',
  411: 'Length Required',
  412: 'Precondition Failed',
  413: 'Content Too Large',
  414: 'URI Too Long',
  415: 'Unsupported Media Type',
  416: 'Range Not Satisfiable',
  417: 'Expectation Failed',
  421: 'Misdirected Request',
  422: 'Unprocessable Content',
  426: 'Upgrade Required',
  428: 'Precondition Required',
  429: 'Too Many Requests',
  431: 'Request Header Fields Too Large',
  500: 'Internal Server Error',
  501: 'Not Implemented',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Timeout',
  505: 'HTTP Version Not Supported',
};

/// Sets [status] on [response] with its standard reason phrase. A status
/// without one (a project route's own `299`) keeps the phrase `dart:io`
/// gives it.
@internal
void dwSetStatus(HttpResponse response, int status) {
  response.statusCode = status;
  if (_reasonPhrases[status] case final phrase?) {
    response.reasonPhrase = phrase;
  }
}
