extends RefCounted

# Handcrafted layouts in simulation pixels. Every new layout has rotational symmetry.
const MAPS: Dictionary = {
	"silent_wells": {
		"name": "The Silent Wells", "size": Vector2(3072, 2048), "label": "Medium",
		"description": "Six spiritual wells across a contested wasteland.",
		"wells": [Vector2(650, 540), Vector2(2422, 1508), Vector2(550, 1450), Vector2(2522, 598), Vector2(1250, 1450), Vector2(1822, 598)],
		"obstacles": [Rect2(1376, 128, 256, 384), Rect2(1376, 1536, 256, 384), Rect2(1024, 864, 256, 224), Rect2(1792, 960, 256, 224)]
	},
	"ashen_crossing": {
		"name": "Ashen Crossing", "size": Vector2(2304, 1536), "label": "Small",
		"description": "Six wells and a broken central ridge favor quick flanking attacks.",
		"wells": [Vector2(650, 540), Vector2(1654, 996), Vector2(550, 1100), Vector2(1754, 436), Vector2(1100, 350), Vector2(1204, 1186)],
		"obstacles": [Rect2(864, 656, 256, 224), Rect2(1184, 656, 256, 224), Rect2(256, 768, 256, 224), Rect2(1792, 544, 256, 224)]
	},
	"shattered_basin": {
		"name": "Shattered Basin", "size": Vector2(4096, 3072), "label": "Large",
		"description": "Eight wells surround scattered cliffs and broad expansion routes.",
		"wells": [Vector2(650, 540), Vector2(3446, 2532), Vector2(650, 2350), Vector2(3446, 722), Vector2(1600, 1200), Vector2(2496, 1872), Vector2(1450, 2400), Vector2(2646, 672)],
		"obstacles": [Rect2(1856, 320, 256, 384), Rect2(1984, 2368, 256, 384), Rect2(1280, 1600, 256, 224), Rect2(2560, 1248, 256, 224)]
	},
	"frontier_reach": {
		"name": "Frontier Reach", "size": Vector2(5120, 3584), "label": "Huge",
		"description": "Ten widely spaced wells reward scouting and distant outposts.",
		"wells": [Vector2(650, 540), Vector2(4470, 3044), Vector2(700, 2800), Vector2(4420, 784), Vector2(1800, 1100), Vector2(3320, 2484), Vector2(2650, 650), Vector2(2470, 2934), Vector2(2200, 2100), Vector2(2920, 1484)],
		"obstacles": [Rect2(2400, 128, 256, 384), Rect2(2464, 3072, 256, 384), Rect2(1100, 1700, 256, 384), Rect2(3764, 1500, 256, 384), Rect2(2200, 1500, 256, 224), Rect2(2664, 1860, 256, 224)]
	}
}
