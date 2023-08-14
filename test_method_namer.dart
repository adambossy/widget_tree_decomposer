import "dart:io";
import 'package:test/test.dart';

import 'decompose.dart';

void main() {
  test('method namer parses the correct method names', () async {
    String code = await File('test_file.dart').readAsString();
    MethodNamer namer = MethodNamer(code);
    expect(namer.methodNames, {
      'Scaffold': 1,
      'AppBar': 1,
      'SvgPicture_asset': 1,
    });
  });

  test('method namer names methods correctly', () async {
    String code = await File('test_file.dart').readAsString();
    MethodNamer namer = MethodNamer(code);

    String methodBody = '''SvgPicture.asset123(
  field3: 'bar',
  field4: null,
);''';

    expect(namer.name(methodBody), 'widgetSvgPicture_asset2');
  });
}
