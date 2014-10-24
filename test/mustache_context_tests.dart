library mustache_context_tests;

import 'package:unittest/unittest.dart';
import 'package:mustache4dart/mustache_context.dart';
import 'mustache_test_utils.dart' as utils;

void main() {
  defineTests();  
}

void defineTests() {
  group ('mustache_context lib', () {
      test('Simple context with map', () {
        var ctx = new MustacheContext({'k1': 'value1', 'k2': 'value2'});
        expect(ctx['k1'](), 'value1');
        expect(ctx['k2'](), 'value2');
        expect(ctx['k3'].isFalsey, true);
        expect(ctx['k1'].isLambda, false);
      });
      
      test('Simple context with object', () {
        var ctx = new MustacheContext(new _Person('Γιώργος', 'Βαλοτάσιος'));
        expect(ctx['name'](), 'Γιώργος');
        expect(ctx['lastname'](), 'Βαλοτάσιος');
        expect(ctx['last'].isFalsey, true);
        expect(ctx['fullname'](), 'Γιώργος Βαλοτάσιος');
        expect(ctx['reversedName'](), 'ςογρώιΓ');
        expect(ctx['reversedLastName'](), 'ςοισάτολαΒ');
      });
      
      group('iterable', () {
        
        test('should return a falsey context given an empty iterable as context', () {
          var ctx = new MustacheContext([]);
          expect(ctx.isFalsey, isTrue);
        });
        
        test('should not be a lambda', () {
          var ctx = new MustacheContext([]);
          expect(ctx.isLambda, isFalse);
          
          var ctx2 = new MustacheContext([1, 2, 3]);
          expect(ctx2.isLambda, isFalse);
        });
        
        test('should be an iterable of proper contextes', () {
          var ctx = new MustacheContext([1, 2, 3]);
          for (var num in ctx) {
            expect(num.isFalsey, isFalse);
          }
        });
        

        test('should not allow recursion of iterable contextes of the same name', () {
          var contextY = {'content': 'Y', 'nodes': []};
          var contextX = {'content': 'X', 'nodes': [contextY]};
          var ctx = new MustacheContext(contextX);
          expect(ctx['nodes'].length, 1);
          expect(ctx['nodes'] is Iterable, isTrue);
          (ctx['nodes'] as Iterable) .forEach((n) {
            expect(n['content'](), 'Y');
            expect(n['nodes'].length, 0);
          });
        });
      });
      
      group('FalseyContext', () {
        test('should be created when wrapping a falsey value', () {
          expect(new MustacheContext(false).isFalsey, isTrue);
          expect(new MustacheContext(null).isFalsey, isTrue);
        });
        
        test('should not be a lambda', () {
          expect(new MustacheContext(false).isLambda, isFalse);
        });
        
        test('should only return falsey context with [] operator', () {
          var ctx = new MustacheContext(false);
          expect(ctx['asd'], ctx);
          expect(ctx['.'], ctx);
          expect(ctx['qwerty'], ctx);
        });
      });
      
      test('Simple map with list of maps', () {
        var ctx = new MustacheContext({'k': [{'k1': 'item1'}, 
                                             {'k2': 'item2'}, 
                                             {'k3': {'kk1' : 'subitem1', 'kk2': 'subitem2'}}]});
        expect(ctx['k'].length, 3);
        expect(ctx['k'].isFalsey, isFalse);
      });
      
      test('Map with list of lists', () {
        var ctx = new MustacheContext({'k': [{'k1': 'item1'}, 
                                             {'k3': [{'kk1' : 'subitem1'}, {'kk2': 'subitem2'}]}]});
        expect(ctx['k'].length, 2);
        expect(ctx['k'] is Iterable, isTrue);
        expect((ctx['k'] as Iterable).last['k3'].length, 2);
      });
      
      test('Object with iterables', () {
        var p = new _Person('Νικόλας', 'Νικολάου');
        p.contactInfos.add(new _ContactInfo('Address', {
          'Street': 'Κολοκωτρόνη',
          'Num': '31',
          'Zip': '42100',
          'Country': 'GR'
        }));
        p.contactInfos.add(new _ContactInfo('skype', 'some1'));
        var ctx = new MustacheContext(p);
        var contactInfos = ctx['contactInfos'];
        expect(contactInfos.length, 2);
        expect(contactInfos is Iterable, isTrue);
        var iterableContactInfos = contactInfos as Iterable;
        expect(iterableContactInfos.first['value']['Num'](), '31');
      });
      
      test('Deep search with object', () {
        //create our model:
        _Person p = null;
        for (int i = 10; i > 0; i--) {
          p = new _Person("name$i", "lastname$i", p);
        }

        var ctx = new MustacheContext(p);
        expect(ctx['name'](), 'name1');
        expect(ctx['parent']['lastname'](), 'lastname2');
        expect(ctx['parent']['parent']['fullname'](), 'name3 lastname3');
      });
      
      test('simple MustacheFunction value', () {
        var t = new _Transformer();
        var ctx = new MustacheContext(t);
        var f = ctx['transform'];
        
        expect(f.isLambda, true);
        expect(f('123 456 777'), t.transform('123 456 777'));
      });
      
      test('MustacheFunction from anonymus function', () {
        var map = {'transform': (String val) => "$val!"};
        var ctx = new MustacheContext(map);
        var f = ctx['transform'];
        
        expect(f.isLambda, true);
        expect(f('woh'), 'woh!');
      });
      
      test('Dotted names', () {
        var ctx = new MustacheContext({'person': new _Person('George', 'Valotasios')});
        expect(ctx['person.name'](), 'George');
      });
      
      group('MustacheContext with parent', () {
        test('should not be queried as soon as the main context have the requiered keys', () {
          var parent = new MustacheContext({'a': 'alpha'});
          var ctx = new MustacheContext({'a': 'one'}, parent);
          expect(ctx['a'](), equals('one'));
        });
        
        test('should try the parent context if no value from the current exists', () {
          var parent = new MustacheContext({'a': 'alpha', 'b': 'beta'});
          var ctx = new MustacheContext({'a': 'one'}, parent);
          expect(ctx['b'](), equals('beta'));
        });

        test('should not try the parent if the value of the current is exists and is falsey', () {
          var parent = new MustacheContext({'a': 'alpha', 'b': 'beta'});
          var ctx = new MustacheContext({'a': 'one', 'b': false}, parent);
          expect(ctx['b'].isFalsey, isTrue);
        });
      });
      
      test('Deep subcontext test', () {
        var map = {'a': {'one': 1}, 'b': {'two': 2}, 'c': {'three': 3}};
        var ctx = new MustacheContext({'a': {'one': 1}, 'b': {'two': 2}, 'c': {'three': 3}});
        expect(ctx['a'], isNotNull, reason: "a should exists when using $map");
        expect(ctx['a']['one'](), '1');
        expect(ctx['a']['two'].isFalsey, isTrue);
        expect(ctx['a']['b'], isNotNull, reason: "a.b should exists when using $map");
        expect(ctx['a']['b']['one'](), '1', reason: "a.b.one == a.own when using $map");
        expect(ctx['a']['b']['two'](), '2', reason: "a.b.two == b.two when using $map");
        expect(ctx['a']['b']['three'].isFalsey, isTrue);
        expect(ctx['a']['b']['c'], isNotNull, reason: "a.b.c should not be null when using $map");
        expect(ctx['a']['b']['c']['one'](), '1', reason: "a.b.c.one == a.one when using $map");
        expect(ctx['a']['b']['c']['two'](), '2', reason: "a.b.c.two == b.two when using $map");
        expect(ctx['a']['b']['c']['three'](), '3');
      });

      test('Recursion of iterable contextes', () {
        var contextY = {'content': 'Y', 'nodes': []};
        var contextX = {'content': 'X', 'nodes': [contextY]};
        var ctx = new MustacheContext(contextX);
        expect(ctx['nodes'], isNotNull);
        expect(ctx['nodes'].length, 1);
        expect(ctx['nodes'] is Iterable, isTrue);
        (ctx['nodes'] as Iterable).forEach((n) {
          expect(n['content'](), 'Y');
          expect(n['nodes'].length, 0);
        });
      });

      test('Direct interpolation', () {
        var ctx = new MustacheContext({'n1': 1, 'n2': 2.0, 's': 'some string'});
        expect(ctx['n1']['.'](), '1');
        expect(ctx['n2']['.'](), '2.0'); 
        expect(ctx['s']['.'](), 'some string'); 
      });
      
      test('Direct list interpolation',  () {
        var list = [1, 'two', 'three', '4'];
        var ctx = new MustacheContext(list);
        expect(ctx['.'] is Iterable, isTrue);
      });
    });
    
    group('Mirrorless mustache_context lib', () {
      
      test('the use of mirrors should be configured with the USE_MIRRORS_DEFAULT', () {
        var ctx = new MustacheContext({'key1': 'value1'});
        expect(ctx.useMirrors, USE_MIRRORS);
      });
      
      test('should be disabled by default', () {
        expect(USE_MIRRORS, true);
      });
      
      test('should return the result of the [] operator', () {
        var ctx = new MustacheContext({'key1': 'value1'});
        ctx.useMirrors = false;
        expect(ctx['key1'](), 'value1');
      });
      
      test('should not be able to analyze classes with reflectioon', () {
        var contactInfo = new _ContactInfo('type', 'value');
        var ctx = new MustacheContext(contactInfo, null);
        ctx.useMirrors = false;
        expect(ctx['type'].isFalsey, isTrue);
      });
      
      //TODO: add check for lambda returned from within a map
    });
    
    group('performance', () {
      test('simple map usage', () {
        var dur = utils.duration(10000, () {
          var ctx = new MustacheContext({'a': 'a', 'b': 'b'});
          expect(ctx['a'](), equals('a'));
          expect(ctx['b'](), equals('b'));
          expect(ctx['c'].isFalsey, isTrue);
        });
        print("Did simple map usage in $dur millis");
      });
      
      test('simple map usage 2', () {
        var nodes = {'nodes': {}};
        var map = {'nodes': nodes, 'first': '1st'};
        for (var i = 0; i< 100; i++) {
          nodes['nodes'] = {};
          nodes = nodes['nodes'];
        }
        
        nodes['last'] = 'last';
        
        var dur = utils.duration(10000, () {
          var ctx = new MustacheContext(map);
          var n = ctx['nodes'];
          while (!n['last'].isFalsey) {
            n = n['nodes'];
          }
          expect(n['first'](), equals('1st'));
        });
        print("Did simple map usage 2 in $dur millis");
      });
      
      test('simple Object usage (reflection)', () {
        var ctx = new MustacheContext(new _Person('name', 'lastname'));

        var dur = utils.duration(10000, () {
          expect(ctx['name'](), equals('name'));
          expect(ctx['lastname'](), equals('lastname'));
          expect(ctx['fullname'](), equals('name lastname'));
          expect(ctx['reversedName'](), equals('eman'));
        });
        print("Did object usage in $dur millis");
      });
    });
}

class _Person {
  final name;
  final lastname;
  final _Person parent;
  List<_ContactInfo> contactInfos = [];
  
  _Person(this.name, this.lastname, [this.parent = null]);
  
  get fullname => "$name $lastname";
  
  getReversedName() => _reverse(name);
  
  static _reverse(String str) {
    StringBuffer out = new StringBuffer();
    for (int i = str.length; i > 0; i--) {
      out.write(str[i - 1]);
    }
    return out.toString();
  }
  
  reversedLastName() => _reverse(lastname);
}

class _ContactInfo {
  final String type;
  final value;
  
  _ContactInfo(this.type, this.value);
}

class _Transformer {
  String transform(String val) => "<b>$val</b>";
}
