"""S12: write the generated CMake project the change-signature runs edit.

Spike code, never promoted.  Run by run.sh:  python3 -I gen_project.py DIR [FILES]
Three target functions in include/calc/api.h, each with a parameter its body never
uses (so it can be removed) and with calls in FILES (default 24) files src/use_NN.cpp:
  calc::combine  free function, default arguments, overloaded twice (2 doubles,
                 5 longs), called through macros, in templates, in lambdas;
  Meter::adjust  const member function defined in src/meter.cpp;
  calc::weigh    function template defined in the header.
tests/main.cpp prints every use_NN's result; run.sh compares that output with the
unedited project's.  The bodies are not symmetric in the parameters a run reorders,
and the double overload's result differs from the int one's, so a call edited wrongly
or left unedited changes the output.  Writes nothing outside DIR; DIR must not exist.
"""
import os
import sys

API_H = """\
#pragma once
// S12 generated project: the functions whose signatures the runs change.
namespace calc {

int combine(int base, int scale, int offset = 0, int tag = 0);
double combine(double base, double scale);  // overload, never changed
long combine(long a, long b, long c, long d, long e);  // overload, never changed

struct Meter {
  int value = 0;
  int adjust(int delta, int times, bool clamp, int reserved) const;
  int twice_adjust(int delta) const;
};

template <class T>
T weigh(T value, int factor, int shift, int unused) {
  return value * factor + shift * 100;
}

// A call in a template, dependent on T: T = int calls the int overload,
// T = double the double one.
template <class T>
T twice(T v) {
  return combine(v, v);
}

}  // namespace calc

// A call written by a macro body, and a macro taking a call as its argument.
#define COMBINE_TWICE(x) calc::combine((x), (x), 1)
#define ADJUST_ONCE(m) (m).adjust(1, 1, false, 0)
#define CHECKED(expr) (expr)
"""

COMBINE_CPP = """\
#include "calc/api.h"

namespace calc {

int combine(int base, int scale, int offset, int tag) {
  return base * 10 + scale + offset;
}

double combine(double base, double scale) { return base * scale + 1000.0; }

long combine(long a, long b, long c, long d, long e) { return a + b + c + d + e; }

}  // namespace calc
"""

METER_CPP = """\
#include "calc/api.h"

namespace calc {

int Meter::adjust(int delta, int times, bool clamp, int reserved) const {
  int result = value + delta * 10 + times;
  if (clamp && result > 1000)
    result = 1000;
  return result;
}

int Meter::twice_adjust(int delta) const { return adjust(delta, 2, false, 0) * 2; }

}  // namespace calc
"""

# Statements adding to `total'; `i' is the use function's argument, `m' a Meter.
COMBINE = [
    "total += calc::combine(i, 2);",
    "total += combine(i, 3, 4);",
    "total += combine(i, 2, 1, 9);",
    "total += combine(i,\n                   5,\n                   6);",
    "total += combine(combine(i, 2), 3);",
    "total += combine(i < 3, i > 1);",
    "total += combine(i < total, total > i);",
    "total += combine(std::max<int>(i, 2), std::pair<int, int>{3, 4}.first);",
    "total += combine([](int a, int b) { return a + b; }(i, 1), 2);",
    "total += CHECKED(combine(i, 4));",
    "total += COMBINE_TWICE(i);",
    "total += ::calc::combine(i, 1, 2, 3);",
    "total += combine(static_cast<int>(std::vector<int>{1, 2, 3}.size()), i);",
    "total += calc::twice(i);",
    "total += via_template(i);",
    "total += Local{}.call(i);",
]
OVERLOADS = [
    "total += int(combine(1.5, 2.0));",
    "total += int(combine(1L, 2L, 3L, 4L, 5L));",
    "total += int(calc::twice(1.5));",
]
METER = [
    "total += Meter{i}.adjust(1, 2, true, 0);",
    "total += m.adjust(i, 3, false, 0);",
    "total += p->adjust(2, i, true, 0);",
    "total += [&](const Meter& x) { return x.adjust(1, 1, false, 0); }(Meter{i});",
    "total += CHECKED(Meter{i}.adjust(2, 2, true, 0));",
    "total += ADJUST_ONCE(m);",
    "total += poke(m);",
    "total += m.twice_adjust(i);",
]
WEIGH = [
    "total += calc::weigh(i, 2, 1, 0);",
    "total += int(calc::weigh<long>(i, 3, 0, 0));",
    "total += int(calc::weigh(1.5, 2, 1, 0));",
    "total += CHECKED(calc::weigh(i, 1, 1, 0));",
    "total += scaled(i);",
]

