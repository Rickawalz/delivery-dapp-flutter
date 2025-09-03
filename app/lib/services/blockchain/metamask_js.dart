@JS()
library metamask;

import 'package:js/js.dart';

@JS('window.ethereum')
external Ethereum? get ethereum;

@JS()
@anonymous
class Ethereum {
  external Promise request(RequestArguments args);
  external String? get selectedAddress;
  external String? get chainId;
}

@JS()
@anonymous
class RequestArguments {
  external String get method;
  external List<dynamic>? get params;
  external factory RequestArguments({String method, List<dynamic>? params});
}

@JS()
class Promise {
  external Promise then(Function(dynamic));
  external Promise catchError(Function(dynamic));
} 