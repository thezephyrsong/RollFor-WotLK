RollFor = RollFor or {}
local m = RollFor

if m.BossList then return end

---@class BossList
---@field zones table<string, string[]>

local M    = {}

M.zones    = {
  [ "Durotar" ] = {
    "Elder Mottled Boar"
  },
  [ "Zul'Gurub" ] = {
    "High Priestess Jeklik",
    "High Priest Venoxis",
    "Witherbark Speaker",
    "High Priestess Mar'li",
    "Vilebranch Speaker",
    "Broodlord Mandokir",
    "Ohgan",
    "Gri'lek",
    "Hazza'rah",
    "Renataki",
    "Wushoolay",
    "Gahz'ranka",
    "High Priest Thekal",
    "Zealot Zath",
    "Zealot Lor'Khan",
    "High Priestess Arlokk",
    "Jin'do the Hexxer",
    "Hakkar"
  },
  [ "Ruins of Ahn'Qiraj" ] = {
    "Kurinnaxx",
    "General Rajaxx",
    "Moam",
    "Buru the Gorger",
    "Ayamiss the Hunter",
    "Ossirian the Unscarred"
  },
  [ "Molten Core" ] = {
    "Incindis",
    "Basalthar",
    "Smoldaris",
    "Sorcerer-Thane Thaurissan",
    "Lucifron",
    "Magmadar",
    "Gehennas",
    "Garr",
    "Shazzrah",
    "Baron Geddon",
    "Golemagg the Incinerator",
    "Sulfuron Harbinger",
    "Majordomo Executus",
    "Ragnaros"
  },
  [ "Blackwing Lair" ] = {
    "Ezzel Darkbrewer",
    "Razorgore the Untamed",
    "Vaelastrasz the Corrupt",
    "Broodlord Lashlayer",
    "Firemaw",
    "Ebonroc",
    "Flamegor",
    "Chromaggus",
    "Nefarian"
  },
  [ "Onyxia's Lair" ] = {
	"Onyxia",
	"Broodcommander Axelus",
	"Atressian",
	"Ortorg the Ardent"
  },
  [ "Ahn'Qiraj" ] = {
    "The Prophet Skeram",
    "Vem",
    "Lord Kri",
    "Princess Yauj",
    "Battleguard Sartura",
    "Fankriss the Unyielding",
    "Viscidus",
    "Princess Huhuran",
    "Emperor Vek'lor",
    "Emperor Vek'nilash",
    "Ouro",
    "C'Thun"
  },
  [ "Naxxramas" ] = {
    "Patchwerk",
    "Grobbulus",
    "Gluth",
    "Thaddius",
    "Anub'Rekhan",
    "Grand Widow Faerlina",
    "Maexxna",
    "Noth the Plaguebringer",
    "Heigan the Unclean",
    "Loatheb",
    "Instructor Razuvious",
    "Gothik the Harvester",
    "Thane Korth'azz",
    "Lady Blaumeux",
    "Highlord Mograine",
    "Sir Zeliek",
    "Sapphiron",
    "Kel'Thuzad"
  },
  -- Zone keys below are unverified -- Ascension has been known to split or
  -- rename instance zone text (see "Tower of Karazhan" / "Lower Karazhan
  -- Halls" above, a custom low-level Karazhan distinct from the endgame one
  -- below). Confirm each key with /dump GetRealZoneText() in-game and fix
  -- the key if it doesn't match.
  [ "Karazhan" ] = {
    "Attumen the Huntsman",
    "Moroes",
    "Maiden of Virtue",
    "Opera Event",
    "The Curator",
    "Shade of Aran",
    "Netherspite",
    "Chess Event",
    "Prince Malchezaar"
  },
  [ "Gruul's Lair" ] = {
    "High King Maulgar",
    "Gruul the Dragonkiller"
  },
  [ "Magtheridon's Lair" ] = {
    "Magtheridon"
  },
  [ "Serpentshrine Cavern" ] = {
    "Hydross the Unstable",
    "The Lurker Below",
    "Leotheras the Blind",
    "Fathom-Lord Karathress",
    "Morogrim Tidewalker",
    "Lady Vashj"
  },
  [ "Tempest Keep" ] = {
    "Al'ar",
    "Void Reaver",
    "High Astromancer Solarian",
    "Kael'thas Sunstrider"
  },
  [ "Zul'Aman" ] = {
    "Akil'zon",
    "Nalorakk",
    "Jan'alai",
    "Halazzi",
    "Hex Lord Malacrass",
    "Zul'jin"
  },
  [ "Black Temple" ] = {
    "High Warlord Naj'entus",
    "Supremus",
    "Shade of Akama",
    "Teron Gorefiend",
    "Gurtogg Bloodboil",
    "Reliquary of Souls",
    "Mother Shahraz",
    "The Illidari Council",
    "Illidan Stormrage"
  },
  [ "Sunwell Plateau" ] = {
    "Kalecgos",
    "Brutallus",
    "Felmyst",
    "Eredar Twins",
    "M'uru",
    "Kil'jaeden"
  },
  [ "Ulduar" ] = {
    "Flame Leviathan",
    "Ignis the Furnace Master",
    "Razorscale",
    "XT-002 Deconstructor",
    "Steelbreaker",
    "Runemaster Molgeim",
    "Stormcaller Brundir",
    "Kologarn",
    "Auriaya",
    "Hodir",
    "Thorim",
    "Freya",
    "Mimiron",
    "General Vezax",
    "Yogg-Saron",
    "Algalon the Observer"
  },
  [ "Trial of the Crusader" ] = {
    "Northrend Beasts",
    "Lord Jaraxxus",
    "Faction Champions",
    "Val'kyr Twins",
    "Anub'arak"
  },
  [ "Icecrown Citadel" ] = {
    "Lord Marrowgar",
    "Lady Deathwhisper",
    "Gunship Battle",
    "Deathbringer Saurfang",
    "Festergut",
    "Rotface",
    "Professor Putricide",
    "Blood Prince Council",
    "Blood-Queen Lana'thel",
    "Valithria Dreamwalker",
    "Sindragosa",
    "The Lich King"
  }
}

---@type BossList
m.BossList = M
return M