USE_CPP = """\
#include "calc/api.h"
#include "calc/use.h"

#include <algorithm>
#include <utility>
#include <vector>

namespace {{

using namespace calc;

// Calls in templates of the calling file: dependent on T.
template <class T>
int via_template(T t) {{
  return calc::combine(t, 2);
}}
template <class M>
int poke(const M& m) {{
  return m.adjust(1, 2, true, 0);
}}
template <class T>
T scaled(T t) {{
  return calc::weigh(t, 2, 0, 0);
}}

// A call in a member function of the calling file.
struct Local {{
  int call(int i) const {{ return calc::combine(i, 1); }}
}};

// A call in a namespace-scope initializer.
const int initial = calc::combine({n}, 2);

}}  // namespace

namespace use {{

int use_{n:02d}(int i) {{
  using namespace calc;
  int total = initial;
  const Meter m{{i}};
  const Meter* p = &m;
  {body}
  (void)p;
  return total;
}}

}}  // namespace use
"""


def statements(n):
    """Every form in at least two files: file N takes a rotating window."""
    out = []
    for forms, take in ((COMBINE, 6), (OVERLOADS, 1), (METER, 3), (WEIGH, 2)):
        for k in range(take):
            out.append(forms[(n * take + k) % len(forms)])
    return out


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii") as f:
        f.write(text)


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: gen_project.py DIR [FILES]")
    root = sys.argv[1]
    files = int(sys.argv[2]) if len(sys.argv) == 3 else 24
    if os.path.exists(root):
        sys.exit(f"gen_project: {root} exists")
    names = [f"use_{n:02d}" for n in range(files)]
    write(os.path.join(root, "CMakeLists.txt"), f"""\
cmake_minimum_required(VERSION 3.20)
project(s12demo CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(calc STATIC src/combine.cpp src/meter.cpp
  {' '.join(f'src/{x}.cpp' for x in names)})
target_include_directories(calc PUBLIC include)
add_executable(calc_tests tests/main.cpp)
target_link_libraries(calc_tests PRIVATE calc)
enable_testing()
add_test(NAME calc_tests COMMAND calc_tests)
""")
    write(os.path.join(root, "CMakePresets.json"), """\
{
  "version": 3,
  "configurePresets": [
    {
      "name": "debug",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/debug",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug",
        "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
      }
    }
  ],
  "buildPresets": [{"name": "debug", "configurePreset": "debug"}]
}
""")
    write(os.path.join(root, ".gitignore"), "/build/\n")
    write(os.path.join(root, "include/calc/api.h"), API_H)
    write(os.path.join(root, "include/calc/use.h"),
          "#pragma once\nnamespace use {\n"
          + "".join(f"int {x}(int i);\n" for x in names) + "}  // namespace use\n")
    write(os.path.join(root, "src/combine.cpp"), COMBINE_CPP)
    write(os.path.join(root, "src/meter.cpp"), METER_CPP)
    for n in range(files):
        body = "\n  ".join(statements(n))
        write(os.path.join(root, f"src/use_{n:02d}.cpp"), USE_CPP.format(n=n, body=body))
    write(os.path.join(root, "tests/main.cpp"),
          "#include <cstdio>\n#include \"calc/use.h\"\n\nint main() {\n"
          + "".join(f'  std::printf("{x} %d\\n", use::{x}({n + 1}));\n'
                    for n, x in enumerate(names))
          + "  return 0;\n}\n")


main()
