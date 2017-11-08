from libc.stdio cimport printf

from .frame_eval cimport (PyThreadState_Get, PyObject, PyFrameObject,
                          PyThreadState, _PyEval_EvalFrameDefault)
from .cfg cimport CFG


cdef PyObject *eval_frame(PyFrameObject *frame_obj, int throwflag):
    frame = <object> frame_obj
    cdef str filename = frame.f_code.co_filename

    frame_cfg = CFG(<object> frame_obj.f_code)

    return _PyEval_EvalFrameDefault(frame_obj, throwflag)


cpdef attach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = eval_frame


cpdef detach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = _PyEval_EvalFrameDefault
