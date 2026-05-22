extends RefCounted
class_name CharacterIdentity

const CAPITAL_COUNTRY_PAIRS: Array[Dictionary] = [
	{"first_name": "Paris", "last_name": "France"},
	{"first_name": "Berlin", "last_name": "Allemagne"},
	{"first_name": "Londres", "last_name": "Royaume-Uni"},
	{"first_name": "Madrid", "last_name": "Espagne"},
	{"first_name": "Rome", "last_name": "Italie"},
	{"first_name": "Lisbonne", "last_name": "Portugal"},
	{"first_name": "Oslo", "last_name": "Norvège"},
	{"first_name": "Stockholm", "last_name": "Suède"},
	{"first_name": "Varsovie", "last_name": "Pologne"},
	{"first_name": "Prague", "last_name": "République tchèque"},
	{"first_name": "Vienne", "last_name": "Autriche"},
	{"first_name": "Bruxelles", "last_name": "Belgique"},
	{"first_name": "Amsterdam", "last_name": "Pays-Bas"},
	{"first_name": "Copenhague", "last_name": "Danemark"},
	{"first_name": "Athènes", "last_name": "Grèce"},
	{"first_name": "Budapest", "last_name": "Hongrie"},
	{"first_name": "Dublin", "last_name": "Irlande"},
	{"first_name": "Helsinki", "last_name": "Finlande"},
]

const RANDOM_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789 "


static func create(rng: RandomNumberGenerator) -> Dictionary:
	var pair: Dictionary = CAPITAL_COUNTRY_PAIRS[rng.randi_range(0, CAPITAL_COUNTRY_PAIRS.size() - 1)]
	return {
		"first_name": pair["first_name"],
		"last_name": pair["last_name"],
		"description": _random_text(rng, 30),
	}


static func _random_text(rng: RandomNumberGenerator, length: int) -> String:
	var result := ""
	for _i in length:
		result += RANDOM_CHARS[rng.randi_range(0, RANDOM_CHARS.length() - 1)]
	return result
