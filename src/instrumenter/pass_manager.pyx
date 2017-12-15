import dis
from cpython.ref cimport Py_XDECREF, Py_INCREF
from libc.stdio cimport printf
from types import CodeType

from .frame_eval cimport (PyThreadState_Get, PyObject, PyCodeObject,
                          PyFrameObject, PyThreadState,
                          _PyEval_EvalFrameDefault, PyFrame_New,
                          PyFrame_LocalsToFast)
from pycfg import CFG
from .logger cimport log
from . import path_profiler


DEF CO_OPTIMIZED = 0x0002
DEF CO_NEWLOCALS = 0x0002


cdef set _instrumented_hashes = set()
cdef object _log_fd


def instrument_code(code):
    _instrumented_hashes.add(hash(code))


cdef bint should_instrument(object frame):
    return hash(frame.f_code) in _instrumented_hashes

    # getattr(frame.f_globals[frame.f_code.co_name], '__should_profile', False)


cdef bytes _compile_op_ints(list ops):
    # byte order doesn't matter for single bytes
    return b''.join(op.to_bytes(1, 'big') for op in ops)


cdef bytes _init_counter_bc(int consti, int namei):
    """
    Generate bytecode to initialize the counter.

    Args:
        consti: the index in co_consts where the integer 0 is stored
        namei: the index in co_names where the counter is stored

    Returns:
        `bytes` object encoding the initialization of the counter to 0
    """

    # TODO: profile this to see if it's necessary to write this as a byte string
    # directly

    cdef list ops_ints = [
        dis.opmap['LOAD_CONST'], consti,        # Pushes onto stack
        dis.opmap['STORE_GLOBAL'], namei,       # POPs stack
    ]

    return _compile_op_ints(ops_ints)


cdef bytes _incr_counter_bc(int consti, int namei, int jump_forward=0):
    cdef list ops_ints = [
        dis.opmap['LOAD_GLOBAL'], namei,        # Pushes onto stack
        dis.opmap['LOAD_CONST'], consti,        # Pushes onto stack
        dis.opmap['INPLACE_ADD'], 0,            # POPs right arg
        dis.opmap['STORE_GLOBAL'], namei,       # POPs stack
        dis.opmap['JUMP_FORWARD'], jump_forward,
    ]

    return _compile_op_ints(ops_ints)


cdef PyObject *eval_frame(PyFrameObject *frame_obj, int throwflag):
    cdef int num_consts, num_names

    frame = <object> frame_obj

    if should_instrument(frame):
        print("Instrumenting fn:", frame.f_code.co_name)
        print("In file:", frame.f_code.co_filename)
        log(hash(frame.f_code), 1, 0.2, _log_fd)

        consts = list(frame.f_code.co_consts)

        cfg = CFG(frame.f_code)

        edge_values = path_profiler.assign_values_to_edges(cfg)
        unique_edge_values = list(set(edge_values.values()))

        edge_val_map = {}
        for edge, value in edge_values.items():
            edge_val_map[edge] = len(consts) + unique_edge_values.index(value)

        new_consts = tuple(consts + unique_edge_values + [0])
        # TODO: create a new name per function to avoid clashes, and clean it
        # up after function executes or else we'll run out of space with
        # long-running programs
        new_names = tuple(list(frame.f_code.co_names) + ['X-instru_counter'])

        counter_idx = len(new_names) - 1
        incr_code_size = len(_incr_counter_bc(0, 0, 0))

        code_to_insert = [
            (0, _init_counter_bc(len(new_consts) - 1, counter_idx), 0),
        ]

        num_instrumentations_on_target = {}

        for edge, val_consti in edge_val_map.items():
            edge_val = new_consts[val_consti]

            if edge_val != 0:
                # NOTE: this assumes that the instrumentation of this edge is in
                # the reverse order from which we're putting into code_to_insert
                jump_forward = 2 * num_instrumentations_on_target.setdefault(edge[1], 0)
                num_instrumentations_on_target[edge[1]] += 1

                new_code = _incr_counter_bc(val_consti, counter_idx,
                                            jump_forward=jump_forward)

                code_to_insert.append((edge[1], new_code, edge_val))

        for edge, val_consti in edge_val_map.items():
            edge_val = new_consts[val_consti]

            if edge_val == 0 and cfg.is_critical(edge):
                # NOTE: this assumes that the instrumentation of this edge is in
                # the reverse order from which we're putting into code_to_insert
                jump_forward = incr_code_size * num_instrumentations_on_target.setdefault(edge[1], 0)

                new_code = _compile_op_ints([
                    dis.opmap['JUMP_FORWARD'], jump_forward,
                ])

                code_to_insert.append((edge[1], new_code, edge_val))

        new_co_code = path_profiler.instrument(frame.f_code.co_code,
                                               reversed(code_to_insert),
                                               incr_code_size,
                                               edge_values)

        new_code = CodeType(
            frame.f_code.co_argcount,
            frame.f_code.co_kwonlyargcount,
            frame.f_code.co_nlocals,
            frame.f_code.co_stacksize + 2,
            frame.f_code.co_flags & (~CO_NEWLOCALS),
            new_co_code,
            new_consts,
            new_names,
            frame.f_code.co_varnames,
            frame.f_code.co_filename,
            frame.f_code.co_name,
            frame.f_code.co_firstlineno,
            frame.f_code.co_lnotab,     # will have to update
            frame.f_code.co_freevars,
            frame.f_code.co_cellvars
        )

        # This seems neessary or else .f_locals on the new frame object will be
        # empty
        Py_INCREF(frame.f_locals)

        frame_obj = PyFrame_New(
            PyThreadState_Get(),
            <PyCodeObject *> new_code,
            frame_obj.f_globals,
            frame_obj.f_locals
        )

        # Necessary to make f_locals stick. Otherwise it gets cleared at some
        # later point.
        # See http://pydev.blogspot.ca/2014/02/changing-locals-of-frame-frameflocals.html
        PyFrame_LocalsToFast(frame_obj, 0)

    return _PyEval_EvalFrameDefault(frame_obj, throwflag)


cpdef attach(log_filename, mode='a'):
    global _log_fd

    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = eval_frame

    _log_fd = open(log_filename, mode)


cpdef detach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = _PyEval_EvalFrameDefault

    _log_fd.close()
