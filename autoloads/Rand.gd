# File: res://autoload/Rand.gd
extends Node
## Deterministic, contention-free seed utilities (SplitMix64) + RNG helpers.

# Keep a session base seed (you can override for reproducible runs).
var _base_seed_64: int = 0

func _ready() -> void:
	# Default to a semi-random base at boot; you can override with set_base_seed().
	var t64 := int(Time.get_unix_time_from_system() * 1_000_000.0) ^ int(Time.get_ticks_usec())
	_base_seed_64 = splitmix64(t64)

## Set a known base seed for reproducible runs (e.g., benchmarks/tests).
func set_base_seed(seed64: int) -> void:
	_base_seed_64 = seed64 & 0xFFFFFFFFFFFFFFFF

## Get the current session base seed.
func base_seed() -> int:
	return _base_seed_64

## SplitMix64 mixer — pure arithmetic, thread-safe, deterministic (64-bit).
static func splitmix64(x: int) -> int:
	var z := (x + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9 & 0xFFFFFFFFFFFFFFFF
	z = (z ^ (z >> 27)) * 0x94D049BB133111EB & 0xFFFFFFFFFFFFFFFF
	return (z ^ (z >> 31)) & 0xFFFFFFFFFFFFFFFF

## Derive N unique 64-bit seeds from the current base (or an override).
func derive_seeds(count: int, base_override: int = -1) -> PackedInt64Array:
	var base := _base_seed_64 if base_override == -1 else (base_override & 0xFFFFFFFFFFFFFFFF)
	var out: PackedInt64Array = PackedInt64Array()
	out.resize(count)
	for i in count:
		# Different stream per i
		out[i] = splitmix64(base + i)
	return out

## Convenience: make a RandomNumberGenerator set to a given 64-bit seed.
static func rng_for_seed(seed64: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	# Godot RNG `seed` is 64-bit in 4.x; mask to be safe.
	rng.seed = seed64 & 0xFFFFFFFFFFFFFFFF
	return rng

## Convenience: RNG for an index from base (or current base).
func rng_for_index(i: int, base_override: int = -1) -> RandomNumberGenerator:
	var base := _base_seed_64 if base_override == -1 else (base_override & 0xFFFFFFFFFFFFFFFF)
	return rng_for_seed(splitmix64(base + i))
