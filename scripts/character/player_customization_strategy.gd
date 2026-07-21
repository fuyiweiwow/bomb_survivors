class_name PlayerCustomizationStrategy
extends RefCounted

const PRESET_ORDER := ["xiami", "fox", "titan", "asha", "maria", "monkey", "blue", "red"]
const BODY_TYPE_ORDER := ["standard", "slim", "sturdy", "runner"]

const PRESETS := {
	"blue": {
		"label": "Blue",
		"gender": "male",
		"body_type": "standard",
		"body_color": "#2E7AF2",
		"visor_color": "#33D9FF",
		"accent_color": "#F2F2F2",
		"theme": "pilot",
		"source_hero": "",
	},
	"red": {
		"label": "Red",
		"gender": "female",
		"body_type": "slim",
		"body_color": "#F24438",
		"visor_color": "#FF9440",
		"accent_color": "#FFE1B8",
		"theme": "pilot",
		"source_hero": "",
	},
	"xiami": {
		"label": "Xiami",
		"gender": "male",
		"body_type": "runner",
		"body_color": "#2E7AF2",
		"visor_color": "#F6E6C8",
		"accent_color": "#F24438",
		"theme": "scarf",
		"source_hero": "BomboAdvanture/original/game/hero/Xiami.json",
	},
	"fox": {
		"label": "Fox",
		"gender": "female",
		"body_type": "runner",
		"body_color": "#F26B2E",
		"visor_color": "#FFE6B3",
		"accent_color": "#FFFFFF",
		"theme": "fox",
		"source_hero": "BomboAdvanture/original/game/hero/Fox.json",
	},
	"titan": {
		"label": "Titan",
		"gender": "male",
		"body_type": "sturdy",
		"body_color": "#5C6E7E",
		"visor_color": "#82F7FF",
		"accent_color": "#F2C94C",
		"theme": "titan",
		"source_hero": "BomboAdvanture/original/game/hero/Titan.json",
	},
	"asha": {
		"label": "Asha",
		"gender": "female",
		"body_type": "slim",
		"body_color": "#8E5CF2",
		"visor_color": "#FFE66D",
		"accent_color": "#FF66A8",
		"theme": "firework",
		"source_hero": "BomboAdvanture/original/game/hero/Asha.json",
	},
	"maria": {
		"label": "Maria",
		"gender": "female",
		"body_type": "standard",
		"body_color": "#30B7A7",
		"visor_color": "#F8F4E8",
		"accent_color": "#FFD166",
		"theme": "healer",
		"source_hero": "BomboAdvanture/original/game/hero/Maria.json",
	},
	"monkey": {
		"label": "Monkey",
		"gender": "male",
		"body_type": "runner",
		"body_color": "#B96D3A",
		"visor_color": "#FFD7A1",
		"accent_color": "#F2C94C",
		"theme": "monkey",
		"source_hero": "BomboAdvanture/original/game/hero/Monkey.json",
	},
}

const BODY_TYPES := {
	"standard": {"radius": 0.35, "height": 1.05, "body_y": 0.62, "visor_y": 0.82, "visor_w": 0.46},
	"slim": {"radius": 0.31, "height": 0.98, "body_y": 0.58, "visor_y": 0.78, "visor_w": 0.52},
	"sturdy": {"radius": 0.38, "height": 1.10, "body_y": 0.64, "visor_y": 0.84, "visor_w": 0.54},
	"runner": {"radius": 0.32, "height": 1.02, "body_y": 0.60, "visor_y": 0.80, "visor_w": 0.48},
}

static func default_config() -> Dictionary:
	var preset := preset_data("xiami")
	return {
		"gender": preset["gender"],
		"character_preset": "xiami",
		"body_type": preset["body_type"],
		"body_color": preset["body_color"],
		"visor_color": preset["visor_color"],
		"accent_color": preset["accent_color"],
		"theme": preset["theme"],
		"source_hero": preset["source_hero"],
	}

