import dis
import random
from pprint import pprint

import instrumenter
import pycfg


def pathprof(f):
    instrumenter.instrument_code(f.__code__)
    f.__globals__['X-instru_counter'] = 0
    return f

instrumenter.attach('./test.log', mode='w')


@pathprof
def f1(x):
    if x > 5:
        return 2
    else:
        return x


@pathprof
def f2(x):
    if x > 5:
        print

    return None


@pathprof
def f3(x):
    if x % 2 == 0:
        print

    if x % 3 == 0:
        print

    if x % 5 == 0:
        print

    return None


@pathprof
def f4(x):
    if x % 2 == 0:
        print
    if x % 3 == 0:
        print
    if x % 5 == 0:
        print
    if x % 7 == 0:
        print
    if x % 11 == 0:
        print
    if x % 13 == 0:
        print
    if x % 17 == 0:
        print
    if x % 19 == 0:
        print
    if x % 23 == 0:
        print
    if x % 29 == 0:
        print
    if x % 31 == 0:
        print
    if x % 37 == 0:
        print
    if x % 41 == 0:
        print
    if x % 43 == 0:
        print
    if x % 47 == 0:
        print
    if x % 53 == 0:
        print
    if x % 59 == 0:
        print
    if x % 61 == 0:
        print
    if x % 67 == 0:
        print
    if x % 71 == 0:
        print
    if x % 73 == 0:
        print
    if x % 79 == 0:
        print
    if x % 83 == 0:
        print
    if x % 89 == 0:
        print
    if x % 97 == 0:
        print


def test(f, num_paths, test_values, check_all_paths=False, sample=0):
    c = pycfg.CFG(f)
    ev = instrumenter.path_profiler.assign_values_to_edges(c)

    all_paths = range(num_paths)

    if sample:
        all_paths = random.sample(all_paths, k=sample)

    for path in all_paths:
        print(f"\nPATH {path}")
        pprint(instrumenter.path_profiler.recover_path(c, ev, path))

    executed_paths = set()

    for i in test_values:
        print(f'f({i}) =', f(i))

        path = f.__globals__['X-instru_counter']

        if not (0 <= path < num_paths):
            raise Exception(f"Unexpected path {path} for input {i}")

        executed_paths.add(path)

        print('Path num:', path)
        print('-'*80)

    if check_all_paths:
        missing_paths = set(range(num_paths)) - executed_paths
        assert len(missing_paths) == 0, f"Missed some paths: {missing_paths}"

    print('='*80)


test(f1, 2, [4, 6])
test(f2, 2, [4, 6])
test(f3, 8, [1, 2, 3, 5, 6, 10, 15, 30], check_all_paths=True)
test(f4, 2**25, [1, 2, 3], sample=1000)


instrumenter.detach()
