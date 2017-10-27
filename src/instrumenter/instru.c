#include <Python.h>
#include <frameobject.h>
#include <stdlib.h>
#include <stdio.h>

static int counter = 0;
static FILE *output_file = NULL;
static Py_ssize_t co_extra_index = -1;

void *
co_extra_counter_free(void *extra)
{
    free(extra);

    return NULL;
}

int
incr_func_counter(PyCodeObject *code)
{
    // TODO: check for errors
    Py_ssize_t *extra;

    _PyCode_GetExtra((PyObject *) code, co_extra_index, (void **) &extra);

    if (extra == NULL) {
        extra = calloc(1, sizeof(Py_ssize_t));

        _PyCode_SetExtra((PyObject *) code, co_extra_index, extra);
    }

    (*extra)++;

    return 0;
}

Py_ssize_t
get_func_counter(PyCodeObject *code)
{
    Py_ssize_t *extra;

    _PyCode_GetExtra((PyObject *) code, co_extra_index, &extra);

    if (extra == NULL) {
        return 0;
    }

    return *extra;
}

PyObject *
instru_eval_frame(PyFrameObject *frame, int throwflag)
{
    const char *filename = _PyUnicode_AsString(frame->f_code->co_filename);
    const char *name = _PyUnicode_AsString(frame->f_code->co_name);

    // TODO: do this by name in some external dict instead
    incr_func_counter(frame->f_code);

    fprintf(output_file, "Function: %s:%s:%d\n", filename, name,
            get_func_counter(frame->f_code));
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

    if (co_extra_index == -1) {
        co_extra_index = _PyEval_RequestCodeExtraIndex(co_extra_counter_free);
    }

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

    co_extra_index = -1;

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
