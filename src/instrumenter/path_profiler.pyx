import dis
import itertools


block_ops = {
    dis.opmap['SETUP_LOOP'],
    dis.opmap['SETUP_EXCEPT'],
    dis.opmap['SETUP_FINALLY'],
    dis.opmap['SETUP_WITH'],
}

EXTENDED_ARG = dis.opmap['EXTENDED_ARG']


def assign_values_to_edges(cfg):
    num_paths = {}
    edge_values = {}

    for bb in reversed(cfg.topological()):
        if bb.is_exit:
            num_paths[bb.offset] = 1
        else:
            num_paths[bb.offset] = 0

            for succ in bb.successors:
                edge_values[bb.offset, succ] = num_paths[bb.offset]

                num_paths[bb.offset] += num_paths[succ]

    return edge_values


def recover_path(cfg, edge_values, path_val):
    path = []
    bb_offset = 0

    def next_bb(bb, path_val):
        candidates = filter(lambda b: edge_values[bb.offset, b] <= path_val, bb.successors)
        return max(candidates, key=lambda b: edge_values[bb.offset, b])

    while path_val >= 0 and bb_offset != -1:
        bb = cfg[bb_offset]
        path.append(bb)

        next_bb_offset = next_bb(bb, path_val)
        path_val -= edge_values[bb_offset, next_bb_offset]
        bb_offset = next_bb_offset

    assert path_val == 0

    return path


def prepend_extended_args(instr, arg):
    if arg <= 255:
        return [(instr, arg)]

    else:
        extended_args = prepend_extended_args(EXTENDED_ARG, arg >> 8)

        if instr in dis.hasjrel + dis.hasjabs:
            # this is used in case the updated jump target argument is > 255
            extended_args = [(EXTENDED_ARG, 0)] + extended_args

        return extended_args + [(instr, arg & 255)]


def update_extended_args(code_list, new_last_arg):
    new_code = prepend_extended_args(code_list[-1][0], new_last_arg)

    total_arg = 0

    for instr, arg in code_list:
        total_arg = (total_arg << 8) | arg

    if len(new_code) == len(code_list) + 1:
        assert new_code[0][1] == 0

    return new_code[-len(code_list):]


def insert_extended_args(code_list):
    """
    Insert EXTENDED_ARG instructions.

    This is done in 2 passes:
        1. Create new EXTENDED_ARG instructions where necessary, keeping track
           of the number of such instructions necessary for each original
           instruction.
        2. Insert new EXTENDED_ARG instructions, and update jump targets.
    """

    num_prefixes = [0] * len(code_list)

    for i in range(0, len(code_list), 2):
        instr, arg = code_list[i:i+2]

        new_instrs = prepend_extended_args(instr, arg)
        num_prefixes[i] = len(new_instrs) - 1

    for i in range(0, len(code_list), 2):
        instr, arg = code_list[i:i+2]

        if instr in dis.hasjrel:
            new_arg = arg - num_prefixes[i+arg] + 2*sum(num_prefixes[i:i+arg])
        elif instr in dis.hasjabs:
            new_arg = arg - num_prefixes[arg] + 2*sum(num_prefixes[:arg])
        else:
            new_arg = arg

        # NOTE: we need to strip off any empty EXTENDED_ARG instructions that
        # are inserted in here, but weren't in the previous version
        for instr, arg in prepend_extended_args(instr, new_arg)[-(num_prefixes[i]+1):]:
            yield instr, arg


def instrument(co_code, code_to_insert, int incr_code_size, edge_values):
    new_code = []
    ext_arg = 0
    code_to_insert = list(code_to_insert)

    num_ext_args = [0] * len(co_code)
    ext_args_for = float('inf')

    for i in range(len(co_code)-2, -2, -2):
        instr, arg = co_code[i:i+2]

        if instr == EXTENDED_ARG:
            num_ext_args[ext_args_for] += 1
        else:
            ext_args_for = i

    for i in range(0, len(co_code), 2):
        # NOTE: we're reversing this so that the JUMP_FORWARD targets are
        # correct since we computed them by seeing how many instrumentation
        # blocks we've added so far
        for co_offset, co_new, incr_value in code_to_insert:
            if co_offset == i:
                new_code.extend(co_new)

        instr, arg = co_code[i:i+2]

        if instr == EXTENDED_ARG:
            ext_arg = (ext_arg << 8) | arg
            continue
        else:
            arg |= ext_arg << 8
            ext_arg = 0

        if instr in block_ops:
            arg += sum(len(b) for o, b, _ in code_to_insert if i+2 <= o <= (i+arg))

        if instr in dis.hasjrel + dis.hasjabs:
            if instr in dis.hasjrel:
                adjust_start = i+2
                edge = (i, i+arg)
            else:
                adjust_start = 0
                edge = (i, arg)

            # everything up to but not including the instrumentation on the
            # jump target
            arg_incr = sum(len(b) for o, b, _ in code_to_insert if adjust_start <= o < edge[1])

            # now we compute the bit of instrumentation we should jump to
            for co_offset, co_new, incr_value in code_to_insert:
                if co_offset == edge[1]:
                    if edge_values[edge] == incr_value:
                        break

                    arg_incr += len(co_new)

            arg += arg_incr
            arg -= sum(num_ext_args[adjust_start:edge[1]]) * 2

        new_code.extend([instr, arg])

    new_code = itertools.chain.from_iterable(insert_extended_args(new_code))

    return bytes(new_code)