static func sanitize_config(raw_config: Variant) -> Dictionary:
	var config := default_config()
	if not raw_config is Dictionary:
		return config
	var source := raw_config as Dictionary
	var requested_preset := str(source.get("character_preset", ""))
	if requested_preset.is_empty() and source.has("gender"):
		requested_preset = "red" if str(source.get("gender", "")) == "female" else "blue"
	if PRESETS.has(requested_preset):
		config["character_preset"] = requested_preset
		var preset := preset_data(requested_preset)
		config["gender"] = preset["gender"]
		config["body_type"] = preset["body_type"]
		config["body_color"] = preset["body_color"]
		config["visor_color"] = preset["visor_color"]
		config["accent_color"] = preset["accent_color"]
		config["theme"] = preset["theme"]
		config["source_hero"] = preset["source_hero"]

	var gender := str(source.get("gender", config["gender"]))
	config["gender"] = gender if gender in ["male", "female"] else config["gender"]
	var body_type := str(source.get("body_type", config["body_type"]))
	config["body_type"] = body_type if BODY_TYPES.has(body_type) else config["body_type"]
	config["body_color"] = normalized_color_string(source.get("body_color", config["body_color"]), str(config["body_color"]))
	config["visor_color"] = normalized_color_string(source.get("visor_color", config["visor_color"]), str(config["visor_color"]))
	config["accent_color"] = normalized_color_string(source.get("accent_color", config["accent_color"]), str(config["accent_color"]))
	return config

static func preset_data(preset_id: String) -> Dictionary:
	return (PRESETS.get(preset_id, PRESETS["blue"]) as Dictionary).duplicate(true)

static func preset_label(preset_id: String) -> String:
	return str(preset_data(preset_id).get("label", preset_id.capitalize()))

static func style_data(config_or_style: Variant) -> Dictionary:
	if config_or_style is Dictionary:
		var config := sanitize_config(config_or_style)
		var base := (BODY_TYPES[str(config["body_type"])] as Dictionary).duplicate(true)
		base["body_color"] = color_from_string(str(config["body_color"]), Color(0.18, 0.48, 0.95))
		base["visor_color"] = color_from_string(str(config["visor_color"]), Color(0.2, 0.85, 1.0))
		base["accent_color"] = color_from_string(str(config["accent_color"]), Color(1.0, 1.0, 1.0))
		base["theme"] = str(config["theme"])
		base["source_hero"] = str(config["source_hero"])
		base["style_id"] = str(config["body_type"])
		return base
	match str(config_or_style):
		"female":
			var red := sanitize_config({"character_preset": "red"})
			return style_data(red)
		"ai":
			return {"radius": 0.36, "height": 1.08, "body_y": 0.63, "visor_y": 0.83, "visor_w": 0.48, "body_color": Color(0.35, 0.36, 0.39), "visor_color": Color(0.02, 0.03, 0.04), "accent_color": Color(0.62, 0.64, 0.70), "theme": "pilot", "source_hero": "", "style_id": "ai"}
		"boss":
			return {"radius": 0.40, "height": 1.18, "body_y": 0.68, "visor_y": 0.90, "visor_w": 0.56, "body_color": Color(0.42, 0.20, 0.12), "visor_color": Color(1.0, 0.82, 0.18), "accent_color": Color(0.92, 0.18, 0.10), "theme": "titan", "source_hero": "", "style_id": "boss"}
		_:
			var blue := sanitize_config({"character_preset": "blue"})
			return style_data(blue)

static func style_id(config_or_style: Variant) -> String:
	return str(style_data(config_or_style).get("style_id", "standard"))

static func color_from_string(value: String, fallback: Color) -> Color:
	return Color.from_string(value, fallback)

static func normalized_color_string(value: Variant, fallback: String) -> String:
	var color := color_from_string(str(value), color_from_string(fallback, Color.WHITE))
	return "#" + color.to_html(false)
