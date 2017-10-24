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
instru_attach(PyObject *self, PyObject *args)
{
    PyThreadState *tstate = PyThreadState_GET();
    tstate->interp->eval_frame = instru_eval_frame;

    Py_RETURN_NONE;
}

PyObject *
instru_detach(PyObject *self, PyObject *args)
{
    PyThreadState *tstate = PyThreadState_GET();
    tstate->interp->eval_frame = _PyEval_EvalFrameDefault;

    Py_RETURN_NONE;
}

static PyMethodDef instru_methods[] = {
    {"attach", instru_attach, METH_VARARGS, "Attach the new frame evaluation function."},
    {"detach", instru_detach, METH_VARARGS, "Detach"},
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
