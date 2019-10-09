import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:anyfirebase/anyfirebase.dart';

const appName = 'anyfirebase demo';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: appName,
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: HomePage(),
        routes: {
          'firestore': (context) =>  TestPage(FirestoreDatabase()),
          'realtime': (context) => TestPage(RealtimeDatabase()),
        });
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(appName)),
        body: Center(
          child: Column(
            children: <Widget>[
              MyButton('Test with Firestore',
                  () => Navigator.of(context).pushNamed('firestore')),
              MyButton('Test with Realtime DB',
                  () => Navigator.of(context).pushNamed('realtime')),
            ],
          ),
        ));
  }
}

class TestPage extends StatelessWidget {
  const TestPage(this.db);
  final Database db;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: Builder(
        builder: (context) {
          return SingleChildScrollView(child: DatabaseTester(db));
        },
      ),
    );
  }
}

class DatabaseTester extends StatefulWidget {
  const DatabaseTester(this.db);
  final Database db;

  @override
  _DatabaseTesterState createState() => _DatabaseTesterState();
}

class _DatabaseTesterState extends State<DatabaseTester> {
  static const String basePath = 'tests';
  String error = '';
  String id;

  Data currentData;
  StreamSubscription currentDataSubscription;

  Database get db => widget.db;
  String get path => '$basePath/$id';

  @override
  void initState() {
    super.initState();
    id = db.generateId(basePath);
    currentDataSubscription =
        db.stream(path).listen((data) => setState(() => currentData = data));
  }

  @override
  void dispose() {
    currentDataSubscription.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DatabaseTester oldWidget) {
    currentDataSubscription.cancel();
    currentDataSubscription =
        db.stream(path).listen((data) => setState(() => currentData = data));
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            MyButton('Create', () {
              if (currentData == null) {
                id = db.generateId(basePath);
              }
              clearError();
              db
                  .create(Data(path, {'created': db.serverTimestamp}))
                  .catchError((e) {
                id = db.generateId(basePath);
                onError(e);
              });
            }),
            MyButton('Read', () {
              clearError();
              db.read(path).catchError(onError).then(showData);
            }),
            MyButton('Update', () {
              clearError();
              db
                  .update(Data(path, {'updated': db.serverTimestamp}))
                  .catchError(onError);
            }),
            MyButton('Delete', () {
              clearError();
              db.delete(path).catchError(onError);
            }),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            MyButton('exists', () {
              clearError();
              db.exists(path).catchError(onError).then(showMsg);
            }),
            MyButton('write', () {
              clearError();
              db
                  .write(Data(path, {'written': db.serverTimestamp}))
                  .catchError(onError);
            }),
            MyButton('batch', () {
              clearError();

              db.batchWrite((batch) async {
                batch.update(Data(
                    path,
                    (currentData.value ?? {})
                      ..addAll({'batchUpdate': db.serverTimestamp})));
                batch.delete(path);
                batch.write(Data(
                    path,
                    (currentData.value ?? {})
                      ..addAll({'batchWrite': db.serverTimestamp})));
                batch.commit();
              }).catchError(onError);
            }),
            MyButton('transact', () {
              clearError();
              if (db is FirestoreDatabase) {
                (db as FirestoreDatabase).transact((tx) async {
                  // Firestore can read/write various locations.
                  Data data = await tx.read(path);
                  tx.update(data
                    ..value.addAll({
                      'txUpdate': db.serverTimestamp,
                      'txDelete': db.serverTimestamp
                    }));
                  tx.delete(path);
                  tx.write(data..value.addAll({'txWrite': db.serverTimestamp}));
                }).catchError(onError);
              } else if (db is RealtimeDatabase) {
                (db as RealtimeDatabase).transact(path, (data) async {
                  data.value['txChanged'] = db.serverTimestamp;
                  data.value['created'] = null;
                  return data;
                }).catchError(onError);
              } else {
                print('Unknown db type');
                assert(false);
              }
            }),
          ],
        ),
        if (error.isNotEmpty)
          Container(
              child: Text(error),
              color: Colors.amber[200],
              padding: EdgeInsets.all(8)),
        if (id != null) DataView('Document $id:', db.stream(path)),
        DataView('All test documents:', db.stream(basePath))
      ],
    );
  }

  void showData(Data data) => showMsg(data.value);
  void showMsg(msg) =>
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('$msg')));

  void clearError() => setState(() => error = '');
  void onError(e) => setState(() => error = '$e');
}

class MyButton extends StatelessWidget {
  const MyButton(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return RaisedButton(child: Text(label), onPressed: onPressed);
  }
}

class DataView extends StatelessWidget {
  const DataView(this.label, this.stream);
  final String label;
  final Stream<Data> stream;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: TextStyle(height: 1.5, fontWeight: FontWeight.w500)),
          StreamBuilder<Data>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasData) {
                return Text(
                  JsonEncoder.withIndent('  ', (value) => '$value')
                      .convert(snap.data.value),
                  softWrap: true,
                );
              } else if (snap.hasError) {
                return Text('${snap.error}');
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        ],
      ),
    );
  }
}
