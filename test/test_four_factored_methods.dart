import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Foobar(
        field1: 'foobar',
        field2: Foo(
          field3: Bar.method(field4: Baz.property),
          field5: true,
        ),
        child: widgetQux1(context));
  }

  Widget widgetGrault1(BuildContext context) {
    return Grault(field8: 'grault');
  }

  Widget widgetCorge1(BuildContext context) {
    return Corge(field7: 'corge1', child: widgetGrault1(context));
  }

  Widget widgetCorge2(BuildContext context) {
    return Corge(field7warble: 'corge2');
  }

  Widget widgetQux1(BuildContext context) {
    return Qux(
        field6: Quux(property: const Text('quux')),
        children: [widgetCorge1(context), widgetCorge2(context)]);
  }
}
