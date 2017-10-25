#include <Python.h>
#include <frameobject.h>
#include <stdio.h>

static int counter;
static FILE *output_file;

PyObject *
instru_eval_frame(PyFrameObject *frame, int throwflag)
{
    const char *filename = _PyUnicode_AsString(frame->f_code->co_filename);
    const char *name = _PyUnicode_AsString(frame->f_code->co_name);

    fprintf(output_file, "Function: %s:%s\n", filename, name);
    counter++;

    return _PyEval_EvalFrameDefault(frame, throwflag);
}

PyObject *
instru_attach(PyObject *self, PyObject *args, PyObject *kwargs)
{
    const char *keywords[] = {"logfile", NULL};

    PyBytesObject* output_path = PyObject_New(PyBytesObject, &PyBytes_Type);

    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O&", keywords,
                PyUnicode_FSConverter, &output_path)) {
        goto fail;
    }

    char *filename = PyBytes_AsString(output_path);

    if (filename == NULL) {
        goto fail;
    }

    output_file = fopen(filename, "a");

    counter = 0;
    PyThreadState *tstate = PyThreadState_GET();
    tstate->interp->eval_frame = instru_eval_frame;

    Py_RETURN_NONE;

fail:
    Py_XDECREF(output_path);

    // we're assuming some exception was already set
    return NULL;
}

PyObject *
instru_detach(PyObject *self, PyObject *args)
{
    // TODO raise exception if this is called without attach having been
    // called.

    PyThreadState *tstate = PyThreadState_GET();
    tstate->interp->eval_frame = _PyEval_EvalFrameDefault;

    fprintf(output_file, "Functions instrumented: %d\n", counter);
    fclose(output_file);

    Py_RETURN_NONE;
}

static PyMethodDef instru_methods[] = {
    {"attach", instru_attach, METH_VARARGS | METH_KEYWORDS, "Attach the new frame evaluation function."},
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
