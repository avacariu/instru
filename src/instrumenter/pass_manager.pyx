from libc.stdio cimport printf

from .frame_eval cimport (PyThreadState_Get, PyObject, PyCodeObject,
                          PyFrameObject, PyThreadState,
                          _PyEval_EvalFrameDefault)
from .cfg cimport CFG
from .logger cimport log

from types import CodeType


cdef set _instrumented_hashes = set()
cdef object _log_fd


def instrument_code(code):
    _instrumented_hashes.add(hash(code))


cdef bint should_instrument(object frame):
    return hash(frame.f_code) in _instrumented_hashes

    # getattr(frame.f_globals[frame.f_code.co_name], '__should_profile', False)


cdef PyObject *eval_frame(PyFrameObject *frame_obj, int throwflag):
    cdef int num_consts, num_names

    frame = <object> frame_obj

    if should_instrument(frame):
        print("Instrumenting fn:", frame.f_code.co_name)
        print("In file:", frame.f_code.co_filename)
        log(hash(frame.f_code), 1, 0.2, _log_fd)

        new_consts = tuple(list(frame.f_code.co_consts) + [5])
        new_names = tuple(list(frame.f_code.co_names) + ['__instru_counter'])

        new_code = CodeType(
            frame.f_code.co_argcount,
            frame.f_code.co_kwonlyargcount,
            frame.f_code.co_nlocals,
            frame.f_code.co_stacksize,
            frame.f_code.co_flags,
            frame.f_code.co_code,
            new_consts,
            new_names,
            frame.f_code.co_varnames,
            frame.f_code.co_filename,
            frame.f_code.co_name,
            frame.f_code.co_firstlineno,
            frame.f_code.co_lnotab,
            frame.f_code.co_freevars,
            frame.f_code.co_cellvars
        )

        frame_obj.f_code = <PyCodeObject *> new_code

        print("#names", len(frame.f_code.co_names))
        print("names", frame.f_code.co_names)
        print("#consts", len(frame.f_code.co_consts))
        print("consts", frame.f_code.co_consts)

        frame_cfg = CFG(<object> frame_obj.f_code)

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
