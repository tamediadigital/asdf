[sajson](https://github.com/chadaustin/sajson) Benchmark
===================

## Benchmark: ASDF vs sajson

### Platform
Intel Haswell (AVX2),

### ASDF Results


```
dub --build=release-nobounds --compiler=ldmd2
```

With SSE 4.2
```
                       file -      avg -      min
                       ---- -      --- -      ---
testdata/apache_builds.json - 0.118 ms - 0.112 ms
testdata/github_events.json - 0.055 ms - 0.053 ms
  testdata/instruments.json - 0.263 ms - 0.250 ms
         testdata/mesh.json - 1.098 ms - 1.063 ms
  testdata/mesh.pretty.json - 1.686 ms - 1.582 ms
       testdata/nested.json - 0.147 ms - 0.140 ms
     testdata/svg_menu.json - 0.001 ms - 0.001 ms
     testdata/truenull.json - 0.017 ms - 0.015 ms
      testdata/twitter.json - 0.615 ms - 0.600 ms
testdata/update-center.json - 0.501 ms - 0.484 ms
   testdata/whitespace.json - 0.008 ms - 0.008 ms
```

### sajson Results

```
clang++ -O2 -std=c++14 benchmark/benchmark.cpp -Iinclude
```

Reason clang++ is only -O2, not -O{3,s,z} is that sajson loops are manually unrolled already. Very aggressive
optimisation makes no sense and may unroll loops additionally and slowdown the program.

```
                       file -      avg -      min
                       ---- -      --- -      ---
testdata/apache_builds.json - 0.158 ms - 0.137 ms
testdata/github_events.json - 0.089 ms - 0.080 ms
  testdata/instruments.json - 0.308 ms - 0.289 ms
         testdata/mesh.json - 2.258 ms - 2.151 ms
  testdata/mesh.pretty.json - 3.150 ms - 2.906 ms
       testdata/nested.json - 0.163 ms - 0.140 ms
     testdata/svg_menu.json - 0.004 ms - 0.002 ms
     testdata/truenull.json - 0.021 ms - 0.017 ms
      testdata/twitter.json - 1.190 ms - 0.847 ms
testdata/update-center.json - 0.894 ms - 0.851 ms
   testdata/whitespace.json - 0.009 ms - 0.007 ms
```
