import 'package:rpc/rpc.dart';
import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:http2/multiprotocol_server.dart';
import 'package:http2/transport.dart';
import 'dart:convert';




final ApiServer apiServer = new ApiServer(); //apiPrefix: '', prettyPrint: true

main() async {
  Logger.root..level = Level.INFO..onRecord.listen(print);

  apiServer.enableDiscoveryApi();
  apiServer.addApi(new MyApi());

  String localFile(path) => Platform.script.resolve(path).toFilePath();
  var context = new SecurityContext()
    ..usePrivateKey(localFile('localhost.key'), password: '')
    ..useCertificateChain(localFile('localhost.crt'))
    ..setAlpnProtocols(['h2', 'h2-14', 'http/1.1'], true);

  final MultiProtocolHttpServer server = await MultiProtocolHttpServer.bind(InternetAddress.ANY_IP_V4, 8181, context);



  runZoned(() {
    server.startServing(
      apiServer.httpRequestHandler,
      apiServer.http2RequestHandler
//      (ServerTransportStream stream) async {
//        String path;
//        List<Header> headers;
//        List<int> data = new List();
//
//        stream.incomingMessages.listen(
//          (StreamMessage message) async {
//            print("Message");
//
//            if (message is HeadersStreamMessage) {
//              path = pathFromHeaders(message.headers);
//              if (path == null) throw 'no path given';
//
//              headers = message.headers;
//
//              //if (!path.startsWith(apiServer._apiPrefix)) {}
//              // if (stream.canPush())
//              //  stream.push(...);
//              //
//            } else if (message is DataStreamMessage) {
//              data.addAll(message.bytes);
//            };
//          },
//          onDone: () async {
//            print("Done");
//
//            if (path == '/favicon.ico') {
//              return new Future(() async {
//                stream.outgoingMessages.add(
//                    new HeadersStreamMessage([
//                      new Header.ascii(':status', '204'),
//                    ])
//                );
//                await stream.outgoingMessages.close();
//              });
//            } else {
//              Map<String, dynamic> headerMap = new Map();
//              headers.forEach((header) {
//                headerMap[ASCII.decode(header.name)] =
//                    ASCII.decode(header.value);
//                print("${ASCII.decode(header.name)}: ${ASCII.decode(
//                    header.value)}");
//              });
//
//              HttpApiRequest request = new HttpApiRequest(
//                  "GET",
//                  Uri.parse(path),
//                  headerMap,
//                  new Stream.fromIterable(data)
//              );
//
//              apiServer.handleHttpApiRequest(request).then(
//                (HttpApiResponse response) {
//                List<Header> headerList = new List();
//                response.headers.forEach((String key, dynamic value) {
//                  print("${key}: ${value}");
//                  headerList.add(
//                      new Header.ascii(key, value)
//                  );
//                });
//
//                return new Future(() async {
//                  stream.outgoingMessages.add(
//                      new HeadersStreamMessage([
//                        new Header.ascii(':status', '200'),
//                      ])
//                  );
//
//                  await response.body.forEach((data) {
//                    stream.outgoingMessages.add(
//                        new DataStreamMessage(data)
//                    );
//                  });
//
//                  await stream.outgoingMessages.close();
//                });
//              },
//                onError: (dynamic) {
//                  print("Error");
//                  stream.outgoingMessages.close();
//                }
//              );
//            }
//          }
//        );
//      }
    );
  }, onError: (e, s) {
    print("Unexpected error: $e");
    print("Unexpected error - stack: $s");
  });


  print('Server listening on https://${server.address.host}:${server.port}');
}


@ApiClass(name: 'api', version: 'v1')
class MyApi {
  List _animals = [];

  @ApiMethod(path: 'animals')
  List<Animal> getAnimals() => _animals;

  @ApiMethod(path: 'animals', method: 'POST')
  Animal postAnimal(Animal animal) {
    _animals.add(animal);
    return animal;
  }
}

class Animal {
  int id;
  String name;
  int numberOfLegs;
}