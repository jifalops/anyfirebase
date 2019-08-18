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
  Database get db => widget.db;
  String lastAction = 'action';
  String lastResult = 'result';
  String id;

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Text('Current ID: $id'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(lastAction),
          Text(lastResult),
        ],
      ),
      Wrap(
        alignment: WrapAlignment.spaceEvenly,
        children: <Widget>[
          RaisedButton(
            child: Text('Create'),
            onPressed: () {
              setState(() => id = db.generateId('/tests'));
              db.create(Data('/tests/$id', {'created': db.serverTimestamp}));
            },
          )
        ],
      ),
      StreamBuilder<Data>(stream: ,)
    ]);
  }
}
