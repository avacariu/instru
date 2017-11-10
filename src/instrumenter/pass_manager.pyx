from libc.stdio cimport printf

from .frame_eval cimport (PyThreadState_Get, PyObject, PyFrameObject,
                          PyThreadState, _PyEval_EvalFrameDefault)
from .cfg cimport CFG


cdef set _instrumented_hashes = set()


def instrument_code(code):
    _instrumented_hashes.add(hash(code))


cdef bint should_instrument(object frame):
    return hash(frame.f_code) in _instrumented_hashes

    # getattr(frame.f_globals[frame.f_code.co_name], '__should_profile', False)


cdef PyObject *eval_frame(PyFrameObject *frame_obj, int throwflag):
    frame = <object> frame_obj

    if should_instrument(frame):
        print("Instrumenting fn:", frame.f_code.co_name)
        print("In file:", frame.f_code.co_filename)
        frame_cfg = CFG(<object> frame_obj.f_code)

    return _PyEval_EvalFrameDefault(frame_obj, throwflag)


cpdef attach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = eval_frame


cpdef detach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = _PyEval_EvalFrameDefault
