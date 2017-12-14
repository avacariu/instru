import dis


block_ops = {
    dis.opmap['SETUP_LOOP'],
    dis.opmap['SETUP_EXCEPT'],
    dis.opmap['SETUP_FINALLY'],
    dis.opmap['SETUP_WITH'],
}


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


def instrument(co_code, code_to_insert, int incr_code_size, edge_values):
    new_code = []

    for i in range(0, len(co_code), 2):
        # NOTE: we're reversing this so that the JUMP_FORWARD targets are
        # correct since we computed them by seeing how many instrumentation
        # blocks we've added so far
        for co_offset, co_new, incr_value in reversed(code_to_insert):
            if co_offset == i:
                new_code.extend(co_new)

        instr, arg = co_code[i:i+2]

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
            for co_offset, co_new, incr_value in reversed(code_to_insert):
                if co_offset == edge[1]:
                    if edge_values[edge] == incr_value:
                        break

                    arg_incr += len(co_new)

            arg += arg_incr

        new_code.extend([instr, arg])

    return bytes(new_code)
