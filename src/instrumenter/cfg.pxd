from .frame_eval cimport PyCodeObject

cdef class CFG:
    cdef public dict basic_blocks

cdef class BasicBlock:
    cdef public list instructions
    cdef public list successors
    cdef public list predecessors
