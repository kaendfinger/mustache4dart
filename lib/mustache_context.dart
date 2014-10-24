library mustache_context;

import 'dart:collection';

@MirrorsUsed(symbols: '*')
import 'dart:mirrors';

const USE_MIRRORS = const bool.fromEnvironment('MIRRORS', defaultValue: true);
const String DOT = '\.';
final FALSEY_CONTEXT = new FalseyContext();

abstract class MustacheContext {
  
  factory MustacheContext(ctx, [MustacheContext parent]) {
    if (ctx == null || ctx == false) {
      return FALSEY_CONTEXT;
    }
    if (ctx is Iterable) {
      return new _IterableMustacheContextDecorator(ctx, parent);
    }
    return new _MustacheContext(ctx, parent);
  }
  
  bool get isFalsey;
  bool get isLambda;
  MustacheContext operator [](String key);
}


class FalseyContext implements MustacheContext {
  bool get isFalsey => true;
  bool get isLambda => false;
  MustacheContext operator [](String key) => this;
}


class _MustacheContext implements MustacheContext {
  final ctx;
  final _MustacheContext parent;
  bool useMirrors = USE_MIRRORS;
  _ObjectReflector _ctxReflector;

  _MustacheContext(this.ctx, [_MustacheContext this.parent]);

  bool get isLambda => ctx is Function;

  bool get isFalsey => false;

  call([arg]) => isLambda ? ctx(arg) : ctx.toString();

  MustacheContext operator [](String key) {
    return _getInThisOrParent(key);
  }

  MustacheContext _getInThisOrParent(String key) {
    var result = _getContextForKey(key);
    //if the result is null, try the parent context
    if (result == null && parent != null) {
      //TODO: simplify this return an EMPTY_CONTEXT maybe?
      result = parent[key];
      if (result == null || result.isFalsey) {
        return FALSEY_CONTEXT;
      }
      return _newMustachContext(result.ctx);
    }
    if (result == null) {
      return FALSEY_CONTEXT;
    }
    return result;
  }

  MustacheContext _getContextForKey(String key) {
    if (key.contains(DOT)) {
      return new _MustacheContextResolver(key)(this);
    }
    return _getMustachContext(key);
  }

  MustacheContext _getMustachContext(String key) {
    var v = _getActualValue(key);
    return _newMustachContext(v);
  }

  MustacheContext _newMustachContext(v) {
    if (v == null) {
      return null;
    }
    return new MustacheContext(v, this);
  }

  _getActualValue(String key) {
    try {
      return ctx[key];
    } catch (NoSuchMethodError) {
      //Try to make dart2js understand that when we define USE_MIRRORS = false
      //we do not want to use any reflector
      return (useMirrors && USE_MIRRORS) ? ctxReflector[key] : null;
    }
  }

  get ctxReflector {
    if (_ctxReflector == null) {
      _ctxReflector = new _ObjectReflector(ctx);
    }
    return _ctxReflector;
  }

  String toString() => "MustacheContext($ctx, $parent)";
}

class _IterableMustacheContextDecorator extends IterableBase<MustacheContext> implements MustacheContext {
  final Iterable ctx;
  final MustacheContext parent;

  _IterableMustacheContextDecorator(this.ctx, this.parent);

  Iterator<MustacheContext> get iterator => new _MustachContextIteratorDecorator(ctx.iterator, parent);  

  int get length => ctx.length;
  bool get isEmpty => ctx.isEmpty;
  bool get isFalsey => isEmpty;
  bool get isLambda => false;
  
  operator [](String key) {
    if (key == DOT) {
      return this;
    }
    throw new Exception('Iterable can only be iterated. No [] implementation is available');
  }

}



class _MustachContextIteratorDecorator extends Iterator<_MustacheContext> {
  final Iterator delegate;
  final MustacheContext parent;

  MustacheContext current;

  _MustachContextIteratorDecorator(this.delegate, this.parent);

  bool moveNext() {
    if (delegate.moveNext()) {
      current = new _MustacheContext(delegate.current, parent);
      return true;
    } else {
      current = null;
      return false;
    }
  }
}

class _MustacheContextResolver {
  final String key;
  
  _MustacheContextResolver(this.key);
  
  MustacheContext call(MustacheContext ctx) {
    if (key == DOT) {
      return ctx;
    }
    Iterator<String> i = key.split(DOT).iterator;
    var val = ctx;
    while (i.moveNext()) {
      val = val._getMustachContext(i.current);
      if (val == null) {
        return null;
      }
    }
    return val;
  }
}

/**
 * Helper class which given an object it will try to get a value by key analyzing
 * the object by reflection
 */
class _ObjectReflector {
  final InstanceMirror m;

  factory _ObjectReflector(o) {
    return new _ObjectReflector._(reflect(o));
  }

  _ObjectReflector._(this.m);

  operator [](String key) {
    var declaration = new _ObjectReflectorDeclaration(m, key);

    if (declaration == null) {
      return null;
    }

    return declaration.value;
  }
}

class _ObjectReflectorDeclaration {
  final InstanceMirror mirror;
  final DeclarationMirror declaration;

  factory _ObjectReflectorDeclaration(InstanceMirror m, String declarationName) {
    var declarations = m.type.declarations;
    var declarationMirror = declarations[new Symbol(declarationName)];
    if (declarationMirror == null) {
      //try out a getter:
      declarationName = "get${declarationName[0].toUpperCase()}${declarationName.substring(1)}";
      declarationMirror = declarations[new Symbol(declarationName)];
    }
    return declarationMirror == null ? null : new _ObjectReflectorDeclaration._(m, declarationMirror);
  }

  _ObjectReflectorDeclaration._(this.mirror, this.declaration);

  bool get isLambda => declaration is MethodMirror && (declaration as MethodMirror).parameters.length == 1;

  Function get lambda => (val) {
    var im = mirror.invoke(declaration.simpleName, [val]);
    if (im is InstanceMirror) {
      var r = im.reflectee;
      return r;
    } else {
      return null;
    }
  };

  get value {
    if (isLambda) {
      return lambda;
    }

    //Now we try to find out a field or a getter named after the given name
    var im = null;
    if (isVariableOrGetter) {
      im = mirror.getField(declaration.simpleName);
    } else if (isParameterlessMethod) {
      im = mirror.invoke(declaration.simpleName, []);
    }
    if (im != null && im is InstanceMirror) {
      return im.reflectee;
    }
    return null;
  }

  bool get isVariableOrGetter => (declaration is VariableMirror) || (declaration is MethodMirror && (declaration as MethodMirror).isGetter);

  bool get isParameterlessMethod => declaration is MethodMirror && (declaration as MethodMirror).parameters.length == 0;
}
