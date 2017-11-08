from .frame_eval cimport PyCodeObject
import dis


cdef set _jump_bytecodes = set(dis.hasjrel) | set(dis.hasjabs)

cdef set _conditional_jumps = {
    'POP_JUMP_IF_TRUE',
    'POP_JUMP_IF_FALSE',
    'JUMP_IF_TRUE_OR_POP',
    'JUMP_IF_FALSE_OR_OP',
}

cdef int bytecode_instr_size = 2


cdef bint _is_jump(instr):
    return instr.opcode in _jump_bytecodes


cdef class CFG:
    def __init__(self, object code):
        bytecode = dis.Bytecode(code)

        basic_blocks = {}

        bb = BasicBlock()

        for instr in bytecode:
            if not bb or not _is_jump(instr):
                bb.instructions.append(instr)
                continue

            bb.instructions.append(instr)

            if instr.opname in _conditional_jumps:
                bb.successors.append(instr.offset + bytecode_instr_size)

            bb.successors.append(instr.argval)

            basic_blocks[bb.instructions[0].offset] = bb

            bb = BasicBlock()

        if bb:
            basic_blocks[bb.instructions[0].offset] = bb

        self.basic_blocks = basic_blocks


cdef class BasicBlock:
    def __cinit__(self, list instructions=None, list successors=None,
                  list predecessors=None):
        self.instructions = instructions or []
        self.successors = successors or []
        self.predecessors = predecessors or []

    @property
    def is_entry(self):
        if self.predecessors:
            return False
        return True

    def __bool__(self):
        return bool(self.instructions)

    def __iter__(self):
        return iter(self.instructions)
