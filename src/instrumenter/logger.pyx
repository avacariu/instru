import time

cdef log(int cfg_id, int path_fragment_id, double seconds_elapsed, fd):
    fd.write(f"{cfg_id}\t{path_fragment_id}\t{seconds_elapsed}\n")
