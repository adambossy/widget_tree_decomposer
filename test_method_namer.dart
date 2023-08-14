import "dart:io";
import 'package:test/test.dart';

import 'decompose.dart';

void main() {
  test('method namer parses method names from monolithic build() method',
      () async {
    String code = await File('test/test_undecomposed.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {});
  });

  test('method namer parses method names with one factored function', () async {
    String code =
        await File('test/test_one_factored_method.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {'Grault': 1});
  });

  test('method namer parses method names with two factored functions',
      () async {
    String code =
        await File('test/test_two_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {'Grault': 1, 'Corge': 1});
  });

  test('method namer parses method names with three factored functions',
      () async {
    String code =
        await File('test/test_three_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {'Grault': 1, 'Corge': 2});
  });

  test('method namer parses method names with four factored functions',
      () async {
    String code =
        await File('test/test_four_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {'Grault': 1, 'Corge': 2, 'Qux': 1});
  });

  test('method namer parses method names with five factored functions',
      () async {
    String code =
        await File('test/test_five_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {'Grault': 1, 'Corge': 2, 'Qux': 1, 'Foobar': 1});
  });

  test('method namer names methods correctly for new method name', () async {
    String code = await File('test/test_undecomposed.dart').readAsString();
    MethodNamer namer = MethodNamer(code);

    String methodBody = '''Grault(field8: 'grault')''';

    expect(namer.name(methodBody), 'widgetGrault1');
  });

  test('method namer names methods correctly for exisiting method name',
      () async {
    String code =
        await File('test/test_two_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);

    String methodBody = '''Corge(field7warble: 'corge2')''';

    expect(namer.name(methodBody), 'widgetCorge2');
  });

  test('method namer names methods correctly for two exisiting method names',
      () async {
    String code =
        await File('test/test_three_factored_methods.dart').readAsString();
    MethodNamer namer = MethodNamer(code);

    String methodBody = '''Corge(field7warble: 'corge2')''';

    expect(namer.name(methodBody), 'widgetCorge3');
  });
}
