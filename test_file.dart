import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: 'foo',
          useMaterial3: true,
        ),
        child: widgetScaffold1(context));
  }

  Widget widgetScaffold1(BuildContext context) {
    return Scaffold(
      appBar: widgetAppBar37(context),
      body: null,
    );
  }

  Widget widgetAppBar37(BuildContext context) {
    return AppBar(
      field1: widgetSvgPicture_asset579(context),
      field2: null,
    );
  }

  Widget widgetSvgPicture_asset579(BuildContext context) {
    return SvgPicture.asset(
      field3: 'bar',
      field4: null,
    );
  }
}
