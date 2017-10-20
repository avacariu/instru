#include <Python.h>
#include <frameobject.h>
#include <stdio.h>

PyObject *
instru_eval_frame(PyFrameObject *frame, int throwflag)
{
    printf("Hello, world!\n");
    return _PyEval_EvalFrameDefault(frame, throwflag);
}

PyObject *
instru_attach_evaler(PyObject *self, PyObject *args)
{
    PyThreadState *tstate = PyThreadState_GET();
    tstate->interp->eval_frame = instru_eval_frame;
    Py_RETURN_NONE;
}

static PyMethodDef instru_methods[] = {
    {"attach", instru_attach_evaler, METH_VARARGS, "Attach the new frame evaluation function."},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef instru_moddef =
{
    PyModuleDef_HEAD_INIT,
    "instru",
    "",
    -1,
    instru_methods
};

PyMODINIT_FUNC
PyInit_instru(void)
{
    return PyModule_Create(&instru_moddef);
}
