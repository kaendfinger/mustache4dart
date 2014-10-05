library mustache_test_utils;

num duration(int reps, f()) {
  var start = new DateTime.now();
  for (int i = 0; i < reps; i++) {
    f();
  }
  var end = new DateTime.now();
  return end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
}
