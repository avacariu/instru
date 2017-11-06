from frame_eval cimport (PyThreadState_Get, PyObject, PyFrameObject,
                         PyThreadState, _PyEval_EvalFrameDefault)


cdef PyObject *eval_frame(PyFrameObject *frame, int throwflag):
    return _PyEval_EvalFrameDefault(frame, throwflag)


cpdef attach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = eval_frame


cpdef detach():
    cdef PyThreadState *tstate = PyThreadState_Get()
    tstate.interp.eval_frame = _PyEval_EvalFrameDefault
