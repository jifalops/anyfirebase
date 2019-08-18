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
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: Builder(
        builder: (context) {
          return ListView(
            children: <Widget>[],
          );
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
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            MyButton('Create', () {
              id = db.generateId(basePath);
              clearError();
              db
                  .create(Data(path, {'created': db.serverTimestamp}))
                  .catchError(onError);
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
              } else if (db is RealTimeDatabase) {
                (db as RealTimeDatabase).transact(path, (data) async {
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
        Text(error),
        if (id != null) DataView('Document $id:', db.stream(path)),
        DataView('All test documents:', db.stream(basePath))
      ],
    );
  }

  void showData(Data data) => showMsg(json.encode('${data.value}'));
  void showMsg(msg) => Scaffold.of(context).showSnackBar(SnackBar(
        content: Text('$msg'),
      ));

  void clearError() => setState(() => error = '');
  void onError(e) => setState(() => error = '$e');
}

class MyButton extends StatelessWidget {
  const MyButton(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Text(label),
      onPressed: onPressed,
    );
  }
}

class DataView extends StatelessWidget {
  const DataView(this.label, this.stream);
  final String label;
  final Stream<Data> stream;
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label),
          StreamBuilder<Data>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.done) {
                return Text(
                  json.encode(snap.data.value),
                  softWrap: true,
                );
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
