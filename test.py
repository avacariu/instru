import instrumenter
import pycfg
import dis
from pprint import pprint


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


def test(f, num_paths, test_values, check_all_paths=False):
    c = pycfg.CFG(f)
    ev = instrumenter.path_profiler.assign_values_to_edges(c)

    for path in range(num_paths):
        print(f"\nPATH {path}")
        pprint(instrumenter.path_profiler.recover_path(c, ev, path))

    expected_paths = set(range(num_paths))
    executed_paths = set()

    for i in test_values:
        print(f'f({i}) =', f(i))

        path = f.__globals__['X-instru_counter']

        if path not in expected_paths:
            raise Exception(f"Unexpected path {path} for input {i}")

        executed_paths.add(path)

        print('Path num:', path)
        print('-'*80)

    if check_all_paths:
        missing_paths = expected_paths - executed_paths
        if missing_paths:
            print("Missed some paths:", missing_paths)
        else:
            print("All paths found")

    print('='*80)


test(f1, 2, [4, 6])
test(f2, 2, [4, 6])
test(f3, 8, range(-10, 20), check_all_paths=True)


instrumenter.detach()
