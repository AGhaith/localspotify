import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/core/utils/text_key.dart';

void main() {
  test('textKey keeps Arabic so different Arabic titles stay distinct', () {
    expect(textKey('تملي معاك'), isNot(textKey('يا بنت')));
    expect(textKey('تملي معاك'), 'تملي معاك');
    expect(textKey('  Fire, Fire! '), 'fire fire');
    expect(textKey('عمرو دياب'), isNotEmpty);
  });
}
