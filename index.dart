import 'package:rpc/rpc.dart';
import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:http2/multiprotocol_server.dart';
import 'package:http2/transport.dart';
import 'dart:convert';


final ApiServer apiServer = new ApiServer(apiPrefix: '', prettyPrint: true);

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


  String pathFromHeaders(List<Header> headers) {
    for (int i = 0 ; i < headers.length; i++) {
      if (ASCII.decode(headers[i].name) == ':path') {
        return ASCII.decode(headers[i].value);
      }
    }
    throw new Exception('Expected a :path header, but did not find one.');
  };


  runZoned(() {
    server.startServing(
      apiServer.httpRequestHandler,
      (ServerTransportStream stream) {
        String path;
        List<Header> headers;
        List<int> data = new List();

        stream.incomingMessages.listen(
          (StreamMessage message) async {
            print("Message");

            if (message is HeadersStreamMessage) {
              path = pathFromHeaders(message.headers);
              if (path == null) throw 'no path given';

              headers = message.headers;

              //if (!path.startsWith(apiServer._apiPrefix)) {}
              // if (stream.canPush())
              //  stream.push(...);
              //
            } else if (message is DataStreamMessage) {
              data.addAll(message.bytes);
            };
          },
          onDone: () {
            print("Done");

            Map<String, dynamic> headerMap = new Map();
            headers.forEach((header) {
              headerMap[ASCII.decode(header.name)] = ASCII.decode(header.value);
              print("${ASCII.decode(header.name)}: ${ASCII.decode(header.value)}");
            });
            HttpApiRequest request = new HttpApiRequest(
                "GET",
                Uri.parse(path),
                headerMap,
                new Stream.fromIterable(data)
            );

            apiServer.handleHttpApiRequest(request).then(
              (HttpApiResponse response) async {
                List<Header> headerList = new List();
                response.headers.forEach((String key, dynamic value) {
                  print("${key}: ${value}");
                  headerList.add(
                      new Header.ascii(key, value)
                  );
                });

                return new Future(() {
                  stream.sendHeaders(headerList);
                  response.body.drain(stream.sendData);
                  stream.outgoingMessages.close();
                });
              },
              onError: (dynamic) {
                print("Error");
                stream.outgoingMessages.close();
              }
            );
          }
        );
      }
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