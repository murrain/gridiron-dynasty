# RngBox.gd
extends Node

var _rngs: Dictionary = {} # { thread_id : RandomNumberGenerator }

func get_rng() -> RandomNumberGenerator:
	var tid := OS.get_thread_caller_id()
	if not _rngs.has(tid):
		var r := RandomNumberGenerator.new()
		r.randomize()
		_rngs[tid] = r
	return _rngs[tid]
