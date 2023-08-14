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

  test(
      'method namer parses method names single factored function', () async {});

//   test('method namer names methods correctly', () async {
//     String code = await File('test_file.dart').readAsString();
//     MethodNamer namer = MethodNamer(code);

//     String methodBody = '''SvgPicture.asset123(
//   field3: 'bar',
//   field4: null,
// );''';

//     expect(namer.name(methodBody), 'widgetSvgPicture_asset2');
//   });
}
